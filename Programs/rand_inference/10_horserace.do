********************************************************************************
* 10_horserace.do  — recentered horse-race (spillover)
* For each outcome, the pooled spillover regression with the connectivity x Post
* and connectivity x Pre (placebo) interactions, first on its own ("real
* assignment") and then adding the expected connectivity mu x Post / mu x Pre
* ("recentered"), for each of four stratification schemes.
* numb_clauses uses the CBA-period structure (post/pre_treat_cba).
* Output: Tables/rand_inference/horserace_recentered.csv
*   outcome, scheme, coef in {conn_post,conn_pre,mu_post,mu_pre}, b, se, n
********************************************************************************
version 17.0
set more off
global randdir "/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference"
global tables  "/kellogg/proj/lgg3230/UnionSpill/Tables/rand_inference"
global programs "/kellogg/proj/lgg3230/UnionSpill/Programs/rand_inference"

use "$randdir/spill_frame.dta", clear
merge m:1 identificad using "$randdir/expected_exposure.dta", keep(master match) nogen
keep if treat_ultra == 0

cap drop placebo_year
gen byte placebo_year = (year < 2011)
cap drop pre_treat_cba
gen byte pre_treat_cba = cond(cba_period < 2, 1, 0) if !missing(cba_period)

local conn "totaltreat_pw_norm"
local schemes "unstrat ind_month ind_month_region ind_month_micro"
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"

capture erase "$tables/horserace_recentered.csv"
tempname fh
file open `fh' using "$tables/horserace_recentered.csv", write replace
file write `fh' "outcome,scheme,coef,b,se,n" _n

program define _post                  // grab b/se of a coefficient into a CSV row
    args fh outcome scheme coef term
    capture local b = _b[`term']
    if _rc {
        file write `fh' "`outcome',`scheme',`coef',.,.,." _n
        exit
    }
    local se = _se[`term']
    local n  = e(N)
    file write `fh' "`outcome',`scheme',`coef',`b',`se',`n'" _n
end

* ── year-based outcomes ──────────────────────────────────────────────────────
foreach out in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
    local ab "`base_fe' ib0.`out'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year"

    * real assignment (baseline): post then pre
    reghdfe `out' c.`conn'##i.treat_year, absorb(`ab') vce(cluster identificad)
    _post `fh' `out' baseline conn_post "1.treat_year#c.`conn'"
    reghdfe `out' c.`conn'##i.placebo_year if year <= 2011, absorb(`ab') vce(cluster identificad)
    _post `fh' `out' baseline conn_pre "1.placebo_year#c.`conn'"

    foreach s of local schemes {
        reghdfe `out' c.`conn'##i.treat_year c.mu_C_`s'##i.treat_year, absorb(`ab') vce(cluster identificad)
        _post `fh' `out' `s' conn_post "1.treat_year#c.`conn'"
        _post `fh' `out' `s' mu_post   "1.treat_year#c.mu_C_`s'"
        reghdfe `out' c.`conn'##i.placebo_year c.mu_C_`s'##i.placebo_year if year <= 2011, absorb(`ab') vce(cluster identificad)
        _post `fh' `out' `s' conn_pre "1.placebo_year#c.`conn'"
        _post `fh' `out' `s' mu_pre   "1.placebo_year#c.mu_C_`s'"
    }
}

* ── numb_clauses (CBA-period structure) ──────────────────────────────────────
local abc "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period ib0.totalflows_pw_pre_07_114#i.cba_period"
reghdfe numb_clauses c.`conn'##post_treat_cba if !missing(cba_period), absorb(`abc') vce(cluster identificad)
_post `fh' numb_clauses baseline conn_post "1.post_treat_cba#c.`conn'"
reghdfe numb_clauses c.`conn'##pre_treat_cba if cba_period <= 2, absorb(`abc') vce(cluster identificad)
_post `fh' numb_clauses baseline conn_pre "1.pre_treat_cba#c.`conn'"
foreach s of local schemes {
    reghdfe numb_clauses c.`conn'##post_treat_cba c.mu_C_`s'##post_treat_cba if !missing(cba_period), absorb(`abc') vce(cluster identificad)
    _post `fh' numb_clauses `s' conn_post "1.post_treat_cba#c.`conn'"
    _post `fh' numb_clauses `s' mu_post   "1.post_treat_cba#c.mu_C_`s'"
    reghdfe numb_clauses c.`conn'##pre_treat_cba c.mu_C_`s'##pre_treat_cba if cba_period <= 2, absorb(`abc') vce(cluster identificad)
    _post `fh' numb_clauses `s' conn_pre "1.pre_treat_cba#c.`conn'"
    _post `fh' numb_clauses `s' mu_pre   "1.pre_treat_cba#c.mu_C_`s'"
}

file close `fh'
di as result "=== horserace_recentered.csv written ==="
