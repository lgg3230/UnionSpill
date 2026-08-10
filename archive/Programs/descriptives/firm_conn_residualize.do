********************************************************************************
* Program:  firm_conn_residualize.do                                   (Task 2)
* Purpose:  Control-effectiveness test for the connectivity descriptives.
*           For each pre-treatment firm characteristic, compare the RAW slope on
*           connectivity to the slope CONDITIONAL on the paper's main-spec
*           controls (FWL residualization). If the controls "work", the
*           conditional slope collapses toward zero.
* Sample:   spillover estimation sample (s_spill), 2011 cross-section, one obs/firm.
* Characteristics: the paper's controls (education shares, tenure, # clauses, age)
*           PLUS the 8 already in conn_descriptives_note (wages, emp, turnover,
*           hiring, churn, retention, %female, %non-white).
* Controls (cross-sectional analog of the main spillover spec absorb set):
*           i.industry1 i.mode_base_month i.microregion
*           ib0.lr_remdezr_w_pre4 ib0.l_firm_emp_pre4
* Output:   Tables/descriptives/firm_conn_residualize.csv
* Inputs:   lagos_sample_sep24_pct_unionexp_ext_df2.dta (firm panel),
*           corrected_turnover_sample.csv, firm_mean_age.csv (built from
*           worker_panel_lagos.parquet by Programs/ (python age aggregation)).
********************************************************************************

version 17.0
set more off

global base      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
global rais_aux  "$base/Data/RAIS_aux"
global tables    "$base/Tables"
cap mkdir "$tables/descriptives"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009
keep if lagos_sample_avg == 1

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ============================ CONNECTIVITY (normalized, as in main spec) =======
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
* firm-constant connectivity (robust to single-year missingness)
cap drop conn_firm
bys identificad: egen double conn_firm = max(totaltreat_pw_norm)

* ============================ MAIN-SPEC PRE-TREATMENT CONTROLS =================
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
drop firm_emp_pre_o
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year,2009,2011)
bys identificad: egen lr_remdezr_w_pre   = min(lr_remdezr_w_pre_o)
drop lr_remdezr_w_pre_o

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
drop l_firm_emp_pre4_o

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) if year==2009 & in_balanced_panel==1, group(4)
bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
drop lr_remdezr_w_pre4_o

* ---- per-worker pre-treatment (2007-2011) flows + quartile control ----
* totalflows_pw_pre_07_11 is BOTH a new outcome and the basis for the quartile
* control (ib0.totalflows_pw_pre_07_114) used as extra_year in the main spec.
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
gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
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

* ============================ TURNOVER / HIRING / CHURN / RETENTION ============
preserve
    import delimited "$rais_aux/corrected_turnover_sample.csv", clear
    keep identificad year turnover_u retention_u hiring_rate_u separations_u hired_u avg_emp
    capture confirm string variable identificad
    if _rc tostring identificad, replace format(%014.0f) force
    gen double churn = (separations_u + hired_u)/avg_emp if avg_emp>0 & !missing(avg_emp)
    rename turnover_u    turnover
    rename retention_u   retention
    rename hiring_rate_u hiring
    keep identificad year turnover retention hiring churn
    tempfile turn
    save `turn'
restore
merge 1:1 identificad year using `turn', keep(master match) nogen

* ============================ MEAN WORKER AGE (firm-year) =====================
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

* ============================ 2011 CROSS-SECTION =============================
replace totaltreat_pw_norm = conn_firm
keep if year == 2011

* winsorize heavy-tailed rate variables at p99 (matches conn_descriptives_note)
foreach r in turnover hiring churn retention {
    cap drop `r'_p99
    sum `r' if `s_spill', detail
    gen `r'_p99 = r(p99)
    replace `r' = `r'_p99 if `r' > `r'_p99 & !missing(`r')
    drop `r'_p99
}

* ============================ RAW vs CONDITIONAL SLOPES =======================
local chars lr_remdezr_w l_firm_emp turnover hiring churn retention ///
            prop_female prop_non_white no_hs_c hs_c sup_c avg_tenure ///
            numb_clauses mean_age totalflows_pw_pre_07_11

local controls "i.industry1 i.mode_base_month i.microregion ib0.lr_remdezr_w_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"

cap erase "$tables/descriptives/firm_conn_residualize.csv"
tempname fh
postfile `fh' str25 characteristic double(raw_b raw_se raw_p cond_b cond_se cond_p pct_reduction) ///
    long(n_raw n_cond) using "$tables/descriptives/firm_conn_residualize_tmp.dta", replace

