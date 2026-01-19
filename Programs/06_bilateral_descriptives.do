********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY DESCRIPTIVES
* INPUT: BILATERAL CONNECTIVITY FROM MATLAB, FIRM-LEVEL RAIS DATA
* OUTPUT: BILATERAL PAIRS DATASET, BINSCATTER PLOTS
********************************************************************************

* Set timer
timer clear
timer on 1

********************************************************************************
* STEP 1: Import bilateral connectivity from MATLAB output
********************************************************************************

import delimited "$rais_aux/bilateral_connectivity_2007_2011.csv", clear stringcols(1 2)

* Convert establishment IDs from MATLAB format back to RAIS format
* The employers CSV has "1" prefix added by Stata to avoid precision loss

* Clean up string identifiers - remove the "1" prefix
gen str14 id_i_clean = substr(identificad_i, 2, 14)
gen str14 id_j_clean = substr(identificad_j, 2, 14)
drop identificad_i identificad_j
rename id_i_clean identificad_i
rename id_j_clean identificad_j

* Rename for clarity
rename flows_total flows_total_bilateral

* Keep essential variables
keep identificad_i identificad_j bilateral_conn_pw flows_total_bilateral ///
     flows_0708 flows_0809 flows_0910 flows_1011

save "$rais_aux/bilateral_connectivity_raw.dta", replace

********************************************************************************
* STEP 2: Merge sample flags for establishment i
********************************************************************************

* Get lagos_sample_avg and in_balanced_panel from main dataset
* These are time-invariant at the firm level

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad lagos_sample_avg in_balanced_panel municipio microregion

* Ensure unique observations
duplicates drop identificad, force

* Ensure municipio is numeric for merging with coordinates
capture confirm string variable municipio
if _rc == 0 {
    destring municipio, replace force
}

* Rename for merge
rename identificad identificad_i
rename lagos_sample_avg lagos_sample_i
rename in_balanced_panel balanced_panel_i
rename municipio municipio_i
rename microregion microregion_i

save "$rais_aux/sample_flags_i.dta", replace

* Now merge to bilateral data
use "$rais_aux/bilateral_connectivity_raw.dta", clear
merge m:1 identificad_i using "$rais_aux/sample_flags_i.dta"
drop if _merge == 2  // drop establishments not in bilateral data
drop _merge

********************************************************************************
* STEP 3: Merge sample flags for establishment j
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad lagos_sample_avg in_balanced_panel municipio microregion

duplicates drop identificad, force

* Ensure municipio is numeric for merging with coordinates
capture confirm string variable municipio
if _rc == 0 {
    destring municipio, replace force
}

rename identificad identificad_j
rename lagos_sample_avg lagos_sample_j
rename in_balanced_panel balanced_panel_j
rename municipio municipio_j
rename microregion microregion_j

save "$rais_aux/sample_flags_j.dta", replace

use "$rais_aux/bilateral_connectivity_raw.dta", clear
merge m:1 identificad_i using "$rais_aux/sample_flags_i.dta", nogen keep(match master)
merge m:1 identificad_j using "$rais_aux/sample_flags_j.dta", nogen keep(match master)

********************************************************************************
* STEP 4: Restrict to pairs where BOTH establishments meet sample criteria
********************************************************************************

* Both must be in lagos_sample_avg and in_balanced_panel
keep if lagos_sample_i == 1 & lagos_sample_j == 1
keep if balanced_panel_i == 1 & balanced_panel_j == 1

* Count pairs
count
local n_pairs = r(N)
di "Number of pairs meeting sample criteria: `n_pairs'"

save "$rais_aux/bilateral_pairs_sample.dta", replace

********************************************************************************
* STEP 5: Merge firm characteristics for establishment i (2009-2011 averages)
********************************************************************************

* First, prepare firm characteristics from individual years
foreach yr in 2009 2010 2011 {
    use "$rais_firm/rais_firm_`yr'.dta", clear

    * Keep relevant variables (r_remdezr is mean December wages in 2015 prices)
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup

    * Generate prop_female and prop_nonwhite
    gen prop_female = 1 - male_prop
    gen prop_nonwhite = 1 - white_prop

    * Rename with year suffix
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup {
        rename `var' `var'_`yr'
    }

    drop male_prop white_prop

    save "$rais_aux/firm_chars_`yr'.dta", replace
}

