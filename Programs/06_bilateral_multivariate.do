********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY MULTIVARIATE REGRESSION - PRE-TREATMENT
* INPUT: bilateral_pairs_descriptives.csv (from Python), CBA-RAIS firm data
* OUTPUT: Coefficient CSV for Python coefplot, LaTeX tables (continuous/dummies)
* NOTE: Pre-treatment period (2007-2011)
********************************************************************************

* This script runs the multivariate regression for pre-treatment bilateral
* connectivity with the specified regressors:
* Continuous: z_size_proximity, z_hs_proximity, z_female_proximity,
*             z_nonwhite_proximity, z_wage_proximity, z_educ_proximity,
*             z_clauses_proximity, z_geo_proximity
* Dummies: same_industry, same_union, same_microregion, same_industry_micro

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
global ibge "$main/UnionSpill/Data/IBGE"

********************************************************************************
* STEP 1: Import CSV data from Python (bilateral pairs)
********************************************************************************

di _newline(2) "=== Importing bilateral pairs data ==="

import delimited "$rais_aux/bilateral_pairs_descriptives.csv", clear stringcols(1 2)

describe
di "Observations imported: " _N

save "$rais_aux/bilateral_pairs_multi_temp.dta", replace

********************************************************************************
* STEP 2: Merge numb_clauses from CBA-RAIS firm data (2009 pretreatment)
********************************************************************************

di _newline(2) "=== Merging numb_clauses from CBA-RAIS data ==="

* Extract numb_clauses for establishment i
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad numb_clauses
duplicates drop identificad, force
rename identificad identificad_i
rename numb_clauses numb_clauses_2009_i
save "$rais_aux/numb_clauses_i_multi.dta", replace

* Extract numb_clauses for establishment j
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad numb_clauses
duplicates drop identificad, force
rename identificad identificad_j
rename numb_clauses numb_clauses_2009_j
save "$rais_aux/numb_clauses_j_multi.dta", replace

* Merge back to bilateral pairs
use "$rais_aux/bilateral_pairs_multi_temp.dta", clear

merge m:1 identificad_i using "$rais_aux/numb_clauses_i_multi.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/numb_clauses_j_multi.dta", keep(master match) nogen

count if !missing(numb_clauses_2009_i)
di "Establishments i with numb_clauses: " r(N)
count if !missing(numb_clauses_2009_j)
di "Establishments j with numb_clauses: " r(N)

save "$rais_aux/bilateral_pairs_multi_temp2.dta", replace

********************************************************************************
* STEP 3: Merge municipality codes and compute geographic proximity
********************************************************************************

di _newline(2) "=== Merging municipality codes and computing geo_proximity ==="

* Extract municipio for establishment i
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad municipio
duplicates drop identificad, force
rename identificad identificad_i
rename municipio municipio_i
capture confirm string variable municipio_i
if _rc == 0 {
    destring municipio_i, replace force
}
save "$rais_aux/municipio_i_multi.dta", replace

* Extract municipio for establishment j
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad municipio
duplicates drop identificad, force
rename identificad identificad_j
rename municipio municipio_j
capture confirm string variable municipio_j
if _rc == 0 {
    destring municipio_j, replace force
}
save "$rais_aux/municipio_j_multi.dta", replace

* Merge municipio back to bilateral pairs
use "$rais_aux/bilateral_pairs_multi_temp2.dta", clear
merge m:1 identificad_i using "$rais_aux/municipio_i_multi.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/municipio_j_multi.dta", keep(master match) nogen

* Check if municipality coordinates file exists
capture confirm file "$ibge/municipality_coordinates.dta"

