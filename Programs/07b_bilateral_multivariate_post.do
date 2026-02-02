********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY MULTIVARIATE REGRESSION - POST-TREATMENT
* INPUT: bilateral_connectivity_2011_2016.csv, bilateral_connectivity_2007_2011.csv
* OUTPUT: Coefficient CSV for Python coefplot, LaTeX tables (continuous/dummies/pre_conn)
* NOTE: Post-treatment period (2011-2015), includes pre-treatment bilateral conn
********************************************************************************

* This script runs the multivariate regression for post-treatment bilateral
* connectivity with the specified regressors:
* Continuous: z_size_proximity, z_hs_proximity, z_female_proximity,
*             z_nonwhite_proximity, z_wage_proximity, z_educ_proximity,
*             z_clauses_proximity, z_geo_proximity
* Dummies: same_industry, same_union, same_microregion, same_industry_micro
* Pre-treatment: z_bilateral_conn_pre (own category)

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
* STEP 1: IMPORT POST-TREATMENT BILATERAL CONNECTIVITY
********************************************************************************

di _newline(2) "=== Importing post-treatment bilateral connectivity ==="

import delimited "$rais_aux/bilateral_connectivity_2011_2016.csv", clear stringcols(1 2)

* Clean up establishment IDs (remove leading "1" prefix)
gen str14 id_i_clean = substr(identificad_i, 2, 14)
gen str14 id_j_clean = substr(identificad_j, 2, 14)
drop identificad_i identificad_j
rename id_i_clean identificad_i
rename id_j_clean identificad_j

* Compute post-treatment flows (4 year pairs, like pre-treatment)
gen flows_post = flows_1112 + flows_1213 + flows_1314 + flows_1415

* Compute average ratio for post-treatment (4 year pairs, non-missing only)
egen bilateral_conn_pw_post = rowmean(ratio_1112 ratio_1213 ratio_1314 ratio_1415)

keep identificad_i identificad_j bilateral_conn_pw_post flows_post
rename bilateral_conn_pw_post bilateral_conn_post
rename flows_post flows_total_post

save "$rais_aux/bilateral_post_multi_temp.dta", replace

di "Post-treatment bilateral pairs: " _N

********************************************************************************
* STEP 2: IMPORT PRE-TREATMENT BILATERAL CONNECTIVITY
********************************************************************************

di _newline(2) "=== Importing pre-treatment bilateral connectivity ==="

import delimited "$rais_aux/bilateral_connectivity_2007_2011.csv", clear stringcols(1 2)

* Clean up establishment IDs
gen str14 id_i_clean = substr(identificad_i, 2, 14)
gen str14 id_j_clean = substr(identificad_j, 2, 14)
drop identificad_i identificad_j
rename id_i_clean identificad_i
rename id_j_clean identificad_j

keep identificad_i identificad_j bilateral_conn_pw flows_total
rename bilateral_conn_pw bilateral_conn_pre
rename flows_total flows_total_pre

save "$rais_aux/bilateral_pre_multi_temp.dta", replace

di "Pre-treatment bilateral pairs: " _N

********************************************************************************
* STEP 3: GET SAMPLE ESTABLISHMENTS
********************************************************************************

di _newline(2) "=== Getting sample establishments ==="

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2011
keep if lagos_sample_avg == 1 & in_balanced_panel == 1
keep identificad municipio microregion big_industry industry1 mode_union
duplicates drop identificad, force

local n_estabs = _N
di "Sample establishments: `n_estabs'"

save "$rais_aux/sample_estabs_multi.dta", replace

********************************************************************************
* STEP 4: CREATE ALL PAIRS AND MERGE BILATERAL CONNECTIVITY
********************************************************************************

di _newline(2) "=== Creating all establishment pairs ==="

* Create establishment i file
use "$rais_aux/sample_estabs_multi.dta", clear
rename identificad identificad_i
rename municipio municipio_i
rename microregion microregion_i
rename big_industry big_industry_i
rename industry1 industry1_i
rename mode_union mode_union_i
gen _crossjoin = 1
save "$rais_aux/estab_i_multi_temp.dta", replace

