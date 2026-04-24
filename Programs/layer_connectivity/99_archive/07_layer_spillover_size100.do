********************************************************************************
* UNION SPILLOVERS — LAYER-LEVEL SPILLOVER BY FIRM SIZE (100-WORKER THRESHOLD)
*
* Mirrors 07_layer_spillover_size.do but uses >=100 workers as the large-firm
* threshold instead of the median (~31.7 workers).
*
* Key design choices:
*   - P90 scaling of layer_conn_norm computed from the FULL spillover sample
*     (not size-specific) so coefficients are on the same scale across groups.
*   - Large: avg December employment 2009-2011 >= 100. Small: < 100.
*   - Two layer specs per size group: within-firm and cross-firm.
*   - Plus firm-level restricted spec (firmrestr) per size group.
*
* Layers:  edu    (3-bin: 0_no_hs / 1_hs / 2_higher)
*          edu2   (2-bin: no_hs / has_hs)
*          gender (female / male)
*          race   (white / nonwhite)
*
* Output:
*   Tables/layer_connectivity/results_spill_layer_{layer}_size100_{size}_{spec}.csv
*   Tables/layer_connectivity/results_spill_firmrestr_{layer}_size100_{size}_{spec}.csv
*   Graphs/layer_connectivity/es_{outcome}_spill_{layer}_size100_{size}_{date}.pdf
********************************************************************************

********************************************************************************
* SECTION 1: PATHS & GLOBALS
********************************************************************************

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global layer_data "$main/UnionSpill/Data/layer_connectivity"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/layer_spillover_size100_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

local spec "layer_spill"

********************************************************************************
* SECTION 2: LOOP OVER LAYER DEFINITIONS
********************************************************************************