if _rc == 0 {
    di "Municipality coordinates file found. Computing geographic proximity..."

    * Load coordinates and merge for i
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i_multi.dta", replace
    restore

    merge m:1 municipio_i using "$rais_aux/coords_i_multi.dta", keep(master match) nogen

    * Load coordinates and merge for j
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j_multi.dta", replace
    restore

    merge m:1 municipio_j using "$rais_aux/coords_j_multi.dta", keep(master match) nogen

    * Compute Haversine distance (in km)
    gen lat1_rad = lat_i * _pi / 180
    gen lat2_rad = lat_j * _pi / 180
    gen lon1_rad = lon_i * _pi / 180
    gen lon2_rad = lon_j * _pi / 180

    gen dlat = lat2_rad - lat1_rad
    gen dlon = lon2_rad - lon1_rad

    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    gen c = 2 * asin(sqrt(a))
    gen geo_distance = 6371 * c

    * Geographic proximity (negative log distance: higher = closer)
    gen geo_proximity = -ln(geo_distance + 0.1)
    label var geo_proximity "Geographic proximity (negative log km)"

    * Clean up temp variables
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j

    count if !missing(geo_proximity)
    di "Pairs with geo_proximity: " r(N)
    summarize geo_distance geo_proximity, detail
}
else {
    di "Municipality coordinates file not found. Skipping geographic proximity."
    gen geo_distance = .
    gen geo_proximity = .
}

********************************************************************************
* STEP 4: Create clauses_proximity measure
********************************************************************************

di _newline(2) "=== Creating clauses_proximity measure ==="

gen clauses_proximity = -abs(numb_clauses_2009_i - numb_clauses_2009_j) ///
    if !missing(numb_clauses_2009_i) & !missing(numb_clauses_2009_j)

label var clauses_proximity "CBA clauses proximity (negative |diff|)"

summarize clauses_proximity numb_clauses_2009_i numb_clauses_2009_j, detail

********************************************************************************
* STEP 5: Standardize variables for regression
********************************************************************************

di _newline(2) "=== Standardizing variables ==="

* Standardize continuous variables (only the ones we need)
foreach var in bilateral_conn_pw geo_proximity size_proximity wage_proximity ///
               female_proximity nonwhite_proximity educ_proximity ///
               hs_proximity clauses_proximity {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
            label var z_`var' "Standardized `var'"
        }
    }
}

********************************************************************************
* STEP 6: Run MULTIVARIATE regressions with establishment i fixed effects
********************************************************************************

di _newline(2) "=== Running multivariate regressions with establishment FE ==="

* Define variable lists
local continuous_vars "z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity"
local dummy_vars "same_industry same_union same_microregion same_industry_micro"

* --------------------------------------------------------------------------
* Regression 1: Standardized DV (for standardized coefficient interpretation)
* --------------------------------------------------------------------------
di _newline(2) "=== Multivariate Regression: Standardized Pre-treatment Bilateral Connectivity ==="

reghdfe z_bilateral_conn_pw ///
    z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
    z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity ///
    same_industry same_union same_microregion same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store reg_pre_multi

* Store N and R2 for tables
local N_obs = e(N)
local r2 = e(r2)

* --------------------------------------------------------------------------
* Regression 2: Raw DV (for interpretable coefficient in original units)
* --------------------------------------------------------------------------
di _newline(2) "=== Multivariate Regression: Raw Pre-treatment Bilateral Connectivity ==="

reghdfe bilateral_conn_pw ///
    z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
    z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity ///
    same_industry same_union same_microregion same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store reg_pre_multi_raw

* Store N and R2 for raw regression
local N_obs_raw = e(N)
local r2_raw = e(r2)

********************************************************************************
* STEP 7: Export coefficients to CSV for Python plotting
********************************************************************************

di _newline(2) "=== Exporting coefficients to CSV for Python ==="

* --------------------------------------------------------------------------
* Export standardized coefficients
* --------------------------------------------------------------------------
estimates restore reg_pre_multi

tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `coef_data'

* Extract coefficients from regression
matrix b = e(b)
matrix V = e(V)
local r2_pre = e(r2)

* Continuous variables
foreach var of local continuous_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold' ("`var'") ("continuous") (`coef') (`se') (`ci_lower') (`ci_upper') ("pre_multivariate") (`r2_pre')
    }
}

* Dummy variables
foreach var of local dummy_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("pre_multivariate") (`r2_pre')
    }
}

postclose `coef_hold'

* Save to CSV
preserve
use `coef_data', clear
export delimited using "$rais_aux/bilateral_multivariate_coefficients_pre.csv", replace
di "Saved: $rais_aux/bilateral_multivariate_coefficients_pre.csv"
restore

