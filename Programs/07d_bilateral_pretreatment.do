********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: PRETREATMENT BILATERAL CONNECTIVITY REGRESSION
* PURPOSE: Assess temporal persistence of bilateral connectivity within pretreatment
* INPUT: bilateral_pretreatment_regression_data.dta (from Python prep)
* OUTPUT: bilateral_pretreatment_coefficients.csv, LaTeX tables
* NOTE: DV = late-pre (2009-11), Main predictor = early-pre (2007-09)
********************************************************************************

* This script runs univariate and multivariate regressions for bilateral
* connectivity within the pretreatment period to assess temporal persistence.
*
* Early-pre connectivity: average of 2007-08, 2008-09 year pairs
* Late-pre connectivity: average of 2009-10, 2010-11 year pairs
*
* Specification matches 07b_bilateral_regression_post.do but for pretreatment.

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

* Define globals
global klc "/gpfs/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"

********************************************************************************
* STEP 1: LOAD DATA FROM PYTHON PREP
********************************************************************************

di _newline(2) "=== Loading pretreatment regression data ==="

use "$rais_aux/bilateral_pretreatment_regression_data.dta", clear

di "Loaded " _N " rows"
describe bilateral_conn_early_pre bilateral_conn_late_pre

********************************************************************************
* STEP 2: MERGE NUMB_CLAUSES FOR CLAUSES PROXIMITY
********************************************************************************

di _newline(2) "=== Merging numb_clauses ==="

* Get numb_clauses for 2009-2011
preserve
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if inlist(year, 2009, 2010, 2011)
keep identificad year numb_clauses
reshape wide numb_clauses, i(identificad) j(year)
egen avg_numb_clauses = rowmean(numb_clauses2009 numb_clauses2010 numb_clauses2011)
keep identificad avg_numb_clauses

rename identificad identificad_i
rename avg_numb_clauses numb_clauses_i
save "$rais_aux/clauses_i_pretreat_temp.dta", replace

use "$rais_aux/clauses_i_pretreat_temp.dta", clear
rename identificad_i identificad_j
rename numb_clauses_i numb_clauses_j
save "$rais_aux/clauses_j_pretreat_temp.dta", replace
restore

* Merge numb_clauses
merge m:1 identificad_i using "$rais_aux/clauses_i_pretreat_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/clauses_j_pretreat_temp.dta", keep(master match) nogen

* Create clauses proximity
gen clauses_proximity = -abs(numb_clauses_i - numb_clauses_j)

di "Observations with clauses_proximity: "
count if !missing(clauses_proximity)

********************************************************************************
* STEP 2b: MERGE CEP AND TURNOVER PROXIMITY
********************************************************************************

di _newline(2) "=== Merging CEP and turnover proximity ==="

* Merge supplementary CEP and turnover data
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_cep_turnover.dta", ///
    keep(master match) nogen

di "Observations with CEP proximity: "
count if !missing(cep_proximity)
di "Observations with turnover proximity: "
count if !missing(turnover_proximity)

********************************************************************************
* STEP 3: STANDARDIZE VARIABLES
********************************************************************************

di _newline(2) "=== Standardizing variables ==="

* Standardize connectivity measures
foreach var in bilateral_conn_early_pre bilateral_conn_late_pre {
    qui sum `var'
    if r(sd) > 0 & !missing(r(sd)) {
        gen z_`var' = (`var' - r(mean)) / r(sd)
        di "Standardized `var': mean = " r(mean) ", sd = " r(sd)
    }
}

* Standardize proximity measures (re-standardize within this sample)
* NOTE: cep_proximity and turnover_proximity already have z_ versions from supplementary data
foreach var in size_proximity wage_proximity female_proximity nonwhite_proximity ///
               educ_proximity hs_proximity nhs_proximity clauses_proximity {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
        }
    }
}
* z_cep_proximity and z_turnover_proximity already exist from supplementary merge

********************************************************************************
* STEP 4: SET UP COEFFICIENT OUTPUT
********************************************************************************

di _newline(2) "=== Setting up coefficient output ==="

* Define variable lists
* NOTE: z_cep_proximity replaces z_geo_proximity, z_turnover_proximity added
local proximity_vars "z_cep_proximity z_turnover_proximity z_size_proximity z_wage_proximity z_female_proximity z_nonwhite_proximity z_educ_proximity z_hs_proximity z_nhs_proximity"
local dummy_vars "same_muni same_microregion same_union same_industry same_industry_micro"

* Initialize postfile for coefficient storage
tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec str20 reg_type r2 using `coef_data'

********************************************************************************
* STEP 5: UNIVARIATE REGRESSIONS
********************************************************************************

di _newline(2) "=== Univariate regressions: Late-pre connectivity ==="

* Proximity measures (univariate)
foreach var of local proximity_vars {
    capture confirm variable `var'
    if _rc == 0 {
        di "  Regressing on `var'..."
        qui reghdfe z_bilateral_conn_late_pre `var', absorb(identificad_i) vce(robust)

        local coef = _b[`var']
        local se = _se[`var']
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        local r2 = e(r2)

        post `coef_hold' ("`var'") ("proximity") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("univariate") (`r2')
    }
    else {
        di "  Skipping `var' (variable not found)"
    }
}

