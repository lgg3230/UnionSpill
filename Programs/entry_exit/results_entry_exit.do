********************************************************************************
* Program:    results_entry_exit.do
* Purpose:    Direct and spillover effects for the entry/exit exercise.
*             Uses unbalanced panel so exiting firms contribute to pre-treatment
*             estimates. Reports results for two samples:
*               (1) Full unbalanced panel (all firms in lagos_sample_unbal_avg)
*               (2) Firms present in all pre-treatment years (present_all_pretreat)
*             Outcomes: l_firm_emp, lr_remdezr_w, numb_clauses
*             Spec: firm + industry×year + microregion×year + base_month×year FE
* Input:      Data/entry_exit/entry_exit_panel.dta
* Outputs:    Tables/entry_exit/results_direct_panelA_entry_exit.csv
*             Tables/entry_exit/results_direct_panelB_entry_exit.csv
*             Tables/entry_exit/results_direct_panelC_entry_exit.csv
*             Tables/entry_exit/results_spill_entry_exit.csv
*             Graphs/entry_exit/es_*.pdf
* Called by:  _run_entry_exit.do (stage 5)
********************************************************************************

version 17.0
set more off

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/results_entry_exit_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD PREPPED DATA
********************************************************************************

use "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear

* Only real observations for all regressions
keep if present_in_year == 1

di "Total real obs: " _N

********************************************************************************
* SECTION 2: SPEC AND SAMPLE MACROS
********************************************************************************

local spec      "entry_exit"
local conn      "totaltreat_pw_norm"

* Fixed effects: firm + industry×year + microregion×year + base_month×year
* mode_base_month is always included. Event-study regressions use tolerance(1e-2)
* to keep MWFE convergence fast under the expanded FE set.
local base_fe      "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year"
local base_fe_cba  "identificad i.industry1#i.cba_period i.microregion#i.cba_period i.mode_base_month#i.cba_period"
local extra_year   "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba    "ib0.totalflows_pw_pre_07_114#i.cba_period"

* Direct effect samples (A = zero connectivity controls, B = ≤1%, C = all untreated)
* Repeated for each of the two panel samples

* ── FULL UNBALANCED PANEL ────────────────────────────────────────────────────
local s_full_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_spill "lagos_sample_unbal_avg==1 & treat_ultra==0"

* ── FIRMS PRESENT IN ALL PRETREATMENT YEARS ──────────────────────────────────
local s_pre_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_spill "lagos_sample_unbal_avg==1 & treat_ultra==0 & present_all_pretreat==1"

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV FILES
********************************************************************************

