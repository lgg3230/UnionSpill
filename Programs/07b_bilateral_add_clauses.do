********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: ADD CBA CLAUSES TO BILATERAL REGRESSION (SUPPLEMENTARY)
* PURPOSE: Add numb_clauses proximity to existing coefficient file
********************************************************************************

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

* Define globals
global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"

********************************************************************************
* STEP 1: CHECK IF PAIRED DATA EXISTS, OTHERWISE RECREATE
********************************************************************************

capture confirm file "$rais_aux/bilateral_pairs_temp.dta"
if _rc != 0 {
    di "Paired data not found, recreating..."

    * Get sample establishments
    use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
    keep if year == 2011
    keep if lagos_sample_avg == 1 & in_balanced_panel == 1
    keep identificad municipio microregion
    duplicates drop identificad, force

    * Create i file
    rename identificad identificad_i
    rename municipio municipio_i
    rename microregion microregion_i
    gen _crossjoin = 1
    save "$rais_aux/estab_i_temp2.dta", replace

    * Create j file
    use "$rais_aux/estab_i_temp2.dta", clear
    rename identificad_i identificad_j
    rename municipio_i municipio_j
    rename microregion_i microregion_j
    save "$rais_aux/estab_j_temp2.dta", replace

    * Cross-join (unique pairs only)
    use "$rais_aux/estab_i_temp2.dta", clear
    joinby _crossjoin using "$rais_aux/estab_j_temp2.dta"
    drop _crossjoin
    drop if identificad_i == identificad_j
    keep if identificad_i < identificad_j

    * Merge bilateral connectivity
    * Post-treatment
    import delimited "$rais_aux/bilateral_connectivity_2011_2016.csv", clear stringcols(1 2)
    gen str14 id_i_clean = substr(identificad_i, 2, 14)
    gen str14 id_j_clean = substr(identificad_j, 2, 14)
    drop identificad_i identificad_j
    rename id_i_clean identificad_i
    rename id_j_clean identificad_j
    egen bilateral_conn_post = rowmean(ratio_1112 ratio_1213 ratio_1314 ratio_1415)
    keep identificad_i identificad_j bilateral_conn_post
    save "$rais_aux/bilateral_post_temp2.dta", replace

    * Reverse direction
    rename identificad_i temp_id
    rename identificad_j identificad_i
    rename temp_id identificad_j
    rename bilateral_conn_post bilateral_conn_post_ji
    save "$rais_aux/bilateral_post_temp2_rev.dta", replace

    * Pre-treatment
    import delimited "$rais_aux/bilateral_connectivity_2007_2011.csv", clear stringcols(1 2)
    gen str14 id_i_clean = substr(identificad_i, 2, 14)
    gen str14 id_j_clean = substr(identificad_j, 2, 14)
    drop identificad_i identificad_j
    rename id_i_clean identificad_i
    rename id_j_clean identificad_j
    keep identificad_i identificad_j bilateral_conn_pw
    rename bilateral_conn_pw bilateral_conn_pre
    save "$rais_aux/bilateral_pre_temp2.dta", replace

    * Reverse direction
    rename identificad_i temp_id
    rename identificad_j identificad_i
    rename temp_id identificad_j
    rename bilateral_conn_pre bilateral_conn_pre_ji
    save "$rais_aux/bilateral_pre_temp2_rev.dta", replace

    * Rebuild pairs with connectivity
    use "$rais_aux/estab_i_temp2.dta", clear
    joinby _crossjoin using "$rais_aux/estab_j_temp2.dta"
    drop _crossjoin
    drop if identificad_i == identificad_j
    keep if identificad_i < identificad_j

    * Merge post (both directions)
    merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_temp2.dta", keep(master match)
    rename bilateral_conn_post bilateral_conn_post_ij
    drop _merge
    merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_temp2_rev.dta", keep(master match)
    drop _merge
    replace bilateral_conn_post_ij = 0 if missing(bilateral_conn_post_ij)
    replace bilateral_conn_post_ji = 0 if missing(bilateral_conn_post_ji)
    gen bilateral_conn_post = (bilateral_conn_post_ij + bilateral_conn_post_ji) / 2
    drop bilateral_conn_post_ij bilateral_conn_post_ji

    * Merge pre (both directions)
    merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_temp2.dta", keep(master match)
    rename bilateral_conn_pre bilateral_conn_pre_ij
    drop _merge
    merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_temp2_rev.dta", keep(master match)
    drop _merge
    replace bilateral_conn_pre_ij = 0 if missing(bilateral_conn_pre_ij)
    replace bilateral_conn_pre_ji = 0 if missing(bilateral_conn_pre_ji)
    gen bilateral_conn_pre = (bilateral_conn_pre_ij + bilateral_conn_pre_ji) / 2
    drop bilateral_conn_pre_ij bilateral_conn_pre_ji

    save "$rais_aux/bilateral_pairs_temp.dta", replace

    * Cleanup
    capture erase "$rais_aux/estab_i_temp2.dta"
    capture erase "$rais_aux/estab_j_temp2.dta"
    capture erase "$rais_aux/bilateral_post_temp2.dta"
    capture erase "$rais_aux/bilateral_post_temp2_rev.dta"
    capture erase "$rais_aux/bilateral_pre_temp2.dta"
    capture erase "$rais_aux/bilateral_pre_temp2_rev.dta"
}

