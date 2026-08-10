********************************************************************************
* Program:  balance_table_task2.do                                     (Task 2)
* Purpose:  9-COLUMN control-effectiveness balance table. For each pre-treatment
*           firm characteristic (2011 cross-section), report THREE comparisons,
*           each at THREE control levels, to show whether the paper's controls
*           bring treated vs control closer to balance:
*             Comparison 1  Treated vs. ALL untreated controls   (b on treat_ultra)
*             Comparison 2  Treated vs. ZERO-connectivity controls
*             Comparison 3  Slope on connectivity (spillover sample)
*           Levels per comparison:
*             RAW           no controls
*             MAIN          main-spec controls only (industry/microregion/month FE
*                           + flows quartile + employment quartile) -- NO own quartile
*             +OWN          MAIN plus the outcome's own pre-treatment quartile dummies
*           So the reader compares the "middle ground" (MAIN) against the fuller
*           (+OWN) version, and can see whether conditioning a characteristic on
*           ITS OWN prior level is what drives the balance (esp. for demographics).
*
* OWN-QUARTILE PRE-WINDOW: 2007-2010 for wage & employment (real reconstructed
*   2007-08 data in the extended-pre panel), 2009-2010 for every other row (their
*   2007-08 values are cloned from 2009 in the extpre panel, so not usable). The
*   universal EMPLOYMENT quartile stays 2009-2010. Quartiles are 4 GROUP DUMMIES,
*   not the lagged level, and the pre-window excludes the 2011 value being compared.
*   Connectivity (exposure, not an outcome) gets the universal set only; the flows
*   row's own quartile IS the universal flows quartile.
*
* Sample:   lagos balanced panel, 2011 cross-section, one obs/firm.
* Output:   Tables/descriptives/balance_table_task2.csv
* Inputs:   lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta (2007-2016 panel),
*           firm_mean_age.csv, totalflows_wide_2007_2011.csv.
********************************************************************************

version 17.0
set more off

global base      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
global rais_aux  "$base/Data/RAIS_aux"
global tables    "$base/Tables"
cap mkdir "$tables/descriptives"

* extended-pre panel: main 2009-2016 rows PLUS reconstructed 2007-2008 wage/emp
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta", clear
keep if year >= 2007
keep if lagos_sample_avg == 1

* ============================ CONNECTIVITY (normalized, as in main spec) =======
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
bys identificad: egen double conn_firm = max(totaltreat_pw_norm)

* ---- per-worker pre-treatment (2007-2011) flows: outcome AND quartile control --
preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    capture confirm string variable identificad
    if _rc tostring identificad, replace format(%014.0f) force
    tempfile tfw
    save `tfw'
restore
merge m:1 identificad using `tfw', keep(master match) nogen
cap drop totalflows_pw_pre_07_11
cap drop totalflows_pw_pre_07_11_cnt
gen double totalflows_pw_pre_07_11     = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009 & in_balanced_panel==1, group(4)
bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
drop totalflows_pw_pre_07_114_o
replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)

* ============================ MEAN WORKER AGE (firm-year, YEARS) ===============
preserve
    import delimited "$rais_aux/firm_mean_age.csv", clear
    capture confirm string variable identificad
    if _rc tostring identificad, replace format(%014.0f) force
    keep identificad year mean_age
    tempfile age
    save `age'
restore
merge 1:1 identificad year using `age', keep(master match) nogen

* ============================ COMPOSITION SHARES ==============================
gen double prop_female    = 1 - male_prop
gen double prop_non_white = 1 - white_prop

