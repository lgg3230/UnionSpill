* Test: do ll_totalflows and fs_totalflows produce non-zero coefs
* when extra_year = totalflows_pw_pre_07_114 is included?

set more off
set varabbrev off

global main     "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* Merge turnover (need hired_u for churn; not strictly needed but harmless)
preserve
    import delimited "$rais_firm/corrected_turnover_sample.csv", clear
    keep identificad year hired_u separations_u
    tostring identificad, replace format(%014.0f) force
    tempfile t
    save `t'
restore
merge 1:1 identificad year using `t', keep(master match) nogen

* Merge flow outcomes panel
preserve
    import delimited "$rais_aux/totalflows_panel_2009_2016.csv", clear
    tostring identificad, replace format(%014.0f) force
    keep identificad year totalflows outflows inflows totalflows_pw
    tempfile fp
    save `fp'
restore
cap drop totalflows_pw
merge 1:1 identificad year using `fp', keep(master match) nogen

* Merge totalflows_wide_2007_2011
preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile fw
    save `fw'
restore
merge m:1 identificad using `fw', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

* Treatment indicators
cap drop treat_year placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year < 2011)

* Connectivity scaling
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90 totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90

* l_firm_emp_pre4
cap drop firm_emp_pre_o firm_emp_pre l_firm_emp_pre l_firm_emp_pre4_o l_firm_emp_pre4
quietly {
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
    bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
    drop firm_emp_pre_o
    gen double l_firm_emp_pre = ln(firm_emp_pre)
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
}

* totalflows_pw_pre_07_114
cap drop totalflows_pw_pre_07_114_o totalflows_pw_pre_07_114
quietly {
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local conn    "totaltreat_pw_norm"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* ── 1. ll_totalflows ─────────────────────────────────────────────────────────
cap drop ll_totalflows ll_totalflows_pre_o ll_totalflows_pre ll_totalflows_pre4_o ll_totalflows_pre4
gen double ll_totalflows = ln(totalflows) if totalflows > 0
quietly {
    bys identificad: egen ll_totalflows_pre_o = mean(ll_totalflows) if inrange(year, 2009, 2011)
    bys identificad: egen ll_totalflows_pre   = min(ll_totalflows_pre_o)
    drop ll_totalflows_pre_o
    egen ll_totalflows_pre4_o = cut(ll_totalflows_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen ll_totalflows_pre4  = min(ll_totalflows_pre4_o)
    drop ll_totalflows_pre4_o
    replace ll_totalflows_pre4 = 0 if missing(ll_totalflows_pre4)
}

di as result _newline "=== ll_totalflows with full absorb (including extra_year) ==="
local absorb "`base_fe' ib0.ll_totalflows_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
reghdfe ll_totalflows c.`conn'##i.treat_year if `s_spill', absorb(`absorb') vce(cluster identificad)
di "b_post = " _b[1.treat_year#c.`conn'] "  se = " _se[1.treat_year#c.`conn'] "  R2 = " e(r2)

* ── 2. fs_totalflows ─────────────────────────────────────────────────────────
cap drop fm_totalflows_o fm_totalflows fs_totalflows totalflows_pre_o totalflows_pre totalflows_pre4_o totalflows_pre4
quietly {
    bys identificad: egen fm_totalflows_o = mean(totalflows) if inrange(year, 2009, 2011)
    bys identificad: egen fm_totalflows   = min(fm_totalflows_o)
    drop fm_totalflows_o
}
gen double fs_totalflows = totalflows / fm_totalflows if fm_totalflows > 0 & !missing(fm_totalflows)
quietly {
    bys identificad: egen totalflows_pre_o = mean(totalflows) if inrange(year, 2009, 2011)
    bys identificad: egen totalflows_pre   = min(totalflows_pre_o)
    drop totalflows_pre_o
    egen totalflows_pre4_o = cut(totalflows_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen totalflows_pre4  = min(totalflows_pre4_o)
    drop totalflows_pre4_o
    replace totalflows_pre4 = 0 if missing(totalflows_pre4)
}

di as result _newline "=== fs_totalflows with full absorb (including extra_year) ==="
local absorb "`base_fe' ib0.totalflows_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
reghdfe fs_totalflows c.`conn'##i.treat_year if `s_spill', absorb(`absorb') vce(cluster identificad)
di "b_post = " _b[1.treat_year#c.`conn'] "  se = " _se[1.treat_year#c.`conn'] "  R2 = " e(r2)

di as result _newline "Done."