********************************************************************************
* STEP 2: GET NUMB_CLAUSES FROM FIRM DATA
********************************************************************************

di _newline(2) "=== Getting numb_clauses from firm data ==="

* Get numb_clauses for 2009-2011
foreach yr in 2009 2010 2011 {
    use "$rais_firm/rais_firm_`yr'.dta", clear
    capture confirm variable numb_clauses
    if _rc == 0 {
        keep identificad numb_clauses
        rename numb_clauses numb_clauses_`yr'
        save "$rais_aux/clauses_`yr'_temp.dta", replace
        di "Found numb_clauses in rais_firm_`yr'.dta"
    }
    else {
        di "numb_clauses not found in rais_firm_`yr'.dta, trying cba_rais_firm..."
    }
}

* If not found, try the merged CBA-RAIS file
capture confirm file "$rais_aux/clauses_2011_temp.dta"
if _rc != 0 {
    di "Trying cba_rais_firm_2009_2016_flows_1.dta..."
    use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
    keep if inlist(year, 2009, 2010, 2011)
    keep identificad year numb_clauses
    reshape wide numb_clauses, i(identificad) j(year)
    save "$rais_aux/clauses_temp.dta", replace
}
else {
    * Merge years
    use "$rais_aux/clauses_2009_temp.dta", clear
    merge 1:1 identificad using "$rais_aux/clauses_2010_temp.dta", nogen
    merge 1:1 identificad using "$rais_aux/clauses_2011_temp.dta", nogen
    save "$rais_aux/clauses_temp.dta", replace
}

* Compute average
use "$rais_aux/clauses_temp.dta", clear
* Handle both naming conventions (with or without underscore after reshape)
capture confirm variable numb_clauses_2009
if _rc == 0 {
    egen avg_numb_clauses = rowmean(numb_clauses_2009 numb_clauses_2010 numb_clauses_2011)
}
else {
    egen avg_numb_clauses = rowmean(numb_clauses2009 numb_clauses2010 numb_clauses2011)
}
keep identificad avg_numb_clauses

* Create for i and j
rename identificad identificad_i
rename avg_numb_clauses numb_clauses_i
save "$rais_aux/clauses_i_temp.dta", replace

use "$rais_aux/clauses_i_temp.dta", clear
rename identificad_i identificad_j
rename numb_clauses_i numb_clauses_j
save "$rais_aux/clauses_j_temp.dta", replace

********************************************************************************
* STEP 3: MERGE AND COMPUTE PROXIMITY
********************************************************************************

di _newline(2) "=== Merging clauses and computing proximity ==="

use "$rais_aux/bilateral_pairs_temp.dta", clear

