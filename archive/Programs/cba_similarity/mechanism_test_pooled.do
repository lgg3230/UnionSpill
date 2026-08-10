********************************************************************************
* mechanism_test_pooled.do
*
* Pooled (treated + untreated) version of the mechanism test. Tests directional
* convergence: does the gap-filling response differ between treated and
* untreated firms?
*
* Spec (alone, gap):
*   cl_count_{fct} = β0 (gap_fc × T_t) + β1 (gap_fc × T_t × Treated_f)
*                  + α_fc + α_t + ε_fct
*
*   β0           = untreated convergence rate (gap is to treated partners)
*   β0 + β1      = treated   convergence rate (gap is to untreated partners)
*   H0: β1 = 0   ↔ both sides close the gap at the same rate
*
* For each firm f:
*   - if Treated_f = 1: gap_fc, surplus_fc come from mechanism_gaps.dta
*     (focal=treated, partner=untreated)
*   - if Treated_f = 0: gap_fc, surplus_fc come from mechanism_gaps_untreated.dta
*     (focal=untreated, partner=treated)
*
* Sample restriction:
*   - Treated firms in the original mechanism panel:    2,648 (1,950 in regs)
*   - Untreated firms in the mirror mechanism panel:    1,721
*
* RHS specifications: 4 (gap_alone, surplus_alone, raw_alone, joint).
* FE structures: 3 (year, clause_x_year, modeunion_x_year).
* Samples: 2 (main, placebo). Cluster levels: 2 (estab, firm).
*
* Per (FE × cluster × sample): 3 alone × 2 rows + 1 joint × 4 rows = 10 rows.
* Total: 10 × 3 FE × 2 cluster × 2 sample = 120 rows.
*
* Output:
*   Tables/cba_similarity/mechanism_test_results_pooled_all.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/mechanism_test_pooled_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 0: APPEND TREATED + UNTREATED GAP FILES
********************************************************************************

use "$rais_firm/mechanism_gaps.dta", clear
qui count
di "Treated   gap rows: " r(N)
gen byte _src_treat = 1

append using "$rais_firm/mechanism_gaps_untreated.dta"
replace _src_treat = 0 if missing(_src_treat)
qui count if _src_treat == 0
di "Untreated gap rows: " r(N)

* identificad × clause_num should be unique post-append; sanity check.
isid identificad clause_num

drop _src_treat
tempfile pooled_gaps
save `pooled_gaps'

********************************************************************************
* SECTION 1: LOAD AND KEEP BOTH TREATED AND UNTREATED BALANCED-PANEL FIRMS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if in_balanced_panel == 1
keep if year              >= 2009
keep if !missing(cba_period)
keep if !missing(treat_ultra)

keep identificad year cba_period mode_union treat_ultra cl_*

qui count if missing(mode_union)
di "Obs with missing mode_union (will be dropped): " r(N)
keep if !missing(mode_union)

di "Pooled balanced-panel obs: " _N
tab treat_ultra

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
* SECTION 4: MERGE POOLED GAP DATA
********************************************************************************

merge m:1 identificad clause_num using `pooled_gaps', keep(match) nogen
di "After merge with pooled gap data: " _N

* Each firm should have a single treat_ultra status across all rows.
qui sum treat_ultra
di "treat_ultra in pooled regression sample: mean=" r(mean) ", min=" r(min) ", max=" r(max)

********************************************************************************
* SECTION 5: BUILD VARIABLES
********************************************************************************

gen post          = (cba_period >= 3)
gen pre_treat_cba = cond(cba_period < 2, 1, 0)

egen firm_clause_id = group(identificad clause_num)

gen str8 identificad8 = substr(identificad, 1, 8)

gen raw_gap = gap - surplus

* Two-way interactions (gap × T)
gen gap_post     = gap     * post
gen surplus_post = surplus * post
gen raw_gap_post = raw_gap * post

gen gap_placebo     = gap     * pre_treat_cba
gen surplus_placebo = surplus * pre_treat_cba
gen raw_gap_placebo = raw_gap * pre_treat_cba

* Three-way interactions (gap × T × Treated)
gen gap_post_xT     = gap_post     * treat_ultra
gen surplus_post_xT = surplus_post * treat_ultra
gen raw_gap_post_xT = raw_gap_post * treat_ultra

gen gap_placebo_xT     = gap_placebo     * treat_ultra
gen surplus_placebo_xT = surplus_placebo * treat_ultra
gen raw_gap_placebo_xT = raw_gap_placebo * treat_ultra

