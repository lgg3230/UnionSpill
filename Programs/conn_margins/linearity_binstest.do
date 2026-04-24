/*
Stata replication of linearity_binstest.py
Formal linearity test: Cattaneo, Crump, Farrell, Feng (2024)

H0: E[raw_did | conn_firm, w] is linear in conn_firm.

Strategy: FWL residualization (required because binstest has no absorb()).
  Step 1: regress raw_did and conn_firm on the same control dummies.
  Step 2: run binstest on the residuals, no additional controls.

Note: pre-residualizing is valid here because binstest has no own covariate
adjustment. The Cattaneo et al. warning against pre-residualizing applies
when using binsreg for *plotting* (where bias enters the bin-mean estimate);
for binstest under H0 of linearity, FWL is algebraically exact.

Output: Tables/conn_margins/linearity_binstest_stata.csv
*/

version 17.0

* ── Paths ────────────────────────────────────────────────────────────────────

global main    "/kellogg/proj/lgg3230/UnionSpill"
global tables  "$main/Tables/conn_margins"
global logs    "$main/Logs/conn_margins"

* ── Install binsreg if needed ────────────────────────────────────────────────

cap which binstest
if _rc != 0 {
    di "Installing binsreg from SSC..."
    ssc install binsreg, replace
}

* ── Load data ─────────────────────────────────────────────────────────────────

import delimited "$tables/scatter_raw_controls.csv", clear varnames(1)

* Drop missing on key variables
drop if missing(conn_firm) | missing(raw_did)
di "Firms: `=_N'"

* ── FWL residualization ───────────────────────────────────────────────────────
* Controls: industry1 (229 cats), mode_base_month (12), microregion (336),
*           lr_remdezr_w_pre4 (4), l_firm_emp_pre4 (4), totalflows_pw_pre_07_114 (4)

reg raw_did  i.industry1 i.mode_base_month i.microregion ///
             i.lr_remdezr_w_pre4 i.l_firm_emp_pre4 i.totalflows_pw_pre_07_114
cap drop y_res
predict y_res, resid

reg conn_firm i.industry1 i.mode_base_month i.microregion ///
              i.lr_remdezr_w_pre4 i.l_firm_emp_pre4 i.totalflows_pw_pre_07_114
cap drop x_res
predict x_res, resid

* ── Linearity test ────────────────────────────────────────────────────────────

di _newline "Running binstest (testmodelpoly(1), nsims(2000), simsgrid(50))..."
di "This may take 1-3 minutes."

binstest y_res x_res, testmodelpoly(1) nsims(2000) simsgrid(50)

* ── Save results ──────────────────────────────────────────────────────────────

* Extract stored scalars
local stat  = e(stat_poly)
local pval  = e(pval_poly)
local nbins = e(nbins)
local n     = e(N)

di _newline "======================================================="
di "Linearity test (Cattaneo et al. 2024) — Stata replication"
di "H0: E[y|x,w] is linear in x"
di "-------------------------------------------------------"
di "  N (firms):              `n'"
di "  Bins (DPI):             `nbins'"
di "  Test statistic (sup-t): " %6.4f `stat'
di "  P-value (2000 sims):    " %6.4f `pval'
di "======================================================="

* Write CSV
tempname fh
file open `fh' using "$tables/linearity_binstest_stata.csv", write replace
file write `fh' "test,outcome,predictor,n,nbins,stat_supt,pval,nsims,simsgrid,lp" _n
file write `fh' `"linearity (testmodelpoly=1),y_res,x_res,`n',`nbins',`stat',`pval',2000,50,inf"' _n
file close `fh'

di "Saved: $tables/linearity_binstest_stata.csv"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata binstest done" ///
    "stat=`stat', p=`pval', bins=`nbins'"