foreach panel in A B C {
    foreach samp in full pre {
        capture erase "$tables/results_direct_panel`panel'_`samp'_`spec'.csv"
        tempname fh
        file open `fh' using "$tables/results_direct_panel`panel'_`samp'_`spec'.csv", write replace
        file write `fh' "spec,section,outcome,row_type,value" _n
        file close `fh'
    }
}

foreach samp in full pre {
    capture erase "$tables/results_spill_`samp'_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/results_spill_`samp'_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
}

********************************************************************************
* SECTION 4: DIRECT EFFECTS — PANELS A, B, C
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "DIRECT EFFECTS — PANELS A, B, C"
di as result "======================================================================="

foreach samp in full pre {

    if "`samp'" == "full" {
        local s_A "`s_full_A'"
        local s_B "`s_full_B'"
        local s_C "`s_full_C'"
        local samp_label "Full unbalanced panel"
    }
    else {
        local s_A "`s_pre_A'"
        local s_B "`s_pre_B'"
        local s_C "`s_pre_C'"
        local samp_label "Firms present all pretreatment years"
    }

    foreach panel in A B C {

        if "`panel'" == "A" {
            local s_use "`s_A'"
            local section "direct_A_`samp'"
        }
        if "`panel'" == "B" {
            local s_use "`s_B'"
            local section "direct_B_`samp'"
        }
        if "`panel'" == "C" {
            local s_use "`s_C'"
            local section "direct_C_`samp'"
        }

        local csv_out "$tables/results_direct_panel`panel'_`samp'_`spec'.csv"

        di _newline(1)
        di as result "--- Panel `panel' | `samp_label' ---"

        * ── YEAR-BASED OUTCOMES: l_firm_emp, lr_remdezr_w, lr_remdezr_h_w ──────

        foreach outcome in l_firm_emp lr_remdezr_w lr_remdezr_h_w {

            di as text "  Estimating: `outcome' (Panel `panel', `samp')"

            local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

            * Post-treatment DiD
            reghdfe `outcome' treat_ultra##i.treat_year if `s_use', ///
                absorb(`absorb') vce(cluster identificad)

            local b_post  = _b[1.treat_ultra#1.treat_year]
            local se_post = _se[1.treat_ultra#1.treat_year]
            local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs   = e(N)
            local n_estab = e(N_clust)

            * Pre-treatment placebo (years ≤ 2011 only)
            reghdfe `outcome' treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
                absorb(`absorb') vce(cluster identificad)

            local b_pre  = _b[1.treat_ultra#1.placebo_year]
            local se_pre = _se[1.treat_ultra#1.placebo_year]
            local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

            * Stars
            local stars_post ""
            if `p_post' < 0.01                           local stars_post "***"
            else if `p_post' < 0.05 & `p_post' >= 0.01  local stars_post "**"
            else if `p_post' < 0.10 & `p_post' >= 0.05  local stars_post "*"

            local stars_pre ""
            if `p_pre' < 0.01                            local stars_pre "***"
            else if `p_pre' < 0.05 & `p_pre' >= 0.01    local stars_pre "**"
            else if `p_pre' < 0.10 & `p_pre' >= 0.05    local stars_pre "*"

            * Event-study F-test for pre-trend
            reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
                absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
            testparm 1.treat_ultra#i(2009 2010).year
            local pre_ftest_pval = r(p)

            * Write CSV
            tempname fh
            file open `fh' using "`csv_out'", write append
            file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
            file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
            file close `fh'

            * Event-study plot (main outcomes only)
            estimates store _es_d_tmp
            local post_coef_s = string(`b_post', "%9.4f")
            local post_se_s   = string(`se_post', "%9.4f")
            local pre_pval_s  = string(`p_pre', "%9.3f")

            coefplot _es_d_tmp, ///
                keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
                     1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
                     1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
                coeflabels(1.treat_ultra#2009.year="2009" 1.treat_ultra#2010.year="2010" ///
                           1.treat_ultra#2011.year="2011" 1.treat_ultra#2012.year="2012" ///
                           1.treat_ultra#2013.year="2013" 1.treat_ultra#2014.year="2014" ///
                           1.treat_ultra#2015.year="2015" 1.treat_ultra#2016.year="2016") ///
                vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
                ytitle("Dynamic DiD coefficients", size(small)) ///
                note("Pre-trend F-test p-value = `pre_pval_s'") ///
                graphregion(color(white)) bgcolor(white) ///
                ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
                text(0.05 6 "`post_coef_s' (`post_se_s')", color(blue) size(small))

            cap graph export "$graphs/es_`outcome'_`panel'_`samp'_`d'.pdf", ///
                as(pdf) replace
            estimates drop _es_d_tmp
        }

        * ── CBA OUTCOME: numb_clauses ─────────────────────────────────────────

        capture confirm variable numb_clauses
        if _rc == 0 {

            di as text "  Estimating: numb_clauses (CBA periods, Panel `panel', `samp')"

            local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

            * Post-treatment
            reghdfe numb_clauses i.treat_ultra##post_treat_cba ///
                if `s_use' & !missing(cba_period), ///
                absorb(`absorb_cba') vce(cluster identificad)

            local b_post  = _b[1.treat_ultra#1.post_treat_cba]
            local se_post = _se[1.treat_ultra#1.post_treat_cba]
            local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs   = e(N)
            local n_estab = e(N_clust)

            * Pre-treatment placebo
            reghdfe numb_clauses i.treat_ultra##pre_treat_cba ///
                if `s_use' & !missing(cba_period) & cba_period <= 2, ///
                absorb(`absorb_cba') vce(cluster identificad)

            local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
            local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
            local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

            * Stars
            local stars_post ""
            if `p_post' < 0.01                           local stars_post "***"
            else if `p_post' < 0.05 & `p_post' >= 0.01  local stars_post "**"
            else if `p_post' < 0.10 & `p_post' >= 0.05  local stars_post "*"

            local stars_pre ""
            if `p_pre' < 0.01                            local stars_pre "***"
            else if `p_pre' < 0.05 & `p_pre' >= 0.01    local stars_pre "**"
            else if `p_pre' < 0.10 & `p_pre' >= 0.05    local stars_pre "*"

            * Event-study F-test for pre-trend
            reghdfe numb_clauses i.treat_ultra##ib2.cba_period ///
                if `s_use' & !missing(cba_period), ///
                absorb(`absorb_cba') vce(cluster identificad) tolerance(1e-2)
            testparm 1.treat_ultra#1.cba_period
            local pre_ftest_pval = r(p)

            * Write CSV
            tempname fh
            file open `fh' using "`csv_out'", write append
            file write `fh' `""`spec'";"`section'";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
            file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
            file close `fh'

            * Event-study plot
            estimates store _es_d_tmp
            local post_coef_s = string(`b_post', "%9.4f")
            local post_se_s   = string(`se_post', "%9.4f")
            local pre_pval_s  = string(`p_pre', "%9.3f")

            coefplot _es_d_tmp, ///
                msymbol(square) ///
                keep(1.treat_ultra#*.cba_period) ///
                coeflabels(1.treat_ultra#1.cba_period="2009" ///
                           1.treat_ultra#2.cba_period="2010-2012" ///
                           1.treat_ultra#3.cba_period="2013" ///
                           1.treat_ultra#4.cba_period="2014" ///
                           1.treat_ultra#5.cba_period="2015" ///
                           1.treat_ultra#6.cba_period="2016") ///
                vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
                ytitle("Dynamic DiD coefficients", size(small)) ///
                note("Pre-trend F-test p-value = `pre_pval_s'") ///
                graphregion(color(white)) bgcolor(white) ///
                ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
                text(2.5 4 "`post_coef_s' (`post_se_s')", color(blue) size(small))

            cap graph export "$graphs/es_numb_clauses_`panel'_`samp'_`d'.pdf", ///
                as(pdf) replace
            estimates drop _es_d_tmp
        }

        di as result "Panel `panel' | `samp' complete."
    }
}

********************************************************************************
* SECTION 5: SPILLOVER EFFECTS
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "SPILLOVER EFFECTS"
di as result "======================================================================="

foreach samp in full pre {

    if "`samp'" == "full" {
        local s_spill "`s_full_spill'"
        local samp_label "Full unbalanced panel"
    }
    else {
        local s_spill "`s_pre_spill'"
        local samp_label "Firms present all pretreatment years"
    }

    local csv_spill "$tables/results_spill_`samp'_`spec'.csv"
    local section   "spill_`samp'"

    di _newline(1)
    di as result "--- Spillover | `samp_label' ---"

    * ── YEAR-BASED OUTCOMES ──────────────────────────────────────────────────

    foreach outcome in l_firm_emp lr_remdezr_w lr_remdezr_h_w {

        di as text "  Estimating: `outcome' (spillover, `samp')"

        local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * Post-treatment: β on connectivity × post
        reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`absorb') vce(cluster identificad)

        local b_post  = _b[c.`conn'#1.treat_year]
        local se_post = _se[c.`conn'#1.treat_year]
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment placebo
        reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
            absorb(`absorb') vce(cluster identificad)

        local b_pre  = _b[c.`conn'#1.placebo_year]
        local se_pre = _se[c.`conn'#1.placebo_year]
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01                           local stars_post "***"
        else if `p_post' < 0.05 & `p_post' >= 0.01  local stars_post "**"
        else if `p_post' < 0.10 & `p_post' >= 0.05  local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01                            local stars_pre "***"
        else if `p_pre' < 0.05 & `p_pre' >= 0.01    local stars_pre "**"
        else if `p_pre' < 0.10 & `p_pre' >= 0.05    local stars_pre "*"

        * Event-study F-test for pre-trend
        local absorb_spill_es "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
            absorb(`absorb_spill_es') vce(cluster identificad) tolerance(1e-2)
        capture testparm c.`conn'#i(2009 2010).year
        local pre_ftest_pval = cond(_rc==0, r(p), .)

        * Write CSV
        tempname fh
        file open `fh' using "`csv_spill'", write append
        file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        * Event-study plot
        estimates store _es_s_tmp
        local post_coef_s = string(`b_post', "%9.4f")
        local post_se_s   = string(`se_post', "%9.4f")
        local pre_pval_s  = string(`p_pre', "%9.3f")

        coefplot _es_s_tmp, ///
            keep(c.`conn'#2009.year c.`conn'#2010.year c.`conn'#2011.year ///
                 c.`conn'#2012.year c.`conn'#2013.year c.`conn'#2014.year ///
                 c.`conn'#2015.year c.`conn'#2016.year) ///
            coeflabels(c.`conn'#2009.year="2009" c.`conn'#2010.year="2010" ///
                       c.`conn'#2011.year="2011" c.`conn'#2012.year="2012" ///
                       c.`conn'#2013.year="2013" c.`conn'#2014.year="2014" ///
                       c.`conn'#2015.year="2015" c.`conn'#2016.year="2016") ///
            vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
            ytitle("Dynamic DiD × connectivity coefficients", size(small)) ///
            note("Pre-trend F-test p-value = `pre_pval_s'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.05 6 "`post_coef_s' (`post_se_s')", color(blue) size(small))

        cap graph export "$graphs/es_spill_`outcome'_`samp'_`d'.pdf", ///
            as(pdf) replace
        estimates drop _es_s_tmp
    }

    * ── CBA OUTCOME: numb_clauses (spillover) ────────────────────────────────

    capture confirm variable numb_clauses
    if _rc == 0 {

        di as text "  Estimating: numb_clauses (CBA periods, spillover, `samp')"

        local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        * Post-treatment
        reghdfe numb_clauses c.`conn'##post_treat_cba ///
            if `s_spill' & !missing(cba_period), ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_post  = _b[c.`conn'#1.post_treat_cba]
        local se_post = _se[c.`conn'#1.post_treat_cba]
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment placebo
        reghdfe numb_clauses c.`conn'##pre_treat_cba ///
            if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_pre  = _b[c.`conn'#1.pre_treat_cba]
        local se_pre = _se[c.`conn'#1.pre_treat_cba]
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01                           local stars_post "***"
        else if `p_post' < 0.05 & `p_post' >= 0.01  local stars_post "**"
        else if `p_post' < 0.10 & `p_post' >= 0.05  local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01                            local stars_pre "***"
        else if `p_pre' < 0.05 & `p_pre' >= 0.01    local stars_pre "**"
        else if `p_pre' < 0.10 & `p_pre' >= 0.05    local stars_pre "*"

        * Event-study F-test for pre-trend
        local absorb_spill_cba_es "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        reghdfe numb_clauses c.`conn'##ib2.cba_period ///
            if `s_spill' & !missing(cba_period), ///
            absorb(`absorb_spill_cba_es') vce(cluster identificad) tolerance(1e-2)
        testparm c.`conn'#1.cba_period
        local pre_ftest_pval = r(p)

        * Write CSV
        tempname fh
        file open `fh' using "`csv_spill'", write append
        file write `fh' `""`spec'";"`section'";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'
    }

    di as result "Spillover | `samp' complete."
}

log close

di "=== results_entry_exit.do done: `c(current_date)' `c(current_time)' ==="
