********************************************************************************
* ROBUSTNESS: ALTERNATIVE CONNECTIVITY MEASURES
* Purpose: Replicates main spillover spec (tfpw_07_11) for the four main
*          outcomes but swaps the connectivity measure to:
*            (1) avg_ftreat_pf_n  — avg flow share to treated across year pairs
*            (2) totaltreat_pf_n  — proportion of flows to treated firms
*          Each measure is scaled to its 90th percentile in the spillover sample
*          (untreated, balanced panel, year==2009), matching the main spec.
* Output:  Tables/robustness/results_spill_alt_conn.csv
* Auto-runs: Programs/robustness/generate_alt_conn_latex.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_alt_conn_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── MERGE TURNOVER DATA ──────────────────────────────────────────────────────

di as result "Merging turnover data..."

preserve
	import delimited "$rais_aux/corrected_turnover_sample.csv", clear
	keep identificad year separations_u hired_u avg_emp
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

gen double churn_u = separations_u + hired_u
label var churn_u "Total churn (separations + hires, uncensored)"

gen double churn_rate_u = (separations_u + hired_u) / avg_emp if avg_emp > 0
label var churn_rate_u "Churn rate (churn / avg employment, uncensored)"

di as result "Turnover data merged."

* ── MERGE TOTALFLOWS DATA (per-worker, 2007-2011; used as extra_year control) ─

di as result "Merging totalflows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe)
gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

di as result "Totalflows data merged."

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables..."

* ── a) TREATMENT & CBA PERIOD INDICATORS ────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

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
label var cba_period "CBA negotiation period (1=earliest, 2=second, 3-6=post-treatment years)"

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

* ── b) SPILLOVER SAMPLE MACRO ────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── c) SCALE ALTERNATIVE CONNECTIVITY MEASURES TO P90 ───────────────────────

cap drop avg_ftreat_pf_n_p90
cap drop avg_ftreat_pf_n_norm
 sum avg_ftreat_pf_n if `s_spill' & year == 2009, detail
gen avg_ftreat_pf_n_p90 = r(p90)
label var avg_ftreat_pf_n_p90 "90th pctile of avg_ftreat_pf_n (spillover sample, 2009)"
gen avg_ftreat_pf_n_norm = avg_ftreat_pf_n / avg_ftreat_pf_n_p90
label var avg_ftreat_pf_n_norm "avg_ftreat_pf_n scaled to 90th pctile"

cap drop totaltreat_pf_n_p90
cap drop totaltreat_pf_n_norm
 sum totaltreat_pf_n if `s_spill' & year == 2009, detail
gen totaltreat_pf_n_p90 = r(p90)
label var totaltreat_pf_n_p90 "90th pctile of totaltreat_pf_n (spillover sample, 2009)"
gen totaltreat_pf_n_norm = totaltreat_pf_n / totaltreat_pf_n_p90
label var totaltreat_pf_n_norm "totaltreat_pf_n scaled to 90th pctile"

* ── d) PRE-TREATMENT MEANS FOR BASE OUTCOMES ─────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

* numb_clauses pre-treatment mean (CBA period based)
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── e) 4-BIN CONTROLS ────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
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

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION"
di as result "======================================================================="

* ── FIXED EFFECTS & SPEC MACROS ──────────────────────────────────────────────

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── INITIALIZE OUTPUT CSV ────────────────────────────────────────────────────

local csv_out "$tables/robustness/results_spill_alt_conn.csv"
capture erase "`csv_out'"
tempname fh
file open `fh' using "`csv_out'", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── MAIN LOOP: CONNECTIVITY MEASURES ─────────────────────────────────────────

foreach conn_var in avg_ftreat_pf_n totaltreat_pf_n {

	local conn "`conn_var'_norm"
	local spec "`conn_var'"

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "SPILLOVER EFFECTS — connectivity: `conn_var'"
	di as result "-----------------------------------------------------------------------"

	* ── Regular outcomes (year-based) ────────────────────────────────────────

	foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

		di as text "  Estimating: `outcome' (spec: `spec')"

		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		* Post-treatment
		reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_year#c.`conn']
		local se_post = _se[1.treat_year#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment placebo
		reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.placebo_year#c.`conn']
		local se_pre = _se[1.placebo_year#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* Stars
		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		* Pre-trend F-test
		reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)
		testparm c.`conn'#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'
	}

	* ── numb_clauses (CBA-period structure) ──────────────────────────────────

	capture confirm variable numb_clauses
	if _rc == 0 {

		di as text "  Estimating: numb_clauses (CBA periods, spec: `spec')"

		local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		* Post-treatment
		reghdfe numb_clauses c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment
		reghdfe numb_clauses c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* Stars
		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		* Pre-trend F-test
		reghdfe numb_clauses c.`conn'##ib2.cba_period ///
			if `s_spill' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"spill";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'
	}

	di as result "Spec `spec' complete."
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION + AUTO-RUN PYTHON
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell ~/.conda/envs/venv_python312/bin/python "$programs/robustness/generate_alt_conn_latex.py"
di as result "LaTeX table written to Tables/robustness/alt_conn_table.tex"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "alt_conn robustness complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
