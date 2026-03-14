********************************************************************************
* UNION SPILLOVERS — LAYER-LEVEL SPILLOVER BY FIRM SIZE
*
* Mirrors 07_layer_spillover.do but splits the spillover sample into small and
* large firms (below vs. at-or-above median avg December employment 2009-2011).
*
* Key design choices:
*   - P90 scaling of layer_conn_norm computed from the FULL spillover sample
*     (not size-specific) so coefficients are on the same scale across groups.
*   - Outer loop: foreach size in small large
*   - Two specs per size group: within-firm (firm×year FE) and cross-firm.
*
* Layers:  edu    (3-bin: 0_no_hs / 1_hs / 2_higher)
*          edu2   (2-bin: no_hs / has_hs)
*          gender (female / male)
*          race   (white / nonwhite)
*
* Output:
*   Tables/layer_connectivity/results_spill_layer_{layer}_size_{size}_{spec}.csv
*   Graphs/layer_connectivity/es_{outcome}_spill_{layer}_size_{size}_{date}.pdf
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
log using "$logs/layer_connectivity/layer_spillover_size_`d'_`t'.log", replace text

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
	* SECTION 2e: SIZE GROUP ASSIGNMENT
	* avg_emp_0911 = avg December employment 2009-2011 within firm.
	* Median computed over untreated balanced-panel firms (spillover sample).
	* Small: below median. Large: at or above median.
	****************************************************************************

	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

	* Average 2009-2011 employment per firm
	cap drop avg_emp_0911_o
	cap drop avg_emp_0911
	bys identificad: ///
		egen avg_emp_0911_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: ///
		egen avg_emp_0911 = min(avg_emp_0911_o)
	drop avg_emp_0911_o

	* Median within spillover sample (computed at year==2009 to avoid duplicates)
	sum avg_emp_0911 if `s_spill' & year == 2009, detail
	local med_emp = r(p50)
	di as result "  Median avg employment 2009-2011 (spillover sample): `med_emp'"

	* Size indicator: 1 = large, 0 = small
	cap drop size_large
	gen byte size_large = (avg_emp_0911 >= `med_emp') if !missing(avg_emp_0911)
	label var size_large "Large firm (avg emp 2009-11 >= median)"

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
	local base_fe    "i.firm_id#i.year"
	local extra_year "ib0.layer_totalflows_pw_pre4#i.year"
	local base_fe_cross ///
		"i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"

	****************************************************************************
	* SECTION 2h: LOOP OVER SIZE GROUPS
	****************************************************************************

	foreach size in small large {

		if "`size'" == "small" local size_cond "size_large == 0"
		if "`size'" == "large" local size_cond "size_large == 1"

		local s_spill_size "`s_spill' & `size_cond'"

		di _newline(2)
		di as result "======================================================================="
		di as result "SIZE GROUP: `size' | LAYER: `layer'"
		di as result "======================================================================="

		************************************************************************
		* WITHIN-FIRM SPEC
		************************************************************************

		local csv_out "$tables/layer_connectivity/results_spill_layer_`layer'_size_`size'_`spec'.csv"
		capture erase "`csv_out'"
		tempname fh
		file open  `fh' using "`csv_out'", write replace
		file write `fh' "spec,section,outcome,row_type,value" _n
		file close `fh'

		di as result "Within-firm spec CSV: `csv_out'"

		foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

			di as text "  Estimating: `outcome' (`layer', `size')"

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

			graph export "$graphs/layer_connectivity/es_`outcome'_spill_`layer'_size_`size'_`d'.pdf", ///
				as(pdf) replace

			estimates drop _es_tmp

			di as result "  Done: `outcome' (`layer', `size')"
		}

		************************************************************************
		* CROSS-FIRM SPEC
		************************************************************************

		local csv_cross "$tables/layer_connectivity/results_spill_layer_cross_`layer'_size_`size'_`spec'.csv"
		capture erase "`csv_cross'"
		tempname fhx
		file open  `fhx' using "`csv_cross'", write replace
		file write `fhx' "spec,section,outcome,row_type,value" _n
		file close `fhx'

		di as result "Cross-firm spec CSV: `csv_cross'"

		foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

			di as text "  Estimating (cross-firm): `outcome' (`layer', `size')"

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

			graph export "$graphs/layer_connectivity/es_`outcome'_cross_`layer'_size_`size'_`d'.pdf", ///
				as(pdf) replace

			estimates drop _es_x_tmp

			di as result "  Done (cross-firm): `outcome' (`layer', `size')"
		}

		di as result "Size group `size' for `layer' complete."
	}

	di as result "Layer `layer' complete."
}

********************************************************************************
* SECTION 3: WRAP-UP
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "07_layer_spillover_size.do complete."
di as result "Output CSVs: $tables/layer_connectivity/results_spill_layer_*_size_*"
di as result "======================================================================="

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "07_layer_spillover_size: all layers × size groups complete"

log close