* Create establishment j file
use "$rais_aux/sample_estabs_multi.dta", clear
rename identificad identificad_j
rename municipio municipio_j
rename microregion microregion_j
rename big_industry big_industry_j
rename industry1 industry1_j
rename mode_union mode_union_j
gen _crossjoin = 1
save "$rais_aux/estab_j_multi_temp.dta", replace

* Cross-join
use "$rais_aux/estab_i_multi_temp.dta", clear
joinby _crossjoin using "$rais_aux/estab_j_multi_temp.dta"
drop _crossjoin
drop if identificad_i == identificad_j

* Keep only unique pairs (i < j)
keep if identificad_i < identificad_j

di "Total unique pairs (i < j): " _N

* Merge post-treatment bilateral connectivity (both directions: i->j and j->i)
* Direction 1: i->j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_multi_temp.dta", keep(master match)
rename bilateral_conn_post bilateral_conn_post_ij
rename flows_total_post flows_post_ij
gen has_flow_post_ij = (_merge == 3)
drop _merge

* Direction 2: j->i
preserve
use "$rais_aux/bilateral_post_multi_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_post bilateral_conn_post_ji
rename flows_total_post flows_post_ji
save "$rais_aux/bilateral_post_multi_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_multi_temp_rev.dta", keep(master match)
gen has_flow_post_ji = (_merge == 3)
drop _merge

* Combine both directions
replace bilateral_conn_post_ij = 0 if missing(bilateral_conn_post_ij)
replace bilateral_conn_post_ji = 0 if missing(bilateral_conn_post_ji)
replace flows_post_ij = 0 if missing(flows_post_ij)
replace flows_post_ji = 0 if missing(flows_post_ji)

gen bilateral_conn_post = (bilateral_conn_post_ij + bilateral_conn_post_ji) / 2
gen flows_total_post = flows_post_ij + flows_post_ji
gen has_flow_post = (has_flow_post_ij == 1 | has_flow_post_ji == 1)
drop bilateral_conn_post_ij bilateral_conn_post_ji flows_post_ij flows_post_ji has_flow_post_ij has_flow_post_ji

* Merge pre-treatment bilateral connectivity (both directions)
* Direction 1: i->j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_multi_temp.dta", keep(master match)
rename bilateral_conn_pre bilateral_conn_pre_ij
rename flows_total_pre flows_pre_ij
gen has_flow_pre_ij = (_merge == 3)
drop _merge

* Direction 2: j->i
preserve
use "$rais_aux/bilateral_pre_multi_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_pre bilateral_conn_pre_ji
rename flows_total_pre flows_pre_ji
save "$rais_aux/bilateral_pre_multi_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_multi_temp_rev.dta", keep(master match)
gen has_flow_pre_ji = (_merge == 3)
drop _merge

* Combine both directions
replace bilateral_conn_pre_ij = 0 if missing(bilateral_conn_pre_ij)
replace bilateral_conn_pre_ji = 0 if missing(bilateral_conn_pre_ji)
replace flows_pre_ij = 0 if missing(flows_pre_ij)
replace flows_pre_ji = 0 if missing(flows_pre_ji)

gen bilateral_conn_pre = (bilateral_conn_pre_ij + bilateral_conn_pre_ji) / 2
gen flows_total_pre = flows_pre_ij + flows_pre_ji
gen has_flow_pre = (has_flow_pre_ij == 1 | has_flow_pre_ji == 1)
drop bilateral_conn_pre_ij bilateral_conn_pre_ji flows_pre_ij flows_pre_ji has_flow_pre_ij has_flow_pre_ji

di "Unique pairs with post-treatment flows: "
count if has_flow_post == 1
di "Unique pairs with pre-treatment flows: "
count if has_flow_pre == 1