* --------------------------------------------------------------------------
* Export raw coefficients (DV in original units)
* --------------------------------------------------------------------------
estimates restore reg_pre_multi_raw

tempname coef_hold_raw
tempfile coef_data_raw
postfile `coef_hold_raw' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `coef_data_raw'

matrix b = e(b)
matrix V = e(V)
local r2_pre_raw = e(r2)

* Continuous variables
foreach var of local continuous_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold_raw' ("`var'") ("continuous") (`coef') (`se') (`ci_lower') (`ci_upper') ("pre_multivariate_raw") (`r2_pre_raw')
    }
}

* Dummy variables
foreach var of local dummy_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold_raw' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("pre_multivariate_raw") (`r2_pre_raw')
    }
}

postclose `coef_hold_raw'

preserve
use `coef_data_raw', clear
export delimited using "$rais_aux/bilateral_multivariate_coefficients_pre_raw.csv", replace
di "Saved: $rais_aux/bilateral_multivariate_coefficients_pre_raw.csv"
restore

********************************************************************************
* STEP 8: Export regression tables (separate for continuous and dummies)
********************************************************************************

di _newline(2) "=== Exporting regression tables ==="

* Table for continuous measures
esttab reg_pre_multi using "$tables/bilateral_multivariate_continuous_pre.tex", ///
    replace booktabs label ///
    keep(z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
         z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity) ///
    order(z_geo_proximity z_clauses_proximity z_educ_proximity z_wage_proximity ///
          z_nonwhite_proximity z_female_proximity z_hs_proximity z_size_proximity) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Pre-Treatment Bilateral Connectivity: Continuous Proximity Measures") ///
    mtitles("Bilateral Conn.") ///
    coeflabels(z_geo_proximity "Geographic" ///
               z_size_proximity "Firm Size" ///
               z_wage_proximity "Wage" ///
               z_female_proximity "\% Female" ///
               z_nonwhite_proximity "\% Non-White" ///
               z_educ_proximity "\% Higher Ed." ///
               z_hs_proximity "\% High School" ///
               z_clauses_proximity "CBA Clauses") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%12.0fc %9.3f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "All proximity measures standardized.")

di "Saved: $tables/bilateral_multivariate_continuous_pre.tex"

* Table for dummy variables
esttab reg_pre_multi using "$tables/bilateral_multivariate_dummies_pre.tex", ///
    replace booktabs label ///
    keep(same_industry same_union same_microregion same_industry_micro) ///
    order(same_industry_micro same_microregion same_union same_industry) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Pre-Treatment Bilateral Connectivity: Same-Category Dummies") ///
    mtitles("Bilateral Conn.") ///
    coeflabels(same_industry "Same Industry" ///
               same_union "Same Union" ///
               same_microregion "Same Microregion" ///
               same_industry_micro "Same Industry x Microregion") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%12.0fc %9.3f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "From same multivariate regression as continuous measures.")

di "Saved: $tables/bilateral_multivariate_dummies_pre.tex"

********************************************************************************
* STEP 9: Clean up temporary files
********************************************************************************

capture erase "$rais_aux/bilateral_pairs_multi_temp.dta"
capture erase "$rais_aux/bilateral_pairs_multi_temp2.dta"
capture erase "$rais_aux/numb_clauses_i_multi.dta"
capture erase "$rais_aux/numb_clauses_j_multi.dta"
capture erase "$rais_aux/municipio_i_multi.dta"
capture erase "$rais_aux/municipio_j_multi.dta"
capture erase "$rais_aux/coords_i_multi.dta"
capture erase "$rais_aux/coords_j_multi.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=== Pre-Treatment Bilateral Multivariate Regression Complete ==="
di _newline "Output files:"
di "  - $rais_aux/bilateral_multivariate_coefficients_pre.csv (standardized)"
di "  - $rais_aux/bilateral_multivariate_coefficients_pre_raw.csv (raw DV)"
di "  - $tables/bilateral_multivariate_continuous_pre.tex"
di "  - $tables/bilateral_multivariate_dummies_pre.tex"
di _newline "Run: python Programs/06_bilateral_multivariate_coefplot.py"