* Clauses proximity (univariate)
capture confirm variable z_clauses_proximity
if _rc == 0 {
    di "  Regressing on z_clauses_proximity..."
    qui reghdfe z_bilateral_conn_late_pre z_clauses_proximity, absorb(identificad_i) vce(robust)

    local coef = _b[z_clauses_proximity]
    local se = _se[z_clauses_proximity]
    local ci_lower = `coef' - 1.96 * `se'
    local ci_upper = `coef' + 1.96 * `se'
    local r2 = e(r2)

    post `coef_hold' ("z_clauses_proximity") ("proximity") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("univariate") (`r2')
}

* Dummy variables (univariate)
foreach var of local dummy_vars {
    di "  Regressing on `var'..."
    qui reghdfe z_bilateral_conn_late_pre `var', absorb(identificad_i) vce(robust)

    local coef = _b[`var']
    local se = _se[`var']
    local ci_lower = `coef' - 1.96 * `se'
    local ci_upper = `coef' + 1.96 * `se'
    local r2 = e(r2)

    post `coef_hold' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("univariate") (`r2')
}

* Early-pre connectivity (univariate)
di "  Regressing on z_bilateral_conn_early_pre..."
qui reghdfe z_bilateral_conn_late_pre z_bilateral_conn_early_pre, absorb(identificad_i) vce(robust)

local coef = _b[z_bilateral_conn_early_pre]
local se = _se[z_bilateral_conn_early_pre]
local ci_lower = `coef' - 1.96 * `se'
local ci_upper = `coef' + 1.96 * `se'
local r2 = e(r2)

post `coef_hold' ("z_bilateral_conn_early_pre") ("early_connectivity") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("univariate") (`r2')

********************************************************************************
* STEP 6: MULTIVARIATE REGRESSION
********************************************************************************

di _newline(2) "=== Multivariate regression: Late-pre connectivity ==="

* Full multivariate regression with all predictors including early-pre
reghdfe z_bilateral_conn_late_pre z_bilateral_conn_early_pre ///
    z_cep_proximity z_turnover_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity z_clauses_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store reg_pretreat_multi

* Store R-squared
local r2_multi = e(r2)

* Extract and store coefficients

* Early-pre connectivity
local coef = _b[z_bilateral_conn_early_pre]
local se = _se[z_bilateral_conn_early_pre]
local ci_lower = `coef' - 1.96 * `se'
local ci_upper = `coef' + 1.96 * `se'
post `coef_hold' ("z_bilateral_conn_early_pre") ("early_connectivity") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("multivariate") (`r2_multi')

* Proximity measures
foreach var in z_cep_proximity z_turnover_proximity z_size_proximity z_wage_proximity z_female_proximity ///
               z_nonwhite_proximity z_educ_proximity z_hs_proximity z_nhs_proximity z_clauses_proximity {
    capture {
        local coef = _b[`var']
        local se = _se[`var']
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold' ("`var'") ("proximity") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("multivariate") (`r2_multi')
    }
}

* Dummy variables
foreach var of local dummy_vars {
    local coef = _b[`var']
    local se = _se[`var']
    local ci_lower = `coef' - 1.96 * `se'
    local ci_upper = `coef' + 1.96 * `se'
    post `coef_hold' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("pretreat") ("multivariate") (`r2_multi')
}

postclose `coef_hold'

********************************************************************************
* STEP 7: EXPORT COEFFICIENTS TO CSV
********************************************************************************

di _newline(2) "=== Exporting coefficients to CSV ==="

preserve
use `coef_data', clear
export delimited using "$rais_aux/bilateral_pretreatment_coefficients.csv", replace
di "Saved: $rais_aux/bilateral_pretreatment_coefficients.csv"
restore

********************************************************************************
* STEP 8: EXPORT REGRESSION TABLE
********************************************************************************

di _newline(2) "=== Exporting regression table ==="

esttab reg_pretreat_multi using "$tables/bilateral_pretreatment_regression.tex", ///
    replace booktabs label ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Pretreatment Bilateral Connectivity: Multivariate Regression") ///
    mtitles("Late-Pre (2009-2011)") ///
    coeflabels(z_bilateral_conn_early_pre "Early-Pre Bilateral Conn." ///
               z_cep_proximity "Spatial (CEP)" ///
               z_turnover_proximity "Turnover" ///
               z_size_proximity "Firm Size" ///
               z_wage_proximity "Wage" ///
               z_female_proximity "\% Female" ///
               z_nonwhite_proximity "\% Non-White" ///
               z_educ_proximity "\% Higher Ed." ///
               z_hs_proximity "\% High School" ///
               z_nhs_proximity "\% Less than HS" ///
               z_clauses_proximity "CBA Clauses" ///
               same_muni "Same Municipality" ///
               same_microregion "Same Microregion" ///
               same_union "Same Union" ///
               same_industry "Same Industry" ///
               same_industry_micro "Same Industry x Microregion") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%12.0fc %9.3f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "Late-pre connectivity: average of 2009-10, 2010-11 year pairs." ///
             "Early-pre connectivity: average of 2007-08, 2008-09 year pairs." ///
             "All continuous variables standardized.")

di "Saved: $tables/bilateral_pretreatment_regression.tex"

********************************************************************************
* STEP 9: CLEAN UP
********************************************************************************

capture erase "$rais_aux/clauses_i_pretreat_temp.dta"
capture erase "$rais_aux/clauses_j_pretreat_temp.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=== Pretreatment Bilateral Connectivity Regression Complete ==="
di _newline "Output files:"
di "  - $rais_aux/bilateral_pretreatment_coefficients.csv"
di "  - $tables/bilateral_pretreatment_regression.tex"
di _newline "Next step: Run 07d_bilateral_pretreatment_coefplot.py"
