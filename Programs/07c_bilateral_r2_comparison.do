********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: R² COMPARISON - POST-TREATMENT BILATERAL CONNECTIVITY
* PURPOSE: Compare R² of two models:
*          Model 1: Excludes pre-treatment bilateral connectivity
*          Model 2: Includes pre-treatment bilateral connectivity, excludes same_industry_micro
*          (both models exclude z_nhs_proximity)
* INPUT: bilateral_connectivity_2011_2016.csv, bilateral_connectivity_2007_2011.csv
* OUTPUT: R² comparison table (CSV and LaTeX)
********************************************************************************

* EQUATIONS:
*
* Model 1 (Excludes pre-treatment bilateral connectivity):
*   z_bilateral_conn_post = α + β₁·z_geo_proximity + β₂·z_size_proximity
*                           + β₃·z_wage_proximity + β₄·z_female_proximity
*                           + β₅·z_nonwhite_proximity + β₆·z_educ_proximity
*                           + β₇·z_hs_proximity + β₈·z_clauses_proximity
*                           + γ₁·same_industry + γ₂·same_union
*                           + γ₃·same_microregion + γ₄·same_industry_micro
*                           + FE_i + ε
*
* Model 2 (Includes pre-treatment bilateral conn, excludes same_industry_micro):
*   z_bilateral_conn_post = α + β₀·z_bilateral_conn_pre
*                           + β₁·z_geo_proximity + β₂·z_size_proximity
*                           + β₃·z_wage_proximity + β₄·z_female_proximity
*                           + β₅·z_nonwhite_proximity + β₆·z_educ_proximity
*                           + β₇·z_hs_proximity + β₈·z_clauses_proximity
*                           + γ₁·same_industry + γ₂·same_union
*                           + γ₃·same_microregion + FE_i + ε

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

* Compute post-treatment flows (4 year pairs)
gen flows_post = flows_1112 + flows_1213 + flows_1314 + flows_1415

* Compute average ratio for post-treatment
egen bilateral_conn_pw_post = rowmean(ratio_1112 ratio_1213 ratio_1314 ratio_1415)

keep identificad_i identificad_j bilateral_conn_pw_post flows_post
rename bilateral_conn_pw_post bilateral_conn_post
rename flows_post flows_total_post

save "$rais_aux/bilateral_post_r2_temp.dta", replace

di "Post-treatment bilateral pairs: " _N

********************************************************************************
* STEP 1b: IMPORT PRE-TREATMENT BILATERAL CONNECTIVITY
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

save "$rais_aux/bilateral_pre_r2_temp.dta", replace

di "Pre-treatment bilateral pairs: " _N

********************************************************************************
* STEP 2: GET SAMPLE ESTABLISHMENTS
********************************************************************************

di _newline(2) "=== Getting sample establishments ==="

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2011
keep if lagos_sample_avg == 1 & in_balanced_panel == 1
keep identificad municipio microregion big_industry industry1 mode_union
duplicates drop identificad, force

local n_estabs = _N
di "Sample establishments: `n_estabs'"

save "$rais_aux/sample_estabs_r2.dta", replace

********************************************************************************
* STEP 3: CREATE ALL PAIRS AND MERGE BILATERAL CONNECTIVITY
********************************************************************************

di _newline(2) "=== Creating all establishment pairs ==="

* Create establishment i file
use "$rais_aux/sample_estabs_r2.dta", clear
rename identificad identificad_i
rename municipio municipio_i
rename microregion microregion_i
rename big_industry big_industry_i
rename industry1 industry1_i
rename mode_union mode_union_i
gen _crossjoin = 1
save "$rais_aux/estab_i_r2_temp.dta", replace

* Create establishment j file
use "$rais_aux/sample_estabs_r2.dta", clear
rename identificad identificad_j
rename municipio municipio_j
rename microregion microregion_j
rename big_industry big_industry_j
rename industry1 industry1_j
rename mode_union mode_union_j
gen _crossjoin = 1
save "$rais_aux/estab_j_r2_temp.dta", replace

* Cross-join
use "$rais_aux/estab_i_r2_temp.dta", clear
joinby _crossjoin using "$rais_aux/estab_j_r2_temp.dta"
drop _crossjoin
drop if identificad_i == identificad_j

* Keep only unique pairs (i < j)
keep if identificad_i < identificad_j

di "Total unique pairs (i < j): " _N

* Merge post-treatment bilateral connectivity (both directions)
* Direction 1: i->j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_r2_temp.dta", keep(master match)
rename bilateral_conn_post bilateral_conn_post_ij
rename flows_total_post flows_post_ij
gen has_flow_post_ij = (_merge == 3)
drop _merge

