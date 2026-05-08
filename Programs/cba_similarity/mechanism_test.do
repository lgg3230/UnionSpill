********************************************************************************
* mechanism_test.do
*
* Tests the content-diffusion mechanism from the treated-firm side.
* Asks: do treated firms add clauses specifically in dimensions where their
* connected (untreated) partners had more pre-treatment?
*
* RHS specifications:
*   - gap_post       = max(0, partner_avg - own_pre) * post           [alone]
*   - surplus_post   = max(0, own_pre - partner_avg) * post           [alone]
*   - raw_gap_post   = (partner_avg - own_pre) * post = gap - surplus [alone]
*   - {gap_post, surplus_post}                                        [joint]
*
* FE structures (in addition to firm x clause-type FE):
*   - year                FE
*   - i.clause_num#i.year FE  (absorbs clause-specific secular trends)
*   - i.mode_union#i.year FE  (absorbs union-specific secular trends)
*
* Samples:
*   - main:    cba_period in {1..6}, post          = 1{cba_period >= 3}
*   - placebo: cba_period in {1, 2},  pre_treat_cba = 1{cba_period == 1}
*              (cba_period 2 = base; tests for differential pre-trends)
*
* Cluster levels:
*   - estab: vce(cluster identificad)   [14-digit establishment CNPJ]
*   - firm : vce(cluster identificad8)  [8-digit parent firm  / CNPJ root]
*
* Total regressions: 4 RHS x 3 FE x 2 samples x 2 clusters = 48
* Master CSV row count: 60 (joint posts 2 coefs + 1 sym-test row each)
*
* Outputs:
*   Tables/cba_similarity/mechanism_test_results_all.csv          (master)
*   Tables/cba_similarity/mechanism_test_gap.csv                  (legacy, estab cluster)
*   Tables/cba_similarity/mechanism_test_gap_clausexyear.csv      (legacy)
*   Tables/cba_similarity/mechanism_test_surplus.csv              (legacy)
*   Tables/cba_similarity/mechanism_test_surplus_clausexyear.csv  (legacy)
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/mechanism_test_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD AND RESTRICT TO TREATED BALANCED-PANEL FIRMS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if treat_ultra       == 1
keep if in_balanced_panel == 1
keep if year              >= 2009
keep if !missing(cba_period)

keep identificad year cba_period mode_union cl_*

qui count if missing(mode_union)
di "Obs with missing mode_union (will be dropped): " r(N)
keep if !missing(mode_union)

di "Treated balanced-panel obs: " _N

********************************************************************************
* SECTION 2: RENAME cl_* -> cl1-cl139 FOR RESHAPE
********************************************************************************

local i = 1
foreach v of varlist cl_* {
    rename `v' cl`i'
    local ++i
}
local ncl = `i' - 1
di "Clause types: `ncl'"

********************************************************************************
* SECTION 3: RESHAPE TO LONG (firm x year x clause_type)
********************************************************************************

reshape long cl, i(identificad year) j(clause_num)
rename cl cl_count

di "Long dataset obs: " _N

********************************************************************************
* SECTION 4: MERGE GAP DATA
********************************************************************************

merge m:1 identificad clause_num using "$rais_firm/mechanism_gaps.dta", ///
    keep(match) nogen

di "After merge with gap data: " _N

********************************************************************************
* SECTION 5: BUILD VARIABLES
********************************************************************************

* Sample / period indicators
gen post          = (cba_period >= 3)
gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var post          "Post-Sumula 277 (cba_period >= 3)"
label var pre_treat_cba "Pre-treatment CBA period indicator"

* Firm x clause-type id (FE)
egen firm_clause_id = group(identificad clause_num)

* Firm-level identifier (8-digit CNPJ root) for firm-level clustering.
* identificad is the 14-digit establishment CNPJ; the first 8 digits are the
* parent firm's CNPJ root.
gen str8 identificad8 = substr(identificad, 1, 8)
label var identificad8 "Firm ID (8-digit CNPJ root)"

* Raw signed gap: gap - surplus = partner_avg - own_pre
gen raw_gap = gap - surplus
label var raw_gap "Signed mismatch: partner_avg - own_pre"

* Main-sample interactions
gen gap_post     = gap     * post
gen surplus_post = surplus * post
gen raw_gap_post = raw_gap * post

* Placebo interactions (cba_period 1 vs. 2; cba_period 2 = base)
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
* SECTION 8: MAIN SAMPLE — loop over FE x cluster x RHS spec
********************************************************************************

di _newline(2) "=========================================================="
di              "MAIN SAMPLE"
di              "=========================================================="