* ============================ 2009-2010 OWN QUARTILES (baseline window) ========
* Used for the universal EMPLOYMENT quartile and for the own quartile of every row
* EXCEPT wage/employment (whose 2007-08 data is real and handled below).
foreach v in lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
             mean_age avg_tenure numb_clauses {
    cap drop `v'_preo
    cap drop `v'_pre
    bys identificad: egen double `v'_preo = mean(`v') if inrange(year,2009,2010)
    bys identificad: egen double `v'_pre  = min(`v'_preo)
    drop `v'_preo
    cap drop `v'_preQ4_o
    cap drop `v'_preQ4
    egen `v'_preQ4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen `v'_preQ4 = min(`v'_preQ4_o)
    drop `v'_preQ4_o
    replace `v'_preQ4 = 0 if missing(`v'_preQ4)
}

* ============================ 2007-2010 OWN QUARTILES (wage & emp only) ========
* Real reconstructed 2007-08 wage/emp in the extpre panel -> genuine 2007-2010 mean.
foreach v in lr_remdezr_w l_firm_emp {
    cap drop `v'_ownpreo
    cap drop `v'_ownpre
    bys identificad: egen double `v'_ownpreo = mean(`v') if inrange(year,2007,2010)
    bys identificad: egen double `v'_ownpre  = min(`v'_ownpreo)
    drop `v'_ownpreo
    cap drop `v'_ownQ4_o
    cap drop `v'_ownQ4
    egen `v'_ownQ4_o = cut(`v'_ownpre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen `v'_ownQ4 = min(`v'_ownQ4_o)
    drop `v'_ownQ4_o
    replace `v'_ownQ4 = 0 if missing(`v'_ownQ4)
}

* ============================ 2011 CROSS-SECTION =============================
replace totaltreat_pw_norm = conn_firm
keep if year == 2011

* ============================ CONTROL SET =====================================
* MAIN = universal main-spec controls (no own quartile); employment quartile = 2009-2010.
local universal "i.industry1 i.mode_base_month i.microregion ib0.totalflows_pw_pre_07_114 ib0.l_firm_emp_preQ4"

* ============================ SAMPLES =========================================
local s_all   "lagos_sample_avg==1 & in_balanced_panel==1"
local s_zero  "lagos_sample_avg==1 & in_balanced_panel==1 & (treat_ultra==1 | conn_firm==0)"

* ============================ CHARACTERISTIC ROWS =============================
local chars_tc  lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
                mean_age avg_tenure numb_clauses totaltreat_pw_norm totalflows_pw_pre_07_11

