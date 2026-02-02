********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL DATA PREPARATION (Steps 1-7 only)
* INPUT: bilateral_connectivity_2011_2016.csv, bilateral_connectivity_2007_2011.csv
* OUTPUT: bilateral_regression_data.parquet (for Python analysis)
* NOTE: This file prepares the 135M+ pair dataset without running regressions
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
* Year pairs in data: flows_1112, flows_1213, flows_1314, flows_1415, flows_1516
gen flows_post = flows_1112 + flows_1213 + flows_1314 + flows_1415

* Compute average ratio for post-treatment (4 year pairs, non-missing only)
egen bilateral_conn_pw_post = rowmean(ratio_1112 ratio_1213 ratio_1314 ratio_1415)

* Keep only relevant variables
keep identificad_i identificad_j bilateral_conn_pw_post flows_post

* Rename for clarity
rename bilateral_conn_pw_post bilateral_conn_post
rename flows_post flows_total_post

save "$rais_aux/bilateral_post_temp.dta", replace

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

* Keep only relevant variables
keep identificad_i identificad_j bilateral_conn_pw flows_total

* Rename for clarity
rename bilateral_conn_pw bilateral_conn_pre
rename flows_total flows_total_pre

save "$rais_aux/bilateral_pre_temp.dta", replace

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

save "$rais_aux/sample_estabs_bilateral.dta", replace

********************************************************************************
* STEP 4: CREATE ALL PAIRS AND MERGE BILATERAL CONNECTIVITY
********************************************************************************

di _newline(2) "=== Creating all establishment pairs ==="

* Create establishment i file
use "$rais_aux/sample_estabs_bilateral.dta", clear
rename identificad identificad_i
rename municipio municipio_i
rename microregion microregion_i
rename big_industry big_industry_i
rename industry1 industry1_i
rename mode_union mode_union_i
gen _crossjoin = 1
save "$rais_aux/estab_i_temp.dta", replace

* Create establishment j file
use "$rais_aux/sample_estabs_bilateral.dta", clear
rename identificad identificad_j
rename municipio municipio_j
rename microregion microregion_j
rename big_industry big_industry_j
rename industry1 industry1_j
rename mode_union mode_union_j
gen _crossjoin = 1
save "$rais_aux/estab_j_temp.dta", replace

* Cross-join
use "$rais_aux/estab_i_temp.dta", clear
joinby _crossjoin using "$rais_aux/estab_j_temp.dta"
drop _crossjoin
drop if identificad_i == identificad_j

* Keep only unique pairs (i < j) since direction doesn't matter
* This cuts the dataset in half
keep if identificad_i < identificad_j

di "Total unique pairs (i < j): " _N

* Merge post-treatment bilateral connectivity (both directions: i→j and j→i)
* Direction 1: i→j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_temp.dta", keep(master match)
rename bilateral_conn_post bilateral_conn_post_ij
rename flows_total_post flows_post_ij
gen has_flow_post_ij = (_merge == 3)
drop _merge

* Direction 2: j→i (swap i and j in the using data)
preserve
use "$rais_aux/bilateral_post_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_post bilateral_conn_post_ji
rename flows_total_post flows_post_ji
save "$rais_aux/bilateral_post_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_temp_rev.dta", keep(master match)
gen has_flow_post_ji = (_merge == 3)
drop _merge

* Combine both directions: sum flows, average connectivity
replace bilateral_conn_post_ij = 0 if missing(bilateral_conn_post_ij)
replace bilateral_conn_post_ji = 0 if missing(bilateral_conn_post_ji)
replace flows_post_ij = 0 if missing(flows_post_ij)
replace flows_post_ji = 0 if missing(flows_post_ji)

gen bilateral_conn_post = (bilateral_conn_post_ij + bilateral_conn_post_ji) / 2
gen flows_total_post = flows_post_ij + flows_post_ji
gen has_flow_post = (has_flow_post_ij == 1 | has_flow_post_ji == 1)
drop bilateral_conn_post_ij bilateral_conn_post_ji flows_post_ij flows_post_ji has_flow_post_ij has_flow_post_ji

* Merge pre-treatment bilateral connectivity (both directions)
* Direction 1: i→j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_temp.dta", keep(master match)
rename bilateral_conn_pre bilateral_conn_pre_ij
rename flows_total_pre flows_pre_ij
gen has_flow_pre_ij = (_merge == 3)
drop _merge

* Direction 2: j→i
preserve
use "$rais_aux/bilateral_pre_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_pre bilateral_conn_pre_ji
rename flows_total_pre flows_pre_ji
save "$rais_aux/bilateral_pre_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_temp_rev.dta", keep(master match)
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

* Save the paired data before loading firm characteristics
save "$rais_aux/bilateral_pairs_temp.dta", replace

********************************************************************************
* STEP 5: MERGE FIRM CHARACTERISTICS (2009-2011 PRE-TREATMENT AVERAGES)
********************************************************************************

di _newline(2) "=== Merging firm characteristics (pre-treatment 2009-2011) ==="

* Get firm characteristics for 2009-2011 (pre-treatment period)
foreach yr in 2009 2010 2011 {
    use "$rais_firm/rais_firm_`yr'.dta", clear
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup prop_hs prop_nhs
    gen prop_female = 1 - male_prop
    gen prop_nonwhite = 1 - white_prop
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup prop_hs prop_nhs {
        rename `var' `var'_`yr'
    }
    drop male_prop white_prop
    save "$rais_aux/firm_chars_`yr'_temp.dta", replace
}