* Direction 2: j->i
preserve
use "$rais_aux/bilateral_post_r2_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_post bilateral_conn_post_ji
rename flows_total_post flows_post_ji
save "$rais_aux/bilateral_post_r2_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_post_r2_temp_rev.dta", keep(master match)
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

di "Unique pairs with post-treatment flows: "
count if has_flow_post == 1

* Merge pre-treatment bilateral connectivity (both directions)
* Direction 1: i->j
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_r2_temp.dta", keep(master match)
rename bilateral_conn_pre bilateral_conn_pre_ij
rename flows_total_pre flows_pre_ij
gen has_flow_pre_ij = (_merge == 3)
drop _merge

* Direction 2: j->i
preserve
use "$rais_aux/bilateral_pre_r2_temp.dta", clear
rename identificad_i temp_id
rename identificad_j identificad_i
rename temp_id identificad_j
rename bilateral_conn_pre bilateral_conn_pre_ji
rename flows_total_pre flows_pre_ji
save "$rais_aux/bilateral_pre_r2_temp_rev.dta", replace
restore

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_pre_r2_temp_rev.dta", keep(master match)
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

di "Unique pairs with pre-treatment flows: "
count if has_flow_pre == 1

save "$rais_aux/bilateral_pairs_r2_temp.dta", replace

********************************************************************************
* STEP 4: MERGE FIRM CHARACTERISTICS (2009-2011 PRE-TREATMENT AVERAGES)
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
    save "$rais_aux/firm_chars_`yr'_r2_temp.dta", replace
}

* Merge years and compute averages
use "$rais_aux/firm_chars_2009_r2_temp.dta", clear
merge 1:1 identificad using "$rais_aux/firm_chars_2010_r2_temp.dta", nogen
merge 1:1 identificad using "$rais_aux/firm_chars_2011_r2_temp.dta", nogen

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
save "$rais_aux/firm_chars_i_r2_temp.dta", replace

use "$rais_aux/firm_chars_i_r2_temp.dta", clear
rename identificad_i identificad_j
foreach var in l_avg_firm_emp l_avg_wage avg_prop_female avg_prop_nonwhite avg_prop_sup avg_prop_hs avg_prop_nhs {
    rename `var'_i `var'_j
}
save "$rais_aux/firm_chars_j_r2_temp.dta", replace

* Reload paired data and merge firm characteristics
use "$rais_aux/bilateral_pairs_r2_temp.dta", clear
merge m:1 identificad_i using "$rais_aux/firm_chars_i_r2_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/firm_chars_j_r2_temp.dta", keep(master match) nogen

********************************************************************************
* STEP 5: MERGE NUMB_CLAUSES FOR CLAUSES PROXIMITY
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
save "$rais_aux/clauses_i_r2_temp.dta", replace

use "$rais_aux/clauses_i_r2_temp.dta", clear
rename identificad_i identificad_j
rename numb_clauses_i numb_clauses_j
save "$rais_aux/clauses_j_r2_temp.dta", replace

* Merge back
use "$rais_aux/bilateral_pairs_r2_temp.dta", clear
merge m:1 identificad_i using "$rais_aux/firm_chars_i_r2_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/firm_chars_j_r2_temp.dta", keep(master match) nogen
merge m:1 identificad_i using "$rais_aux/clauses_i_r2_temp.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/clauses_j_r2_temp.dta", keep(master match) nogen

********************************************************************************
* STEP 6: CREATE PROXIMITY MEASURES
********************************************************************************

di _newline(2) "=== Creating proximity measures ==="

* Same dummies
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
gen nhs_proximity = -abs(avg_prop_nhs_i - avg_prop_nhs_j)
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
    save "$rais_aux/coords_i_r2_temp.dta", replace
    restore

    merge m:1 municipio_i_num using "$rais_aux/coords_i_r2_temp.dta", keep(master match) nogen

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j_num
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j_r2_temp.dta", replace
    restore

    merge m:1 municipio_j_num using "$rais_aux/coords_j_r2_temp.dta", keep(master match) nogen

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
* STEP 7: STANDARDIZE VARIABLES
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
* STEP 8: RUN R² COMPARISON REGRESSIONS
********************************************************************************

di _newline(2) "=========================================================="
di "R² COMPARISON: POST-TREATMENT BILATERAL CONNECTIVITY"
di "=========================================================="

* Create file to store R² results
tempname r2_hold
tempfile r2_data
postfile `r2_hold' str80 model_description n r2 r2_within r2_overall using `r2_data'

* --------------------------------------------------------------------------
* MODEL 1: Excludes pre-treatment bilateral connectivity
*          (includes all proximity measures except z_nhs_proximity, all dummies)
* --------------------------------------------------------------------------

di _newline(2) "=== MODEL 1: Excludes pre-treatment bilateral connectivity ==="
di "Regressors: proximity measures (excl. nhs) + same_industry + same_union + same_microregion + same_industry_micro"
di "Excludes: z_bilateral_conn_pre, z_nhs_proximity"

