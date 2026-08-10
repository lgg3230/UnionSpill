********************************************************************************
* exact_pretrend_pval.do
* The clause-count spillover pre-trend p-values straddle the 0.10 star
* threshold (normal approximation: 0.1060 baseline, 0.0960 filtered).
* Recover the exact t-based p-values reghdfe would report, using e(df_r),
* for that one specification in both arms. Targeted rerun: the placebo
* regressions use only cba_period <= 2, so this is cheap.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/max_clause_row/exact_pretrend_pval_`d'_`t'.log", replace text

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

tempfile prepped
save `prepped'

local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

foreach arm in baseline filtered {

	use `prepped', clear

	if "`arm'" == "filtered" {
		cap drop _negclauses
		gen double _negclauses = -numb_clauses
		sort identificad cba_period _negclauses avg_file_date year
		cap drop _rank
		by identificad cba_period: gen long _rank = _n
		drop if !missing(cba_period) & _rank > 1
	}

	reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b   = _b[1.pre_treat_cba#c.`conn']
	local se  = _se[1.pre_treat_cba#c.`conn']
	local df  = e(df_r)
	local p_t = 2*ttail(`df', abs(`b'/`se'))
	local p_z = 2*(1 - normal(abs(`b'/`se')))

	di as result "ARM `arm': b=" %9.6f `b' "  se=" %9.6f `se' "  df_r=" `df'
	di as result "   exact t p-value = " %9.6f `p_t'
	di as result "   normal-approx p = " %9.6f `p_z'
	di as result "   star at 0.10?  t: " cond(`p_t'<0.10,"YES","NO") ///
		"   z: " cond(`p_z'<0.10,"YES","NO")
}

capture log close
