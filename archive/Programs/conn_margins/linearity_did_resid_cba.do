/*
================================================================================
linearity_did_resid_cba.do — Cattaneo linearity test for numb_clauses on the
PUBLISHED 6-level cba_period DiD (reproduces the 0.0180 spillover slope).

A first difference is a 2-period object and can only reproduce the 2-level
pre/post DiD (0.0145), not the published spec, which uses 6 cba_period fixed
effects (4012_pct_tfpw.do PART D). To test linearity against the
published coefficient we use Frisch-Waugh residualization:

    y_res = numb_clauses  residualized on the full published FE set
    d_res = (conn x post)  residualized on the full published FE set
    OLS of y_res on d_res  ==  the published DiD beta  (0.0180), by FWL.

The Cattaneo binstest then tests linearity of E[y_res | d_res].

WHY RESIDUALIZATION IS REQUIRED (not just a feasibility fallback):
Running binstest directly on the raw DiD with native absorb() — the textbook-exact
internal adjustment — DEGENERATES here (see linearity_did_panel_cba.do: sup-t blows
up to ~1e12, bins collapse 50->17). The running variable conn x post is an ATOM:
every pre-period obs and every unconnected firm sits at exactly 0 (40%+ of the
sample), and binsreg bins on the RAW running variable, so the mass point cannot be
resolved and the bin variance explodes. The DiD slope (one linear projection) is
fine, but the nonparametric curve is not identified by binning the raw panel. To
bin a sensible dose-response the atom must be removed, i.e. the firm FE must be
taken out of the running variable — that is exactly this residualization (the FD
does the same by collapsing to firm-level conn).

ON "PROBLEM 1": Cattaneo, Crump, Farrell & Feng (2024) warn against pre-residual-
ization when the covariate adjustment involves flexibly-adjusted CONTINUOUS controls.
Here EVERY control is an additive categorical fixed effect (firm, group x period,
bin x period); for additive FE, residualization equals the exact within/FWL
projection, and under the linear null the bin basis is linear so projection
commutes. The test is therefore SIZE-VALID under the linearity null — the right
condition for a test that fails to reject. Reported alongside the weighted-FD test
(linearity_did_fd_cba_binstest.do), which gives the same verdict.

Unlike the FD cross-section (one row per firm, N = firms with both windows), this
test runs on the SAME firm-year observations as the DiD, so its N matches the
DiD estimation sample exactly.

Outputs (Tables/conn_margins/):
  linearity_did_resid_cba_test.csv            binstest result row
  linearity_did_resid_cba_numb_clauses.csv    (y_res, d_res) for the figure
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
log using "$logs/conn_margins/linearity_did_resid_cba_`d'_`t'.log", replace text

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

* ── Published DiD (target 0.0180) + lock the estimation sample ────────────────

local absorb_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period ib0.totalflows_pw_pre_07_114#i.cba_period"

di _newline "==== PUBLISHED DiD (6-level cba_period FE) ===="
reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
local b_panel  = _b[1.post_treat_cba#c.`conn']
local se_panel = _se[1.post_treat_cba#c.`conn']
di as result "PUBLISHED beta (target ~0.0180) = " %9.6f `b_panel'

cap drop did_sample
gen byte did_sample = e(sample)

* ── FWL residualization of Y and D on the full published FE set ───────────────
* Same absorb, same sample. conn main effect is absorbed by firm FE (time-
* invariant); post main effect by the #cba_period interactions. The only RHS the
* DiD leaves is conn_x_post_cba, so residual-Y on residual-D returns 0.0180.

cap drop y_res
cap drop d_res
reghdfe numb_clauses       if did_sample, absorb(`absorb_cba') residuals(y_res)
reghdfe conn_x_post_cba    if did_sample, absorb(`absorb_cba') residuals(d_res)

di _newline "==== FWL CHECK: OLS of y_res on d_res should equal published beta ===="
reg y_res d_res if did_sample, vce(cluster firm_num)
local b_fwl = _b[d_res]
di as result "published beta = " %9.6f `b_panel' "   FWL beta = " %9.6f `b_fwl' ///
	"   diff = " %9.2e (`b_panel'-`b_fwl')

* ── Cattaneo binstest on the residualized panel (cluster on firm) ─────────────

di _newline "==== binstest: residualized panel (numb_clauses, published spec) ===="
binstest y_res d_res if did_sample, ///
	testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
	nsims(2000) simsgrid(50) simsseed(12345) vce(cluster firm_num)
local stat  = e(stat_poly)
local pval  = e(pval_poly)
local nbins = e(nbins)
local n     = e(N)
di "  N=`n'  bins=`nbins'  sup-t=" %6.4f `stat' "  p=" %6.4f `pval'

* ── Export test row + residual cross-section for the figure ───────────────────

tempname fh
file open `fh' using "$tables/conn_margins/linearity_did_resid_cba_test.csv", write replace
file write `fh' "outcome,sample,n,nbins,stat_supt,pval,nsims,simsgrid,beta_published,beta_fwl" _n
file write `fh' `"numb_clauses,s_spill_panel,`n',`nbins',`stat',`pval',2000,50,`b_panel',`b_fwl'"' _n
file close `fh'

preserve
	keep if did_sample
	keep identificad firm_num year cba_period y_res d_res
	export delimited "$tables/conn_margins/linearity_did_resid_cba_numb_clauses.csv", replace
restore

di _newline "======================================================="
di "RESIDUALIZED PANEL BINSTEST (numb_clauses, published 6-level spec)"
type "$tables/conn_margins/linearity_did_resid_cba_test.csv"

capture log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "clause resid binstest done" "residualized 6-level panel binstest for numb_clauses complete"
