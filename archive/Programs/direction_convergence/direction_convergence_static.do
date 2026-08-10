********************************************************************************
* direction_convergence_static.do
*
* Static spec: do connected untreated firms become more similar to their
* fixed cba_period==2 treated benchmark after Súmula 277?
*
*   sim_y_{it} = α_i + λ_t + β (connectivity_treat_i × post_t)
*              + δ (mode_base_month × cba_period FE) + ε_{it}
*
* connectivity_treat_i = Σ_j w_{ij,pre} (sum of bilateral_conn_pw weights to
*   treated partners; same weight construction as cba_similarity_prep.py).
*
* Outcomes:
*   sim_cosine_shares    composition (cosine on shares)
*   sim_tv_shares        composition (TV similarity on shares)
*   sim_ruzicka_counts   counts (Ruzicka)
*   sim_bc_counts        counts (Bray-Curtis)
*
* Samples:
*   main:    cba_period 1..6, post = 1{cba_period >= 3}
*   placebo: cba_period in {1,2}, placebo = 1{cba_period == 1}
*            (cba_period 2 = base period; tests for differential pre-trends)
*
* Cluster: identificad (14-digit, project's "firm" level).
*
* Output:
*   Tables/direction_convergence/direction_convergence_static_results.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/direction_convergence"
log using "$logs/direction_convergence/direction_convergence_static_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/direction_convergence"

********************************************************************************
* SECTION 1: LOAD UNTREATED FIRM × CBA_PERIOD PANEL
********************************************************************************

use "$dirconv_data/direction_convergence_untreated.dta", clear
di _newline "Untreated firm × cba_period panel: " _N

* Numeric firm id (string identificad → numeric for FE absorption).
egen long firm_id = group(identificad)
label var firm_id "Numeric firm id (= group identificad)"

* Sanity check: each firm × cba_period unique.
isid firm_id cba_period

* Pre-create scalar interactions (avoid factor-variable omitted-base ambiguity
* under FE absorption).
gen connect_x_post    = connectivity_treat * post
gen connect_x_placebo = connectivity_treat * pre_treat_cba

local outcomes "sim_cosine_shares sim_tv_shares sim_ruzicka_counts sim_bc_counts"
local fe       "firm_id cba_period i.mode_base_month#i.cba_period"
local cluster  firm_id

********************************************************************************
* SECTION 2: HELPER POSTFILE
********************************************************************************

cap program drop _post_result
program define _post_result
    args handle outcome sample coefname
    local coef    = _b[`coefname']
    local se      = _se[`coefname']
    local ci_low  = `coef' - 1.96 * `se'
    local ci_high = `coef' + 1.96 * `se'
    local r2      = e(r2)
    local N       = e(N)
    local N_clust = e(N_clust)
    qui sum `outcome' if e(sample)
    local ymean   = r(mean)
    post `handle' ("`outcome'") ("`sample'") (`coef') (`se') ///
        (`ci_low') (`ci_high') (`r2') (`N') (`N_clust') (`ymean')
end

tempname res
tempfile resfile
postfile `res' str25 outcome str10 sample double coef se ci_lower ci_upper ///
    double r2 N N_clust ymean using `resfile'

********************************************************************************
* SECTION 3: MAIN SAMPLE — connectivity_treat × post
********************************************************************************

di _newline(2) "=========================================================="
di              "MAIN SAMPLE: c.connectivity_treat#i.post"
di              "=========================================================="

foreach y of local outcomes {
    di _newline(2) "--- `y' (main) ---"
    reghdfe `y' connect_x_post, ///
        absorb(`fe') vce(cluster `cluster') tolerance(1e-2)
    _post_result `res' `y' main connect_x_post
}

********************************************************************************
* SECTION 4: PLACEBO SAMPLE — connectivity_treat × pre_treat_cba (cba_period 1 vs 2)
********************************************************************************

di _newline(2) "=========================================================="
di              "PLACEBO SAMPLE (cba_period <= 2): c.connectivity_treat#i.pre_treat_cba"
di              "=========================================================="

preserve
keep if cba_period <= 2
di _newline "Placebo subset rows: " _N

foreach y of local outcomes {
    di _newline(2) "--- `y' (placebo) ---"
    reghdfe `y' connect_x_placebo, ///
        absorb(`fe') vce(cluster `cluster') tolerance(1e-2)
    _post_result `res' `y' placebo connect_x_placebo
}

restore

********************************************************************************
* SECTION 5: CLOSE AND EXPORT
********************************************************************************

postclose `res'

preserve
    use `resfile', clear
    sort sample outcome
    export delimited using "$tables/direction_convergence/direction_convergence_static_results.csv", replace
    di _newline "Exported: " _N " rows"
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "direction_convergence_static.do finished"
