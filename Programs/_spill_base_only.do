********************************************************************************
* STANDALONE: SPILLOVER EFFECTS FOR BASE OUTCOMES ONLY
* Replicates Part D of Main_Results_pct_tfpw_07_11.do for:
*   lr_remdezr_w, lr_remdezr_h_w, l_firm_emp
* (Skips percentiles, ratios, numb_clauses, and all graph exports)
********************************************************************************

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/spill_base_only_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

* ── Load main firm panel ──────────────────────────────────────────────────────
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows wide ─────────────────────────────────────────────────────
preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile tfwide
    save `tfwide'
restore
merge m:1 identificad using `tfwide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011
gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
    if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample after restrictions: " _N

* ── Treatment indicators ──────────────────────────────────────────────────────
cap drop placebo_year
gen byte placebo_year = (year < 2011)
cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── Connectivity scaling (P90 in full spillover control sample) ───────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment employment ──────────────────────────────────────────────────
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
drop firm_emp_pre_o
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* l_firm_emp 4-bin control
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
drop l_firm_emp_pre4_o
replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)

* ── Totalflows pre bins ───────────────────────────────────────────────────────
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
    if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
drop totalflows_pw_pre_07_114_o
replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)

di as result "Bins created."

* ── Spec macros ───────────────────────────────────────────────────────────────
local spec    "tfpw_07_11_pct"
local conn    "totaltreat_pw_norm"
local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* ── Output CSV ────────────────────────────────────────────────────────────────
local csv_spill "$tables/results_spill_base_only.csv"
capture erase "`csv_spill'"
tempname fh
file open  `fh' using "`csv_spill'", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

di as result "Output: `csv_spill'"

********************************************************************************
* SPILLOVER REGRESSIONS — BASE OUTCOMES ONLY
********************************************************************************

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

    di as text "  Estimating: `outcome' (spillover)"

    * Pre-treatment mean & 4-bin control for this outcome
    cap drop `outcome'_pre_o
    cap drop `outcome'_pre
    cap drop `outcome'_pre4_o
    cap drop `outcome'_pre4
    bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
    bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
    drop `outcome'_pre_o
    egen `outcome'_pre4_o = cut(`outcome'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
    drop `outcome'_pre4_o
    replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)

    local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

    * Post-treatment
    reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)

    local b_post  = _b[1.treat_year#c.`conn']
    local se_post = _se[1.treat_year#c.`conn']
    local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
    local n_obs   = e(N)
    local n_estab = e(N_clust)

    * Stars
    local stars_post ""
    if `p_post' < 0.01                           local stars_post "***"
    else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
    else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

    * Pre-treatment placebo
    reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
        absorb(`absorb') vce(cluster identificad)

    local b_pre  = _b[1.placebo_year#c.`conn']
    local se_pre = _se[1.placebo_year#c.`conn']
    local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

    local stars_pre ""
    if `p_pre' < 0.01                           local stars_pre "***"
    else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
    else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

    * Event study for pre-trend F-test
    reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)
    testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval = r(p)

    * Write CSV
    tempname fh
    file open  `fh' using "`csv_spill'", write append
    file write `fh' `""`spec'";"spill";"`outcome'";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'             _n
    file write `fh' `""`spec'";"spill";"`outcome'";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""'  _n
    file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') `"""'             _n
    file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') `"""'            _n
    file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
    file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval') `"""'     _n
    file close `fh'

    di as result "  Done: `outcome' — post=`b_post' (`se_post'), pre=`b_pre' (`se_pre'), pre-trend p=`pre_ftest_pval'"
}

log close
di as result "Finished: `c(current_date)' `c(current_time)'"
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "spill_base_only done" "spillover base outcomes complete"
