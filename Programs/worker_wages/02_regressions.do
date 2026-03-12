********************************************************************************
* UNION SPILLOVERS — WORKER-LEVEL WAGE REGRESSIONS (worker_wages spec)
* Purpose: Estimate spillover effects on worker-level wages using a 2×2 matrix
*          of specifications: (firm FE vs firm×year FE) × (unweighted vs
*          inverse-firm-size weighted).
* Output:  4 CSV files per spec + event study PDFs
* Specs:   firmFE_unwt, firmFE_wt, fxyrFE_unwt, fxyrFE_wt
********************************************************************************

set more off
set varabbrev off

global main     "/kellogg/proj/lgg3230"
global data_in  "$main/UnionSpill/Data/worker_wages"
global tables   "$main/UnionSpill/Tables/worker_wages"
global graphs   "$main/UnionSpill/Graphs/worker_wages"
global logs     "$main/UnionSpill/Logs/worker_wages"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/worker_wages_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: LOAD DATA
********************************************************************************

use "$data_in/worker_wages_panel.dta", clear

* Destring string identifier and industry if needed
capture confirm string variable identificad
if _rc == 0 {
    * already string — keep as-is for reghdfe
}
capture destring industry1, replace force

di as result "Observations loaded: " _N
tab year

********************************************************************************
* SECTION 2: MACROS
********************************************************************************

* ── Sample ───────────────────────────────────────────────────────────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── Outcomes ─────────────────────────────────────────────────────────────────
* lr_remdezr_h   = firm-level log average hourly December wage
* lr_remdezr_h_w = individual worker log hourly December wage
global outcomes "lr_remdezr_h lr_remdezr_h_w"

* ── Spec 1 & 2: Firm FE ──────────────────────────────────────────────────────
local conn_std   "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_std  "ib0.totalflows_pw_pre_07_114#i.year"

* ── Spec 3 & 4: Firm×Year FE ─────────────────────────────────────────────────
* Uses pre-treatment proportion (avg_ftreat_pf_n normalized) as connectivity
* because totaltreat_pw_norm is time-invariant and absorbed by firm×year FE.
local conn_fxyr  "totaltreat_pw_norm"
local fe_fxyr    "identificad#year"
local extra_fxyr "ib0.totalflows_pw_pre_07_114#i.year"

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV FILES
********************************************************************************

foreach spec in firmFE_unwt firmFE_wt fxyrFE_unwt fxyrFE_wt {
    capture erase "$tables/results_spill_worker_wages_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/results_spill_worker_wages_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
}

********************************************************************************
* SECTION 4: ESTIMATION — 2×2 SPECS
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION"
di as result "======================================================================="

foreach spec in firmFE_unwt firmFE_wt fxyrFE_unwt fxyrFE_wt {

    di _newline(1)
    di as result "--- Spec: `spec' ---"

    * ── Set spec-specific locals ─────────────────────────────────────────────
    if inlist("`spec'", "firmFE_unwt", "firmFE_wt") {
        local conn        "`conn_std'"
        local absorb_base "`base_fe'"
        local extra       "`extra_std'"
    }
    else {
        local conn        "`conn_fxyr'"
        local absorb_base "`fe_fxyr'"
        local extra       "`extra_fxyr'"
    }

    local wgt ""
    if inlist("`spec'", "firmFE_wt", "fxyrFE_wt") local wgt "[aweight=inv_firm_emp]"

    local csv_out "$tables/results_spill_worker_wages_`spec'.csv"

    foreach outcome in $outcomes {

        di as text "  Estimating: `outcome' (spec = `spec')"

        * Per-outcome absorb: include pre4 bins for both firm FE and firm×year FE.
        * reghdfe automatically handles any collinearity with a note.
        local absorb "`absorb_base' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra'"

        * ── Post-treatment coefficient ───────────────────────────────────────
        reghdfe `outcome' c.`conn'##i.treat_year `wgt' ///
            if `s_spill' & year >= 2009, ///
            absorb(`absorb') vce(cluster identificad)

        local b_post  = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        local stars_post ""
        if `p_post' < 0.01                           local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        * ── Pre-treatment placebo ────────────────────────────────────────────
        reghdfe `outcome' c.`conn'##i.placebo_year `wgt' ///
            if `s_spill' & inrange(year, 2009, 2011), ///
            absorb(`absorb') vce(cluster identificad)

        local b_pre  = _b[1.placebo_year#c.`conn']
        local se_pre = _se[1.placebo_year#c.`conn']
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        local stars_pre ""
        if `p_pre' < 0.01                           local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

        * ── Event study (for F-test + graph) ────────────────────────────────
        reghdfe `outcome' c.`conn'##ib2011.year `wgt' ///
            if `s_spill' & year >= 2009, ///
            absorb(`absorb') vce(cluster identificad)

        testparm c.`conn'#i(2009 2010).year
        local pre_ftest_pval = r(p)

        * ── Write CSV ────────────────────────────────────────────────────────
        tempname fh
        file open `fh' using "`csv_out'", write append
        file write `fh' `""`spec'";"spill";"`outcome'";"main";"'     %9.4f (`b_post')  `"`stars_post'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"'  %9.4f (`se_post') `"""'            _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre";"'      %9.4f (`b_pre')   `"`stars_pre'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"'   %9.4f (`se_pre')  `"""'            _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"'    %12.0fc (`n_obs')  `"""'           _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"'  %12.0fc (`n_estab') `"""'          _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'     _n
        file close `fh'

        * ── Event study graph ────────────────────────────────────────────────
        estimates store _es_tmp
        local post_s = string(`b_post', "%9.4f")
        local se_s   = string(`se_post', "%9.4f")
        local pre_p  = string(`p_pre', "%9.3f")

        coefplot _es_tmp, ///
            keep(*#*c.`conn') ///
            msymbol(diamond) ///
            coeflabels( ///
                2009.year#c.`conn' = "2009" ///
                2010.year#c.`conn' = "2010" ///
                2011.year#c.`conn' = "2011" ///
                2012.year#c.`conn' = "2012" ///
                2013.year#c.`conn' = "2013" ///
                2014.year#c.`conn' = "2014" ///
                2015.year#c.`conn' = "2015" ///
                2016.year#c.`conn' = "2016") ///
            vert omitted baselevels ///
            yline(0) xline(3.75, lpattern(dash)) ///
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("Placebo pre-trend p-value = `pre_p'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.015 5 "`post_s' (`se_s')", color(blue) size(small))

        graph export "$graphs/es_`outcome'_`spec'_`d'.pdf", as(pdf) replace
        estimates drop _es_tmp

        di as result "    Done: `outcome' | spec = `spec'"
    }

    di as result "--- Spec `spec' complete ---"
}

********************************************************************************
* SECTION 5: COMPLETION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "ALL SPECS COMPLETE"
di as result "Finished: `c(current_date)' `c(current_time)'"
di as result "======================================================================="

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && \
    notify "worker_wages done" "02_regressions.do complete — all 4 specs"