* ============================ ESTIMATE ========================================
tempname fh
postfile `fh' str25 characteristic ///
    double(c1_b c1_se c1_p  c2_b c2_se c2_p  c3_b c3_se c3_p ///
           c4_b c4_se c4_p  c5_b c5_se c5_p  c6_b c6_se c6_p ///
           c7_b c7_se c7_p  c8_b c8_se c8_p  c9_b c9_se c9_p) ///
    long(n_all n_zero n_spill) ///
    using "$tables/descriptives/balance_table_task2_tmp.dta", replace

* helper: run reg / reghdfe, return b se p n in r()
capture program drop _grab
program define _grab, rclass
    args cmd yvar xvar cond absorbspec
    if "`cmd'" == "reg" {
        capture reg `yvar' `xvar' if `cond', vce(robust)
    }
    else {
        capture reghdfe `yvar' `xvar' if `cond', absorb(`absorbspec') vce(robust)
    }
    if _rc {
        return scalar b = .
        return scalar se = .
        return scalar p = .
        return scalar n = .
        exit
    }
    return scalar b  = _b[`xvar']
    return scalar se = _se[`xvar']
    return scalar p  = 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar']))
    return scalar n  = e(N)
end

foreach y of local chars_tc {
    di as text "==== `y' ===="
    * own-outcome quartile: 2007-2010 for wage/emp, 2009-2010 for others;
    * none for connectivity (exposure) or flows (its quartile is universal).
    local own ""
    if "`y'" == "lr_remdezr_w"      local own "ib0.lr_remdezr_w_ownQ4"
    else if "`y'" == "l_firm_emp"   local own "ib0.l_firm_emp_ownQ4"
    else if !inlist("`y'","totaltreat_pw_norm","totalflows_pw_pre_07_11") {
        capture confirm variable `y'_preQ4
        if !_rc local own "ib0.`y'_preQ4"
    }
    local full "`universal' `own'"

    * ---- Comparison 1: Treated vs ALL controls ----
    _grab reg     `y' treat_ultra "`s_all'" ""
    local c1b = r(b)
    local c1s = r(se)
    local c1p = r(p)
    local nall = r(n)
    _grab reghdfe `y' treat_ultra "`s_all'" "`universal'"
    local c2b = r(b)
    local c2s = r(se)
    local c2p = r(p)
    _grab reghdfe `y' treat_ultra "`s_all'" "`full'"
    local c3b = r(b)
    local c3s = r(se)
    local c3p = r(p)

    * ---- Comparison 2: Treated vs ZERO-connectivity controls ----
    _grab reg     `y' treat_ultra "`s_zero'" ""
    local c4b = r(b)
    local c4s = r(se)
    local c4p = r(p)
    local nzero = r(n)
    _grab reghdfe `y' treat_ultra "`s_zero'" "`universal'"
    local c5b = r(b)
    local c5s = r(se)
    local c5p = r(p)
    _grab reghdfe `y' treat_ultra "`s_zero'" "`full'"
    local c6b = r(b)
    local c6s = r(se)
    local c6p = r(p)

    * ---- Comparison 3: Slope on connectivity (spillover sample) ----
    if "`y'" == "totaltreat_pw_norm" {
        local c7b = .
        local c7s = .
        local c7p = .
        local nspill = .
        local c8b = .
        local c8s = .
        local c8p = .
        local c9b = .
        local c9s = .
        local c9p = .
    }
    else {
        _grab reg     `y' totaltreat_pw_norm "`s_spill'" ""
        local c7b = r(b)
        local c7s = r(se)
        local c7p = r(p)
        local nspill = r(n)
        _grab reghdfe `y' totaltreat_pw_norm "`s_spill'" "`universal'"
        local c8b = r(b)
        local c8s = r(se)
        local c8p = r(p)
        _grab reghdfe `y' totaltreat_pw_norm "`s_spill'" "`full'"
        local c9b = r(b)
        local c9s = r(se)
        local c9p = r(p)
    }

    post `fh' ("`y'") (`c1b') (`c1s') (`c1p') (`c2b') (`c2s') (`c2p') (`c3b') (`c3s') (`c3p') ///
        (`c4b') (`c4s') (`c4p') (`c5b') (`c5s') (`c5p') (`c6b') (`c6s') (`c6p') ///
        (`c7b') (`c7s') (`c7p') (`c8b') (`c8s') (`c8p') (`c9b') (`c9s') (`c9p') ///
        (`nall') (`nzero') (`nspill')
}
postclose `fh'

preserve
    use "$tables/descriptives/balance_table_task2_tmp.dta", clear
    export delimited using "$tables/descriptives/balance_table_task2.csv", replace
    list characteristic c1_b c2_b c3_b c7_b c8_b c9_b, sep(0) noobs
restore
erase "$tables/descriptives/balance_table_task2_tmp.dta"

* ===== residual frame for the connectivity binscatters (matches cols 7/8/9) =====
* Residualize each characteristic X and connectivity on X's FULL controls (universal
* + own quartile), spillover sample; FWL slope of resid_X on rc_X = table col 9.
local chars_bs lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
               mean_age avg_tenure numb_clauses totalflows_pw_pre_07_11
preserve
    keep if `s_spill'
    foreach y of local chars_bs {
        local own ""
        if "`y'" == "lr_remdezr_w"      local own "ib0.lr_remdezr_w_ownQ4"
        else if "`y'" == "l_firm_emp"   local own "ib0.l_firm_emp_ownQ4"
        else if "`y'" != "totalflows_pw_pre_07_11" {
            capture confirm variable `y'_preQ4
            if !_rc local own "ib0.`y'_preQ4"
        }
        local full "`universal' `own'"
        cap drop resid_`y'
        cap drop rc_`y'
        qui reghdfe `y', absorb(`full') residuals(resid_`y')
        qui reghdfe totaltreat_pw_norm if !missing(`y'), absorb(`full') residuals(rc_`y')
    }
    keep identificad totaltreat_pw_norm `chars_bs' resid_* rc_*
    export delimited using "$tables/descriptives/balance_binscatter_frame.csv", replace
    di "=== balance_binscatter_frame.csv exported (n=" _N ") ==="
restore

* auto-render the LaTeX table (cluster python3; on Mac run the .py directly with
* /opt/homebrew/bin/python3 -- see unionspill-local-stata-run memory)
cap shell python3 "$base/Programs/descriptives/generate_balance_table_task2_latex.py"

di "=== balance_table_task2.do done ==="
