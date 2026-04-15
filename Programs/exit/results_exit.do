********************************************************************************
* results_exit.do
* PURPOSE:  Effect of treatment / spillover on firm survival (present_in_year).
*
* STANDALONE — can be run directly from Stata (Mac or cluster) with no other
* do-file needed.  Set Stata's working directory to the project root before
* running, or pre-set $tables, $graphs, $data_in before calling this file.
*
* COLLINEARITY NOTE:
*   With firm FE + industry×year + microregion×year + mode_base_month×year in
*   the absorb, any pure-time dummy (including treat_year and placebo_year) is
*   spanned by the year-interacted FEs and would be dropped. The fix is to
*   include ONLY the interaction term (1.treat_ultra#1.treat_year) without the
*   main effects of treat_ultra (absorbed by firm FE) and treat_year (absorbed
*   by year-spanning FEs).
*
* PRE-TREND NOTE:
*   In the present_all_pretreat==1 sample, all firms have present_in_year=1 in
*   2009-2011 by construction → zero within-cell variation in pre-treatment →
*   pre-trend test not identified. capture testparm + cond(_rc==0,...) handles
*   this. For the full unbalanced panel, treated firms are all present pre-
*   treatment, so the pre-trend test will also typically be missing.
*
* Specs (4 total):
*   (1) Direct,    full unbalanced panel          → results_exit_direct_full_*.csv
*   (2) Direct,    present all pretreat yrs        → results_exit_direct_pre_*.csv
*   (3) Spillover, full unbalanced panel           → results_exit_spill_full_*.csv
*   (4) Spillover, present all pretreat yrs        → results_exit_spill_pre_*.csv
*
* Input:  Data/entry_exit/entry_exit_panel.dta
* Output: Tables/exit/results_exit_*.csv
*         Graphs/exit/es_exit_*.pdf
********************************************************************************

* ── PATHS ─────────────────────────────────────────────────────────────────────
* Auto-detect from working directory (project root) when globals are not already
* set by a calling wrapper (e.g. _run_exit.do on the cluster).
if "$tables"  == "" global tables  "`c(pwd)'/Tables/exit"
if "$graphs"  == "" global graphs  "`c(pwd)'/Graphs/exit"
if "$data_in" == "" global data_in "`c(pwd)'/Data/entry_exit/entry_exit_panel.dta"

* Create output directories if they do not exist (harmless on cluster)
cap mkdir "$tables"
cap mkdir "$graphs"

local d    : display %tdCYND date("`c(current_date)'","DMY")
local spec "exit"
local conn "totaltreat_pw_norm"

* ── Fixed effects ─────────────────────────────────────────────────────────────
* mode_base_month always included. Event-study uses tolerance(1e-2).
* No outcome pre-treatment bins (not meaningful for a presence indicator).
local base_fe    "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb     "`base_fe' ib0.l_firm_emp_pre4#i.year `extra_year'"

* ── Load panel ────────────────────────────────────────────────────────────────
use "$data_in", clear

* ── Sample macros ─────────────────────────────────────────────────────────────
local s_direct_full "lagos_sample_unbal_avg==1"
local s_direct_pre  "lagos_sample_unbal_avg==1 & present_all_pretreat==1"
local s_spill_full  "lagos_sample_unbal_avg==1 & treat_ultra==0"
local s_spill_pre   "lagos_sample_unbal_avg==1 & treat_ultra==0 & present_all_pretreat==1"

* ── Initialise CSVs ───────────────────────────────────────────────────────────
foreach spec2 in direct_full direct_pre spill_full spill_pre {
    capture erase "$tables/results_exit_`spec2'_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/results_exit_`spec2'_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
}

********************************************************************************
* DIRECT EFFECTS
********************************************************************************

foreach samp in full pre {

    if "`samp'" == "full" {
        local s_use    "`s_direct_full'"
        local samp_label "Full unbalanced panel"
    }
    else {
        local s_use    "`s_direct_pre'"
        local samp_label "Present all pre-treat yrs"
    }

    local csv_out "$tables/results_exit_direct_`samp'_`spec'.csv"
    local section "direct_`samp'"

    di as result "=== Direct Exit (`samp_label') ==="

    * ── Post-treatment DiD ───────────────────────────────────────────────────
    * Include ONLY the interaction (not main effects — both absorbed by FEs)
    reghdfe present_in_year 1.treat_ultra#1.treat_year ///
        if `s_use', absorb(`absorb') vce(cluster identificad)

    local b_post  = _b[1.treat_ultra#1.treat_year]
    local se_post = _se[1.treat_ultra#1.treat_year]
    local n_obs   = e(N)
    local n_estab = e(N_clust)
    local p_post  = 2 * ttail(e(df_r), abs(`b_post' / `se_post'))
    local stars_post ""
    if `p_post' < 0.01                          local stars_post "***"
    else if `p_post' < 0.05 & `p_post' >= 0.01 local stars_post "**"
    else if `p_post' < 0.10 & `p_post' >= 0.05 local stars_post "*"

    * ── Pre-treatment placebo ────────────────────────────────────────────────
    reghdfe present_in_year 1.treat_ultra#1.placebo_year ///
        if `s_use' & year <= 2011, absorb(`absorb') vce(cluster identificad)

    local b_pre  = _b[1.treat_ultra#1.placebo_year]
    local se_pre = _se[1.treat_ultra#1.placebo_year]
    local p_pre  = 2 * ttail(e(df_r), abs(`b_pre' / `se_pre'))
    local stars_pre ""
    if `p_pre' < 0.01                          local stars_pre "***"
    else if `p_pre' < 0.05 & `p_pre' >= 0.01  local stars_pre "**"
    else if `p_pre' < 0.10 & `p_pre' >= 0.05  local stars_pre "*"

    * ── Event study (pre-trend F-test + graph) ───────────────────────────────
    * Include only interaction terms, not main effects of treat_ultra or year
    reghdfe present_in_year 1.treat_ultra#ib2011.year ///
        if `s_use', absorb(`absorb') vce(cluster identificad) tolerance(1e-2)

    * Pre-trend: may not be identified (see header note)
    capture testparm 1.treat_ultra#i(2009 2010).year
    local pre_ftest_pval = cond(_rc==0, r(p), .)

    * Event study graph
    estimates store _es_exit_tmp
    local post_coef_s = string(`b_post', "%9.4f")
    local post_se_s   = string(`se_post', "%9.4f")

    coefplot _es_exit_tmp, keep(1.treat_ultra#*.year) ///
        rename(1.treat_ultra#2009.year = "2009" 1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2012.year = "2012" 1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" 1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
        vertical recast(connected) ///
        yline(0, lcolor(black) lwidth(thin)) ///
        xline(2.5, lcolor(red) lpattern(dash)) ///
        ylabel(, format(%6.4f)) ///
        ytitle("Treated {&times} Year") ///
        xtitle("Year") ///
        note("Post DiD: `post_coef_s' (`post_se_s')", position(6))

    cap graph export "$graphs/es_exit_direct_`samp'_`d'.pdf", as(pdf) replace
    estimates drop _es_exit_tmp

    * ── Write CSV ────────────────────────────────────────────────────────────
    tempname fh
    file open `fh' using "`csv_out'", write append
    file write `fh' `""`spec'";"`section'";"present_in_year";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"main_se";"' %9.4f (`se_post') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre";"'    %9.4f (`b_pre') `"`stars_pre'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_se";"' %9.4f (`se_pre') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_estab";"' %12.0fc (`n_estab') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
    file close `fh'
}

********************************************************************************
* SPILLOVER EFFECTS
********************************************************************************

foreach samp in full pre {

    if "`samp'" == "full" {
        local s_spill  "`s_spill_full'"
        local samp_label "Full unbalanced panel"
    }
    else {
        local s_spill  "`s_spill_pre'"
        local samp_label "Present all pre-treat yrs"
    }

    local csv_spill "$tables/results_exit_spill_`samp'_`spec'.csv"
    local section   "spill_`samp'"

    di as result "=== Spillover Exit (`samp_label') ==="

    * ── Post-treatment ───────────────────────────────────────────────────────
    reghdfe present_in_year c.`conn'#1.treat_year ///
        if `s_spill', absorb(`absorb') vce(cluster identificad)

    local b_post  = _b[c.`conn'#1.treat_year]
    local se_post = _se[c.`conn'#1.treat_year]
    local n_obs   = e(N)
    local n_estab = e(N_clust)
    local p_post  = 2 * ttail(e(df_r), abs(`b_post' / `se_post'))
    local stars_post ""
    if `p_post' < 0.01                          local stars_post "***"
    else if `p_post' < 0.05 & `p_post' >= 0.01 local stars_post "**"
    else if `p_post' < 0.10 & `p_post' >= 0.05 local stars_post "*"

    * ── Pre-treatment placebo ────────────────────────────────────────────────
    reghdfe present_in_year c.`conn'#1.placebo_year ///
        if `s_spill' & year <= 2011, absorb(`absorb') vce(cluster identificad)

    local b_pre  = _b[c.`conn'#1.placebo_year]
    local se_pre = _se[c.`conn'#1.placebo_year]
    local p_pre  = 2 * ttail(e(df_r), abs(`b_pre' / `se_pre'))
    local stars_pre ""
    if `p_pre' < 0.01                          local stars_pre "***"
    else if `p_pre' < 0.05 & `p_pre' >= 0.01  local stars_pre "**"
    else if `p_pre' < 0.10 & `p_pre' >= 0.05  local stars_pre "*"

    * ── Event study ──────────────────────────────────────────────────────────
    reghdfe present_in_year c.`conn'#ib2011.year ///
        if `s_spill', absorb(`absorb') vce(cluster identificad) tolerance(1e-2)

    capture testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval = cond(_rc==0, r(p), .)

    * Event study graph
    estimates store _es_spill_exit_tmp
    local post_coef_s = string(`b_post', "%9.4f")
    local post_se_s   = string(`se_post', "%9.4f")

    coefplot _es_spill_exit_tmp, keep(c.`conn'#*.year) ///
        rename(c.`conn'#2009.year = "2009" c.`conn'#2010.year = "2010" ///
               c.`conn'#2012.year = "2012" c.`conn'#2013.year = "2013" ///
               c.`conn'#2014.year = "2014" c.`conn'#2015.year = "2015" ///
               c.`conn'#2016.year = "2016") ///
        vertical recast(connected) ///
        yline(0, lcolor(black) lwidth(thin)) ///
        xline(2.5, lcolor(red) lpattern(dash)) ///
        ylabel(, format(%6.4f)) ///
        ytitle("Connectivity {&times} Year") ///
        xtitle("Year") ///
        note("Post DiD: `post_coef_s' (`post_se_s')", position(6))

    cap graph export "$graphs/es_exit_spill_`samp'_`d'.pdf", as(pdf) replace
    estimates drop _es_spill_exit_tmp

    * ── Write CSV ────────────────────────────────────────────────────────────
    tempname fh
    file open `fh' using "`csv_spill'", write append
    file write `fh' `""`spec'";"`section'";"present_in_year";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"main_se";"' %9.4f (`se_post') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre";"'    %9.4f (`b_pre') `"`stars_pre'""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_se";"' %9.4f (`se_pre') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"n_estab";"' %12.0fc (`n_estab') `"""' _n
    file write `fh' `""`spec'";"`section'";"present_in_year";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
    file close `fh'
}

di as result "results_exit.do complete."
