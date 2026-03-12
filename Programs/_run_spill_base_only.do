* Minimal spillover regressions — mirrors Main_Results_pct_tfpw_07_11.do exactly
* Purpose: compare with layer firmrestr results
set more off
set varabbrev off

global main     "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/spill_base_only_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

* ── Load data (same as Main_Results_pct_tfpw_07_11.do) ──────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* Merge totalflows
preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile totalflows_wide
    save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

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

di "Obs after sample restriction: " _N

* ── Variable creation (mirroring Main_Results_pct_tfpw_07_11.do) ────────────

cap drop treat_year
gen byte treat_year = (year >= 2012)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Connectivity scaling
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* Pre-treatment firm employment
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
drop firm_emp_pre_o
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
}
replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)

* Totalflows bins
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
        if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* Pre-treatment bins for each outcome
foreach outcome in lr_remdezr lr_remdezr_h l_firm_emp {
    cap drop `outcome'_pre_o
    cap drop `outcome'_pre
    cap drop `outcome'_pre4_o
    cap drop `outcome'_pre4
    quietly {
        bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
        bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
        drop `outcome'_pre_o
        egen `outcome'_pre4_o = cut(`outcome'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
        bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
        drop `outcome'_pre4_o
        replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)
    }
}

* ── FE macros (same as main do-file) ────────────────────────────────────────

local spec       "tfpw_07_11_pct"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* ── Diagnostic ───────────────────────────────────────────────────────────────

di "Spillover sample obs (non-missing connectivity):"
count if `s_spill' & !missing(totaltreat_pw_norm) & !missing(lr_remdezr_w)

* ── Output CSV ───────────────────────────────────────────────────────────────

capture erase "$tables/results_spill_base_only.csv"
tempname fh
file open `fh' using "$tables/results_spill_base_only.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── Spillover regressions ────────────────────────────────────────────────────

foreach outcome in lr_remdezr lr_remdezr_h l_firm_emp {

    di as result "Estimating spillover: `outcome'"

    local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

    * Post-treatment
    reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)

    local b_post  = _b[1.treat_year#c.`conn']
    local se_post = _se[1.treat_year#c.`conn']
    local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
    local n_obs   = e(N)
    local n_firms = e(N_clust)

    local stars_post ""
    if `p_post' < 0.01                           local stars_post "***"
    else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
    else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

    * Pre-trend F-test
    reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
        absorb(`absorb') vce(cluster identificad)
    testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval = r(p)

    tempname fh
    file open `fh' using "$tables/results_spill_base_only.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'";"n_firms";"' %12.0fc (`n_firms') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
    file close `fh'
}

di as result "Done."
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "spill_base_only done" "spillover base outcomes complete"