* Merge all years
use "$rais_aux/firm_chars_2009.dta", clear
merge 1:1 identificad using "$rais_aux/firm_chars_2010.dta", nogen
merge 1:1 identificad using "$rais_aux/firm_chars_2011.dta", nogen

* Compute 2009-2011 averages
egen avg_firm_emp = rowmean(firm_emp_2009 firm_emp_2010 firm_emp_2011)
egen avg_prop_female = rowmean(prop_female_2009 prop_female_2010 prop_female_2011)
egen avg_prop_sup = rowmean(prop_sup_2009 prop_sup_2010 prop_sup_2011)
egen avg_prop_nonwhite = rowmean(prop_nonwhite_2009 prop_nonwhite_2010 prop_nonwhite_2011)

* Compute median wages across years (use rowmedian)
egen med_r_remdezr = rowmedian(r_remdezr_2009 r_remdezr_2010 r_remdezr_2011)

* Log of average employment
gen l_avg_firm_emp = ln(avg_firm_emp)

* Log of median wages
gen l_med_r_remdezr = ln(med_r_remdezr)

* Keep only needed variables
keep identificad avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr

* Prepare for merge with establishment i
rename identificad identificad_i
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr {
    rename `var' `var'_i
}

save "$rais_aux/firm_chars_avg_i.dta", replace

* Prepare for merge with establishment j
use "$rais_aux/firm_chars_avg_i.dta", clear
rename identificad_i identificad_j
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr {
    local newvar = subinstr("`var'_i", "_i", "_j", .)
    rename `var' `newvar'
}

save "$rais_aux/firm_chars_avg_j.dta", replace

********************************************************************************
* STEP 6: Merge firm characteristics to bilateral pairs
********************************************************************************

use "$rais_aux/bilateral_pairs_sample.dta", clear

merge m:1 identificad_i using "$rais_aux/firm_chars_avg_i.dta", nogen keep(match master)
merge m:1 identificad_j using "$rais_aux/firm_chars_avg_j.dta", nogen keep(match master)

********************************************************************************
* STEP 7: Compute distance measures
********************************************************************************

* Same municipality dummy
gen same_muni = (municipio_i == municipio_j) if !missing(municipio_i) & !missing(municipio_j)

* Same microregion dummy
gen same_microregion = (microregion_i == microregion_j) if !missing(microregion_i) & !missing(microregion_j)

* Size distance (absolute difference in log employment)
gen size_distance = abs(l_avg_firm_emp_i - l_avg_firm_emp_j)

* Wage distance (absolute difference in median wages)
gen wage_distance = abs(med_r_remdezr_i - med_r_remdezr_j)

* Log of wage distance (for visualization)
gen l_wage_distance = ln(wage_distance + 1)

********************************************************************************
* STEP 8: Geographic distance (Haversine) if coordinates available
********************************************************************************

* Check if municipality coordinates file exists
capture confirm file "$ibge/municipality_coordinates.dta"

if _rc == 0 {
    di "Municipality coordinates file found. Computing geographic distance..."

    * Load coordinates and merge for i
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i.dta", replace
    restore

    merge m:1 municipio_i using "$rais_aux/coords_i.dta", nogen keep(match master)

    * Load coordinates and merge for j
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j.dta", replace
    restore

    merge m:1 municipio_j using "$rais_aux/coords_j.dta", nogen keep(match master)

    * Compute Haversine distance (in km)
    * Formula: 2 * R * arcsin(sqrt(sin^2((lat2-lat1)/2) + cos(lat1)*cos(lat2)*sin^2((lon2-lon1)/2)))
    * R = 6371 km (Earth radius)

    gen lat1_rad = lat_i * _pi / 180
    gen lat2_rad = lat_j * _pi / 180
    gen lon1_rad = lon_i * _pi / 180
    gen lon2_rad = lon_j * _pi / 180

    gen dlat = lat2_rad - lat1_rad
    gen dlon = lon2_rad - lon1_rad

    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    gen c = 2 * asin(sqrt(a))
    gen geo_distance = 6371 * c

    * Log of geographic distance
    gen l_geo_distance = ln(geo_distance + 1)

    * Clean up temp variables
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j
}
else {
    di "Municipality coordinates file not found. Skipping geographic distance computation."
    di "To enable this, provide: $ibge/municipality_coordinates.dta"
    di "Required variables: municipio (7-digit IBGE code), latitude, longitude"
    gen geo_distance = .
    gen l_geo_distance = .
}

