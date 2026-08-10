********************************************************************************
* direction_convergence_eventstudy.do
*
* Dynamic version of the direction-of-convergence test:
*
*   sim_y_{it} = α_i + λ_t + Σ_τ β_τ (connectivity_treat_i × 1{cba_period_t = τ})
*              + δ (mode_base_month × cba_period FE) + ε_{it}
*
* cba_period == 2 is the omitted base period (last pre-Súmula CBA cycle).
*
* Outputs (one row per (outcome, cba_period) coefficient):
*   Tables/direction_convergence/direction_convergence_eventstudy_results.csv
*
* Cluster: identificad (14-digit, project's "firm" level).
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/direction_convergence"
log using "$logs/direction_convergence/direction_convergence_eventstudy_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/direction_convergence"

********************************************************************************
* SECTION 1: LOAD PANEL
********************************************************************************

use "$dirconv_data/direction_convergence_untreated.dta", clear
egen long firm_id = group(identificad)
isid firm_id cba_period

di _newline "Untreated firm × cba_period panel: " _N

local outcomes "sim_cosine_shares sim_tv_shares sim_ruzicka_counts sim_bc_counts"
local fe       "firm_id cba_period i.mode_base_month#i.cba_period"
local cluster  firm_id

* cba_periods present:
qui levelsof cba_period, local(periods)
di "cba_periods present: `periods'"

* Pre-create scalar period × connectivity interactions (skip period 2 = base).
local es_terms ""
foreach p of local periods {
    local pi = `p'
    if `pi' != 2 {
        cap drop conn_p`pi'
        gen conn_p`pi' = (cba_period == `pi') * connectivity_treat
        local es_terms `es_terms' conn_p`pi'
    }
}
di "Event-study regressors: `es_terms'"

********************************************************************************
* SECTION 2: HELPER POSTFILE
********************************************************************************

cap program drop _post_es
program define _post_es
    args handle outcome period coef se
    local ci_low  = `coef' - 1.96 * `se'
    local ci_high = `coef' + 1.96 * `se'
    post `handle' ("`outcome'") (`period') (`coef') (`se') (`ci_low') (`ci_high')
end

tempname res
tempfile resfile
postfile `res' str25 outcome int cba_period_val ///
    double coef se ci_lower ci_upper using `resfile'

********************************************************************************
* SECTION 3: EVENT STUDY — one regression per outcome
********************************************************************************

di _newline(2) "=========================================================="
di              "EVENT STUDY: ib2.cba_period#c.connectivity_treat"
di              "=========================================================="

foreach y of local outcomes {
    di _newline(2) "--- `y' ---"
    reghdfe `y' `es_terms', ///
        absorb(`fe') vce(cluster `cluster') tolerance(1e-2)

    foreach p of local periods {
        local pi = `p'
        if `pi' == 2 {
            _post_es `res' `y' `pi' 0 0
        }
        else {
            local coef = _b[conn_p`pi']
            local se   = _se[conn_p`pi']
            _post_es `res' `y' `pi' `coef' `se'
        }
    }
}

********************************************************************************
* SECTION 4: CLOSE AND EXPORT
********************************************************************************

postclose `res'

preserve
    use `resfile', clear
    sort outcome cba_period_val
    export delimited using "$tables/direction_convergence/direction_convergence_eventstudy_results.csv", replace
    di _newline "Exported: " _N " rows"
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "direction_convergence_eventstudy.do finished"
