********************************************************************************
* Program:    lpm_entry_exit.do
* Purpose:    Linear probability model for firm presence in dataset.
*             Outcome: present_in_year (1=real obs, 0=padded/absent).
*             Uses full firm×year balanced panel (including padded rows).
*             Same FE spec as results_entry_exit.do but no outcome-specific pre4 bin.
*             Reports direct and spillover effects for two samples:
*               (1) Full unbalanced panel (lagos_sample_unbal_avg)
*               (2) Firms present in all pre-treatment years (present_all_pretreat)
* Input:      Data/entry_exit/entry_exit_panel.dta
* Outputs:    Tables/entry_exit/lpm_direct_panel{A,B,C}_{full,pre}_entry_exit.csv
*             Tables/entry_exit/lpm_spill_{full,pre}_entry_exit.csv
*             Graphs/entry_exit/lpm_es_*.pdf
* Called by:  _run_entry_exit.do (stage 6)
********************************************************************************

version 17.0
set more off

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/lpm_entry_exit_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD DATA — FULL PANEL (real + padded rows)
********************************************************************************

use "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear

* Do NOT keep if present_in_year == 1 — padded rows are the variation we need
di "Total obs (full panel): " _N
count if present_in_year == 0
di "Padded (absent) obs: " r(N)

********************************************************************************
* SECTION 2: SPEC AND SAMPLE MACROS
********************************************************************************

local spec "lpm_entry_exit"
local conn "totaltreat_pw_norm"

* FE: firm + industry×year + microregion×year + base_month×year
* No outcome-specific pre4 bin (outcome is a 0/1 presence dummy)
local base_fe     "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local absorb      "`base_fe' ib0.l_firm_emp_pre4#i.year `extra_year'"

* ── FULL UNBALANCED PANEL ────────────────────────────────────────────────────
local s_full_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_unbal_avg==1"
local s_full_spill "lagos_sample_unbal_avg==1 & treat_ultra==0"

* ── FIRMS PRESENT IN ALL PRE-TREATMENT YEARS (exit margin only) ──────────────
local s_pre_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_pre_spill "lagos_sample_unbal_avg==1 & treat_ultra==0 & present_all_pretreat==1"

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV FILES
********************************************************************************

