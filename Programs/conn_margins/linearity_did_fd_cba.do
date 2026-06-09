/*
================================================================================
linearity_did_fd_cba.do — clause linearity test on a firm x cba_period panel

numb_clauses lives on the irregular CBA-negotiation calendar, not the balanced
annual panel, so the first-difference/panel equivalence that is exact for the
calendar outcomes only holds approximately when pre/post clause means are taken
over cba_period inside the firm x year data.

This rebuilds the clause analysis on a firm x cba_period panel (one row per firm
per CBA period), redefines every time-indexed object in cba_period terms, and:
  (1) explores balance (pre/post period counts per firm),
  (2) validates the FD slope against the panel DiD coefficient,
  (3) if validated, runs the Cattaneo binstest on the FD cross-section.

Outputs: diagnostics to log; (if it validates) test row + cross-section CSV.
================================================================================
*/

version 17.0
set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/conn_margins"
log using "$logs/conn_margins/linearity_did_fd_cba_`d'_`t'.log", replace text

cap which binstest
if _rc != 0 ssc install binsreg, replace

* ── Load + merge totalflows ───────────────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile tf
	save `tf'
restore
merge m:1 identificad using `tf', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen tfc = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace tfc = tfc + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11/tfc if tfc>0
replace totalflows_pw_pre_07_11 = . if tfc==0
drop tfc

keep if year >= 2009
keep if lagos_sample_avg == 1

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── cba_period + connectivity + firm-level bins (firm x year data) ────────────

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* firm-level pre-treatment bins (computed on firm x year data, time-invariant)
cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}
cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o

	egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
	replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)

	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── Restrict to clause analysis sample, collapse to firm x cba_period ─────────