save "$rais_aux/bilateral_pairs_multi_temp.dta", replace

********************************************************************************
* STEP 5: MERGE FIRM CHARACTERISTICS (2009-2011 PRE-TREATMENT AVERAGES)
********************************************************************************

di _newline(2) "=== Merging firm characteristics (pre-treatment 2009-2011) ==="

foreach yr in 2009 2010 2011 {
    use "$rais_firm/rais_firm_`yr'.dta", clear
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup prop_hs prop_nhs
    gen prop_female = 1 - male_prop
    gen prop_nonwhite = 1 - white_prop
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup prop_hs prop_nhs {
        rename `var' `var'_`yr'
    }
    drop male_prop white_prop
    save "$rais_aux/firm_chars_`yr'_multi_temp.dta", replace
}

* Merge years and compute averages
use "$rais_aux/firm_chars_2009_multi_temp.dta", clear
merge 1:1 identificad using "$rais_aux/firm_chars_2010_multi_temp.dta", nogen
merge 1:1 identificad using "$rais_aux/firm_chars_2011_multi_temp.dta", nogen

egen avg_firm_emp = rowmean(firm_emp_2009 firm_emp_2010 firm_emp_2011)
egen avg_wage = rowmean(r_remdezr_2009 r_remdezr_2010 r_remdezr_2011)
egen avg_prop_female = rowmean(prop_female_2009 prop_female_2010 prop_female_2011)
egen avg_prop_nonwhite = rowmean(prop_nonwhite_2009 prop_nonwhite_2010 prop_nonwhite_2011)
egen avg_prop_sup = rowmean(prop_sup_2009 prop_sup_2010 prop_sup_2011)
egen avg_prop_hs = rowmean(prop_hs_2009 prop_hs_2010 prop_hs_2011)
egen avg_prop_nhs = rowmean(prop_nhs_2009 prop_nhs_2010 prop_nhs_2011)

gen l_avg_firm_emp = ln(avg_firm_emp)
gen l_avg_wage = ln(avg_wage)

keep identificad l_avg_firm_emp l_avg_wage avg_prop_female avg_prop_nonwhite avg_prop_sup avg_prop_hs avg_prop_nhs

* Save for i and j
rename identificad identificad_i
foreach var in l_avg_firm_emp l_avg_wage avg_prop_female avg_prop_nonwhite avg_prop_sup avg_prop_hs avg_prop_nhs {
    rename `var' `var'_i
}
save "$rais_aux/firm_chars_i_multi_temp.dta", replace

use "$rais_aux/firm_chars_i_multi_temp.dta", clear
rename identificad_i identificad_j
foreach var in l_avg_firm_emp l_avg_wage avg_prop_female avg_prop_nonwhite avg_prop_sup avg_prop_hs avg_prop_nhs {
    rename `var'_i `var'_j
}
save "$rais_aux/firm_chars_j_multi_temp.dta", replace

* Reload paired data and merge firm characteristics
use "$rais_aux/bilateral_pairs_multi_temp.dta", clear
merge m:1 identificad_i using "$rais_aux/firm_chars_i_multi_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/firm_chars_j_multi_temp.dta", keep(master match) nogen

********************************************************************************
* STEP 6: MERGE NUMB_CLAUSES FOR CLAUSES PROXIMITY
********************************************************************************

di _newline(2) "=== Merging numb_clauses ==="

* Get numb_clauses for 2009-2011
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if inlist(year, 2009, 2010, 2011)
keep identificad year numb_clauses
reshape wide numb_clauses, i(identificad) j(year)
egen avg_numb_clauses = rowmean(numb_clauses2009 numb_clauses2010 numb_clauses2011)
keep identificad avg_numb_clauses

rename identificad identificad_i
rename avg_numb_clauses numb_clauses_i
save "$rais_aux/clauses_i_multi_temp.dta", replace

