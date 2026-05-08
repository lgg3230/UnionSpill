********************************************************************************
* direct_contamination_test.do
* Three-group DiD to test whether β_A ≠ β_C (H0: β5 = 0).
*
* Groups (within lagos_sample_avg==1 & in_balanced_panel==1):
*   treat_ultra==1                                 : T — treated
*   treat_ultra==0 & totaltreat_pw_n==0 (or miss.) : C — pure controls [ref.]
*   treat_ultra==0 & totaltreat_pw_n>0             : D — contaminated controls
*
* Regression:
*   y = FE + β4(treat_ultra × Post) + β5(d_contam × Post) + ε
*
*   β4 ≈ β_A  (direct effect vs. pure controls)
*   β5 = τ_D  (spillover onto contaminated controls = contamination bias)
*   β_C = β4 − β5
*   H0: β_A = β_C  ↔  H0: β5 = 0
*
* Outcomes: lr_remdezr_w, lr_remdezr_h_w, l_firm_emp, numb_clauses
*
* Output:
*   Tables/main_results/contamination_test.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/main_results"
log using "$logs/main_results/contamination_test_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap mkdir "$tables/main_results"

********************************************************************************
* SECTION 1: LOAD AND MERGE
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
* SECTION 2: VARIABLES
********************************************************************************

* ── Period dummies ────────────────────────────────────────────────────────────

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* ── Three-group indicator ─────────────────────────────────────────────────────

cap drop d_contam
gen byte d_contam = (treat_ultra == 0 & totaltreat_pw_n > 0 & !missing(totaltreat_pw_n))

* ── Pre-treatment means ───────────────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* ── 4-bin controls ───────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
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

local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

local s_C "lagos_sample_avg==1 & in_balanced_panel==1"

* ── Initialize CSV ────────────────────────────────────────────────────────────

capture erase "$tables/main_results/contamination_test.csv"
tempname fh
file open `fh' using "$tables/main_results/contamination_test.csv", write replace
file write `fh' "outcome;row_type;value" _n
file close `fh'

* ── Loop ─────────────────────────────────────────────────────────────────────

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses {

	di as result _newline "--- Contamination test: `outcome' ---"

	if "`outcome'" == "numb_clauses" {
		local absorb_use "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
		local if_main    "`s_C' & !missing(cba_period)"
		local if_pre     "`s_C' & !missing(cba_period) & cba_period <= 2"
	}
	else {
		local absorb_use "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
		local if_main    "`s_C'"
		local if_pre     "`s_C' & year <= 2011"
	}

	* ── Main regression ────────────────────────────────────────────────────────

	if "`outcome'" == "numb_clauses" {
		reghdfe numb_clauses treat_ultra##i.post_treat_cba d_contam##i.post_treat_cba ///
			if `if_main', absorb(`absorb_use') vce(cluster identificad)
		local b4  = _b[1.treat_ultra#1.post_treat_cba]
		local se4 = _se[1.treat_ultra#1.post_treat_cba]
		local b5  = _b[1.d_contam#1.post_treat_cba]
		local se5 = _se[1.d_contam#1.post_treat_cba]
	}
	else {
		reghdfe `outcome' treat_ultra##i.treat_year d_contam##i.treat_year ///
			if `if_main', absorb(`absorb_use') vce(cluster identificad)
		local b4  = _b[1.treat_ultra#1.treat_year]
		local se4 = _se[1.treat_ultra#1.treat_year]
		local b5  = _b[1.d_contam#1.treat_year]
		local se5 = _se[1.d_contam#1.treat_year]
	}

	local df_r    = e(df_r)
	local n_obs   = e(N)
	local n_estab = e(N_clust)
	local p4      = 2*ttail(`df_r', abs(`b4'/`se4'))
	local p5      = 2*ttail(`df_r', abs(`b5'/`se5'))
	local bc      = `b4' - `b5'

	* ── Pre-trend placebo ──────────────────────────────────────────────────────

	if "`outcome'" == "numb_clauses" {
		reghdfe numb_clauses treat_ultra##i.pre_treat_cba d_contam##i.pre_treat_cba ///
			if `if_pre', absorb(`absorb_use') vce(cluster identificad)
		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
	}
	else {
		reghdfe `outcome' treat_ultra##i.placebo_year d_contam##i.placebo_year ///
			if `if_pre', absorb(`absorb_use') vce(cluster identificad)
		local b_pre  = _b[1.treat_ultra#1.placebo_year]
		local se_pre = _se[1.treat_ultra#1.placebo_year]
	}

	local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	* ── Write CSV (raw numbers; Python script applies formatting) ───────────────

	tempname fh
	file open `fh' using "$tables/main_results/contamination_test.csv", write append
	file write `fh' `""`outcome'";"b4";"'    %10.6f (`b4')    `"""' _n
	file write `fh' `""`outcome'";"se4";"'   %10.6f (`se4')   `"""' _n
	file write `fh' `""`outcome'";"p4";"'    %10.6f (`p4')    `"""' _n
	file write `fh' `""`outcome'";"b5";"'    %10.6f (`b5')    `"""' _n
	file write `fh' `""`outcome'";"se5";"'   %10.6f (`se5')   `"""' _n
	file write `fh' `""`outcome'";"p5";"'    %10.6f (`p5')    `"""' _n
	file write `fh' `""`outcome'";"bc";"'    %10.6f (`bc')    `"""' _n
	file write `fh' `""`outcome'";"b_pre";"' %10.6f (`b_pre') `"""' _n
	file write `fh' `""`outcome'";"se_pre";"'%10.6f (`se_pre') `"""' _n
	file write `fh' `""`outcome'";"p_pre";"' %10.6f (`p_pre') `"""' _n
	file write `fh' `""`outcome'";"n_obs";"'  %12.0f (`n_obs')  `"""' _n
	file write `fh' `""`outcome'";"n_estab";"'%12.0f (`n_estab') `"""' _n
	file close `fh'

	di as result "  β4=`b4'  p4=`p4'  β5=`b5'  p5=`p5'  β_C≈`bc'"
}

di as result _newline "Done. CSV written to $tables/main_results/contamination_test.csv"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "Stata done" "direct_contamination_test.do finished"

log close