label var gap_post_xT     "gap × post × Treated"
label var surplus_post_xT "surplus × post × Treated"
label var raw_gap_post_xT "raw_gap × post × Treated"
label var gap_placebo_xT     "gap × placebo × Treated"
label var surplus_placebo_xT "surplus × placebo × Treated"
label var raw_gap_placebo_xT "raw_gap × placebo × Treated"

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

********************************************************************************
* SECTION 7: OPEN MASTER POSTFILE
********************************************************************************

tempname master
tempfile masterres
postfile `master' str25 var str10 spec str10 sample str20 fe str10 cluster ///
    double coef se ci_lower ci_upper double r2 N N_clust ///
    using `masterres'

********************************************************************************
* SECTION 8: MAIN SAMPLE — pooled regressions
********************************************************************************

di _newline(2) "=========================================================="
di              "POOLED MAIN SAMPLE (treated + untreated)"
di              "=========================================================="

foreach fe_struct in year clause_x_year modeunion_x_year {
    if "`fe_struct'" == "year"               local absorb "firm_clause_id year"
    if "`fe_struct'" == "clause_x_year"      local absorb "firm_clause_id i.clause_num#i.year"
    if "`fe_struct'" == "modeunion_x_year"   local absorb "firm_clause_id i.mode_union#i.year"

    foreach cluster_var in identificad identificad8 {
        local cluster_label = cond("`cluster_var'" == "identificad", "estab", "firm")
        di _newline(2) "--- POOLED FE=`fe_struct', cluster=`cluster_label' ---"

        * gap × post + gap × post × Treated  (alone)
        reghdfe cl_count gap_post gap_post_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_post     alone main `fe_struct' `cluster_label'
        _post_result `master' gap_post_xT  alone main `fe_struct' `cluster_label'

        * surplus × post + surplus × post × Treated  (alone)
        reghdfe cl_count surplus_post surplus_post_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_post     alone main `fe_struct' `cluster_label'
        _post_result `master' surplus_post_xT  alone main `fe_struct' `cluster_label'

        * raw_gap × post + raw_gap × post × Treated  (alone)
        reghdfe cl_count raw_gap_post raw_gap_post_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_post     alone main `fe_struct' `cluster_label'
        _post_result `master' raw_gap_post_xT  alone main `fe_struct' `cluster_label'

        * Joint: gap + gap×T + surplus + surplus×T
        reghdfe cl_count gap_post gap_post_xT surplus_post surplus_post_xT, ///
            absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_post         joint main `fe_struct' `cluster_label'
        _post_result `master' gap_post_xT      joint main `fe_struct' `cluster_label'
        _post_result `master' surplus_post     joint main `fe_struct' `cluster_label'
        _post_result `master' surplus_post_xT  joint main `fe_struct' `cluster_label'
    }
}

********************************************************************************
* SECTION 9: PLACEBO SAMPLE — pooled regressions
********************************************************************************

di _newline(2) "=========================================================="
di              "POOLED PLACEBO SAMPLE"
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
        di _newline(2) "--- POOLED PLACEBO FE=`fe_struct', cluster=`cluster_label' ---"

        reghdfe cl_count gap_placebo gap_placebo_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_placebo     alone placebo `fe_struct' `cluster_label'
        _post_result `master' gap_placebo_xT  alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count surplus_placebo surplus_placebo_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' surplus_placebo     alone placebo `fe_struct' `cluster_label'
        _post_result `master' surplus_placebo_xT  alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count raw_gap_placebo raw_gap_placebo_xT, absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' raw_gap_placebo     alone placebo `fe_struct' `cluster_label'
        _post_result `master' raw_gap_placebo_xT  alone placebo `fe_struct' `cluster_label'

        reghdfe cl_count gap_placebo gap_placebo_xT surplus_placebo surplus_placebo_xT, ///
            absorb(`absorb') vce(cluster `cluster_var')
        _post_result `master' gap_placebo         joint placebo `fe_struct' `cluster_label'
        _post_result `master' gap_placebo_xT      joint placebo `fe_struct' `cluster_label'
        _post_result `master' surplus_placebo     joint placebo `fe_struct' `cluster_label'
        _post_result `master' surplus_placebo_xT  joint placebo `fe_struct' `cluster_label'
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
    export delimited using "$tables/cba_similarity/mechanism_test_results_pooled_all.csv", replace
    di _newline "Pooled master CSV rows: " _N
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "mechanism_test_pooled.do finished"