foreach layer in edu edu2 gender race {

	di _newline(2)
	di as result "======================================================================="
	di as result "LAYER: `layer'"
	di as result "======================================================================="

	* ── 2a. Load outcomes (firm × layer × year) ──────────────────────────────
	use "$layer_data/firm_layer_outcomes_`layer'.dta", clear
	keep if year >= 2009

	cap drop firm_id
	egen firm_id = group(identificad)

	* Create firm×layer unit ID for cross-section FE
	cap drop firm_layer_id
	egen firm_layer_id = group(identificad layer_id)

	* ── 2b. Merge connectivity (firm × layer, time-invariant pre-treatment) ──
	merge m:1 identificad layer_id using ///
		"$layer_data/final_measures/firm_layer_connectivity_`layer'.dta", ///
		keep(master match) nogen

	* ── 2c. Merge firm-level controls (firm × year) ──────────────────────────
	merge m:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
		          industry1 mode_base_month microregion firm_emp) ///
		keep(master match) nogen

	* ── Encode categorical FE variables ──────────────────────────────────────
	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	* ── 2d. Sample restriction ────────────────────────────────────────────────
	keep if lagos_sample_avg == 1

	di as result "  After sample restriction: `r(N)'"

	****************************************************************************
	* SECTION 2e: SIZE GROUP ASSIGNMENT (100-WORKER THRESHOLD)
	* avg_emp_0911 = avg December employment 2009-2011 within firm.
	* Large: avg_emp_0911 >= 100. Small: < 100.
	****************************************************************************

	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

	* Average 2009-2011 employment per firm — deduplicate to firm×year first
	* so each year gets equal weight regardless of how many layers exist.
	preserve
	keep if inrange(year, 2009, 2011)
	bys identificad year: keep if _n == 1
	bys identificad: egen avg_emp_0911 = mean(firm_emp)
	keep identificad avg_emp_0911
	bys identificad: keep if _n == 1
	tempfile emp_avg
	save `emp_avg'
	restore
	cap drop avg_emp_0911
	merge m:1 identificad using `emp_avg', keep(master match) nogen

	* Size indicator: 1 = large (>=100 workers), 0 = small (<100)
	cap drop size_large
	gen byte size_large = (avg_emp_0911 >= 100) if !missing(avg_emp_0911)
	label var size_large "Large firm (avg emp 2009-11 >= 100)"

	* Report share large
	count if `s_spill' & year == 2009 & size_large == 1
	local n_large = r(N)
	count if `s_spill' & year == 2009 & size_large == 0
	local n_small = r(N)
	di as result "  Large firms (>=100): `n_large' | Small firms (<100): `n_small'"

	****************************************************************************
	* SECTION 2f: VARIABLE CREATION
	****************************************************************************

	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	label var treat_year "Post-treatment period (year >= 2012)"

	cap drop placebo_year
	gen byte placebo_year = (year < 2011)
	label var placebo_year "Pre-treatment placebo (year < 2011)"

	* ── P90 scaling: anchored to the FULL spillover sample for comparability ──
	cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity to treated (scaled to P90, full sample)"

	* ── Pre-treatment layer-level outcome averages ───────────────────────────
	foreach v in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {
		cap drop `v'_pre_o
		cap drop `v'_pre
		bys identificad layer_id: ///
			egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad layer_id: ///
			egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o

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
	capture confirm variable totalflows_layer_pw_n
	if _rc {
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

	di as result "All variables created for `layer'."

	****************************************************************************
	* SECTION 2g: FE AND SPEC MACROS
	****************************************************************************

	local conn       "layer_conn_norm"
	local base_fe    "i.firm_layer_id i.year i.firm_id#i.year"
	local extra_year "ib0.layer_totalflows_pw_pre4#i.year"
	local base_fe_cross ///
		"i.firm_layer_id i.year i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"

	****************************************************************************
	* SECTION 2h: LOOP OVER SIZE GROUPS
	****************************************************************************

	foreach size in small large {

		if "`size'" == "small" local size_cond "size_large == 0"
		if "`size'" == "large" local size_cond "size_large == 1"

		local s_spill_size "`s_spill' & `size_cond'"

		di _newline(2)
		di as result "======================================================================="
		di as result "SIZE GROUP: `size' | LAYER: `layer' | THRESHOLD: 100"
		di as result "======================================================================="

		************************************************************************
		* WITHIN-FIRM SPEC
		************************************************************************

		local csv_out "$tables/layer_connectivity/results_spill_layer_`layer'_size100_`size'_`spec'.csv"
		capture erase "`csv_out'"
		tempname fh
		file open  `fh' using "`csv_out'", write replace
		file write `fh' "spec,section,outcome,row_type,value" _n
		file close `fh'

		di as result "Within-firm spec CSV: `csv_out'"

		foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

			di as text "  Estimating: `outcome' (`layer', `size', size100)"

			local absorb ///
				"`base_fe' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"

			* Post-treatment spillover
			reghdfe `outcome' c.`conn'##i.treat_year if `s_spill_size', ///
				absorb(`absorb') vce(cluster identificad)

			local b_post  = _b[1.treat_year#c.`conn']
			local se_post = _se[1.treat_year#c.`conn']
			local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
			local n_obs   = e(N)
			local n_firms = e(N_clust)

			* Pre-treatment placebo
			reghdfe `outcome' c.`conn'##i.placebo_year ///
				if `s_spill_size' & year <= 2011, ///
				absorb(`absorb') vce(cluster identificad)

			local b_pre  = _b[1.placebo_year#c.`conn']
			local se_pre = _se[1.placebo_year#c.`conn']
			local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

			* Stars
			local stars_post ""
			if `p_post' < 0.01                             local stars_post "***"
			else if (`p_post' < 0.05 & `p_post' > 0.01)   local stars_post "**"
			else if (`p_post' < 0.10 & `p_post' > 0.05)   local stars_post "*"

			local stars_pre ""
			if `p_pre' < 0.01                              local stars_pre "***"
			else if (`p_pre' < 0.05 & `p_pre' > 0.01)     local stars_pre "**"
			else if (`p_pre' < 0.10 & `p_pre' > 0.05)     local stars_pre "*"

			* Event study (pre-trend F-test + plot)
			reghdfe `outcome' c.`conn'##ib2011.year if `s_spill_size', ///
				absorb(`absorb') vce(cluster identificad)

			testparm c.`conn'#i(2009 2010).year
			local pre_ftest_pval = r(p)

			* Count unique firm×layer cells
			tempvar in_samp cell_first
			gen byte `in_samp'   = e(sample)
			bys identificad layer_id (`in_samp'): ///
				gen byte `cell_first' = (_n == 1 & `in_samp' == 1)
			qui count if `cell_first' == 1
			local n_cells = r(N)
			cap drop `in_samp'
			cap drop `cell_first'

			* Write to CSV
			tempname fh
			file open  `fh' using "`csv_out'", write append
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"main";"'    %9.4f (`b_post')         `"`stars_post'""' _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post')        `"""'             _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"pre";"'     %9.4f (`b_pre')          `"`stars_pre'""'  _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre')         `"""'             _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')        `"""'             _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"n_firms";"' %12.0fc (`n_firms')      `"""'             _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"n_cells";"' %12.0fc (`n_cells')      `"""'             _n
			file write `fh' `""spill_`layer'_`size'";"spill";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval') `"""'             _n
			file close `fh'

			* Event study plot
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

			graph export "$graphs/layer_connectivity/es_`outcome'_spill_`layer'_size100_`size'_`d'.pdf", ///
				as(pdf) replace

			estimates drop _es_tmp

			di as result "  Done: `outcome' (`layer', `size', size100)"
		}

		************************************************************************
		* CROSS-FIRM SPEC
		************************************************************************

		local csv_cross "$tables/layer_connectivity/results_spill_layer_cross_`layer'_size100_`size'_`spec'.csv"
		capture erase "`csv_cross'"
		tempname fhx
		file open  `fhx' using "`csv_cross'", write replace
		file write `fhx' "spec,section,outcome,row_type,value" _n
		file close `fhx'

		di as result "Cross-firm spec CSV: `csv_cross'"

		foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

			di as text "  Estimating (cross-firm): `outcome' (`layer', `size', size100)"

			local absorb_cross ///
				"`base_fe_cross' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"

			* Post-treatment spillover
			reghdfe `outcome' c.`conn'##i.treat_year if `s_spill_size', ///
				absorb(`absorb_cross') vce(cluster identificad)

			local b_post_x  = _b[1.treat_year#c.`conn']
			local se_post_x = _se[1.treat_year#c.`conn']
			local p_post_x  = 2*ttail(e(df_r), abs(`b_post_x'/`se_post_x'))
			local n_obs_x   = e(N)
			local n_firms_x = e(N_clust)

			* Pre-treatment placebo
			reghdfe `outcome' c.`conn'##i.placebo_year ///
				if `s_spill_size' & year <= 2011, ///
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
			reghdfe `outcome' c.`conn'##ib2011.year if `s_spill_size', ///
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
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"main";"'    %9.4f (`b_post_x')          `"`stars_post_x'""' _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"main_se";"' %9.4f (`se_post_x')         `"""'              _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"pre";"'     %9.4f (`b_pre_x')           `"`stars_pre_x'""' _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"pre_se";"'  %9.4f (`se_pre_x')          `"""'              _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"n_obs";"'   %12.0fc (`n_obs_x')         `"""'              _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"n_firms";"' %12.0fc (`n_firms_x')       `"""'              _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"n_cells";"' %12.0fc (`n_cells_x')       `"""'              _n
			file write `fhx' `""cross_`layer'_`size'";"cross";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval_x')  `"""'              _n
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

			graph export "$graphs/layer_connectivity/es_`outcome'_cross_`layer'_size100_`size'_`d'.pdf", ///
				as(pdf) replace

			estimates drop _es_x_tmp

			di as result "  Done (cross-firm): `outcome' (`layer', `size', size100)"
		}

		di as result "Size group `size' for `layer' complete (size100)."
	}

	****************************************************************************
	* SECTION 2i: FIRM-LEVEL RESTRICTED SPEC BY SIZE (100-WORKER THRESHOLD)
	* Mirrors firmrestr in 07_layer_spillover.do but restricted to small/large
	* firms as defined by size_large (100-worker threshold) above.
	* Bins computed on FULL sample before size restriction for comparability.
	****************************************************************************

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "FIRM-LEVEL RESTRICTED BY SIZE (100-worker) — layer: `layer'"
	di as result "-----------------------------------------------------------------------"

	* ── Phase 1: Extract restricted firm sets by size ────────────────────
	local s_spill "treat_ultra==0 & in_balanced_panel==1 & lagos_sample_avg==1"
	foreach size in small large {
		local size_ind = cond("`size'" == "large", 1, 0)
		preserve
		keep if (`s_spill') & !missing(layer_treat_pw_n) & size_large == `size_ind'
		keep identificad
		duplicates drop
		count
		di as result "  Restricted `size' firms (layer: `layer', size100): `r(N)'"
		tempfile restr_firms_`size'
		save `restr_firms_`size''
		restore
	}

	* ── Phase 2: Load firm-level panel, compute bins on FULL sample ──────
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
	tempfile tfwide
	save `tfwide'

	use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
	keep if year >= 2009
	merge m:1 identificad using `tfwide', keep(master match) nogen
	keep if lagos_sample_avg == 1

	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	cap drop placebo_year
	gen byte placebo_year = (year < 2011)

	local s_spill_r "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
	sum totaltreat_pw_n if `s_spill_r' & year == 2009, detail
	cap drop totaltreat_pw_norm_r
	gen double totaltreat_pw_norm_r = totaltreat_pw_n / r(p90)
	label var totaltreat_pw_norm_r "Firm connectivity (scaled to P90, full spillover sample)"

	cap drop firm_emp_pre_o
	cap drop firm_emp_pre
	bys identificad: ///
		egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: ///
		egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	cap drop l_firm_emp_pre
	gen double l_firm_emp_pre = ln(firm_emp_pre)

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

	foreach outcome in lr_remdezr_w lr_remdezr_h_w {
		cap drop `outcome'_pre_o
		cap drop `outcome'_pre
		cap drop `outcome'_pre4_o
		cap drop `outcome'_pre4
		bys identificad: ///
			egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: ///
			egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
		egen `outcome'_pre4_o = cut(`outcome'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: ///
			egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
		replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)
	}
	cap drop l_firm_emp_pre4_o
	cap drop l_firm_emp_pre4
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: ///
		egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
	replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)

	tempfile firm_panel_full
	save `firm_panel_full'

	* ── Phase 3: Loop over sizes, run firm-level regressions ─────────────
	local conn_r    "totaltreat_pw_norm_r"
	local base_fe_r "identificad i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
	local extra_r   "ib0.totalflows_pw_pre4_r#i.year"

	foreach size in small large {

		use `firm_panel_full', clear
		merge m:1 identificad using `restr_firms_`size'', keep(match) nogen

		count
		di as result "  Firmrestr-`size' (size100) obs after size restriction: `r(N)'"

		local csv_rs "$tables/layer_connectivity/results_spill_firmrestr_`layer'_size100_`size'_`spec'.csv"
		capture erase "`csv_rs'"
		tempname fhrs
		file open  `fhrs' using "`csv_rs'", write replace
		file write `fhrs' "spec,section,outcome,row_type,value" _n
		file close `fhrs'

		di as result "Firmrestr-`size' (size100) CSV: `csv_rs'"

		foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

			di as text "  Estimating (firmrestr-`size', size100): `outcome' (layer: `layer')"

			local absorb_rs "`base_fe_r' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_r'"

			* Post-treatment spillover
			reghdfe `outcome' c.`conn_r'##i.treat_year if `s_spill_r', ///
				absorb(`absorb_rs') vce(cluster identificad)

			local b_post_rs  = _b[1.treat_year#c.`conn_r']
			local se_post_rs = _se[1.treat_year#c.`conn_r']
			local p_post_rs  = 2*ttail(e(df_r), abs(`b_post_rs'/`se_post_rs'))
			local n_obs_rs   = e(N)
			local n_firms_rs = e(N_clust)

			* Pre-treatment placebo
			reghdfe `outcome' c.`conn_r'##i.placebo_year ///
				if `s_spill_r' & year <= 2011, ///
				absorb(`absorb_rs') vce(cluster identificad)

			local b_pre_rs  = _b[1.placebo_year#c.`conn_r']
			local se_pre_rs = _se[1.placebo_year#c.`conn_r']
			local p_pre_rs  = 2*ttail(e(df_r), abs(`b_pre_rs'/`se_pre_rs'))

			* Stars
			local stars_post_rs ""
			if `p_post_rs' < 0.01                                  local stars_post_rs "***"
			else if (`p_post_rs' < 0.05 & `p_post_rs' > 0.01)     local stars_post_rs "**"
			else if (`p_post_rs' < 0.10 & `p_post_rs' > 0.05)     local stars_post_rs "*"

			local stars_pre_rs ""
			if `p_pre_rs' < 0.01                                   local stars_pre_rs "***"
			else if (`p_pre_rs' < 0.05 & `p_pre_rs' > 0.01)       local stars_pre_rs "**"
			else if (`p_pre_rs' < 0.10 & `p_pre_rs' > 0.05)       local stars_pre_rs "*"

			* Event study (pre-trend F-test)
			reghdfe `outcome' c.`conn_r'##ib2011.year if `s_spill_r', ///
				absorb(`absorb_rs') vce(cluster identificad)

			testparm c.`conn_r'#i(2009 2010).year
			local pre_ftest_pval_rs = r(p)

			* Write to CSV
			tempname fhrs
			file open  `fhrs' using "`csv_rs'", write append
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"main";"'    %9.4f (`b_post_rs')          `"`stars_post_rs'""' _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"main_se";"' %9.4f (`se_post_rs')         `"""'              _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"pre";"'     %9.4f (`b_pre_rs')           `"`stars_pre_rs'""' _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"pre_se";"'  %9.4f (`se_pre_rs')          `"""'              _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs_rs')         `"""'              _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"n_firms";"' %12.0fc (`n_firms_rs')       `"""'              _n
			file write `fhrs' `""firmrestr_`layer'_`size'";"firmrestr";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval_rs')  `"""'              _n
			file close `fhrs'

			di as result "  Done (firmrestr-`size', size100): `outcome' (layer: `layer')"
		}

		di as result "Firmrestr size group `size' (size100) for `layer' complete."
	}

	di as result "Firm-level restricted by size (size100) for `layer' complete."

	di as result "Layer `layer' complete (size100)."
}

********************************************************************************
* SECTION 3: WRAP-UP
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "07_layer_spillover_size100.do complete."
di as result "Output CSVs: $tables/layer_connectivity/results_spill_*_size100_*"
di as result "======================================================================="

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "07_layer_spillover_size100: all layers × size groups complete"

log close
