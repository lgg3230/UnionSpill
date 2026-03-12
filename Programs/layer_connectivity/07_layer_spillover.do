********************************************************************************
* UNION SPILLOVERS — LAYER-LEVEL SPILLOVER EFFECTS
* Purpose: Test spillover effects on firm×layer×year outcomes using the
*          layer-specific connectivity to treated firms as the treatment variable.
*          Identifies within-firm cross-layer variation in spillover transmission.
*
* Layers:  edu  (3-bin: 0_no_hs / 1_hs / 2_higher)
*          edu2 (2-bin: no_hs / has_hs)
*
* Main FE: identificad × year  — absorbs all firm-level controls
* Other FE (layer-level, vary within firm×year):
*          outcome_pre4 × year, l_layer_emp_pre4 × year,
*          layer_totalflows_pw_pre4 × year
*
* Output:  Tables/layer_connectivity/results_spill_layer_{edu,edu2}_layer_spill.csv
*          Graphs/layer_connectivity/es_{outcome}_spill_{layer}_{date}.pdf
********************************************************************************

********************************************************************************
* SECTION 1: PATHS & GLOBALS
* Must come first — log using needs $logs before anything else
********************************************************************************

* ── Set globals (safe to set unconditionally — same values as 00_master.do) ──
global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/layer_spillover_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

global layer_data "$main/UnionSpill/Data/layer_connectivity"
local  spec       "layer_spill"

********************************************************************************
* SECTION 2: LOOP OVER LAYER DEFINITIONS
********************************************************************************

