********************************************************************************
* cba_similarity_multi_ref.do
* Same spillover exercises as cba_similarity.do, but for cosine and ruzicka
* similarity computed against FIVE different reference CBAs:
*
*   A. Time-varying flow-weighted avg of connected treated firms' CBAs       (treat_t)
*   B. Flow-weighted avg of connected treated firms, fixed at cba_period==2  (treat_p2)
*   C. Equal-weighted mean of Ref A vectors at cba_period 1 and 2           (treat_p12)
*   D. Focal firm's own CBA at cba_period==2                                (self_p2)
*   E. Equal-weighted mean of focal firm's own CBAs at cba_periods 1 and 2  (self_p12)
*
* Each (similarity measure, reference) pair is a separate outcome:
*   cosine_treat_t  cosine_treat_p2  cosine_treat_p12  cosine_self_p2  cosine_self_p12
*   ruzicka_treat_t ruzicka_treat_p2 ruzicka_treat_p12 ruzicka_self_p2 ruzicka_self_p12
*
* This script runs Panel A spillover regressions only (no mode_union × period FE).
*
* Output:
*   Tables/cba_similarity/results_spill_cba_similarity_multi_ref.csv
*   Tables/cba_similarity/cba_similarity_multi_ref_cosine_table.tex
*   Tables/cba_similarity/cba_similarity_multi_ref_ruzicka_table.tex
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/cba_similarity_multi_ref_`d'_`t'.log", replace text

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

gen double totalflows_pw_pre_07_11     = 0
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
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile"

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
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
* SECTION 3: EXPORT INTERMEDIATE CLAUSE DATA + RUN PYTHON PREP
* Produces (or refreshes) Data/RAIS_aux/cba_similarity_panel_multi_ref.dta
* with all 20 similarity columns (5 references × 4 measures).
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

di as result "Running Python similarity prep (multi-reference)..."
shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/cba_similarity_prep.py"
di as result "Python prep complete."

********************************************************************************
* SECTION 4: MERGE MULTI-REF SIMILARITY PANEL
********************************************************************************

di as result "Merging multi-ref similarity measures into panel..."

merge m:1 identificad cba_period using "$rais_aux/cba_similarity_panel_multi_ref.dta", ///
	keep(master match) gen(m_sim_multi)
drop m_sim_multi

* Outcome lists
local cosine_outs   "cosine_treat_t cosine_treat_p2 cosine_treat_p12 cosine_self_p2 cosine_self_p12"
local ruzicka_outs  "ruzicka_treat_t ruzicka_treat_p2 ruzicka_treat_p12 ruzicka_self_p2 ruzicka_self_p12"
local all_outs      "`cosine_outs' `ruzicka_outs'"

di as result "Observations with each similarity outcome:"
foreach v of local all_outs {
	count if !missing(`v')
	di as text "  `v': " r(N)
}

********************************************************************************
* SECTION 5: PRE-TREATMENT BASELINE BINS PER OUTCOME
********************************************************************************

foreach v of local all_outs {
	cap drop `v'_pre_o
	cap drop `v'_pre
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

********************************************************************************
* SECTION 6: SPECIFICATION MACROS
********************************************************************************

local spec        "cba_similarity_multi_ref"
local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

********************************************************************************
* SECTION 7: INITIALIZE OUTPUT CSV
********************************************************************************

local csv_spill "$tables/cba_similarity/results_spill_cba_similarity_multi_ref.csv"
capture erase "`csv_spill'"
tempname fh
file open `fh' using "`csv_spill'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 8: SPILLOVER REGRESSIONS (Panel A only — no union FE)
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS — multi-reference"
di as result "-----------------------------------------------------------------------"

foreach outcome of local all_outs {

	di as text "  Estimating: `outcome'"

	local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* (1) Post-treatment spillover
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

	* (2) Pre-treatment placebo
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

	* (3) Event-study for pre-trend test
	reghdfe `outcome' c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
		absorb(`absorb_cba') vce(cluster identificad)
	capture testparm c.`conn'#1.cba_period
	local pre_ftest_pval = cond(_rc==0, r(p), .)

	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"'          %9.4f (`b_post') `"`stars_post'"' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"'       %9.4f (`se_post') _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"'           %9.4f (`b_pre') `"`stars_pre'"' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"'        %9.4f (`se_pre') _n
	file write `fh' `""`spec'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"'         %12.0fc (`n_obs') _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"'       %12.0fc (`n_estab') _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"'      %9.4f (`pre_ftest_pval') _n
	file close `fh'
}

di as result _newline "All multi-reference regressions complete."

********************************************************************************
* SECTION 9: GENERATE LATEX TABLES (one per similarity measure)
********************************************************************************

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_cba_similarity_multi_ref_latex.py"
di as result "LaTeX tables written to $tables/cba_similarity/cba_similarity_multi_ref_*_table.tex"

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell source "$programs/notify.sh" && notify "cba_similarity_multi_ref done" "Multi-reference similarity regressions and tables complete"

********************************************************************************
* END
********************************************************************************