********************************************************************************
* STEP 9: Summary statistics
********************************************************************************

di _newline(2) "=== Summary Statistics for Bilateral Connectivity ==="
summarize bilateral_conn_pw flows_total_bilateral, detail

di _newline(2) "=== Distance Measures ==="
summarize same_muni same_microregion size_distance wage_distance, detail

if !missing(geo_distance) {
    summarize geo_distance, detail
}

* Tabulate same municipality and microregion
tab same_muni, missing
tab same_microregion, missing

********************************************************************************
* STEP 10: Save final bilateral pairs dataset
********************************************************************************

order identificad_i identificad_j bilateral_conn_pw flows_total_bilateral ///
      same_muni same_microregion geo_distance ///
      avg_firm_emp_i avg_firm_emp_j med_r_remdezr_i med_r_remdezr_j ///
      size_distance wage_distance

compress
save "$rais_aux/bilateral_pairs_descriptives.dta", replace

di _newline "Saved: $rais_aux/bilateral_pairs_descriptives.dta"
di "Number of pairs: " _N

********************************************************************************
* STEP 11: Generate binned scatterplots
********************************************************************************

* Install binscatter if needed (ssc install binscatter)
capture which binscatter
if _rc != 0 {
    di "binscatter not installed. Please run: ssc install binscatter"
}

* Plot 1: Bilateral connectivity vs same municipality
binscatter bilateral_conn_pw same_muni, ///
    xtitle("Same Municipality") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity by Same Municipality") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel")
graph export "$graphs/binscatter_conn_same_muni.png", replace width(1200)

* Plot 2: Bilateral connectivity vs same microregion
binscatter bilateral_conn_pw same_microregion, ///
    xtitle("Same Microregion") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity by Same Microregion") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel")
graph export "$graphs/binscatter_conn_same_microregion.png", replace width(1200)

* Plot 3: Bilateral connectivity vs geographic distance (if available)
capture confirm variable geo_distance
if _rc == 0 & !missing(geo_distance[1]) {
    binscatter bilateral_conn_pw l_geo_distance, nquantiles(20) ///
        xtitle("Log Geographic Distance (km)") ///
        ytitle("Bilateral Connectivity (per worker)") ///
        title("Bilateral Connectivity vs Geographic Distance") ///
        note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel")
    graph export "$graphs/binscatter_conn_geo_distance.png", replace width(1200)
}

* Plot 4: Bilateral connectivity vs size distance
binscatter bilateral_conn_pw size_distance, nquantiles(20) ///
    xtitle("Size Distance (|log emp_i - log emp_j|)") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity vs Size Distance") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel")
graph export "$graphs/binscatter_conn_size_distance.png", replace width(1200)

* Plot 5: Bilateral connectivity vs wage distance
binscatter bilateral_conn_pw l_wage_distance, nquantiles(20) ///
    xtitle("Log Wage Distance (|median wage_i - median wage_j| + 1)") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity vs Wage Distance") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel")
graph export "$graphs/binscatter_conn_wage_distance.png", replace width(1200)

********************************************************************************
* STEP 12: Clean up temporary files
********************************************************************************

capture erase "$rais_aux/sample_flags_i.dta"
capture erase "$rais_aux/sample_flags_j.dta"
capture erase "$rais_aux/firm_chars_2009.dta"
capture erase "$rais_aux/firm_chars_2010.dta"
capture erase "$rais_aux/firm_chars_2011.dta"
capture erase "$rais_aux/firm_chars_avg_i.dta"
capture erase "$rais_aux/firm_chars_avg_j.dta"
capture erase "$rais_aux/coords_i.dta"
capture erase "$rais_aux/coords_j.dta"
capture erase "$rais_aux/bilateral_connectivity_raw.dta"

timer off 1
timer list

di _newline(2) "=== Bilateral Descriptives Complete ==="
di "Output files:"
di "  - $rais_aux/bilateral_pairs_descriptives.dta"
di "  - $graphs/binscatter_conn_same_muni.png"
di "  - $graphs/binscatter_conn_same_microregion.png"
di "  - $graphs/binscatter_conn_size_distance.png"
di "  - $graphs/binscatter_conn_wage_distance.png"
capture confirm variable geo_distance
if _rc == 0 & !missing(geo_distance[1]) {
    di "  - $graphs/binscatter_conn_geo_distance.png"
}
