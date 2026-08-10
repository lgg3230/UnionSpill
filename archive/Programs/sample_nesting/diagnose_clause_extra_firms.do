********************************************************************************
* diagnose_clause_extra_firms.do
* Why does the numb_clauses spillover sample contain 58 MORE establishments
* than the wage sample, despite having far FEWER firm-year observations?
*
* Two competing explanations:
*   H1 (firm-FE singleton via partial wage missingness):
*       The extra firms have <2 non-missing wage-years, so reghdfe drops them
*       as identificad singletons, while they retain >=2 clause observations.
*   H2 (interacted-cell granularity):
*       year-indexed FE cells are thinner than cba_period-indexed cells,
*       so the cascade purges more firms in the wage spec.
*
* Also answers directly: is any establishment observed more than once within
* a single cba_period in the clause estimation sample?
*
* Reuses the data prep from check_sample_nesting.do verbatim.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/sample_nesting/diagnose_clause_extra_firms_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD AND MERGE  (verbatim from check_sample_nesting.do)
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

********************************************************************************
* SECTION 2: VARIABLES  (verbatim from check_sample_nesting.do)
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

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

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
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

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		egen `outcome'_pre4_o = cut(`outcome'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
	}
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
}

********************************************************************************
* SECTION 3: THE TWO ESTIMATION SAMPLES
********************************************************************************

local conn        "totaltreat_pw_norm"
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_wage "`base_fe' ib0.lr_remdezr_w_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

di as result "=== WAGE spillover regression ==="
reghdfe lr_remdezr_w c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_wage') vce(cluster identificad)
cap drop insamp_wage
gen byte insamp_wage = e(sample)
di as result "wage obs = " e(N) "  estabs = " e(N_clust)

di as result "=== CLAUSE spillover regression ==="
reghdfe numb_clauses c.`conn'##i.post_treat_cba ///
	if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
cap drop insamp_clause
gen byte insamp_clause = e(sample)
di as result "clause obs = " e(N) "  estabs = " e(N_clust)

********************************************************************************
* SECTION 4: DOES ANY FIRM APPEAR TWICE IN ONE CBA_PERIOD?
********************************************************************************

di as result "=== Q: obs per establishment x cba_period, clause estimation sample ==="
preserve
	keep if insamp_clause == 1
	bysort identificad cba_period: gen long n_in_cell = _N
	tab n_in_cell, missing
	di as result "max obs for a single estab x cba_period cell:"
	summ n_in_cell
restore

********************************************************************************
* SECTION 5: FIRM-LEVEL COUNTS FOR THE 58 EXTRA FIRMS
********************************************************************************

* Firm-level membership flags
cap drop any_wage
cap drop any_clause
bysort identificad: egen byte any_wage   = max(insamp_wage)
bysort identificad: egen byte any_clause = max(insamp_clause)

* Rows that are ELIGIBLE for the wage spec before singleton dropping:
* in s_spill, outcome non-missing, and every absorb component non-missing.
cap drop elig_wage
gen byte elig_wage = (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1) ///
	& !missing(lr_remdezr_w) & !missing(totaltreat_pw_norm) ///
	& !missing(identificad) & !missing(industry1) & !missing(mode_base_month) ///
	& !missing(microregion) & !missing(year) ///
	& !missing(lr_remdezr_w_pre4) & !missing(l_firm_emp_pre4) ///
	& !missing(totalflows_pw_pre_07_114)

cap drop elig_clause
gen byte elig_clause = (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1) ///
	& !missing(numb_clauses) & !missing(cba_period) & !missing(totaltreat_pw_norm) ///
	& !missing(identificad) & !missing(industry1) & !missing(mode_base_month) ///
	& !missing(microregion) ///
	& !missing(numb_clauses_pre4) & !missing(l_firm_emp_pre4) ///
	& !missing(totalflows_pw_pre_07_114)

cap drop n_elig_wage
cap drop n_elig_clause
bysort identificad: egen long n_elig_wage   = total(elig_wage)
bysort identificad: egen long n_elig_clause = total(elig_clause)

* Flag the extra firms: in clause sample, not in wage sample
cap drop extra_firm
gen byte extra_firm = (any_clause == 1 & any_wage == 0)

preserve
	bysort identificad: keep if _n == 1
	di as result "=== Establishment counts ==="
	count if any_wage == 1
	di as result "  estabs in wage sample:   " r(N)
	count if any_clause == 1
	di as result "  estabs in clause sample: " r(N)
	count if extra_firm == 1
	di as result "  extra (clause not wage): " r(N)

	di as result ""
	di as result "=== H1 TEST: eligible wage-years for the extra firms ==="
	di as result "(H1 predicts a mass at 0 and 1: too few years to survive the firm FE)"
	tab n_elig_wage if extra_firm == 1, missing

	di as result ""
	di as result "=== Their eligible CLAUSE-years, same firms ==="
	tab n_elig_clause if extra_firm == 1, missing

	di as result ""
	di as result "=== Benchmark: eligible wage-years for firms IN the wage sample ==="
	tab n_elig_wage if any_wage == 1, missing

	di as result ""
	di as result "=== H1 accounting ==="
	count if extra_firm == 1 & n_elig_wage == 0
	local h1_zero = r(N)
	count if extra_firm == 1 & n_elig_wage == 1
	local h1_one = r(N)
	count if extra_firm == 1 & n_elig_wage >= 2
	local h1_two = r(N)
	di as result "  extra firms with 0 eligible wage-years:  `h1_zero'  (never in wage spec)"
	di as result "  extra firms with 1 eligible wage-year:   `h1_one'   (firm-FE singleton -> H1)"
	di as result "  extra firms with >=2 eligible wage-years: `h1_two'  (must be cascade -> H2)"

	* Export
	keep identificad extra_firm any_wage any_clause n_elig_wage n_elig_clause
	order identificad any_wage any_clause n_elig_wage n_elig_clause extra_firm
	export delimited using "$tables/sample_nesting/extra_firm_diagnosis.csv", replace
restore

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Clause-extra-firm diagnosis done" "H1 vs H2 for the 58 firms"
