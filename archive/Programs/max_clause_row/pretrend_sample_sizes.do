********************************************************************************
* pretrend_sample_sizes.do
*
* max_clause_row.do stores n_obs / n_estab from the MAIN regression only, so
* Panel B of the comparison table has empty sample-size columns. The placebo
* regressions are estimated on cba_period <= 2 only and therefore have their
* own, much smaller samples. This script recovers those, for both arms and
* every specification, and writes them alongside the placebo coefficients.
*
* Prep is identical to max_clause_row.do; only the placebo regressions run.
* Output: Tables/max_clause_row/pretrend_sample_sizes.csv
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
log using "$logs/max_clause_row/pretrend_sample_sizes_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* PREP (identical to max_clause_row.do)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore
cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

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

cap drop wage_clauses
cap drop emp_clauses
cap drop other_clauses
cap drop wage_clause_prop
cap drop emp_clause_prop
cap drop other_clause_prop
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

gen double wage_clause_prop  = wage_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double emp_clause_prop   = emp_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double other_clause_prop = other_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)

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

foreach v in numb_clauses wage_clauses emp_clauses other_clauses ///
             wage_clause_prop emp_clause_prop other_clause_prop cba_value {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

tempfile prepped
save `prepped'

********************************************************************************
* PLACEBO REGRESSIONS ONLY — capture N and exact t-based p-values
********************************************************************************

tempname pf
tempfile pf_data
postfile `pf' str16 regression str20 outcome str10 arm ///
	double pre_coef pre_se pre_pval pre_n_obs pre_n_estab pre_df ///
	using `pf_data', replace

local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

local spill_outcomes "numb_clauses wage_clauses emp_clauses other_clauses wage_clause_prop emp_clause_prop other_clause_prop cba_value"

foreach arm in baseline filtered {

	use `prepped', clear

	if "`arm'" == "filtered" {
		cap drop _negclauses
		gen double _negclauses = -numb_clauses
		sort identificad cba_period _negclauses avg_file_date year
		cap drop _rank
		by identificad cba_period: gen long _rank = _n
		drop if !missing(cba_period) & _rank > 1
		cap drop _negclauses
		cap drop _rank
	}

	* Direct-effect placebos, samples A and C
	foreach panel in A C {

		if "`panel'" == "A" local s_use "`s_direct_A'"
		if "`panel'" == "C" local s_use "`s_direct_C'"

		local outcome "numb_clauses"
		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' i.treat_ultra##pre_treat_cba ///
			if `s_use' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b   = _b[1.treat_ultra#1.pre_treat_cba]
		local se  = _se[1.treat_ultra#1.pre_treat_cba]
		local df  = e(df_r)
		local p   = 2*ttail(`df', abs(`b'/`se'))

		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ///
			(`b') (`se') (`p') (e(N)) (e(N_clust)) (`df')
	}

	* Spillover placebos
	foreach outcome of local spill_outcomes {

		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b   = _b[1.pre_treat_cba#c.`conn']
		local se  = _se[1.pre_treat_cba#c.`conn']
		local df  = e(df_r)
		local p   = 2*ttail(`df', abs(`b'/`se'))

		post `pf' ("spillover") ("`outcome'") ("`arm'") ///
			(`b') (`se') (`p') (e(N)) (e(N_clust)) (`df')
	}
}

postclose `pf'

use `pf_data', clear
export delimited using "$tables/max_clause_row/pretrend_sample_sizes.csv", replace

list, noobs

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Pre-trend Ns done" "placebo sample sizes both arms"