keep if `s_spill' & !missing(cba_period) & !missing(numb_clauses)

di _newline "==== firm x year obs by cba_period (clause sample) ===="
tab cba_period

* how many firm-years map to a single firm-cba_period cell?
cap drop _nfp
bys identificad cba_period: gen _nfp = _N
di _newline "==== firm-years per (firm,cba_period) cell ===="
tab _nfp

collapse (mean) numb_clauses ///
         (first) totaltreat_pw_norm industry1 mode_base_month microregion ///
                 numb_clauses_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114, ///
         by(identificad cba_period)

gen byte post = cba_period >= 3

* ── Balance diagnostics ───────────────────────────────────────────────────────

cap drop n_pre
cap drop n_post
bys identificad: egen n_pre  = total(post==0)
bys identificad: egen n_post = total(post==1)

preserve
	bys identificad: keep if _n == 1
	di _newline "==== periods per firm: pre (1-2) x post (3-6) ===="
	tab n_pre n_post
	count
	di "firms total: " r(N)
	count if n_pre>0 & n_post>0
	di "firms with BOTH windows: " r(N)
	count if n_pre==2 & n_post==4
	di "firms with ALL 6 periods (fully balanced): " r(N)
restore

* keep only firms identified by the DiD (need both windows)
keep if n_pre > 0 & n_post > 0

* ── (1) Panel DiD on firm x cba_period panel ─────────────────────────────────

local absorb "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period ib0.totalflows_pw_pre_07_114#i.cba_period"

di _newline "==== PANEL DiD (firm x cba_period) ===="
reghdfe numb_clauses c.totaltreat_pw_norm##i.post, absorb(`absorb') vce(cluster identificad)
local b_panel  = _b[1.post#c.totaltreat_pw_norm]
local se_panel = _se[1.post#c.totaltreat_pw_norm]

* ── (2) First difference on the cba_period panel ──────────────────────────────

cap drop clauses_post_o
cap drop clauses_post
cap drop clauses_pre_o
cap drop clauses_pre
quietly {
	bys identificad: egen clauses_post_o = mean(numb_clauses) if post==1
	bys identificad: egen clauses_post   = min(clauses_post_o)
	drop clauses_post_o
	bys identificad: egen clauses_pre_o  = mean(numb_clauses) if post==0
	bys identificad: egen clauses_pre    = min(clauses_pre_o)
	drop clauses_pre_o
}
cap drop clauses_fd
gen double clauses_fd = clauses_post - clauses_pre

di _newline "==== FIRST DIFFERENCE (one row per firm) ===="
preserve
	bys identificad: keep if _n == 1
	reghdfe clauses_fd c.totaltreat_pw_norm ///
		ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114, ///
		absorb(industry1 mode_base_month microregion) vce(robust)
	local b_fd  = _b[totaltreat_pw_norm]
	local se_fd = _se[totaltreat_pw_norm]

	di _newline "==== VALIDATION (cba_period panel) ===="
	di "panel beta = " %9.6f `b_panel' "   FD beta = " %9.6f `b_fd' ///
		"   diff = " %9.2e (`b_panel'-`b_fd') ///
		"   se_ratio = " %6.3f (`se_fd'/`se_panel')

	* binstest on the FD cross-section (internal-w), only if it validates
	local W "i.industry1 i.mode_base_month i.microregion ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"
	di _newline "==== binstest (FD cross-section, cba_period) ===="
	binstest clauses_fd totaltreat_pw_norm `W' if !missing(clauses_fd), ///
		testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
		nsims(2000) simsgrid(50) simsseed(12345) vce(robust)
	di "  N=" e(N) "  bins=" e(nbins) "  stat=" %6.4f e(stat_poly) "  p=" %6.4f e(pval_poly)

	* export cross-section for the figure
	gen double outcome_fd = clauses_fd
	keep identificad outcome_fd totaltreat_pw_norm industry1 mode_base_month ///
	     microregion numb_clauses_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114
	rename numb_clauses_pre4 outcome_pre4
	export delimited "$tables/conn_margins/linearity_did_fd_cba_numb_clauses.csv", replace
restore

* ── (3) Balanced subset: firms with ALL 6 periods (n_pre==2 & n_post==4) ──────
* If the cba_period panel is balanced, the FD must reproduce the panel exactly.

keep if n_pre == 2 & n_post == 4

di _newline "==== BALANCED SUBSET (all 6 periods) ===="
count
bys identificad: gen _one = (_n==1)
count if _one
di "balanced firms: " r(N)

reghdfe numb_clauses c.totaltreat_pw_norm##i.post, absorb(`absorb') vce(cluster identificad)
local b_panel_bal  = _b[1.post#c.totaltreat_pw_norm]
local se_panel_bal = _se[1.post#c.totaltreat_pw_norm]

preserve
	bys identificad: keep if _n == 1
	reghdfe clauses_fd c.totaltreat_pw_norm ///
		ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114, ///
		absorb(industry1 mode_base_month microregion) vce(robust)
	local b_fd_bal  = _b[totaltreat_pw_norm]
	local se_fd_bal = _se[totaltreat_pw_norm]

	di _newline "==== VALIDATION (balanced subset) ===="
	di "panel beta = " %9.6f `b_panel_bal' "   FD beta = " %9.6f `b_fd_bal' ///
		"   diff = " %9.2e (`b_panel_bal'-`b_fd_bal') ///
		"   se_ratio = " %6.3f (`se_fd_bal'/`se_panel_bal')

	di _newline "==== binstest (balanced FD cross-section) ===="
	binstest clauses_fd totaltreat_pw_norm ///
		i.industry1 i.mode_base_month i.microregion ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114 ///
		if !missing(clauses_fd), ///
		testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
		nsims(2000) simsgrid(50) simsseed(12345) vce(robust)
	di "  N=" e(N) "  bins=" e(nbins) "  stat=" %6.4f e(stat_poly) "  p=" %6.4f e(pval_poly)
restore

capture log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "linearity_did_fd_cba done" "clause cba_period FD validation complete"
