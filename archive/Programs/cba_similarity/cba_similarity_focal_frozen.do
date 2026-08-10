********************************************************************************
* cba_similarity_focal_frozen.do
*
* Exercise B in the A/B/C decomposition:
*   Hold the spillover (untreated focal) firm's clause vector FIXED at
*   cba_period == 2, but let the flow-weighted treated partner reference MOVE
*   with the current cba_period t. Uses the SAME uncorrected bilateral_conn_pw
*   weights as Exercise A (cba_similarity.do, headline) and Exercise C
*   (cba_similarity_pretreat_ref_uncorr_w.do), so the connectivity coefficient
*   in this regression is directly comparable to A and C.
*
* For each (untreated firm i, cba_period t):
*   sim_{it} = sim( u_{i,2},  T_{i,t} )
* where
*   u_{i,2} = focal firm i's clauses at cba_period 2 (FIXED)
*   T_{i,t} = Σ_k w_{ik} * x_{k,t} / Σ_k w_{ik}     (MOVING)
*   k ranges over treated firms with positive flow weight to i AND a CBA at t.
*
* Pipeline:
*   1. Load + setup variables (mirrors cba_similarity.do)
*   2. Export intermediate clause data for Python (cba_clauses_by_period.dta)
*   3. Python computes the moving treated reference + fixed focal vector +
*      similarities (cba_similarity_focal_frozen_prep.py)
*   4. Merge similarity panel and run panel regressions
*
* Output:
*   Tables/cba_similarity/results_spill_focal_frozen_cba_similarity.csv
*   Tables/cba_similarity/results_spill_focal_frozen_ln_cba_similarity.csv
*   Tables/cba_similarity/focal_frozen_cba_similarity_table.tex
*   Tables/cba_similarity/focal_frozen_ln_cba_similarity_table.tex
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/cba_similarity_focal_frozen_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION (mirrors cba_similarity.do)
********************************************************************************

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
label var cba_period "CBA negotiation period"

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile"

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}
cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

********************************************************************************
* SECTION 3: EXPORT INTERMEDIATE CLAUSE DATA FOR PYTHON
********************************************************************************

di as result "Exporting clause data for Python..."

ds cl_*
local clause_vars `r(varlist)'

preserve
	keep if !missing(cba_period)
	keep identificad cba_period treat_ultra lagos_sample_avg in_balanced_panel `clause_vars'
	foreach v of local clause_vars {
		replace `v' = 0 if missing(`v')
	}
	save "$rais_aux/cba_clauses_by_period.dta", replace
restore

di as result "Clause data exported."

********************************************************************************
* SECTION 4: RUN PYTHON PREP SCRIPT
* Builds focal-firm-corrected weights, fixed cba_period==2 reference, and
* four similarity measures. Output: cba_similarity_focal_frozen_panel.dta.
********************************************************************************

di as result "Running Python focal-frozen similarity prep..."
shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/cba_similarity_focal_frozen_prep.py"
di as result "Python prep complete."

********************************************************************************
* SECTION 5: LOAD SIMILARITY PANEL + MERGE WITH PANEL CONTROLS
********************************************************************************

di as result "Merging focal-frozen similarity measures into panel..."

merge m:1 identificad cba_period using "$rais_aux/cba_similarity_focal_frozen_panel.dta", ///
	keep(master match) gen(m_sim)
drop m_sim

label var cosine          "Cosine similarity: focal frozen at p2 vs moving treated avg"
label var bray_curtis     "Bray-Curtis similarity: focal frozen at p2 vs moving treated avg"
label var total_variation "Total variation similarity: focal frozen at p2 vs moving treated avg"
label var ruzicka         "Ruzicka similarity: focal frozen at p2 vs moving treated avg"

local sim_outcomes "cosine bray_curtis total_variation ruzicka"

di as result "Focal-frozen similarity merge complete. Observations with similarity:"
foreach v of local sim_outcomes {
	count if !missing(`v')
	di as text "  `v': " r(N)
}

********************************************************************************
* SECTION 6: PRE-TREATMENT BASELINE BINS FOR SIMILARITY OUTCOMES
********************************************************************************

foreach v of local sim_outcomes {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}

	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

********************************************************************************
* SECTION 6b: LOG SIMILARITY OUTCOMES
********************************************************************************

foreach v of local sim_outcomes {
	cap drop ln_`v'
	gen double ln_`v' = ln(`v') if `v' > 0
	label var ln_`v' "Log `v' similarity"
}