reghdfe z_bilateral_conn_post ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_clauses_proximity ///
    same_industry same_union same_microregion same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store model1_no_pre

local n1 = e(N)
local r2_1 = e(r2)
local r2_within_1 = e(r2_within)
local r2_overall_1 = e(r2)

di _newline "Model 1 Results:"
di "  N = " %12.0fc `n1'
di "  R² = " %9.4f `r2_1'
di "  R² (within) = " %9.4f `r2_within_1'

post `r2_hold' ("Model 1: Excl. pre-treatment bilateral conn") (`n1') (`r2_1') (`r2_within_1') (`r2_overall_1')

* --------------------------------------------------------------------------
* MODEL 2: Includes pre-treatment bilateral connectivity, excludes same_industry_micro
*          (includes all proximity measures except z_nhs_proximity)
* --------------------------------------------------------------------------

di _newline(2) "=== MODEL 2: Includes pre-treatment bilateral conn, excludes same_industry_micro ==="
di "Regressors: z_bilateral_conn_pre + proximity measures (excl. nhs) + same_industry + same_union + same_microregion"
di "Excludes: same_industry_micro, z_nhs_proximity"

reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_clauses_proximity ///
    same_industry same_union same_microregion, ///
    absorb(identificad_i) vce(robust)

estimates store model2_with_pre

local n2 = e(N)
local r2_2 = e(r2)
local r2_within_2 = e(r2_within)
local r2_overall_2 = e(r2)

di _newline "Model 2 Results:"
di "  N = " %12.0fc `n2'
di "  R² = " %9.4f `r2_2'
di "  R² (within) = " %9.4f `r2_within_2'

post `r2_hold' ("Model 2: Incl. pre-treatment conn, excl. same_ind_micro") (`n2') (`r2_2') (`r2_within_2') (`r2_overall_2')

* --------------------------------------------------------------------------
* COMPUTE R² DIFFERENCE
* --------------------------------------------------------------------------

local r2_diff = `r2_2' - `r2_1'
local r2_within_diff = `r2_within_2' - `r2_within_1'

di _newline(2) "=========================================================="
di "R² COMPARISON SUMMARY"
di "=========================================================="
di _newline "Model 1 (Excl. pre-treatment bilateral conn):"
di "  - Includes: all proximity (excl. nhs) + all dummies (incl. same_industry_micro)"
di "  - Excludes: z_bilateral_conn_pre, z_nhs_proximity"
di "  R² = " %9.4f `r2_1'
di "  R² (within) = " %9.4f `r2_within_1'
di _newline "Model 2 (Incl. pre-treatment bilateral conn, excl. same_industry_micro):"
di "  - Includes: z_bilateral_conn_pre + all proximity (excl. nhs) + dummies (excl. same_industry_micro)"
di "  - Excludes: same_industry_micro, z_nhs_proximity"
di "  R² = " %9.4f `r2_2'
di "  R² (within) = " %9.4f `r2_within_2'
di _newline "Difference (Model 2 - Model 1):"
di "  Delta R² = " %9.4f `r2_diff'
di "  Delta R² (within) = " %9.4f `r2_within_diff'
di _newline "Interpretation:"
di "  - Adding pre-treatment bilateral conn (and removing same_industry_micro)"
di "    changes R² by " %6.4f `r2_diff' " (" %5.2f (`r2_diff' * 100) " percentage points)"

postclose `r2_hold'

********************************************************************************
* STEP 9: EXPORT RESULTS
********************************************************************************

di _newline(2) "=== Exporting results ==="

* Export R² comparison to CSV
preserve
use `r2_data', clear
export delimited using "$rais_aux/bilateral_r2_comparison.csv", replace
di "Saved: $rais_aux/bilateral_r2_comparison.csv"
restore

* Export regression table
esttab model1_no_pre model2_with_pre using "$tables/bilateral_r2_comparison.tex", ///
    replace booktabs label ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Post-Treatment Bilateral Connectivity: R² Comparison") ///
    mtitles("Excl. Pre-Conn" "Incl. Pre-Conn") ///
    order(z_bilateral_conn_pre z_geo_proximity z_size_proximity z_wage_proximity ///
          z_female_proximity z_nonwhite_proximity z_educ_proximity z_hs_proximity ///
          z_clauses_proximity same_industry same_union same_microregion same_industry_micro) ///
    coeflabels(z_bilateral_conn_pre "Pre-treatment Bilateral Conn." ///
               z_geo_proximity "Geographic Proximity" ///
               z_size_proximity "Size Proximity" ///
               z_wage_proximity "Wage Proximity" ///
               z_female_proximity "\% Female Proximity" ///
               z_nonwhite_proximity "\% Non-White Proximity" ///
               z_educ_proximity "\% Higher Ed. Proximity" ///
               z_hs_proximity "\% High School Proximity" ///
               z_clauses_proximity "CBA Clauses Proximity" ///
               same_industry "Same Industry" ///
               same_union "Same Union" ///
               same_microregion "Same Microregion" ///
               same_industry_micro "Same Industry x Microregion") ///
    stats(N r2 r2_within, labels("Observations" "R²" "R² (within)") fmt(%12.0fc %9.4f %9.4f)) ///
    addnotes("Robust standard errors in parentheses." ///
             "Establishment i fixed effects absorbed." ///
             "Both models exclude z\_nhs\_proximity." ///
             "Model 1 excludes pre-treatment bilateral connectivity." ///
             "Model 2 includes pre-treatment bilateral connectivity but excludes same\_industry\_micro." ///
             "All proximity measures standardized.")