use "$rais_aux/clauses_i_multi_temp.dta", clear
rename identificad_i identificad_j
rename numb_clauses_i numb_clauses_j
save "$rais_aux/clauses_j_multi_temp.dta", replace

* Merge back
use "$rais_aux/bilateral_pairs_multi_temp.dta", clear
merge m:1 identificad_i using "$rais_aux/firm_chars_i_multi_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/firm_chars_j_multi_temp.dta", keep(master match) nogen
merge m:1 identificad_i using "$rais_aux/clauses_i_multi_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/clauses_j_multi_temp.dta", keep(master match) nogen

********************************************************************************
* STEP 7: CREATE PROXIMITY MEASURES
********************************************************************************

di _newline(2) "=== Creating proximity measures ==="

* Same dummies (only the ones we need)
gen same_microregion = (microregion_i == microregion_j)
gen same_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j)
replace same_union = 0 if missing(same_union)
gen same_industry = (industry1_i == industry1_j)
gen same_industry_micro = (industry1_i == industry1_j & microregion_i == microregion_j)

* Continuous proximity measures (negative absolute difference)
gen size_proximity = -abs(l_avg_firm_emp_i - l_avg_firm_emp_j)
gen wage_proximity = -abs(l_avg_wage_i - l_avg_wage_j)
gen female_proximity = -abs(avg_prop_female_i - avg_prop_female_j)
gen nonwhite_proximity = -abs(avg_prop_nonwhite_i - avg_prop_nonwhite_j)
gen educ_proximity = -abs(avg_prop_sup_i - avg_prop_sup_j)
gen hs_proximity = -abs(avg_prop_hs_i - avg_prop_hs_j)
gen clauses_proximity = -abs(numb_clauses_i - numb_clauses_j)

* Geographic proximity
capture confirm file "$ibge/municipality_coordinates.dta"
if _rc == 0 {
    destring municipio_i, gen(municipio_i_num) force
    destring municipio_j, gen(municipio_j_num) force

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i_num
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i_multi_temp.dta", replace
    restore

    merge m:1 municipio_i_num using "$rais_aux/coords_i_multi_temp.dta", keep(master match) nogen

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j_num
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j_multi_temp.dta", replace
    restore

    merge m:1 municipio_j_num using "$rais_aux/coords_j_multi_temp.dta", keep(master match) nogen

    drop municipio_i_num municipio_j_num

    * Haversine distance
    gen lat1_rad = lat_i * _pi / 180
    gen lat2_rad = lat_j * _pi / 180
    gen lon1_rad = lon_i * _pi / 180
    gen lon2_rad = lon_j * _pi / 180
    gen dlat = lat2_rad - lat1_rad
    gen dlon = lon2_rad - lon1_rad
    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    gen c = 2 * asin(sqrt(a))
    gen geo_distance = 6371 * c
    gen geo_proximity = -ln(geo_distance + 0.1)
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j
}
else {
    gen geo_distance = .
    gen geo_proximity = .
}

********************************************************************************
* STEP 8: STANDARDIZE VARIABLES
********************************************************************************

di _newline(2) "=== Standardizing variables ==="

foreach var in bilateral_conn_post bilateral_conn_pre geo_proximity size_proximity ///
               wage_proximity female_proximity nonwhite_proximity educ_proximity ///
               hs_proximity clauses_proximity {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
        }
    }
}

********************************************************************************
* STEP 9: RUN MULTIVARIATE REGRESSIONS
********************************************************************************

di _newline(2) "=== Running multivariate regressions ==="

* Define variable lists
local continuous_vars "z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity"
local dummy_vars "same_industry same_union same_microregion same_industry_micro"

* --------------------------------------------------------------------------
* Regression 1: Standardized DV (for standardized coefficient interpretation)
* --------------------------------------------------------------------------
di _newline(2) "=== Multivariate Regression: Standardized Post-treatment Bilateral Connectivity ==="

reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
    z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity ///
    same_industry same_union same_microregion same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store reg_post_multi

* Store N and R2
local N_obs = e(N)
local r2 = e(r2)

