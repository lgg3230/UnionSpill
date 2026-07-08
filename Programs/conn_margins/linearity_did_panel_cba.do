/*
================================================================================
linearity_did_panel_cba.do — DIAGNOSTIC: why the raw-panel binsreg degenerates.

NOT the headline test. This documents that running binstest directly on the raw
DiD with native absorb() FAILS, so nobody re-attempts the naive route. The
HEADLINE clause linearity test is linearity_did_resid_cba.do.

RESULT (recorded 2026-06-16): the binstest recovers the published slope 0.0180
exactly, but the linearity statistic DEGENERATES — sup-t ~= 1.1e12, bins collapse
50 -> 17, p reported 0.0000. This is numerical breakdown, not a real rejection.
CAUSE: the running variable conn x post is an ATOM. Every pre-period observation
(cba_period 1-2) and every unconnected firm sits at exactly 0 (40%+ of the 19,693
firm-year obs). binsreg bins on the RAW running variable, so it cannot resolve the
mass point; the within-bin variance collapses and the sup-t explodes. The DiD
slope (a single linear projection) is unaffected, but the nonparametric
dose-response curve is NOT identified by binning the raw panel. The fix is to
remove the firm FE from the running variable (within-transform), which spreads the
atom — i.e. the residualized panel test (linearity_did_resid_cba.do) or the FD.

Tests linearity of the dose-response in the PUBLISHED 6-level cba_period DiD
(Main_Results_pct_tfpw_07_11.do PART D, numb_clauses spillover, beta = 0.0180)
WITHOUT pre-residualizing anything.

Method: run the Cattaneo, Crump, Farrell & Feng (2024) binstest directly on the
raw DiD equation. The running variable is the treatment term itself,
    D = conn x post   (conn_x_post_cba),
and EVERY other regressor — firm FE + industry/month/microregion/bin x cba_period
FE — is passed to binstest's native absorb(), which uses reghdfe to project them
out of the outcome and of the SPLINE BASIS of D jointly inside the fit.

Why this is the right test (and not "Problem 1"): Cattaneo's "Problem 1" is the
distortion from MANUALLY pre-residualizing y and D on covariates and then binning
the residuals as if raw. binstest's absorb() does the within-projection of the
basis jointly with the bin estimation (proper semi-linear / within estimator), so
it is the correct internal adjustment. The earlier residualized do-file
(linearity_did_resid_cba.do) used manual pre-residualization and is removed.

Feasibility: the ~8,000 firm dummies that make internal-w infeasible as othercovs
are instead absorbed by reghdfe (fast). The binsreg basis is within-transformed,
not g itself, so the nonlinear-within issue does not arise.

This runs on the SAME firm-year observations as the DiD, so its N matches the DiD
estimation sample — there is no establishment-count reduction.

Outputs (Tables/conn_margins/):
  linearity_did_panel_cba_test.csv            binstest result row
  linearity_did_panel_cba_numb_clauses.csv    FE-residualized (y,D) for the figure
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
log using "$logs/conn_margins/linearity_did_panel_cba_`d'_`t'.log", replace text

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
local conn    "totaltreat_pw_norm"

* numeric firm id for clustering (binstest disallows string clusters)
cap drop firm_num
encode identificad, gen(firm_num)

* ── cba_period + connectivity + running variable D = conn x post ──────────────

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
cap drop post_treat_cba
gen byte post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop conn_x_post_cba
gen double conn_x_post_cba = totaltreat_pw_norm * post_treat_cba

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}
cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period,1,2)
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

* ── The published DiD absorb set (everything except the treatment term D) ──────

local absorb_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── (0) Published DiD: confirm the target slope + lock the estimation sample ───

di _newline "==== PUBLISHED DiD (6-level cba_period FE) ===="
reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster firm_num)
local b_panel = _b[1.post_treat_cba#c.`conn']
di as result "PUBLISHED beta (target ~0.0180) = " %9.6f `b_panel'
cap drop did_sample
gen byte did_sample = e(sample)

* ── (1) HEADLINE: binstest on the raw DiD, FE absorbed natively ───────────────
* Running variable = D = conn_x_post_cba. All other regressors -> absorb().
* binstest within-projects the spline basis of D on the FE jointly (no manual
* pre-residualization), so the linear restriction it tests IS the published DiD.

di _newline "==== HEADLINE binstest (raw DiD, native HDFE absorb) ===="
binstest numb_clauses conn_x_post_cba if did_sample, ///
	absorb(`absorb_cba') ///
	testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
	nsims(2000) simsgrid(50) simsseed(12345) vce(cluster firm_num)
local stat  = e(stat_poly)
local pval  = e(pval_poly)
local nbins = e(nbins)
local n     = e(N)
di "  N=`n'  bins=`nbins'  sup-t=" %6.4f `stat' "  p=" %6.4f `pval'

* ── (2) Export test row ───────────────────────────────────────────────────────

tempname fh
file open `fh' using "$tables/conn_margins/linearity_did_panel_cba_test.csv", write replace
file write `fh' "outcome,sample,n,nbins,stat_supt,pval,nsims,simsgrid,beta_published" _n
file write `fh' `"numb_clauses,s_spill_panel,`n',`nbins',`stat',`pval',2000,50,`b_panel'"' _n
file close `fh'

* ── (3) FE-residualized (y, D) for the figure (plotting aid only) ─────────────
* The TEST above uses native absorb; these residuals just reproduce the binscatter
* points for the figure. FWL on the same absorb set; slope of yres on Dres = beta.

cap drop yres
cap drop Dres
reghdfe numb_clauses    if did_sample, absorb(`absorb_cba') residuals(yres)
reghdfe conn_x_post_cba if did_sample, absorb(`absorb_cba') residuals(Dres)

preserve
	keep if did_sample
	keep identificad firm_num year cba_period yres Dres
	export delimited "$tables/conn_margins/linearity_did_panel_cba_numb_clauses.csv", replace
restore

di _newline "======================================================="
di "HEADLINE PANEL BINSTEST (numb_clauses, raw DiD, native absorb)"
type "$tables/conn_margins/linearity_did_panel_cba_test.csv"

capture log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "clause panel binstest done" "raw-DiD native-absorb binstest for numb_clauses complete"
