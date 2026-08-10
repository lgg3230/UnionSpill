********************************************************************************
* numb_clauses_winsor.do
* Winsorizes numb_clauses at the 99th percentile (computed across all CBA
* periods in the spillover sample) and re-runs the spillover clause-count
* regressions. Also runs year-based labor spillover regressions to confirm
* those are unaffected by the winsorization.
*
* Outputs:
*   Tables/numb_clauses_outliers/winsor_threshold.csv
*   Tables/numb_clauses_outliers/winsor_clause_spill_results.csv
*   Tables/numb_clauses_outliers/winsor_labor_spill_results.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/numb_clauses_outliers"
log using "$logs/numb_clauses_outliers/numb_clauses_winsor_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/numb_clauses_outliers"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

capture confirm string variable identificad
if _rc {
	tostring identificad, replace format(%014.0f) force
}

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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: CLAUSE COUNT VARIABLES
********************************************************************************

cap drop wage_clauses
cap drop emp_clauses
cap drop other_clauses
gen int wage_clauses  = 0
gen int emp_clauses   = 0
gen int other_clauses = 0

ds cl_*
local clause_vars `r(varlist)'

foreach v of local clause_vars {
	if substr("`v'", 4, 1) == "1" {
		replace wage_clauses = wage_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "3", "4") {
		replace emp_clauses = emp_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "2", "5", "6", "7", "8", "9") {
		replace other_clauses = other_clauses + cond(missing(`v'), 0, `v')
	}
}

label var wage_clauses  "Count of wage-related clauses"
label var emp_clauses   "Count of employment clauses"
label var other_clauses "Count of other clauses"

********************************************************************************
* SECTION 3: VARIABLE CREATION
********************************************************************************

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
label var cba_period "CBA negotiation period"

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
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
* SECTION 4: WINSORIZE numb_clauses AT 99th PERCENTILE
*
* The 99th percentile is computed in the spillover sample across ALL cba_period
* observations (not within each period). This gives one global cutoff applied
* uniformly everywhere numb_clauses appears as an outcome.
********************************************************************************

quietly sum numb_clauses if `s_spill' & !missing(cba_period), detail
local p99_numb = r(p99)
local n_obs_all = r(N)
local mean_raw  = r(mean)

di as result "Winsorization cutoff (p99 of numb_clauses, spillover sample, all CBA periods): `p99_numb'"

cap drop numb_clauses_w
gen numb_clauses_w = min(numb_clauses, `p99_numb')
label var numb_clauses_w "numb_clauses winsorized at 99th pct (all CBA periods)"

quietly sum numb_clauses_w if `s_spill' & !missing(cba_period), meanonly
local mean_winsor = r(mean)
quietly count if numb_clauses > `p99_numb' & !missing(numb_clauses) & `s_spill' & !missing(cba_period)
local n_winsorized = r(N)

* Save threshold summary
preserve
	clear
	set obs 1
	gen double p99_cutoff     = `p99_numb'
	gen long   n_obs_sample   = `n_obs_all'
	gen long   n_winsorized   = `n_winsorized'
	gen double pct_winsorized = `n_winsorized' / `n_obs_all' * 100
	gen double mean_raw_numb  = `mean_raw'
	gen double mean_winsor_numb = `mean_winsor'
	export delimited using "$tables/numb_clauses_outliers/winsor_threshold.csv", replace
restore

* Build _pre and _pre4 for winsorized variable (mirrors how numb_clauses_pre4 is built)
cap drop numb_clauses_w_pre_o
cap drop numb_clauses_w_pre
quietly {
	bys identificad: egen numb_clauses_w_pre_o = mean(numb_clauses_w) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_w_pre = min(numb_clauses_w_pre_o)
	drop numb_clauses_w_pre_o
}

cap drop numb_clauses_w_pre4_o
cap drop numb_clauses_w_pre4
quietly {
	egen numb_clauses_w_pre4_o = cut(numb_clauses_w_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_w_pre4 = min(numb_clauses_w_pre4_o)
	drop numb_clauses_w_pre4_o
}

* Also build _pre and _pre4 for original numb_clauses (used in baseline absorb)
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

* Pre bins for labor outcomes (used in year-based regressions)
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}

	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		egen `outcome'_pre4_o = cut(`outcome'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
	}
}

********************************************************************************
* SECTION 5: SPECIFICATION MACROS
********************************************************************************

local conn "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

********************************************************************************
* SECTION 6: SPILLOVER CLAUSE COUNT REGRESSIONS — BASELINE vs WINSORIZED
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER REGRESSIONS: numb_clauses BASELINE vs WINSORIZED"
di as result "-----------------------------------------------------------------------"

tempname cres
tempfile cres_file
postfile `cres' str20 version str24 outcome ///
	double b_post se_post p_post double b_pre se_pre p_pre ///
	double pre_ftest_pval long n_obs long n_estab ///
	using `cres_file', replace

foreach version in baseline winsorized {

	local outcome "numb_clauses"
	if "`version'" == "winsorized" local outcome "numb_clauses_w"

	// Use the appropriate pre4 bins in the absorb
	if "`version'" == "baseline" {
		local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
	}
	else {
		local absorb_cba "`base_fe_cba' ib0.numb_clauses_w_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
	}

	di as text "  `version': `outcome'"

	reghdfe `outcome' c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	reghdfe `outcome' c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	reghdfe `outcome' c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	post `cres' ("`version'") ("`outcome'") ///
		(`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') ///
		(`pre_ftest_pval') (`n_obs') (`n_estab')
}

postclose `cres'

preserve
	use `cres_file', clear
	export delimited using "$tables/numb_clauses_outliers/winsor_clause_spill_results.csv", replace
restore

********************************************************************************
* SECTION 7: YEAR-BASED LABOR SPILLOVER REGRESSIONS
* These use l_firm_emp and lr_remdezr_w as outcomes — unaffected by winsorizing
* numb_clauses. Run on the full spillover sample to confirm no change.
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "LABOR SPILLOVER REGRESSIONS (should be unaffected by winsorization)"
di as result "-----------------------------------------------------------------------"

local labor_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"

tempname lres
tempfile lres_file
postfile `lres' str24 outcome ///
	double b_post se_post p_post double b_pre se_pre p_pre ///
	double pre_ftest_pval long n_obs long n_estab ///
	using `lres_file', replace

foreach outcome of local labor_outcomes {
	di as text "  Labor spillover: `outcome'"
	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)
	local b_pre  = _b[1.placebo_year#c.`conn']
	local se_pre = _se[1.placebo_year#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	post `lres' ("`outcome'") ///
		(`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') ///
		(`pre_ftest_pval') (`n_obs') (`n_estab')
}

postclose `lres'

preserve
	use `lres_file', clear
	export delimited using "$tables/numb_clauses_outliers/winsor_labor_spill_results.csv", replace
restore

di as result "Winsorization robustness check complete."
log close
