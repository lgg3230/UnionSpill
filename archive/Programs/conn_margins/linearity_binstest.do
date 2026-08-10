/*
Linearity test — panel DiD formulation
Cattaneo, Crump, Farrell, Feng (2024)

H0: E[outcome | conn×post, FE] is linear in conn×post

Running variable: totaltreat_pw_norm × treat_year      (calendar-year outcomes)
                  totaltreat_pw_norm × post_treat_cba   (numb_clauses)

FE structure mirrors conn_margins.do exactly (firm FE + industry/mode/region × year,
plus outcome pre4 bins × year and totalflows bins × year).

mass point at x=0 (all pre-period obs) handled with masspoints(nolocalcheck).

Output: Tables/conn_margins/linearity_binstest_panel.csv
*/

version 17.0

* ── Paths ─────────────────────────────────────────────────────────────────────

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"
global programs  "$main/Programs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/conn_margins"
log using "$logs/conn_margins/linearity_binstest_panel_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

* ── Install binsreg if needed ────────────────────────────────────────────────

cap which binstest
if _rc != 0 {
	di "Installing binsreg from SSC..."
	ssc install binsreg, replace
}

* ── Load data ─────────────────────────────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows ─────────────────────────────────────────────────────────

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

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

keep if year >= 2009
keep if lagos_sample_avg == 1

* ── Variable creation (mirrors conn_margins.do) ───────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Numeric firm ID for clustering in binstest (binstest does not handle string clusters)
cap drop firm_num
encode identificad, gen(firm_num)

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

gen byte post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* Connectivity scaling
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* Running variables: connectivity × post indicator
cap drop conn_x_post
cap drop conn_x_post_cba
gen double conn_x_post     = totaltreat_pw_norm * treat_year
gen double conn_x_post_cba = totaltreat_pw_norm * post_treat_cba

* Pre-treatment employment mean
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

* Pre-treatment outcome means
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

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

* 4-bin controls
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre4_o
	cap drop numb_clauses_pre4
	quietly {
		egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
		drop numb_clauses_pre4_o
		replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
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

* ── FE macros (mirror conn_margins.do exactly) ───────────────────────────────

local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── Initialize output CSV ────────────────────────────────────────────────────

tempname fh
file open `fh' using "$tables/conn_margins/linearity_binstest_panel.csv", write replace
file write `fh' "outcome,year_sample,n,nbins,stat_supt,pval,nsims,simsgrid" _n
file close `fh'

* ── Cross-section at year == 2011 ────────────────────────────────────────────
*
* Running variable: totaltreat_pw_norm (continuous, no mass point).
* Controls passed as othercovs; binstest handles them via regress internally.
* One obs per firm at year==2011, so vce(robust) == vce(cluster firm_num).

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di _newline "============================================================"
	di "Linearity test (cross-section 2011): `outcome'"
	di "============================================================"

	if "`outcome'" == "l_firm_emp" {
		local controls "i.industry1 i.mode_base_month i.microregion ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"
	}
	else {
		local controls "i.industry1 i.mode_base_month i.microregion ib0.`outcome'_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"
	}

	binstest `outcome' totaltreat_pw_norm `controls' ///
		if `s_spill' & year == 2011, ///
		vce(robust) nbins(50) masspoints(nolocalcheck) ///
		testmodelpoly(1) nsims(2000) simsgrid(50) simsseed(12345)

	local stat  = e(stat_poly)
	local pval  = e(pval_poly)
	local nbins = e(nbins)
	local n     = e(N)

	di "  N: `n'  |  bins: `nbins'  |  stat: " %6.4f `stat' "  |  p-val: " %6.4f `pval'

	tempname fh
	file open `fh' using "$tables/conn_margins/linearity_binstest_panel.csv", write append
	file write `fh' `"`outcome',2011,`n',`nbins',`stat',`pval',2000,50"' _n
	file close `fh'
}

* ── numb_clauses at cba_period == 2 ──────────────────────────────────────────

capture confirm variable numb_clauses
if _rc == 0 {

	di _newline "============================================================"
	di "Linearity test (cba_period==2): numb_clauses"
	di "============================================================"

	local controls_cba "i.industry1 i.mode_base_month i.microregion ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"

	binstest numb_clauses totaltreat_pw_norm `controls_cba' ///
		if `s_spill' & cba_period == 2, ///
		vce(robust) nbins(50) masspoints(nolocalcheck) ///
		testmodelpoly(1) nsims(2000) simsgrid(50) simsseed(12345)

	local stat  = e(stat_poly)
	local pval  = e(pval_poly)
	local nbins = e(nbins)
	local n     = e(N)

	di "  N: `n'  |  bins: `nbins'  |  stat: " %6.4f `stat' "  |  p-val: " %6.4f `pval'

	tempname fh
	file open `fh' using "$tables/conn_margins/linearity_binstest_panel.csv", write append
	file write `fh' `"numb_clauses,cba_period2,`n',`nbins',`stat',`pval',2000,50"' _n
	file close `fh'
}

* ── Summary ───────────────────────────────────────────────────────────────────

di _newline "======================================================="
di "LINEARITY TEST RESULTS (cross-section 2011)"
di "H0: E[outcome | totaltreat_pw_norm, controls] is linear in connectivity"
di "======================================================="
di "See: $tables/conn_margins/linearity_binstest_panel.csv"
di "======================================================="

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "binstest panel done" "linearity_binstest.do complete"