foreach layer in edu edu2 {

	di _newline(2)
	di as result "======================================================================="
	di as result "LAYER: `layer'"
	di as result "======================================================================="

	* ── 2a. Load outcomes (firm × layer × year) ──────────────────────────────
	use "$layer_data/firm_layer_outcomes_`layer'.dta", clear
	keep if year >= 2009

	count
	di as result "  Observations loaded: `r(N)'"

	* Create numeric firm ID for interaction FE
	cap drop firm_id
	egen firm_id = group(identificad)

	* ── 2b. Merge connectivity (firm × layer, time-invariant pre-treatment) ──
	di as result "Merging layer connectivity..."
	merge m:1 identificad layer_id using ///
		"$layer_data/final_measures/firm_layer_connectivity_edu2.dta", ///
		keep(master match) nogen

	count
	di as result "  After connectivity merge: `r(N)'"

	* ── 2c. Merge firm-level controls (firm × year) ──────────────────────────
	di as result "Merging firm-level controls..."
	merge m:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
		          industry1 mode_base_month microregion) ///
		keep(master match) nogen

	count
	di as result "  After firm merge: `r(N)'"

	* ── Encode firm-level categorical FE variables (needed for cross-firm spec) ─
	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	* ── 2d. Sample restriction ───────────────────────────────────────────────
	keep if lagos_sample_avg == 1

	count
	di as result "  After sample restriction (lagos_sample_avg==1): `r(N)'"

	****************************************************************************
	* SECTION 2e: VARIABLE CREATION
	****************************************************************************

	* ── Treatment period indicators ──────────────────────────────────────────
	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	label var treat_year "Post-treatment period (year >= 2012)"

	cap drop placebo_year
	gen byte placebo_year = (year < 2011)
	label var placebo_year "Pre-treatment placebo (year < 2011)"

	* ── Layer connectivity scaling ───────────────────────────────────────────
	* Scale layer_treat_pw_n to P90 of untreated balanced-panel firms at 2009.
	* layer_conn_norm varies across layers within the same firm × year.
	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

	cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity to treated (scaled to P90)"

	* ── Pre-treatment layer-level outcome averages ───────────────────────────
	* Computed within firm × layer, so they vary across layers within a firm.
	* NOT absorbed by firm×year FE — used as additional within-firm controls.
	foreach v in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {
		cap drop `v'_pre_o
		cap drop `v'_pre
		bys identificad layer_id: ///
			egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad layer_id: ///
			egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o

		* 4-bin controls (balanced-panel firms at 2009, then propagate to all years)
		cap drop `v'_pre4_o
		cap drop `v'_pre4
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad layer_id: ///
			egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}

	* ── Layer-level totalflows bins ──────────────────────────────────────────
	* totalflows_layer_pw_n: layer-specific movers per worker (pre-treatment avg).
	* Must exist in firm_layer_connectivity_{layer}.dta (requires pipeline re-run).
	capture confirm variable totalflows_layer_pw_n
	if _rc {
		di as error "WARNING: totalflows_layer_pw_n not found — using zero bins."
		gen byte layer_totalflows_pw_pre4 = 0
	}
	else {
		cap drop layer_totalflows_pw_pre4_o
		cap drop layer_totalflows_pw_pre4
		egen layer_totalflows_pw_pre4_o = cut(totalflows_layer_pw_n) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad layer_id: ///
			egen layer_totalflows_pw_pre4 = min(layer_totalflows_pw_pre4_o)
		drop layer_totalflows_pw_pre4_o
		replace layer_totalflows_pw_pre4 = 0 if missing(layer_totalflows_pw_pre4)
	}

	di as result "All variables created."

	****************************************************************************
	* SECTION 2f: FE AND SPEC MACROS
	****************************************************************************

	local conn       "layer_conn_norm"
	local base_fe    "i.identificad#i.year"
	local extra_year "ib0.layer_totalflows_pw_pre4#i.year"

	****************************************************************************
	* SECTION 2g: INITIALIZE OUTPUT CSV
	****************************************************************************

	local csv_out "$tables/layer_connectivity/results_spill_layer_`layer'_`spec'.csv"
	capture erase "`csv_out'"
	tempname fh
	file open  `fh' using "`csv_out'", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'

	di as result "Output CSV: `csv_out'"

	****************************************************************************
	* SECTION 2h: SPILLOVER REGRESSIONS
	****************************************************************************

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "SPILLOVER REGRESSIONS — layer: `layer'"
	di as result "-----------------------------------------------------------------------"

	foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

		di as text "  Estimating: `outcome' (layer: `layer')"

		local absorb ///
			"`base_fe' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"

		* ── Post-treatment spillover ─────────────────────────────────────────
		reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_year#c.`conn']
		local se_post = _se[1.treat_year#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_firms = e(N_clust)

		* ── Pre-treatment placebo ────────────────────────────────────────────
		reghdfe `outcome' c.`conn'##i.placebo_year ///
			if `s_spill' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.placebo_year#c.`conn']
		local se_pre = _se[1.placebo_year#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* ── Stars ────────────────────────────────────────────────────────────
		local stars_post ""
		if `p_post' < 0.01                             local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)   local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)   local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                              local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)     local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)     local stars_pre "*"

		* ── Event study (pre-trend F-test + plot) ────────────────────────────
		reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)

		testparm c.`conn'#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* ── Count unique firm×layer cells in estimation sample ───────────────
		tempvar in_samp cell_first
		gen byte `in_samp'   = e(sample)
		bys identificad layer_id (`in_samp'): ///
			gen byte `cell_first' = (_n == 1 & `in_samp' == 1)
		qui count if `cell_first' == 1
		local n_cells = r(N)
		cap drop `in_samp'
		cap drop `cell_first'

		* ── Write to CSV ─────────────────────────────────────────────────────
		tempname fh
		file open  `fh' using "`csv_out'", write append
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"main";"'    %9.4f (`b_post')         `"`stars_post'""' _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post')        `"""'             _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"pre";"'     %9.4f (`b_pre')          `"`stars_pre'""'  _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre')         `"""'             _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')        `"""'             _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"n_firms";"' %12.0fc (`n_firms')      `"""'             _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"n_cells";"' %12.0fc (`n_cells')      `"""'             _n
		file write `fh' `""spill_`layer'";"spill";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval') `"""'             _n
		file close `fh'

		* ── Event study plot ─────────────────────────────────────────────────
		estimates store _es_tmp
		local post_coef_s = string(`b_post',         "%9.4f")
		local post_se_s   = string(`se_post',        "%9.4f")
		local pre_pval_s  = string(`pre_ftest_pval', "%9.3f")

		coefplot _es_tmp, ///
			keep(*#c.`conn') ///
			msymbol(diamond) ///
			coeflabels(2009.year#c.`conn' = "2009" ///
			           2010.year#c.`conn' = "2010" ///
			           2011.year#c.`conn' = "2011" ///
			           2012.year#c.`conn' = "2012" ///
			           2013.year#c.`conn' = "2013" ///
			           2014.year#c.`conn' = "2014" ///
			           2015.year#c.`conn' = "2015" ///
			           2016.year#c.`conn' = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ytitle("Spillover coefficients (layer × connectivity)", size(small)) ///
			note("Pre-trend F-test p = `pre_pval_s'  |  Post: `post_coef_s' (`post_se_s')") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

		graph export "$graphs/layer_connectivity/es_`outcome'_spill_`layer'_`d'.pdf", ///
			as(pdf) replace

		estimates drop _es_tmp

		di as result "  Done: `outcome' (layer: `layer')"
	}

	****************************************************************************
	* SECTION 2j: CROSS-FIRM SPEC (micro×year + industry×year + mode×year FE)
	* Same layer connectivity treatment but no firm×year FE.
	* Identification from cross-firm variation in layer-specific connectivity.
	****************************************************************************

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "CROSS-FIRM SPEC — layer: `layer'"
	di as result "-----------------------------------------------------------------------"

	local base_fe_cross "i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"

	local csv_cross "$tables/layer_connectivity/results_spill_layer_cross_`layer'_`spec'.csv"
	capture erase "`csv_cross'"
	tempname fhx
	file open  `fhx' using "`csv_cross'", write replace
	file write `fhx' "spec,section,outcome,row_type,value" _n
	file close `fhx'

	di as result "Output CSV: `csv_cross'"

	foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

		di as text "  Estimating (cross-firm): `outcome' (layer: `layer')"

		local absorb_cross ///
			"`base_fe_cross' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"

		* Post-treatment spillover
		reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
			absorb(`absorb_cross') vce(cluster identificad)

		local b_post_x  = _b[1.treat_year#c.`conn']
		local se_post_x = _se[1.treat_year#c.`conn']
		local p_post_x  = 2*ttail(e(df_r), abs(`b_post_x'/`se_post_x'))
		local n_obs_x   = e(N)
		local n_firms_x = e(N_clust)

		* Pre-treatment placebo
		reghdfe `outcome' c.`conn'##i.placebo_year ///
			if `s_spill' & year <= 2011, ///
			absorb(`absorb_cross') vce(cluster identificad)

		local b_pre_x  = _b[1.placebo_year#c.`conn']
		local se_pre_x = _se[1.placebo_year#c.`conn']
		local p_pre_x  = 2*ttail(e(df_r), abs(`b_pre_x'/`se_pre_x'))

		* Stars
		local stars_post_x ""
		if `p_post_x' < 0.01                               local stars_post_x "***"
		else if (`p_post_x' < 0.05 & `p_post_x' > 0.01)   local stars_post_x "**"
		else if (`p_post_x' < 0.10 & `p_post_x' > 0.05)   local stars_post_x "*"

		local stars_pre_x ""
		if `p_pre_x' < 0.01                                local stars_pre_x "***"
		else if (`p_pre_x' < 0.05 & `p_pre_x' > 0.01)     local stars_pre_x "**"
		else if (`p_pre_x' < 0.10 & `p_pre_x' > 0.05)     local stars_pre_x "*"

		* Event study (pre-trend F-test + plot)
		reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
			absorb(`absorb_cross') vce(cluster identificad)

		testparm c.`conn'#i(2009 2010).year
		local pre_ftest_pval_x = r(p)

		* Count unique firm×layer cells
		tempvar in_samp_x cell_first_x
		gen byte `in_samp_x'   = e(sample)
		bys identificad layer_id (`in_samp_x'): ///
			gen byte `cell_first_x' = (_n == 1 & `in_samp_x' == 1)
		qui count if `cell_first_x' == 1
		local n_cells_x = r(N)
		cap drop `in_samp_x'
		cap drop `cell_first_x'

		* Write to CSV
		tempname fhx
		file open  `fhx' using "`csv_cross'", write append
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"main";"'    %9.4f (`b_post_x')          `"`stars_post_x'""' _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"main_se";"' %9.4f (`se_post_x')         `"""'              _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"pre";"'     %9.4f (`b_pre_x')           `"`stars_pre_x'""' _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"pre_se";"'  %9.4f (`se_pre_x')          `"""'              _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"n_obs";"'   %12.0fc (`n_obs_x')         `"""'              _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"n_firms";"' %12.0fc (`n_firms_x')       `"""'              _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"n_cells";"' %12.0fc (`n_cells_x')       `"""'              _n
		file write `fhx' `""cross_`layer'";"cross";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval_x')  `"""'              _n
		file close `fhx'

		* Event study plot
		estimates store _es_x_tmp
		local post_coef_s_x = string(`b_post_x',         "%9.4f")
		local post_se_s_x   = string(`se_post_x',        "%9.4f")
		local pre_pval_s_x  = string(`pre_ftest_pval_x', "%9.3f")

		coefplot _es_x_tmp, ///
			keep(*#c.`conn') ///
			msymbol(diamond) ///
			coeflabels(2009.year#c.`conn' = "2009" ///
			           2010.year#c.`conn' = "2010" ///
			           2011.year#c.`conn' = "2011" ///
			           2012.year#c.`conn' = "2012" ///
			           2013.year#c.`conn' = "2013" ///
			           2014.year#c.`conn' = "2014" ///
			           2015.year#c.`conn' = "2015" ///
			           2016.year#c.`conn' = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ytitle("Spillover coefs (cross-firm, layer × connectivity)", size(small)) ///
			note("Pre-trend F-test p = `pre_pval_s_x'  |  Post: `post_coef_s_x' (`post_se_s_x')") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

		graph export "$graphs/layer_connectivity/es_`outcome'_cross_`layer'_`d'.pdf", ///
			as(pdf) replace

		estimates drop _es_x_tmp

		di as result "  Done (cross-firm): `outcome' (layer: `layer')"
	}

	di as result "Cross-firm spec for `layer' complete. Results in `csv_cross'"

	****************************************************************************
	* SECTION 2i: FIRM-LEVEL RESTRICTED SPEC
	* Run standard firm-level spillover restricted to firms in the layer sample.
	* Isolates whether layer null results reflect identification or sample selection.
	****************************************************************************

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "FIRM-LEVEL RESTRICTED SPEC — layer: `layer'"
	di as result "-----------------------------------------------------------------------"

	* ── Identify restricted firm set from current layer data ─────────────
	* Keep unique firms satisfying s_spill with non-missing layer connectivity.
	local s_spill "treat_ultra==0 & in_balanced_panel==1 & lagos_sample_avg==1"
	tempfile restr_firms
	keep if (`s_spill') & !missing(layer_treat_pw_n)
	keep identificad
	duplicates drop
	count
	di as result "  Restricted sample: `r(N)' unique firms (non-missing layer connectivity)"
	save `restr_firms'

	* ── Load totalflows pre-treatment year-pair data ──────────────────────
	* stringcols(1): force identificad to be read as string (prevents type mismatch)
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
	tempfile tfwide
	save `tfwide'

	* ── Load firm-level panel ─────────────────────────────────────────────
	use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
	keep if year >= 2009
	merge m:1 identificad using `tfwide', keep(master match) nogen
	merge m:1 identificad using `restr_firms', keep(match) nogen
	keep if lagos_sample_avg == 1

	count
	di as result "  Firm-panel obs after restriction: `r(N)'"

	* ── Encode categorical FE variables ──────────────────────────────────
	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	* ── Treatment period indicators ──────────────────────────────────────
	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	cap drop placebo_year
	gen byte placebo_year = (year < 2011)

	* ── Firm connectivity scaling (P90 in restricted control sample) ──────
	local s_spill_r "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
	sum totaltreat_pw_n if `s_spill_r' & year == 2009, detail
	cap drop totaltreat_pw_norm_r
	gen double totaltreat_pw_norm_r = totaltreat_pw_n / r(p90)
	label var totaltreat_pw_norm_r "Firm connectivity (scaled to P90, restricted sample)"

	* ── Pre-treatment firm employment bins ───────────────────────────────
	cap drop firm_emp_pre_o
	cap drop firm_emp_pre
	bys identificad: ///
		egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: ///
		egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	cap drop l_firm_emp_pre
	gen double l_firm_emp_pre = ln(firm_emp_pre)
	cap drop l_firm_emp_pre4_o
	cap drop l_firm_emp_pre4
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
	replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)

	* ── Pre-treatment totalflows bins ────────────────────────────────────
	cap drop totalflows_pw_pre_07_11
	gen double totalflows_pw_pre_07_11 = 0
	cap drop totalflows_pw_pre_07_11_cnt
	gen totalflows_pw_pre_07_11_cnt = 0
	foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
		replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
		replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
	}
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
		if totalflows_pw_pre_07_11_cnt > 0
	replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
	drop totalflows_pw_pre_07_11_cnt
	cap drop totalflows_pw_pre4_r_o
	cap drop totalflows_pw_pre4_r
	egen totalflows_pw_pre4_r_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre4_r = min(totalflows_pw_pre4_r_o)
	drop totalflows_pw_pre4_r_o
	replace totalflows_pw_pre4_r = 0 if missing(totalflows_pw_pre4_r)

	di as result "Firm-level restricted variables created."

	* ── FE macros ────────────────────────────────────────────────────────
	local conn_r    "totaltreat_pw_norm_r"
	local base_fe_r "identificad i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
	local extra_r   "ib0.totalflows_pw_pre4_r#i.year"

	* ── Initialize output CSV ────────────────────────────────────────────
	local csv_r "$tables/layer_connectivity/results_spill_firmrestr_`layer'_`spec'.csv"
	capture erase "`csv_r'"
	tempname fhr
	file open  `fhr' using "`csv_r'", write replace
	file write `fhr' "spec,section,outcome,row_type,value" _n
	file close `fhr'

	di as result "Output CSV: `csv_r'"

	* ── Regressions ──────────────────────────────────────────────────────
	foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

		di as text "  Estimating (restricted): `outcome' (layer: `layer')"

		* Pre-treatment outcome bins
		cap drop `outcome'_pre_o
		cap drop `outcome'_pre
		bys identificad: ///
			egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: ///
			egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o

		cap drop `outcome'_pre4_o
		cap drop `outcome'_pre4
		egen `outcome'_pre4_o = cut(`outcome'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: ///
			egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
		replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)

		local absorb_r "`base_fe_r' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_r'"

		* Post-treatment spillover
		reghdfe `outcome' c.`conn_r'##i.treat_year if `s_spill_r', ///
			absorb(`absorb_r') vce(cluster identificad)

		local b_post_r  = _b[1.treat_year#c.`conn_r']
		local se_post_r = _se[1.treat_year#c.`conn_r']
		local p_post_r  = 2*ttail(e(df_r), abs(`b_post_r'/`se_post_r'))
		local n_obs_r   = e(N)
		local n_firms_r = e(N_clust)

		* Pre-treatment placebo
		reghdfe `outcome' c.`conn_r'##i.placebo_year ///
			if `s_spill_r' & year <= 2011, ///
			absorb(`absorb_r') vce(cluster identificad)

		local b_pre_r  = _b[1.placebo_year#c.`conn_r']
		local se_pre_r = _se[1.placebo_year#c.`conn_r']
		local p_pre_r  = 2*ttail(e(df_r), abs(`b_pre_r'/`se_pre_r'))

		* Stars
		local stars_post_r ""
		if `p_post_r' < 0.01                               local stars_post_r "***"
		else if (`p_post_r' < 0.05 & `p_post_r' > 0.01)   local stars_post_r "**"
		else if (`p_post_r' < 0.10 & `p_post_r' > 0.05)   local stars_post_r "*"

		local stars_pre_r ""
		if `p_pre_r' < 0.01                                local stars_pre_r "***"
		else if (`p_pre_r' < 0.05 & `p_pre_r' > 0.01)     local stars_pre_r "**"
		else if (`p_pre_r' < 0.10 & `p_pre_r' > 0.05)     local stars_pre_r "*"

		* Event study (pre-trend F-test + plot)
		reghdfe `outcome' c.`conn_r'##ib2011.year if `s_spill_r', ///
			absorb(`absorb_r') vce(cluster identificad)

		testparm c.`conn_r'#i(2009 2010).year
		local pre_ftest_pval_r = r(p)

		* Write to CSV
		tempname fhr
		file open  `fhr' using "`csv_r'", write append
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"main";"'    %9.4f (`b_post_r')          `"`stars_post_r'""' _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"main_se";"' %9.4f (`se_post_r')         `"""'              _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre";"'     %9.4f (`b_pre_r')           `"`stars_pre_r'""' _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre_se";"'  %9.4f (`se_pre_r')          `"""'              _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs_r')         `"""'              _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"n_firms";"' %12.0fc (`n_firms_r')       `"""'              _n
		file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval_r')  `"""'              _n
		file close `fhr'

		* Event study plot
		estimates store _es_r_tmp
		local post_coef_s_r = string(`b_post_r',         "%9.4f")
		local post_se_s_r   = string(`se_post_r',        "%9.4f")
		local pre_pval_s_r  = string(`pre_ftest_pval_r', "%9.3f")

		coefplot _es_r_tmp, ///
			keep(*#c.`conn_r') ///
			msymbol(diamond) ///
			coeflabels(2009.year#c.`conn_r' = "2009" ///
			           2010.year#c.`conn_r' = "2010" ///
			           2011.year#c.`conn_r' = "2011" ///
			           2012.year#c.`conn_r' = "2012" ///
			           2013.year#c.`conn_r' = "2013" ///
			           2014.year#c.`conn_r' = "2014" ///
			           2015.year#c.`conn_r' = "2015" ///
			           2016.year#c.`conn_r' = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ytitle("Spillover coefs (firm-level, restricted sample)", size(small)) ///
			note("Pre-trend F-test p = `pre_pval_s_r'  |  Post: `post_coef_s_r' (`post_se_s_r')") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

		graph export "$graphs/layer_connectivity/es_`outcome'_firmrestr_`layer'_`d'.pdf", ///
			as(pdf) replace

		estimates drop _es_r_tmp

		di as result "  Done (restricted): `outcome' (layer: `layer')"
	}

	di as result "Firm-level restricted spec for `layer' complete. Results in `csv_r'"

	di as result "Layer `layer' complete."
}

********************************************************************************
* SECTION 3: COMPLETION
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Layer spillover done" "edu + edu2 regressions complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
