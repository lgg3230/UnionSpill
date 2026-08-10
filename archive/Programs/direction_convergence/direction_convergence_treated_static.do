********************************************************************************
* direction_convergence_treated_static.do
*
* Mirror of direction_convergence_static.do — treated firms moving toward
* their fixed cba_period==2 untreated benchmark.
*
*   sim_y_{jt} = α_j + λ_t + β (connectivity_untreat_j × post_t)
*              + δ (mode_base_month × cba_period FE) + ε_{jt}
*
* Output:
*   Tables/direction_convergence/direction_convergence_treated_static_results.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/direction_convergence"
log using "$logs/direction_convergence/direction_convergence_treated_static_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/direction_convergence"

use "$dirconv_data/direction_convergence_treated.dta", clear
di _newline "Treated firm × cba_period panel: " _N

egen long firm_id = group(identificad)
isid firm_id cba_period

gen connect_x_post    = connectivity_untreat * post
gen connect_x_placebo = connectivity_untreat * pre_treat_cba

local outcomes "sim_cosine_shares sim_tv_shares sim_ruzicka_counts sim_bc_counts"
local fe       "firm_id cba_period i.mode_base_month#i.cba_period"
local cluster  firm_id

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

di _newline(2) "MAIN: connectivity_untreat × post"
foreach y of local outcomes {
    di _newline(2) "--- `y' (main) ---"
    reghdfe `y' connect_x_post, ///
        absorb(`fe') vce(cluster `cluster') tolerance(1e-2)
    _post_result `res' `y' main connect_x_post
}

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

postclose `res'

preserve
    use `resfile', clear
    sort sample outcome
    export delimited using "$tables/direction_convergence/direction_convergence_treated_static_results.csv", replace
    di _newline "Exported: " _N " rows"
restore

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Stata done" "direction_convergence_treated_static.do finished"
