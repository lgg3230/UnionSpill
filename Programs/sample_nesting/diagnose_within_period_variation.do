********************************************************************************
* diagnose_within_period_variation.do
* For establishments observed more than once within a single cba_period in the
* numb_clauses spillover estimation sample: does numb_clauses actually VARY
* within the cell, or are these repeated rows carrying the same agreement?
*
* If constant within cell, the multi-obs cells are the same CBA attached to
* two calendar years, not two distinct agreements.
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
log using "$logs/sample_nesting/diagnose_within_period_variation_`d'_`t'.log", replace text

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
* SECTION 3: RECOVER THE CLAUSE ESTIMATION SAMPLE
********************************************************************************

local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

reghdfe numb_clauses c.`conn'##i.post_treat_cba ///
	if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
cap drop insamp_clause
gen byte insamp_clause = e(sample)
di as result "clause obs = " e(N) "  estabs = " e(N_clust)

keep if insamp_clause == 1

********************************************************************************
* SECTION 4: WITHIN-CELL VARIATION IN numb_clauses
********************************************************************************

cap drop n_in_cell
bysort identificad cba_period: gen long n_in_cell = _N

cap drop sd_clauses
bysort identificad cba_period: egen double sd_clauses = sd(numb_clauses)

cap drop range_clauses
cap drop max_clauses
cap drop min_clauses
bysort identificad cba_period: egen double max_clauses = max(numb_clauses)
bysort identificad cba_period: egen double min_clauses = min(numb_clauses)
gen double range_clauses = max_clauses - min_clauses

cap drop varies
gen byte varies = (range_clauses > 0) if n_in_cell > 1

di as result "=== Cells with >1 obs: does numb_clauses vary within the cell? ==="
di as result "(observation-level; cells counted once further down)"
tab varies if n_in_cell > 1, missing

di as result ""
di as result "=== Same, at the CELL level ==="
preserve
	bysort identificad cba_period: keep if _n == 1
	di as result "Total firm x cba_period cells:"
	count
	di as result "Cells with more than one observation:"
	count if n_in_cell > 1
	di as result "  of which numb_clauses CONSTANT within cell:"
	count if n_in_cell > 1 & range_clauses == 0
	di as result "  of which numb_clauses VARIES within cell:"
	count if n_in_cell > 1 & range_clauses > 0

	di as result ""
	di as result "Distribution of within-cell range, multi-obs cells:"
	summ range_clauses if n_in_cell > 1, detail

	di as result ""
	di as result "Within-cell range by cell size:"
	tabstat range_clauses if n_in_cell > 1, by(n_in_cell) stat(n mean sd min p50 max)
restore

********************************************************************************
* SECTION 5: WHICH YEARS GET PAIRED, AND DO THE OTHER RHS VARS MOVE?
********************************************************************************

di as result ""
di as result "=== Calendar years inside multi-obs cells, by cba_period ==="
tab cba_period year if n_in_cell > 1, missing

di as result ""
di as result "=== Does post_treat_cba vary within cell? (should not: function of cba_period) ==="
cap drop sd_post
bysort identificad cba_period: egen double sd_post = sd(post_treat_cba)
count if n_in_cell > 1 & sd_post > 0 & !missing(sd_post)
di as result "  multi-obs observations where post_treat_cba varies: " r(N)

di as result ""
di as result "=== Does avg_file_date vary within cell? (identifies same-CBA duplicates) ==="
cap drop sd_filedate
bysort identificad cba_period: egen double sd_filedate = sd(avg_file_date)
preserve
	bysort identificad cba_period: keep if _n == 1
	count if n_in_cell > 1
	di as result "  multi-obs cells: " r(N)
	count if n_in_cell > 1 & sd_filedate == 0
	di as result "  with IDENTICAL avg_file_date (same agreement): " r(N)
	count if n_in_cell > 1 & sd_filedate > 0 & !missing(sd_filedate)
	di as result "  with DIFFERENT avg_file_date: " r(N)
restore

********************************************************************************
* SECTION 6: HOW MUCH OF THE ESTIMATION SAMPLE IS AFFECTED
********************************************************************************

di as result ""
di as result "=== Share of estimation sample in multi-obs cells ==="
count
local n_all = r(N)
count if n_in_cell > 1
di as result "  obs in multi-obs cells: " r(N) " of `n_all'"
count if n_in_cell > 1 & range_clauses == 0
di as result "  obs in multi-obs cells with CONSTANT outcome: " r(N)

preserve
	bysort identificad cba_period: keep if _n == 1
	keep identificad cba_period n_in_cell range_clauses sd_clauses
	export delimited using "$tables/sample_nesting/within_period_variation.csv", replace
restore

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Within-period variation done" "numb_clauses within firm x cba_period"
