********************************************************************************
* mechanism_test_untreated.do
*
* MIRROR of mechanism_test.do — runs the same regression on UNTREATED balanced-
* panel firms, with their pool of "connected counterparts" being the treated
* firms they are tied to via worker flows.
*
* RHS specifications: same 4 (gap_post, surplus_post, raw_gap_post, joint).
* FE structures: same 3 (year, clause_x_year, modeunion_x_year).
* Samples: same 2 (main, placebo). Cluster levels: same 2 (estab, firm).
*
* Total regressions: 48. Master CSV row count: 60.
*
* Output:
*   Tables/cba_similarity/mechanism_test_results_untreated_all.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/mechanism_test_untreated_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD AND RESTRICT TO UNTREATED BALANCED-PANEL FIRMS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if treat_ultra       == 0
keep if in_balanced_panel == 1
keep if year              >= 2009
keep if !missing(cba_period)

keep identificad year cba_period mode_union cl_*

qui count if missing(mode_union)
di "Obs with missing mode_union (will be dropped): " r(N)
keep if !missing(mode_union)

di "Untreated balanced-panel obs: " _N

********************************************************************************
* SECTION 2: RENAME cl_* -> cl1-cl139
********************************************************************************

local i = 1
foreach v of varlist cl_* {
    rename `v' cl`i'
    local ++i
}
local ncl = `i' - 1
di "Clause types: `ncl'"

********************************************************************************
* SECTION 3: RESHAPE LONG
********************************************************************************

reshape long cl, i(identificad year) j(clause_num)
rename cl cl_count
di "Long dataset obs: " _N

********************************************************************************
* SECTION 4: MERGE GAP DATA
********************************************************************************

merge m:1 identificad clause_num using "$rais_firm/mechanism_gaps_untreated.dta", ///
    keep(match) nogen

di "After merge with untreated gap data: " _N

********************************************************************************
* SECTION 5: BUILD VARIABLES
********************************************************************************

gen post          = (cba_period >= 3)
gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var post          "Post-Sumula 277 (cba_period >= 3)"
label var pre_treat_cba "Pre-treatment CBA period indicator"

egen firm_clause_id = group(identificad clause_num)

gen str8 identificad8 = substr(identificad, 1, 8)
label var identificad8 "Firm ID (8-digit CNPJ root)"

gen raw_gap = gap - surplus
label var raw_gap "Signed mismatch: partner_avg - own_pre"

gen gap_post     = gap     * post
gen surplus_post = surplus * post
gen raw_gap_post = raw_gap * post

gen gap_placebo     = gap     * pre_treat_cba
gen surplus_placebo = surplus * pre_treat_cba
gen raw_gap_placebo = raw_gap * pre_treat_cba

compress

********************************************************************************
* SECTION 6: HELPER PROGRAMS
********************************************************************************

cap program drop _post_result
program define _post_result
    args handle var spec sample fe cluster
    local coef    = _b[`var']
    local se      = _se[`var']
    local ci_low  = `coef' - 1.96 * `se'
    local ci_high = `coef' + 1.96 * `se'
    local r2      = e(r2)
    local N       = e(N)
    local N_clust = e(N_clust)
    post `handle' ("`var'") ("`spec'") ("`sample'") ("`fe'") ("`cluster'") ///
        (`coef') (`se') (`ci_low') (`ci_high') (`r2') (`N') (`N_clust')
end

cap program drop _post_sym
program define _post_sym
    args handle spec sample fe cluster pval N N_clust
    post `handle' ("sym_test") ("`spec'") ("`sample'") ("`fe'") ("`cluster'") ///
        (`pval') (.) (.) (.) (.) (`N') (`N_clust')
end

********************************************************************************
* SECTION 7: OPEN MASTER POSTFILE
********************************************************************************

tempname master
tempfile masterres
postfile `master' str20 var str10 spec str10 sample str20 fe str10 cluster ///
    double coef se ci_lower ci_upper double r2 N N_clust ///
    using `masterres'

********************************************************************************
* SECTION 8: MAIN SAMPLE
********************************************************************************

di _newline(2) "=========================================================="
di              "MAIN SAMPLE (untreated firms)"
di              "=========================================================="

foreach fe_struct in year clause_x_year modeunion_x_year {
    if "`fe_struct'" == "year"               local absorb "firm_clause_id year"
    if "`fe_struct'" == "clause_x_year"      local absorb "firm_clause_id i.clause_num#i.year"
    if "`fe_struct'" == "modeunion_x_year"   local absorb "firm_clause_id i.mode_union#i.year"

    foreach cluster_var in identificad identificad8 {
        local cluster_label = cond("`cluster_var'" == "identificad", "estab", "firm")
        di _newline(2) "--- FE=`fe_struct', cluster=`cluster_label' ---"

        reghdfe cl_count gap_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_post alone main `fe_struct' `cluster_label'

        reghdfe cl_count surplus_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_post alone main `fe_struct' `cluster_label'

        reghdfe cl_count raw_gap_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_post alone main `fe_struct' `cluster_label'

        reghdfe cl_count gap_post surplus_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_post     joint main `fe_struct' `cluster_label'
        _post_result `master' surplus_post joint main `fe_struct' `cluster_label'
        local _N = e(N)
        local _Nc = e(N_clust)
        test gap_post = -surplus_post
        _post_sym `master' joint main `fe_struct' `cluster_label' `r(p)' `_N' `_Nc'
    }
}

********************************************************************************
* SECTION 9: PLACEBO SAMPLE
********************************************************************************

di _newline(2) "=========================================================="
di              "PLACEBO SAMPLE (untreated firms)"
di              "=========================================================="

preserve
keep if cba_period <= 2
di _newline "Placebo subset obs: " _N

foreach fe_struct in year clause_x_year modeunion_x_year {
    if "`fe_struct'" == "year"               local absorb "firm_clause_id year"
    if "`fe_struct'" == "clause_x_year"      local absorb "firm_clause_id i.clause_num#i.year"
    if "`fe_struct'" == "modeunion_x_year"   local absorb "firm_clause_id i.mode_union#i.year"

    foreach cluster_var in identificad identificad8 {
        local cluster_label = cond("`cluster_var'" == "identificad", "estab", "firm")
        di _newline(2) "--- PLACEBO: FE=`fe_struct', cluster=`cluster_label' ---"

        reghdfe cl_count gap_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_placebo alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count surplus_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_placebo alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count raw_gap_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_placebo alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count gap_placebo surplus_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_placebo     joint placebo `fe_struct' `cluster_label'
        _post_result `master' surplus_placebo joint placebo `fe_struct' `cluster_label'
        local _N = e(N)
        local _Nc = e(N_clust)
        test gap_placebo = -surplus_placebo
        _post_sym `master' joint placebo `fe_struct' `cluster_label' `r(p)' `_N' `_Nc'
    }
}

restore

********************************************************************************
* SECTION 10: CLOSE POSTFILE AND EXPORT MASTER
********************************************************************************

postclose `master'

preserve
    use `masterres', clear
    sort sample spec fe cluster var
    export delimited using "$tables/cba_similarity/mechanism_test_results_untreated_all.csv", replace
    di _newline "Master CSV rows: " _N
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "mechanism_test_untreated.do finished"