local ln_sim_outcomes "ln_cosine ln_bray_curtis ln_total_variation ln_ruzicka"

di as result "Observations with log similarity (zeros dropped):"
foreach v of local ln_sim_outcomes {
	count if !missing(`v')
	di as text "  `v': " r(N)
}

foreach v of local ln_sim_outcomes {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

********************************************************************************
* SECTION 7: SPECIFICATION MACROS (identical to cba_similarity.do)
********************************************************************************

local spec             "focal_frozen_cba_similarity_tfpw_07_11"
local conn             "totaltreat_pw_norm"
local base_fe_cba      "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local base_fe_cba_union "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period i.mode_union#i.cba_period"
local extra_cba        "ib0.totalflows_pw_pre_07_114#i.cba_period"

********************************************************************************
* SECTION 8: INITIALIZE OUTPUT CSV FILES
********************************************************************************

capture erase "$tables/cba_similarity/results_spill_focal_frozen_cba_similarity.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_spill_focal_frozen_cba_similarity.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

capture erase "$tables/cba_similarity/results_spill_focal_frozen_ln_cba_similarity.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_spill_focal_frozen_ln_cba_similarity.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 9: SPILLOVER EFFECTS
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS — FOCAL FROZEN AT P2"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/cba_similarity/results_spill_focal_frozen_cba_similarity.csv"

foreach fe_variant in base union {
	if "`fe_variant'" == "base" {
		local cur_base_fe "`base_fe_cba'"
		local cur_spec    "`spec'"
	}
	else {
		local cur_base_fe "`base_fe_cba_union'"
		local cur_spec    "`spec'_union"
	}

	foreach outcome of local sim_outcomes {

		di as text "  Estimating: `outcome' (spillover, focal-frozen, `fe_variant')"

		local absorb_cba "`cur_base_fe' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		qui sum `outcome' if e(sample) & cba_period == 2
		local base_mean = cond(r(N) > 0, r(mean), .)

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2 & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                            local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

		reghdfe `outcome' c.`conn'##ib2.cba_period ///
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		tempname fh
		file open `fh' using "`csv_spill'", write append
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'"' _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre') `"`stars_pre'"'  _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
		file close `fh'
	}
}

di as result _newline "All level regressions complete."

********************************************************************************
* SECTION 9b: SPILLOVER EFFECTS — LOG SIMILARITY
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS — LOG SIMILARITY (FOCAL FROZEN AT P2)"
di as result "-----------------------------------------------------------------------"

local spec_ln    "focal_frozen_ln_cba_similarity_tfpw_07_11"
local csv_ln     "$tables/cba_similarity/results_spill_focal_frozen_ln_cba_similarity.csv"

foreach fe_variant in base union {
	if "`fe_variant'" == "base" {
		local cur_base_fe  "`base_fe_cba'"
		local cur_spec_ln  "`spec_ln'"
	}
	else {
		local cur_base_fe  "`base_fe_cba_union'"
		local cur_spec_ln  "`spec_ln'_union"
	}

	foreach outcome of local ln_sim_outcomes {

		di as text "  Estimating: `outcome' (spillover, log, focal-frozen, `fe_variant')"

		local absorb_cba "`cur_base_fe' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		qui sum `outcome' if e(sample) & cba_period == 2
		local base_mean = cond(r(N) > 0, r(mean), .)

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2 & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                            local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

		reghdfe `outcome' c.`conn'##ib2.cba_period ///
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		tempname fh
		file open `fh' using "`csv_ln'", write append
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'"' _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre') `"`stars_pre'"'  _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
		file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
		file close `fh'
	}
}

di as result _newline "Log similarity regressions complete."

********************************************************************************
* SECTION 10: COMPLETION + AUTO-RUN PYTHON FOR LATEX TABLE
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_focal_frozen_similarity_latex.py"
di as result "LaTeX table written to Tables/cba_similarity/focal_frozen_cba_similarity_table.tex"

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_focal_frozen_ln_similarity_latex.py"
di as result "LaTeX table written to Tables/cba_similarity/focal_frozen_ln_cba_similarity_table.tex"

shell source "$programs/notify.sh" && notify "cba_similarity_focal_frozen done" "Focal-frozen similarity regressions and tables complete"

********************************************************************************
* END
********************************************************************************
