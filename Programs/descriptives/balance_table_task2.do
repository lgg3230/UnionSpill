********************************************************************************
* Program:  balance_table_task2.do                                     (Task 2)
* Purpose:  6-COLUMN control-effectiveness balance table. For each pre-treatment
*           firm characteristic (2011 cross-section), report three comparisons,
*           each RAW and CONTROLLED (residualized on the paper's main-spec
*           covariates via FWL). The point is to show whether the regression
*           controls make treated vs control look CLOSER to random assignment
*           (imbalanced raw -> attenuated once controls are applied).
*
*   Col 1  Treated vs. ALL untreated controls          -- raw   (b on treat_ultra)
*   Col 2  Treated vs. ALL untreated controls          -- controlled
*   Col 3  Treated vs. ZERO-connectivity controls      -- raw
*   Col 4  Treated vs. ZERO-connectivity controls      -- controlled
*   Col 5  Within-sample slope on connectivity (spill) -- raw
*   Col 6  Within-sample slope on connectivity (spill) -- controlled
*
* CONTROLS (mirror the main spec's absorb structure: `outcome'_pre4 + l_firm_emp_pre4
* + flows quartile + industry/microregion/month FE, in EVERY outcome regression):
*   UNIVERSAL (all rows):  i.industry1 i.mode_base_month i.microregion
*                          ib0.totalflows_pw_pre_07_114  ib0.l_firm_emp_preQ4
*   OWN quartile (that row only): ib0.`row'_preQ4 -- quartile-group dummies of the
*     row characteristic's OWN 2009-2010 mean, exactly as the spec nets out each
*     outcome's own pre-treatment quartile. NOTE these are 4 GROUP DUMMIES, not the
*     lagged level, so they coarse-adjust (do not mechanically zero the coefficient).
*   Exceptions: the EMPLOYMENT row's own quartile IS the universal l_firm_emp_preQ4
*     (not added twice); the FLOWS row's own quartile IS the universal flows quartile
*     (kept -- not dropped); the CONNECTIVITY row is exposure, not an outcome, so it
*     gets the universal set ONLY (no own quartile).
* Own/employment quartiles use window `outcome_ctrl_window': "0910" (2009-2010,
*   DEFAULT -- excludes the 2011 value being tested), "full" (2009-2011), or "none"
*   (universal set only, no per-row own quartile). See balance-table-task2 memory.
*
* Sample:   lagos balanced panel, 2011 cross-section, one obs/firm.
* Output:   Tables/descriptives/balance_table_task2.csv
* Inputs:   lagos_sample_sep24_pct_unionexp_ext_df2.dta, firm_mean_age.csv,
*           totalflows_wide_2007_2011.csv.
********************************************************************************

version 17.0
set more off

* ---------------------------------------------------------------- config ------
* window for the own / employment pre-treatment quartiles:
*   "0910" (default, careful) | "full" (2009-2011) | "none" (universal set only)
global outcome_ctrl_window "0910"

global base      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
global rais_aux  "$base/Data/RAIS_aux"
global tables    "$base/Tables"
cap mkdir "$tables/descriptives"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009
keep if lagos_sample_avg == 1

* ============================ CONNECTIVITY (normalized, as in main spec) =======
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
* firm-constant connectivity (robust to single-year missingness)
bys identificad: egen double conn_firm = max(totaltreat_pw_norm)

* window for the own-quartile controls
if "$outcome_ctrl_window" == "0910"  local ocw_lo 2009
if "$outcome_ctrl_window" == "0910"  local ocw_hi 2010
if "$outcome_ctrl_window" == "full"  local ocw_lo 2009
if "$outcome_ctrl_window" == "full"  local ocw_hi 2011
if "$outcome_ctrl_window" == "none"  local ocw_lo 2009
if "$outcome_ctrl_window" == "none"  local ocw_hi 2010
di as text "own-quartile window = $outcome_ctrl_window  (`ocw_lo'-`ocw_hi')"

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

* ============================ PER-ROW OWN 2009-2010 QUARTILES ==================
* Quartile-group dummies of each characteristic's OWN pre-treatment mean, mirroring
* the spec's `outcome'_pre4. Built here (pre-2011) so the 2011 value is excluded.
* (Flows has its own 2007-2011 quartile built above; connectivity is exposure, no
* quartile.)
foreach v in lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
             mean_age avg_tenure numb_clauses {
    cap drop `v'_preo
    cap drop `v'_pre
    bys identificad: egen double `v'_preo = mean(`v') if inrange(year,`ocw_lo',`ocw_hi')
    bys identificad: egen double `v'_pre  = min(`v'_preo)
    drop `v'_preo
    cap drop `v'_preQ4_o
    cap drop `v'_preQ4
    egen `v'_preQ4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen `v'_preQ4 = min(`v'_preQ4_o)
    drop `v'_preQ4_o
    replace `v'_preQ4 = 0 if missing(`v'_preQ4)
}

* ============================ 2011 CROSS-SECTION =============================
replace totaltreat_pw_norm = conn_firm
keep if year == 2011

* ============================ CONTROL SET =====================================
* Universal controls present in EVERY main-spec regression (cross-sectional analog):
*   industry, negotiation-month, microregion FE + flows quartile + EMPLOYMENT quartile.
* Each row adds its OWN pre-treatment quartile in the estimation loop below.
local universal "i.industry1 i.mode_base_month i.microregion ib0.totalflows_pw_pre_07_114 ib0.l_firm_emp_preQ4"

* ============================ SAMPLES =========================================
local s_all   "lagos_sample_avg==1 & in_balanced_panel==1"
local s_zero  "lagos_sample_avg==1 & in_balanced_panel==1 & (treat_ultra==1 | conn_firm==0)"
* s_spill already defined above (untreated balanced-panel = spillover control set)

