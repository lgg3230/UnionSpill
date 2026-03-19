* Test: does totalflows_pw yield non-null spill coefficients?
set more off
set varabbrev off

global main "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
drop _merge

* ── Same data loading as loglevel script ─────────────────────────────────────

* Totalflows wide (2007-2011) for pre-treatment average
preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile totalflows_wide
    save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
    if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

* Flow outcomes panel (2009-2016)
preserve
    import delimited "$rais_aux/totalflows_panel_2009_2016.csv", clear
    tostring identificad, replace format(%014.0f) force
    keep identificad year totalflows outflows inflows totalflows_pw outflows_pw inflows_pw
    tempfile flows_panel
    save `flows_panel'
restore
merge m:1 identificad year using `flows_panel', keep(master match) nogen

* ── Treatment indicators ──────────────────────────────────────────────────────
cap drop treat_year
cap drop placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year < 2011)

* ── Pre-treatment bins ───────────────────────────────────────────────────────

* totalflows_pw_pre_07_114 (4 bins of pre 2007-2011 average)
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
        if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* totalflows_pw pre4 bins
cap drop totalflows_pw_pre_o
cap drop totalflows_pw_pre
quietly {
    bys identificad: egen totalflows_pw_pre_o = mean(totalflows_pw) if inrange(year, 2009, 2011)
    bys identificad: egen totalflows_pw_pre = min(totalflows_pw_pre_o)
    drop totalflows_pw_pre_o
}
cap drop totalflows_pw_pre4_o
cap drop totalflows_pw_pre4
quietly {
    egen totalflows_pw_pre4_o = cut(totalflows_pw_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen totalflows_pw_pre4 = min(totalflows_pw_pre4_o)
    drop totalflows_pw_pre4_o
    replace totalflows_pw_pre4 = 0 if missing(totalflows_pw_pre4)
}

* l_firm_emp pre4
cap drop l_firm_emp
gen double l_firm_emp = ln(firm_emp) if firm_emp > 0
cap drop l_firm_emp_pre_o
cap drop l_firm_emp_pre
quietly {
    bys identificad: egen l_firm_emp_pre_o = mean(l_firm_emp) if inrange(year, 2009, 2011)
    bys identificad: egen l_firm_emp_pre = min(l_firm_emp_pre_o)
    drop l_firm_emp_pre_o
}
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
    replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)
}

* totaltreat_pw_norm
local s_spill "treat_ultra==0 & lagos_sample_avg==1 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── User's exact test ─────────────────────────────────────────────────────────
local outcome "totalflows_pw"
local s_use "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
* Theory test: panel-based pre4 (totalflows_pw_pre4) as extra_year — does this avoid absorption?
local absorb "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre4#i.year"
local conn "totaltreat_pw_norm"

di _newline(2)
di as result "=== SPILL SPEC (s_spill) ==="
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`absorb') vce(cluster identificad)