* --------------------------------------------------------------------------
* Regression 2: Raw DV (for interpretable coefficient in original units)
* --------------------------------------------------------------------------
di _newline(2) "=== Multivariate Regression: Raw Post-treatment Bilateral Connectivity ==="

reghdfe bilateral_conn_post bilateral_conn_pre ///
    z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
    z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity ///
    same_industry same_union same_microregion same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store reg_post_multi_raw

* Store N and R2 for raw regression
local N_obs_raw = e(N)
local r2_raw = e(r2)

********************************************************************************
* STEP 10: EXPORT COEFFICIENTS TO CSV FOR PYTHON
********************************************************************************

di _newline(2) "=== Exporting coefficients to CSV for Python ==="

* --------------------------------------------------------------------------
* Export standardized coefficients
* --------------------------------------------------------------------------
estimates restore reg_post_multi

tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `coef_data'

matrix b = e(b)
matrix V = e(V)
local r2_post = e(r2)

* Pre-treatment bilateral connectivity (own category)
local coef = b[1, colnumb(b, "z_bilateral_conn_pre")]
local se = sqrt(V[colnumb(V, "z_bilateral_conn_pre"), colnumb(V, "z_bilateral_conn_pre")])
local ci_lower = `coef' - 1.96 * `se'
local ci_upper = `coef' + 1.96 * `se'
post `coef_hold' ("z_bilateral_conn_pre") ("pre_connectivity") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate") (`r2_post')

* Continuous variables
foreach var of local continuous_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold' ("`var'") ("continuous") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate") (`r2_post')
    }
}

* Dummy variables
foreach var of local dummy_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate") (`r2_post')
    }
}

postclose `coef_hold'

preserve
use `coef_data', clear
export delimited using "$rais_aux/bilateral_multivariate_coefficients_post.csv", replace
di "Saved: $rais_aux/bilateral_multivariate_coefficients_post.csv"
restore

* --------------------------------------------------------------------------
* Export raw coefficients (DV in original units)
* --------------------------------------------------------------------------
estimates restore reg_post_multi_raw

tempname coef_hold_raw
tempfile coef_data_raw
postfile `coef_hold_raw' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `coef_data_raw'

matrix b = e(b)
matrix V = e(V)
local r2_post_raw = e(r2)

* Pre-treatment bilateral connectivity (raw)
local coef = b[1, colnumb(b, "bilateral_conn_pre")]
local se = sqrt(V[colnumb(V, "bilateral_conn_pre"), colnumb(V, "bilateral_conn_pre")])
local ci_lower = `coef' - 1.96 * `se'
local ci_upper = `coef' + 1.96 * `se'
post `coef_hold_raw' ("bilateral_conn_pre") ("pre_connectivity") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate_raw") (`r2_post_raw')

* Continuous variables
foreach var of local continuous_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold_raw' ("`var'") ("continuous") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate_raw") (`r2_post_raw')
    }
}

* Dummy variables
foreach var of local dummy_vars {
    capture {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'
        post `coef_hold_raw' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("post_multivariate_raw") (`r2_post_raw')
    }
}

postclose `coef_hold_raw'

preserve
use `coef_data_raw', clear
export delimited using "$rais_aux/bilateral_multivariate_coefficients_post_raw.csv", replace
di "Saved: $rais_aux/bilateral_multivariate_coefficients_post_raw.csv"
restore

********************************************************************************
* STEP 11: EXPORT REGRESSION TABLES (SEPARATE FOR CONTINUOUS, DUMMIES, PRE_CONN)
********************************************************************************

di _newline(2) "=== Exporting regression tables ==="