di "Saved: $tables/bilateral_r2_comparison.tex"

* Also export a simple summary table
file open r2_summary using "$tables/bilateral_r2_summary.txt", write replace
file write r2_summary "R² Comparison: Post-Treatment Bilateral Connectivity" _newline
file write r2_summary "==================================================" _newline(2)
file write r2_summary "Model 1: Excludes pre-treatment bilateral connectivity" _newline
file write r2_summary "  - Includes: all proximity (excl. nhs) + all dummies (incl. same_industry_micro)" _newline
file write r2_summary "  - Excludes: z_bilateral_conn_pre, z_nhs_proximity" _newline
file write r2_summary "  - R² = " %9.4f (`r2_1') _newline
file write r2_summary "  - R² (within) = " %9.4f (`r2_within_1') _newline(2)
file write r2_summary "Model 2: Includes pre-treatment bilateral conn, excludes same_industry_micro" _newline
file write r2_summary "  - Includes: z_bilateral_conn_pre + all proximity (excl. nhs) + dummies (excl. same_ind_micro)" _newline
file write r2_summary "  - Excludes: same_industry_micro, z_nhs_proximity" _newline
file write r2_summary "  - R² = " %9.4f (`r2_2') _newline
file write r2_summary "  - R² (within) = " %9.4f (`r2_within_2') _newline(2)
file write r2_summary "Difference (Model 2 - Model 1):" _newline
file write r2_summary "  - Delta R² = " %9.4f (`r2_diff') _newline
file write r2_summary "  - Delta R² (within) = " %9.4f (`r2_within_diff') _newline(2)
file write r2_summary "Interpretation:" _newline
file write r2_summary "  Adding pre-treatment bilateral conn (and removing same_industry_micro)" _newline
file write r2_summary "  changes R² by " %6.4f (`r2_diff') " (" %5.2f (`r2_diff' * 100) " percentage points)" _newline
file close r2_summary

di "Saved: $tables/bilateral_r2_summary.txt"

********************************************************************************
* STEP 10: CLEAN UP
********************************************************************************

capture erase "$rais_aux/bilateral_post_r2_temp.dta"
capture erase "$rais_aux/bilateral_post_r2_temp_rev.dta"
capture erase "$rais_aux/bilateral_pre_r2_temp.dta"
capture erase "$rais_aux/bilateral_pre_r2_temp_rev.dta"
capture erase "$rais_aux/bilateral_pairs_r2_temp.dta"
capture erase "$rais_aux/sample_estabs_r2.dta"
capture erase "$rais_aux/estab_i_r2_temp.dta"
capture erase "$rais_aux/estab_j_r2_temp.dta"
capture erase "$rais_aux/firm_chars_2009_r2_temp.dta"
capture erase "$rais_aux/firm_chars_2010_r2_temp.dta"
capture erase "$rais_aux/firm_chars_2011_r2_temp.dta"
capture erase "$rais_aux/firm_chars_i_r2_temp.dta"
capture erase "$rais_aux/firm_chars_j_r2_temp.dta"
capture erase "$rais_aux/clauses_i_r2_temp.dta"
capture erase "$rais_aux/clauses_j_r2_temp.dta"
capture erase "$rais_aux/coords_i_r2_temp.dta"
capture erase "$rais_aux/coords_j_r2_temp.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=========================================================="
di "R² COMPARISON ANALYSIS COMPLETE"
di "=========================================================="
di _newline "Output files:"
di "  - $rais_aux/bilateral_r2_comparison.csv"
di "  - $tables/bilateral_r2_comparison.tex"
di "  - $tables/bilateral_r2_summary.txt"
di _newline "Key results:"
di "  Model 1 R² (excl. pre-conn, incl. same_ind_micro): " %9.4f `r2_1'
di "  Model 2 R² (incl. pre-conn, excl. same_ind_micro): " %9.4f `r2_2'
di "  Delta R² (Model 2 - Model 1):                      " %9.4f `r2_diff'