foreach y of local chars {
    di as text "--- `y' ---"
    * RAW slope
    capture reg `y' totaltreat_pw_norm if `s_spill', vce(robust)
    if _rc continue
    local rb  = _b[totaltreat_pw_norm]
    local rse = _se[totaltreat_pw_norm]
    local rp  = 2*ttail(e(df_r), abs(`rb'/`rse'))
    local rn  = e(N)
    * CONDITIONAL slope (residualized on main-spec controls)
    capture reghdfe `y' totaltreat_pw_norm if `s_spill', absorb(`controls') vce(robust)
    if _rc {
        post `fh' ("`y'") (`rb') (`rse') (`rp') (.) (.) (.) (.) (`rn') (.)
        continue
    }
    local cb  = _b[totaltreat_pw_norm]
    local cse = _se[totaltreat_pw_norm]
    local cp  = 2*ttail(e(df_r), abs(`cb'/`cse'))
    local cn  = e(N)
    local pct = .
    if `rb' != 0 local pct = (1 - `cb'/`rb')*100
    post `fh' ("`y'") (`rb') (`rse') (`rp') (`cb') (`cse') (`cp') (`pct') (`rn') (`cn')
}
postclose `fh'

preserve
    use "$tables/descriptives/firm_conn_residualize_tmp.dta", clear
    export delimited using "$tables/descriptives/firm_conn_residualize.csv", replace
    list, sep(0) noobs
restore
erase "$tables/descriptives/firm_conn_residualize_tmp.dta"

* ============================ EXPORT FRAME + RESIDUALS (for plotting) =========
* residualize connectivity and each characteristic on the main-spec controls so
* the residualized binscatter is resid(Y|controls) vs resid(conn|controls).
cap drop resid_conn
qui reghdfe totaltreat_pw_norm if `s_spill', absorb(`controls') residuals(resid_conn)
foreach y of local chars {
    cap drop resid_`y'
    qui reghdfe `y' if `s_spill', absorb(`controls') residuals(resid_`y')
}
* ---- Cattaneo, Crump, Farrell & Feng (2024) covariate-adjusted binscatter ----
* TODO: the binsreg figure looked off -> guarded OFF. Set do_binsreg 1 to revisit.
local do_binsreg 0
if `do_binsreg' {
cap mkdir "$tables/descriptives/binsreg"
foreach y of local chars {
    di as text "binsreg (covariate-adjusted): `y'"
    cap binsreg `y' totaltreat_pw_norm `controls' if `s_spill', ///
        ci(3 3) nodraw savedata("$tables/descriptives/binsreg/bs_`y'") replace
}
}

* ============================ TREATED SET frame + residuals ===================
* Same characteristics, controls, and connectivity normalization, but on the
* TREATED firms (treat_ultra==1, balanced panel). Rates re-winsorized at the
* treated-set p99. Output: firm_conn_frame_treated.csv (plotted as *_treated).
* DEPRECATED: treated-firm connectivity graphs dropped in favor of the Task-2
* balance table (balance_table_task2). Guarded off; set `do_treated' 1 to revive.
local do_treated 0
if `do_treated' {
preserve
    local strt "treat_ultra==1 & in_balanced_panel==1 & !missing(lr_remdezr_w)"
    foreach r in turnover hiring churn retention {
        cap drop `r'_p99t
        qui sum `r' if `strt', detail
        gen `r'_p99t = r(p99)
        replace `r' = `r'_p99t if `r' > `r'_p99t & !missing(`r')
        drop `r'_p99t
    }
    cap drop resid_conn
    qui reghdfe totaltreat_pw_norm if `strt', absorb(`controls') residuals(resid_conn)
    foreach y of local chars {
        cap drop resid_`y'
        qui reghdfe `y' if `strt', absorb(`controls') residuals(resid_`y')
    }
    keep if `strt'
    keep identificad totaltreat_pw_norm resid_conn `chars' resid_*
    export delimited using "$tables/descriptives/firm_conn_frame_treated.csv", replace
    di "=== firm_conn_frame_treated.csv exported (n=" _N ") ==="
restore
}

keep if `s_spill'
keep identificad totaltreat_pw_norm resid_conn `chars' resid_*
export delimited using "$tables/descriptives/firm_conn_frame.csv", replace
di "=== firm_conn_frame.csv exported (n=" _N ") ==="

di "=== firm_conn_residualize.do done ==="