* ============================ CHARACTERISTIC ROWS (focused subset) ============
* cols 1-4 (treated-vs-control): connectivity IS a meaningful row.
local chars_tc  lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
                mean_age avg_tenure numb_clauses totaltreat_pw_norm totalflows_pw_pre_07_11
* cols 5-6 (slope ON connectivity): drop connectivity itself (skipped below).

* ============================ ESTIMATE ========================================
tempname fh
postfile `fh' str25 characteristic ///
    double(c1_b c1_se c1_p  c2_b c2_se c2_p  c3_b c3_se c3_p  c4_b c4_se c4_p  c5_b c5_se c5_p  c6_b c6_se c6_p) ///
    long(n_all n_zero n_spill) ///
    using "$tables/descriptives/balance_table_task2_tmp.dta", replace

* helper: run reg / reghdfe, return b se p in r()
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
    * add THIS row's own 2009-2010 quartile (mirrors the spec's own-outcome quartile).
    * Skip where the own quartile IS already universal (employment) or undefined
    * (connectivity, flows -> flows quartile is universal), and skip under "none".
    local own ""
    if "$outcome_ctrl_window" != "none" {
        capture confirm variable `y'_preQ4
        if !_rc & "`y'" != "l_firm_emp" {
            local own "ib0.`y'_preQ4"
        }
    }
    local controls_y "`universal' `own'"
    * cols 1-2: treated vs ALL controls
    _grab reg     `y' treat_ultra "`s_all'"  ""
    local c1b = r(b)
    local c1s = r(se)
    local c1p = r(p)
    local nall = r(n)
    _grab reghdfe `y' treat_ultra "`s_all'"  "`controls_y'"
    local c2b = r(b)
    local c2s = r(se)
    local c2p = r(p)
    * cols 3-4: treated vs ZERO-connectivity controls
    _grab reg     `y' treat_ultra "`s_zero'" ""
    local c3b = r(b)
    local c3s = r(se)
    local c3p = r(p)
    local nzero = r(n)
    _grab reghdfe `y' treat_ultra "`s_zero'" "`controls_y'"
    local c4b = r(b)
    local c4s = r(se)
    local c4p = r(p)
    * cols 5-6: slope ON connectivity within spillover control sample
    if "`y'" == "totaltreat_pw_norm" {
        local c5b = .
        local c5s = .
        local c5p = .
        local nspill = .
        local c6b = .
        local c6s = .
        local c6p = .
    }
    else {
        _grab reg     `y' totaltreat_pw_norm "`s_spill'" ""
        local c5b = r(b)
        local c5s = r(se)
        local c5p = r(p)
        local nspill = r(n)
        _grab reghdfe `y' totaltreat_pw_norm "`s_spill'" "`controls_y'"
        local c6b = r(b)
        local c6s = r(se)
        local c6p = r(p)
    }
    post `fh' ("`y'") (`c1b') (`c1s') (`c1p') (`c2b') (`c2s') (`c2p') ///
        (`c3b') (`c3s') (`c3p') (`c4b') (`c4s') (`c4p') ///
        (`c5b') (`c5s') (`c5p') (`c6b') (`c6s') (`c6p') ///
        (`nall') (`nzero') (`nspill')
}
postclose `fh'

preserve
    use "$tables/descriptives/balance_table_task2_tmp.dta", clear
    export delimited using "$tables/descriptives/balance_table_task2.csv", replace
    list characteristic c1_b c2_b c3_b c4_b c5_b c6_b, sep(0) noobs
restore
erase "$tables/descriptives/balance_table_task2_tmp.dta"

* ===== residual frame for the connectivity binscatters (matches cols 5-6) =====
* For each focal characteristic X, residualize BOTH X and connectivity on X's OWN
* controls_y (universal + own quartile), on the spillover sample. By FWL the OLS
* slope of resid_X on rc_X (residualized connectivity) equals the table's col-6
* coefficient; raw X vs raw connectivity gives col 5. Plotted by balance_binscatter.py.
local chars_bs lr_remdezr_w l_firm_emp hs_c sup_c prop_female prop_non_white ///
               mean_age avg_tenure numb_clauses totalflows_pw_pre_07_11
preserve
    keep if `s_spill'
    foreach y of local chars_bs {
        local own ""
        if "$outcome_ctrl_window" != "none" {
            capture confirm variable `y'_preQ4
            if !_rc & "`y'" != "l_firm_emp" local own "ib0.`y'_preQ4"
        }
        local controls_y "`universal' `own'"
        cap drop resid_`y'
        cap drop rc_`y'
        qui reghdfe `y', absorb(`controls_y') residuals(resid_`y')
        * residualize connectivity on the SAME non-missing sample as `y' so the
        * OLS slope of resid_`y' on rc_`y' equals the table's col-6 reghdfe coef (FWL)
        qui reghdfe totaltreat_pw_norm if !missing(`y'), absorb(`controls_y') residuals(rc_`y')
    }
    keep identificad totaltreat_pw_norm `chars_bs' resid_* rc_*
    export delimited using "$tables/descriptives/balance_binscatter_frame.csv", replace
    di "=== balance_binscatter_frame.csv exported (n=" _N ") ==="
restore

* auto-render the LaTeX table (cluster python3; on Mac run the .py directly with
* /opt/homebrew/bin/python3 -- see unionspill-local-stata-run memory)
cap shell python3 "$base/Programs/descriptives/generate_balance_table_task2_latex.py"

di "=== balance_table_task2.do done (window=$outcome_ctrl_window) ==="