foreach panel in A B C {
    foreach samp in full pre {
        capture erase "$tables/lpm_direct_panel`panel'_`samp'_`spec'.csv"
        tempname fh
        file open `fh' using "$tables/lpm_direct_panel`panel'_`samp'_`spec'.csv", write replace
        file write `fh' "spec;section;outcome;row_type;value" _n
        file close `fh'
    }
}

foreach samp in full pre {
    capture erase "$tables/lpm_spill_`samp'_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/lpm_spill_`samp'_`spec'.csv", write replace
    file write `fh' "spec;section;outcome;row_type;value" _n
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

        local csv_out "$tables/lpm_direct_panel`panel'_`samp'_`spec'.csv"

        di _newline(1)
        di as result "--- Panel `panel' | `samp_label' ---"
        di as text "  Estimating: present_in_year (Panel `panel', `samp')"

        * Post-treatment DiD
        reghdfe present_in_year treat_ultra##i.treat_year if `s_use', ///
            absorb(`absorb') vce(cluster identificad)

        local b_post  = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment placebo (years <= 2011 only)
        reghdfe present_in_year treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
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
        reghdfe present_in_year i.treat_ultra##ib2011.year if `s_use', ///
            absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
        testparm 1.treat_ultra#i(2009 2010).year
        local pre_ftest_pval = r(p)

        * Write CSV
        tempname fh
        file open `fh' using "`csv_out'", write append
        file write `fh' `""`spec'";"`section'";"present_in_year";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"pre";"'    %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"n_obs";"'  %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file write `fh' `""`spec'";"`section'";"present_in_year";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        * Event-study plot
        estimates store _es_d_tmp
        local post_coef_s = string(`b_post', "%9.4f")
        local post_se_s   = string(`se_post', "%9.4f")
        local pre_pval_s  = string(`pre_ftest_pval', "%9.3f")

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

        cap graph export "$graphs/lpm_es_direct_`panel'_`samp'_`d'.pdf", ///
            as(pdf) replace
        estimates drop _es_d_tmp

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

    local csv_spill "$tables/lpm_spill_`samp'_`spec'.csv"
    local section   "spill_`samp'"

    di _newline(1)
    di as result "--- Spillover | `samp_label' ---"
    di as text "  Estimating: present_in_year (spillover, `samp')"

    * Post-treatment: β on connectivity × post
    reghdfe present_in_year c.`conn'##i.treat_year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)

    local b_post  = _b[c.`conn'#1.treat_year]
    local se_post = _se[c.`conn'#1.treat_year]
    local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
    local n_obs   = e(N)
    local n_estab = e(N_clust)

    * Pre-treatment placebo
    reghdfe present_in_year c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
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
    reghdfe present_in_year c.`conn'##ib2011.year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
    capture testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval = cond(_rc==0, r(p), .)

    * Write CSV
    tempname fh
    file open `fh' using "`csv_spill'", write append
    file write `fh' `""`spec'";"`section'";"present_in_year";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"main_se";"'  %9.4f (`se_post') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre";"'     %9.4f (`b_pre') `"`stars_pre'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_se";"'  %9.4f (`se_pre') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_estab";"' %12.0fc (`n_estab') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
    file close `fh'

    * Event-study plot
    estimates store _es_s_tmp
    local post_coef_s = string(`b_post', "%9.4f")
    local post_se_s   = string(`se_post', "%9.4f")
    local pre_pval_s  = string(`pre_ftest_pval', "%9.3f")

    coefplot _es_s_tmp, ///
        keep(2009.year#c.`conn' 2010.year#c.`conn' 2011.year#c.`conn' ///
             2012.year#c.`conn' 2013.year#c.`conn' 2014.year#c.`conn' ///
             2015.year#c.`conn' 2016.year#c.`conn') ///
        coeflabels(2009.year#c.`conn'="2009" 2010.year#c.`conn'="2010" ///
                   2011.year#c.`conn'="2011" 2012.year#c.`conn'="2012" ///
                   2013.year#c.`conn'="2013" 2014.year#c.`conn'="2014" ///
                   2015.year#c.`conn'="2015" 2016.year#c.`conn'="2016") ///
        vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
        ytitle("Dynamic DiD × connectivity coefficients", size(small)) ///
        note("Pre-trend F-test p-value = `pre_pval_s'") ///
        graphregion(color(white)) bgcolor(white) ///
        ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
        text(0.05 6 "`post_coef_s' (`post_se_s')", color(blue) size(small))

    cap graph export "$graphs/lpm_es_spill_`samp'_`d'.pdf", ///
        as(pdf) replace
    estimates drop _es_s_tmp

    di as result "Spillover | `samp' complete."
}

log close

// shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
//     notify "lpm_entry_exit done" "LPM regressions complete"

di "=== lpm_entry_exit.do done: `c(current_date)' `c(current_time)' ==="



local conn totaltreat_pw_norm
local s_spill "lagos_sample_unbal_avg==1 & treat_ultra==0"
local absorb "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year ib0.totalflows_pw_pre_07_114#i.year ib0.l_firm_emp_pre4#i.year"
 

reghdfe present_in_year c.`conn'##i.treat_year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)
reghdfe present_in_year c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
        absorb(`absorb') vce(cluster identificad)
reghdfe present_in_year c.`conn'##ib2011.year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)
estimates store _es_s_tmp
    
    coefplot _es_s_tmp, ///
        keep(2009.year#c.`conn' 2010.year#c.`conn' 2011.year#c.`conn' ///
             2012.year#c.`conn' 2013.year#c.`conn' 2014.year#c.`conn' ///
             2015.year#c.`conn' 2016.year#c.`conn') ///
        coeflabels(2009.year#c.`conn'="2009" 2010.year#c.`conn'="2010" ///
                   2011.year#c.`conn'="2011" 2012.year#c.`conn'="2012" ///
                   2013.year#c.`conn'="2013" 2014.year#c.`conn'="2014" ///
                   2015.year#c.`conn'="2015" 2016.year#c.`conn'="2016") ///
        vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
        ytitle("Dynamic DiD × connectivity coefficients", size(small)) ///
        graphregion(color(white)) bgcolor(white) ///
        ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