merge m:1 identificad_i using "$rais_aux/clauses_i_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/clauses_j_temp.dta", keep(master match) nogen

* Compute proximity (negative absolute difference)
gen clauses_proximity = -abs(numb_clauses_i - numb_clauses_j)

* Standardize bilateral connectivity and clauses proximity
qui sum bilateral_conn_post
gen z_bilateral_conn_post = (bilateral_conn_post - r(mean)) / r(sd)

qui sum bilateral_conn_pre
gen z_bilateral_conn_pre = (bilateral_conn_pre - r(mean)) / r(sd)

qui sum clauses_proximity
gen z_clauses_proximity = (clauses_proximity - r(mean)) / r(sd)

di "Observations with non-missing clauses proximity: "
count if !missing(z_clauses_proximity)

********************************************************************************
* STEP 4: RUN UNIVARIATE REGRESSIONS
********************************************************************************

di _newline(2) "=== Running univariate regressions for clauses proximity ==="

* Post-treatment
di "Regressing post-treatment on clauses proximity..."
reghdfe z_bilateral_conn_post z_clauses_proximity, absorb(identificad_i) vce(robust)

local coef_post = _b[z_clauses_proximity]
local se_post = _se[z_clauses_proximity]
local ci_lower_post = `coef_post' - 1.96 * `se_post'
local ci_upper_post = `coef_post' + 1.96 * `se_post'

* Pre-treatment
di "Regressing pre-treatment on clauses proximity..."
reghdfe z_bilateral_conn_pre z_clauses_proximity, absorb(identificad_i) vce(robust)

local coef_pre = _b[z_clauses_proximity]
local se_pre = _se[z_clauses_proximity]
local ci_lower_pre = `coef_pre' - 1.96 * `se_pre'
local ci_upper_pre = `coef_pre' + 1.96 * `se_pre'

********************************************************************************
* STEP 5: APPEND TO EXISTING COEFFICIENT FILE
********************************************************************************

di _newline(2) "=== Appending to coefficient file ==="

* Load existing coefficients
import delimited "$rais_aux/bilateral_regression_coefficients_post.csv", clear

* Count existing rows
local n_existing = _N

* Add new rows
local new_row1 = `n_existing' + 1
local new_row2 = `n_existing' + 2

set obs `new_row2'

* Post-treatment univariate
replace variable = "z_clauses_proximity" in `new_row1'
replace var_type = "proximity" in `new_row1'
replace coef = `coef_post' in `new_row1'
replace se = `se_post' in `new_row1'
replace ci_lower = `ci_lower_post' in `new_row1'
replace ci_upper = `ci_upper_post' in `new_row1'
replace spec = "post" in `new_row1'
replace reg_type = "univariate" in `new_row1'

* Pre-treatment univariate
replace variable = "z_clauses_proximity" in `new_row2'
replace var_type = "proximity" in `new_row2'
replace coef = `coef_pre' in `new_row2'
replace se = `se_pre' in `new_row2'
replace ci_lower = `ci_lower_pre' in `new_row2'
replace ci_upper = `ci_upper_pre' in `new_row2'
replace spec = "pre" in `new_row2'
replace reg_type = "univariate" in `new_row2'

* Save updated file
export delimited using "$rais_aux/bilateral_regression_coefficients_post.csv", replace

di _newline "Added clauses proximity coefficients:"
di "  Post-treatment: coef = `coef_post', se = `se_post'"
di "  Pre-treatment:  coef = `coef_pre', se = `se_pre'"

********************************************************************************
* CLEANUP
********************************************************************************

capture erase "$rais_aux/clauses_2009_temp.dta"
capture erase "$rais_aux/clauses_2010_temp.dta"
capture erase "$rais_aux/clauses_2011_temp.dta"
capture erase "$rais_aux/clauses_temp.dta"
capture erase "$rais_aux/clauses_i_temp.dta"
capture erase "$rais_aux/clauses_j_temp.dta"

timer off 1
timer list

di _newline(2) "===== CLAUSES PROXIMITY ADDED SUCCESSFULLY ====="
