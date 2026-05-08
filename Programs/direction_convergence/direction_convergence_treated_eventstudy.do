********************************************************************************
* direction_convergence_treated_eventstudy.do
*
* Mirror event study: treated firms' similarity to fixed cba_period==2
* untreated benchmark, dynamic in cba_period × connectivity_untreat.
*
* Output:
*   Tables/direction_convergence/direction_convergence_treated_eventstudy_results.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/direction_convergence"
log using "$logs/direction_convergence/direction_convergence_treated_eventstudy_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/direction_convergence"

use "$dirconv_data/direction_convergence_treated.dta", clear
egen long firm_id = group(identificad)
isid firm_id cba_period

di _newline "Treated firm × cba_period panel: " _N

local outcomes "sim_cosine_shares sim_tv_shares sim_ruzicka_counts sim_bc_counts"
local fe       "firm_id cba_period i.mode_base_month#i.cba_period"
local cluster  firm_id

qui levelsof cba_period, local(periods)
di "cba_periods present: `periods'"

local es_terms ""
foreach p of local periods {
    local pi = `p'
    if `pi' != 2 {
        cap drop conn_p`pi'
        gen conn_p`pi' = (cba_period == `pi') * connectivity_untreat
        local es_terms `es_terms' conn_p`pi'
    }
}
di "Event-study regressors: `es_terms'"

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

postclose `res'

preserve
    use `resfile', clear
    sort outcome cba_period_val
    export delimited using "$tables/direction_convergence/direction_convergence_treated_eventstudy_results.csv", replace
    di _newline "Exported: " _N " rows"
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "direction_convergence_treated_eventstudy.do finished"