* Table for continuous measures
esttab reg_post_multi using "$tables/bilateral_multivariate_continuous_post.tex", ///
    replace booktabs label ///
    keep(z_size_proximity z_hs_proximity z_female_proximity z_nonwhite_proximity ///
         z_wage_proximity z_educ_proximity z_clauses_proximity z_geo_proximity) ///
    order(z_geo_proximity z_clauses_proximity z_educ_proximity z_wage_proximity ///
          z_nonwhite_proximity z_female_proximity z_hs_proximity z_size_proximity) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Post-Treatment Bilateral Connectivity: Continuous Proximity Measures") ///
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
             "All proximity measures standardized." ///
             "Regression includes pre-treatment bilateral connectivity.")

di "Saved: $tables/bilateral_multivariate_continuous_post.tex"

* Table for dummy variables
esttab reg_post_multi using "$tables/bilateral_multivariate_dummies_post.tex", ///
    replace booktabs label ///
    keep(same_industry same_union same_microregion same_industry_micro) ///
    order(same_industry_micro same_microregion same_union same_industry) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Post-Treatment Bilateral Connectivity: Same-Category Dummies") ///
    mtitles("Bilateral Conn.") ///
    coeflabels(same_industry "Same Industry" ///
               same_union "Same Union" ///
               same_microregion "Same Microregion" ///
               same_industry_micro "Same Industry x Microregion") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%12.0fc %9.3f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "From same multivariate regression as continuous measures." ///
             "Regression includes pre-treatment bilateral connectivity.")

di "Saved: $tables/bilateral_multivariate_dummies_post.tex"

* Table for pre-treatment bilateral connectivity (own table)
esttab reg_post_multi using "$tables/bilateral_multivariate_pre_conn_post.tex", ///
    replace booktabs label ///
    keep(z_bilateral_conn_pre) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Post-Treatment Bilateral Connectivity: Pre-Treatment Connectivity") ///
    mtitles("Bilateral Conn.") ///
    coeflabels(z_bilateral_conn_pre "Pre-treatment Bilateral Conn.") ///
    stats(N r2, labels("Observations" "R-squared") fmt(%12.0fc %9.3f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "From same multivariate regression as proximity measures and dummies.")

di "Saved: $tables/bilateral_multivariate_pre_conn_post.tex"

********************************************************************************
* STEP 12: CLEAN UP
********************************************************************************

capture erase "$rais_aux/bilateral_post_multi_temp.dta"
capture erase "$rais_aux/bilateral_post_multi_temp_rev.dta"
capture erase "$rais_aux/bilateral_pre_multi_temp.dta"
capture erase "$rais_aux/bilateral_pre_multi_temp_rev.dta"
capture erase "$rais_aux/bilateral_pairs_multi_temp.dta"
capture erase "$rais_aux/sample_estabs_multi.dta"
capture erase "$rais_aux/estab_i_multi_temp.dta"
capture erase "$rais_aux/estab_j_multi_temp.dta"
capture erase "$rais_aux/firm_chars_2009_multi_temp.dta"
capture erase "$rais_aux/firm_chars_2010_multi_temp.dta"
capture erase "$rais_aux/firm_chars_2011_multi_temp.dta"
capture erase "$rais_aux/firm_chars_i_multi_temp.dta"
capture erase "$rais_aux/firm_chars_j_multi_temp.dta"
capture erase "$rais_aux/clauses_i_multi_temp.dta"
capture erase "$rais_aux/clauses_j_multi_temp.dta"
capture erase "$rais_aux/coords_i_multi_temp.dta"
capture erase "$rais_aux/coords_j_multi_temp.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=== Post-Treatment Bilateral Multivariate Regression Complete ==="
di _newline "Output files:"
di "  - $rais_aux/bilateral_multivariate_coefficients_post.csv (standardized)"
di "  - $rais_aux/bilateral_multivariate_coefficients_post_raw.csv (raw DV)"
di "  - $tables/bilateral_multivariate_continuous_post.tex"
di "  - $tables/bilateral_multivariate_dummies_post.tex"
di "  - $tables/bilateral_multivariate_pre_conn_post.tex"
di _newline "Run: python Programs/07b_bilateral_multivariate_coefplot_post.py"
