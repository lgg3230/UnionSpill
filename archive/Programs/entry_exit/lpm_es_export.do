********************************************************************************
* Program:    lpm_es_export.do
* Purpose:    Re-run LPM event-study regressions and export year-by-year
*             coefficients to CSV for Python plotting.
*             Full sample only (lagos_sample_unbal_avg, Panel C).
* Outputs:    Tables/entry_exit/lpm_es_direct_full.csv
*             Tables/entry_exit/lpm_es_spill_full.csv
********************************************************************************

version 17.0
set more off

use "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear

local conn     "totaltreat_pw_norm"
local base_fe  "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb   "`base_fe' ib0.l_firm_emp_pre4#i.year `extra_year'"

local s_direct "lagos_sample_unbal_avg==1"
local s_spill  "lagos_sample_unbal_avg==1 & treat_ultra==0"

* ── Direct effects event study ───────────────────────────────────────────────

reghdfe present_in_year i.treat_ultra##ib2011.year if `s_direct', ///
    absorb(`absorb') vce(cluster identificad) tolerance(1e-2)

tempname fh
file open `fh' using "$tables/lpm_es_direct_full.csv", write replace
file write `fh' "year,coef,se" _n
foreach y in 2009 2010 2011 2012 2013 2014 2015 2016 {
    if `y' == 2011 {
        file write `fh' "`y',0,0" _n
    }
    else {
        local b = _b[1.treat_ultra#`y'.year]
        local s = _se[1.treat_ultra#`y'.year]
        file write `fh' "`y'," %9.6f (`b') "," %9.6f (`s') _n
    }
}
file close `fh'

* ── Spillover event study (no extra_year to avoid collinearity) ──────────────

local absorb_spill "`base_fe' ib0.l_firm_emp_pre4#i.year"

reghdfe present_in_year c.`conn'##ib2011.year if `s_spill', ///
    absorb(`absorb_spill') vce(cluster identificad) tolerance(1e-2)

tempname fh
file open `fh' using "$tables/lpm_es_spill_full.csv", write replace
file write `fh' "year,coef,se" _n
foreach y in 2009 2010 2011 2012 2013 2014 2015 2016 {
    if `y' == 2011 {
        file write `fh' "`y',0,0" _n
    }
    else {
        local b = _b[`y'.year#c.`conn']
        local s = _se[`y'.year#c.`conn']
        file write `fh' "`y'," %9.6f (`b') "," %9.6f (`s') _n
    }
}
file close `fh'

di "=== lpm_es_export.do done ==="