foreach fe_struct in year clause_x_year modeunion_x_year {
    if "`fe_struct'" == "year"               local absorb "firm_clause_id year"
    if "`fe_struct'" == "clause_x_year"      local absorb "firm_clause_id i.clause_num#i.year"
    if "`fe_struct'" == "modeunion_x_year"   local absorb "firm_clause_id i.mode_union#i.year"

    foreach cluster_var in identificad identificad8 {
        local cluster_label = cond("`cluster_var'" == "identificad", "estab", "firm")
        di _newline(2) "--- FE=`fe_struct', cluster=`cluster_label' ---"

        * gap × post (alone)
        reghdfe cl_count gap_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_post alone main `fe_struct' `cluster_label'

        * surplus × post (alone)
        reghdfe cl_count surplus_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_post alone main `fe_struct' `cluster_label'

        * raw_gap × post (alone)
        reghdfe cl_count raw_gap_post, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_post alone main `fe_struct' `cluster_label'

        * joint (gap_post + surplus_post)
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
* SECTION 9: PLACEBO SAMPLE — same loop structure
********************************************************************************

di _newline(2) "=========================================================="
di              "PLACEBO SAMPLE (cba_period <= 2, placebo = 1{cba_period==2})"
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

        * gap × placebo (alone)
        reghdfe cl_count gap_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_placebo alone placebo `fe_struct' `cluster_label'

        * surplus × placebo (alone)
        reghdfe cl_count surplus_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_placebo alone placebo `fe_struct' `cluster_label'

        * raw_gap × placebo (alone)
        reghdfe cl_count raw_gap_placebo, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_placebo alone placebo `fe_struct' `cluster_label'

        * joint (gap_placebo + surplus_placebo)
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
    export delimited using "$tables/cba_similarity/mechanism_test_results_all.csv", replace
    di _newline "Master CSV rows: " _N
restore

********************************************************************************
* SECTION 11: BACKWARD-COMPATIBLE LEGACY EXPORTS (estab cluster only)
********************************************************************************

* mechanism_test_gap.csv  (gap_post, alone, main, year FE, estab cluster)
preserve
    use `masterres', clear
    keep if var == "gap_post" & spec == "alone" & sample == "main" ///
        & fe == "year" & cluster == "estab"
    drop spec sample fe cluster
    rename var var0
    gen str20 var = "gap_x_post"
    gen str20 spec = "main"
    keep var spec coef se ci_lower ci_upper r2 N
    order var spec coef se ci_lower ci_upper r2 N
    export delimited using "$tables/cba_similarity/mechanism_test_gap.csv", replace
restore

* mechanism_test_gap_clausexyear.csv  (estab cluster)
preserve
    use `masterres', clear
    keep if var == "gap_post" & spec == "alone" & sample == "main" ///
        & fe == "clause_x_year" & cluster == "estab"
    drop spec sample fe cluster
    rename var var0
    gen str20 var = "gap_x_post"
    gen str30 spec = "clause_x_year_FE"
    keep var spec coef se ci_lower ci_upper r2 N
    order var spec coef se ci_lower ci_upper r2 N
    export delimited using "$tables/cba_similarity/mechanism_test_gap_clausexyear.csv", replace
restore

* mechanism_test_surplus.csv  (estab cluster)
preserve
    use `masterres', clear
    keep if var == "surplus_post" & spec == "alone" & sample == "main" ///
        & fe == "year" & cluster == "estab"
    drop spec sample fe cluster
    rename var var0
    gen str20 var = "surplus_x_post"
    gen str20 spec = "falsification"
    keep var spec coef se ci_lower ci_upper r2 N
    order var spec coef se ci_lower ci_upper r2 N
    export delimited using "$tables/cba_similarity/mechanism_test_surplus.csv", replace
restore

* mechanism_test_surplus_clausexyear.csv  (estab cluster)
preserve
    use `masterres', clear
    keep if var == "surplus_post" & spec == "alone" & sample == "main" ///
        & fe == "clause_x_year" & cluster == "estab"
    drop spec sample fe cluster
    rename var var0
    gen str20 var = "surplus_x_post"
    gen str30 spec = "clause_x_year_FE"
    keep var spec coef se ci_lower ci_upper r2 N
    order var spec coef se ci_lower ci_upper r2 N
    export delimited using "$tables/cba_similarity/mechanism_test_surplus_clausexyear.csv", replace
restore

di _newline "Saved: master + 4 legacy CSVs"

********************************************************************************
* SECTION 12: AUTO-RUN PYTHON FOR LATEX TABLES
********************************************************************************

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_mechanism_test_latex.py"

********************************************************************************
* DONE
********************************************************************************

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "mechanism_test.do finished (48 regs, 2 cluster levels)"