* Merge years and compute averages
use "$rais_aux/firm_chars_2009_temp.dta", clear
merge 1:1 identificad using "$rais_aux/firm_chars_2010_temp.dta", nogen
merge 1:1 identificad using "$rais_aux/firm_chars_2011_temp.dta", nogen

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
save "$rais_aux/firm_chars_i_temp.dta", replace

use "$rais_aux/firm_chars_i_temp.dta", clear
rename identificad_i identificad_j
foreach var in l_avg_firm_emp l_avg_wage avg_prop_female avg_prop_nonwhite avg_prop_sup avg_prop_hs avg_prop_nhs {
    rename `var'_i `var'_j
}
save "$rais_aux/firm_chars_j_temp.dta", replace

* Reload the paired data and merge firm characteristics
use "$rais_aux/bilateral_pairs_temp.dta", clear
merge m:1 identificad_i using "$rais_aux/firm_chars_i_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/firm_chars_j_temp.dta", keep(master match) nogen

********************************************************************************
* STEP 6: CREATE PROXIMITY MEASURES
********************************************************************************

di _newline(2) "=== Creating proximity measures ==="

* Same dummies
gen same_muni = (municipio_i == municipio_j)
gen same_microregion = (microregion_i == microregion_j)
gen same_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j)
replace same_union = 0 if missing(same_union)  // Treat missing as "different union"
gen same_big_industry = (big_industry_i == big_industry_j)
gen same_industry = (industry1_i == industry1_j)
gen same_industry_micro = (industry1_i == industry1_j & microregion_i == microregion_j)

* Continuous proximity measures (negative absolute difference)
gen size_proximity = -abs(l_avg_firm_emp_i - l_avg_firm_emp_j)
gen wage_proximity = -abs(l_avg_wage_i - l_avg_wage_j)
gen female_proximity = -abs(avg_prop_female_i - avg_prop_female_j)
gen nonwhite_proximity = -abs(avg_prop_nonwhite_i - avg_prop_nonwhite_j)
gen educ_proximity = -abs(avg_prop_sup_i - avg_prop_sup_j)
gen hs_proximity = -abs(avg_prop_hs_i - avg_prop_hs_j)
gen nhs_proximity = -abs(avg_prop_nhs_i - avg_prop_nhs_j)

* Geographic proximity (if coordinates available)
capture confirm file "$ibge/municipality_coordinates.dta"
if _rc == 0 {
    * Convert municipio variables to numeric for merge
    destring municipio_i, gen(municipio_i_num) force
    destring municipio_j, gen(municipio_j_num) force

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i_num
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i_temp.dta", replace
    restore

    merge m:1 municipio_i_num using "$rais_aux/coords_i_temp.dta", keep(master match) nogen

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j_num
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j_temp.dta", replace
    restore

    merge m:1 municipio_j_num using "$rais_aux/coords_j_temp.dta", keep(master match) nogen

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
    * Log proximity: negative of log distance (higher = closer)
    * Add small constant to avoid log(0) for same-municipality pairs
    gen geo_proximity = -ln(geo_distance + 0.1)
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j
}
else {
    gen geo_distance = .
    gen geo_proximity = .
}

********************************************************************************
* STEP 7: STANDARDIZE VARIABLES
********************************************************************************

di _newline(2) "=== Standardizing variables ==="

foreach var in bilateral_conn_post bilateral_conn_pre geo_proximity size_proximity ///
               wage_proximity female_proximity nonwhite_proximity educ_proximity ///
               hs_proximity nhs_proximity {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
        }
    }
}

********************************************************************************
* STEP 8: SAVE DATA FOR PYTHON ANALYSIS
********************************************************************************

di _newline(2) "=== Saving regression data ==="

* Save as Stata .dta file (can be converted to parquet via Python separately)
save "$rais_aux/bilateral_regression_data.dta", replace

di "Data saved: $rais_aux/bilateral_regression_data.dta"
di "To convert to parquet, run: python Programs/07b_convert_to_parquet.py"

********************************************************************************
* STEP 9: CLEAN UP TEMP FILES
********************************************************************************

capture erase "$rais_aux/bilateral_post_temp.dta"
capture erase "$rais_aux/bilateral_post_temp_rev.dta"
capture erase "$rais_aux/bilateral_pre_temp.dta"
capture erase "$rais_aux/bilateral_pre_temp_rev.dta"
capture erase "$rais_aux/bilateral_pairs_temp.dta"
capture erase "$rais_aux/sample_estabs_bilateral.dta"
capture erase "$rais_aux/estab_i_temp.dta"
capture erase "$rais_aux/estab_j_temp.dta"
capture erase "$rais_aux/firm_chars_2009_temp.dta"
capture erase "$rais_aux/firm_chars_2010_temp.dta"
capture erase "$rais_aux/firm_chars_2011_temp.dta"
capture erase "$rais_aux/firm_chars_i_temp.dta"
capture erase "$rais_aux/firm_chars_j_temp.dta"
capture erase "$rais_aux/coords_i_temp.dta"
capture erase "$rais_aux/coords_j_temp.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "===== BILATERAL DATA PREPARATION COMPLETE ====="
di _newline "Output file:"
di "  - $rais_aux/bilateral_regression_data.parquet"
di _newline "To load in Python:"
di "  import pandas as pd"
di "  df = pd.read_parquet('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet')"
