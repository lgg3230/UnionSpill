********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY DESCRIPTIVES
* INPUT: BILATERAL CONNECTIVITY FROM MATLAB, FIRM-LEVEL RAIS DATA
* OUTPUT: BILATERAL PAIRS DATASET, BINSCATTER PLOTS
********************************************************************************

* Set timer
timer clear                                                                      // Reset all timers to zero
timer on 1                                                                       // Start timer 1 to track program execution time

********************************************************************************
* STEP 1: Import bilateral connectivity from MATLAB output
********************************************************************************

import delimited "$rais_aux/bilateral_connectivity_2007_2011.csv", clear stringcols(1 2) // Import CSV file with bilateral connectivity data; stringcols preserves establishment IDs as strings to avoid precision loss

* Convert establishment IDs from MATLAB format back to RAIS format
* The employers CSV has "1" prefix added by Stata to avoid precision loss

* Clean up string identifiers - remove the "1" prefix
gen str14 id_i_clean = substr(identificad_i, 2, 14)                              // Extract characters 2-15 from establishment i ID, removing the "1" prefix added during export
gen str14 id_j_clean = substr(identificad_j, 2, 14)                              // Extract characters 2-15 from establishment j ID, removing the "1" prefix added during export
drop identificad_i identificad_j                                                  // Drop original prefixed ID variables
rename id_i_clean identificad_i                                                   // Rename cleaned ID for establishment i back to standard name
rename id_j_clean identificad_j                                                   // Rename cleaned ID for establishment j back to standard name

* Rename for clarity
rename flows_total bilateral_conn_pw                                             // Rename total flows variable to bilateral connectivity per worker for clarity

* Keep essential variables
keep identificad_i identificad_j bilateral_conn_pw flows_total_bilateral ///
     flows_0708 flows_0809 flows_0910 flows_1011                                  // Keep only establishment IDs, connectivity measure, and year-pair flow variables

save "$rais_aux/bilateral_connectivity_raw.dta", replace                          // Save raw bilateral connectivity data as Stata dataset

********************************************************************************
* STEP 2: Merge sample flags for establishment i
********************************************************************************

* Get lagos_sample_avg and in_balanced_panel from main dataset
* These are time-invariant at the firm level

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load main firm-level dataset with CBA and RAIS merged data
keep if year == 2009                                                              // Keep only 2009 observations (sample flags are time-invariant)
keep identificad lagos_sample_avg in_balanced_panel municipio microregion         // Keep establishment ID, sample restriction flags, and geographic identifiers

* Ensure unique observations
duplicates drop identificad, force                                                // Remove duplicate establishment observations, keeping first occurrence

* Ensure municipio is numeric for merging with coordinates
capture confirm string variable municipio                                         // Check if municipio is stored as string
if _rc == 0 {                                                                     // If municipio is string (return code 0 means string confirmed)
    destring municipio, replace force                                             // Convert municipality code from string to numeric, forcing conversion even with non-numeric characters
}

* Rename for merge
rename identificad identificad_i                                                  // Rename establishment ID for merging as "sending" establishment i
rename lagos_sample_avg lagos_sample_i                                            // Rename Lagos sample flag with _i suffix for establishment i
rename in_balanced_panel balanced_panel_i                                         // Rename balanced panel flag with _i suffix for establishment i
rename municipio municipio_i                                                      // Rename municipality code with _i suffix for establishment i
rename microregion microregion_i                                                  // Rename microregion code with _i suffix for establishment i

save "$rais_aux/sample_flags_i.dta", replace                                      // Save sample flags for establishment i as temporary file

* Now merge to bilateral data
use "$rais_aux/bilateral_connectivity_raw.dta", clear                             // Load raw bilateral connectivity data
merge m:1 identificad_i using "$rais_aux/sample_flags_i.dta"                      // Many-to-one merge: multiple pairs can have same establishment i
drop if _merge == 2                                                               // Drop establishments only in sample flags (not in bilateral data)
drop _merge                                                                       // Drop merge indicator variable

********************************************************************************
* STEP 3: Merge sample flags for establishment j
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load main firm-level dataset again for establishment j
keep if year == 2009                                                              // Keep only 2009 observations
keep identificad lagos_sample_avg in_balanced_panel municipio microregion         // Keep establishment ID and sample/geographic variables

duplicates drop identificad, force                                                // Remove duplicate establishment observations

* Ensure municipio is numeric for merging with coordinates
capture confirm string variable municipio                                         // Check if municipio is stored as string
if _rc == 0 {                                                                     // If municipio is string
    destring municipio, replace force                                             // Convert to numeric
}

rename identificad identificad_j                                                  // Rename establishment ID for merging as "receiving" establishment j
rename lagos_sample_avg lagos_sample_j                                            // Rename Lagos sample flag with _j suffix for establishment j
rename in_balanced_panel balanced_panel_j                                         // Rename balanced panel flag with _j suffix for establishment j
rename municipio municipio_j                                                      // Rename municipality code with _j suffix for establishment j
rename microregion microregion_j                                                  // Rename microregion code with _j suffix for establishment j

save "$rais_aux/sample_flags_j.dta", replace                                      // Save sample flags for establishment j as temporary file

use "$rais_aux/bilateral_connectivity_raw.dta", clear                             // Load raw bilateral connectivity data again
merge m:1 identificad_i using "$rais_aux/sample_flags_i.dta", nogen keep(match master) // Merge sample flags for establishment i; keep matched and unmatched from master
merge m:1 identificad_j using "$rais_aux/sample_flags_j.dta", nogen keep(match master) // Merge sample flags for establishment j; keep matched and unmatched from master

********************************************************************************
* STEP 4: Restrict to pairs where BOTH establishments meet sample criteria
********************************************************************************

* Both must be in lagos_sample_avg and in_balanced_panel
keep if lagos_sample_i == 1 & lagos_sample_j == 1                                 // Keep only pairs where both establishments are in Lagos sample
keep if balanced_panel_i == 1 & balanced_panel_j == 1                             // Keep only pairs where both establishments are in balanced panel

* Count pairs
count                                                                             // Count number of observations (pairs) remaining
local n_pairs = r(N)                                                              // Store count in local macro
di "Number of pairs meeting sample criteria: `n_pairs'"                           // Display number of pairs meeting all sample restrictions

save "$rais_aux/bilateral_pairs_sample.dta", replace                              // Save filtered bilateral pairs dataset

********************************************************************************
* STEP 5: Merge firm characteristics for establishment i (2009-2011 averages)
********************************************************************************

* First, prepare firm characteristics from individual years
foreach yr in 2009 2010 2011 {                                                    // Loop through years 2009, 2010, and 2011
    use "$rais_firm/rais_firm_`yr'.dta", clear                                    // Load firm-level RAIS data for current year

    * Keep relevant variables (r_remdezr is mean December wages in 2015 prices)
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup             // Keep establishment ID, employment, wages, and demographic proportions

    * Generate prop_female and prop_nonwhite
    gen prop_female = 1 - male_prop                                               // Calculate proportion female as complement of male proportion
    gen prop_nonwhite = 1 - white_prop                                            // Calculate proportion non-white as complement of white proportion

    * Rename with year suffix
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup {        // Loop through firm characteristic variables
        rename `var' `var'_`yr'                                                   // Add year suffix to variable name
    }

    drop male_prop white_prop                                                     // Drop original male and white proportion variables

    save "$rais_aux/firm_chars_`yr'.dta", replace                                 // Save year-specific firm characteristics as temporary file
}

* Merge all years
use "$rais_aux/firm_chars_2009.dta", clear                                        // Load 2009 firm characteristics
merge 1:1 identificad using "$rais_aux/firm_chars_2010.dta", nogen                // Merge 2010 data by establishment ID; one-to-one merge
merge 1:1 identificad using "$rais_aux/firm_chars_2011.dta", nogen                // Merge 2011 data by establishment ID; one-to-one merge

* Compute 2009-2011 averages
egen avg_firm_emp = rowmean(firm_emp_2009 firm_emp_2010 firm_emp_2011)            // Calculate average employment across 2009-2011
egen avg_prop_female = rowmean(prop_female_2009 prop_female_2010 prop_female_2011) // Calculate average proportion female across 2009-2011
egen avg_prop_sup = rowmean(prop_sup_2009 prop_sup_2010 prop_sup_2011)            // Calculate average proportion with higher education across 2009-2011
egen avg_prop_nonwhite = rowmean(prop_nonwhite_2009 prop_nonwhite_2010 prop_nonwhite_2011) // Calculate average proportion non-white across 2009-2011

* Compute median wages across years (use rowmedian)
egen med_r_remdezr = rowmedian(r_remdezr_2009 r_remdezr_2010 r_remdezr_2011)      // Calculate median December wages across 2009-2011

* Log of average employment
gen l_avg_firm_emp = ln(avg_firm_emp)                                             // Generate log of average employment

* Log of median wages
gen l_med_r_remdezr = ln(med_r_remdezr)                                           // Generate log of median December wages

* Keep only needed variables
keep identificad avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr // Keep establishment ID and computed averages

* Prepare for merge with establishment i
rename identificad identificad_i                                                  // Rename establishment ID for merging as establishment i
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr { // Loop through average variables
    rename `var' `var'_i                                                          // Add _i suffix for establishment i
}

save "$rais_aux/firm_chars_avg_i.dta", replace                                    // Save firm characteristics for establishment i

* Prepare for merge with establishment j
use "$rais_aux/firm_chars_avg_i.dta", clear                                       // Load firm characteristics (currently suffixed with _i)
rename identificad_i identificad_j                                                // Rename establishment ID for establishment j
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite med_r_remdezr l_med_r_remdezr { // Loop through average variables
    local newvar = subinstr("`var'_i", "_i", "_j", .)                             // Create new variable name by replacing _i with _j
    rename `var' `newvar'                                                         // Rename variable with _j suffix
}

save "$rais_aux/firm_chars_avg_j.dta", replace                                    // Save firm characteristics for establishment j

********************************************************************************
* STEP 6: Merge firm characteristics to bilateral pairs
********************************************************************************

use "$rais_aux/bilateral_pairs_sample.dta", clear                                 // Load filtered bilateral pairs dataset

merge m:1 identificad_i using "$rais_aux/firm_chars_avg_i.dta", nogen keep(match master) // Merge firm characteristics for establishment i
merge m:1 identificad_j using "$rais_aux/firm_chars_avg_j.dta", nogen keep(match master) // Merge firm characteristics for establishment j

********************************************************************************
* STEP 7: Compute distance measures
********************************************************************************

* Same municipality dummy
gen same_muni = (municipio_i == municipio_j) if !missing(municipio_i) & !missing(municipio_j) // Create dummy = 1 if both establishments in same municipality

* Same microregion dummy
gen same_microregion = (microregion_i == microregion_j) if !missing(microregion_i) & !missing(microregion_j) // Create dummy = 1 if both establishments in same microregion

* Size distance (absolute difference in log employment)
gen size_distance = abs(l_avg_firm_emp_i - l_avg_firm_emp_j)                      // Calculate absolute difference in log employment between establishments

* Wage distance (absolute difference in median wages)
gen wage_distance = abs(med_r_remdezr_i - med_r_remdezr_j)                        // Calculate absolute difference in median wages between establishments

* Log of wage distance (for visualization)
gen l_wage_distance = ln(wage_distance + 1)                                       // Calculate log of wage distance plus 1 (to handle zeros)

********************************************************************************
* STEP 8: Geographic distance (Haversine) if coordinates available
********************************************************************************

* Check if municipality coordinates file exists
capture confirm file "$ibge/municipality_coordinates.dta"                         // Check if coordinates file exists; capture suppresses error if not found

if _rc == 0 {                                                                     // If file exists (return code 0)
    di "Municipality coordinates file found. Computing geographic distance..."    // Display status message

    * Load coordinates and merge for i
    preserve                                                                      // Preserve current dataset in memory
    use "$ibge/municipality_coordinates.dta", clear                               // Load municipality coordinates
    rename municipio municipio_i                                                  // Rename municipality code for establishment i
    rename latitude lat_i                                                         // Rename latitude for establishment i
    rename longitude lon_i                                                        // Rename longitude for establishment i
    save "$rais_aux/coords_i.dta", replace                                        // Save coordinates file for establishment i
    restore                                                                       // Restore bilateral pairs dataset

    merge m:1 municipio_i using "$rais_aux/coords_i.dta", nogen keep(match master) // Merge coordinates for establishment i

    * Load coordinates and merge for j
    preserve                                                                      // Preserve current dataset in memory
    use "$ibge/municipality_coordinates.dta", clear                               // Load municipality coordinates
    rename municipio municipio_j                                                  // Rename municipality code for establishment j
    rename latitude lat_j                                                         // Rename latitude for establishment j
    rename longitude lon_j                                                        // Rename longitude for establishment j
    save "$rais_aux/coords_j.dta", replace                                        // Save coordinates file for establishment j
    restore                                                                       // Restore bilateral pairs dataset

    merge m:1 municipio_j using "$rais_aux/coords_j.dta", nogen keep(match master) // Merge coordinates for establishment j

    * Compute Haversine distance (in km)
    * Formula: 2 * R * arcsin(sqrt(sin^2((lat2-lat1)/2) + cos(lat1)*cos(lat2)*sin^2((lon2-lon1)/2)))
    * R = 6371 km (Earth radius)

    gen lat1_rad = lat_i * _pi / 180                                              // Convert latitude of establishment i from degrees to radians
    gen lat2_rad = lat_j * _pi / 180                                              // Convert latitude of establishment j from degrees to radians
    gen lon1_rad = lon_i * _pi / 180                                              // Convert longitude of establishment i from degrees to radians
    gen lon2_rad = lon_j * _pi / 180                                              // Convert longitude of establishment j from degrees to radians

    gen dlat = lat2_rad - lat1_rad                                                // Calculate difference in latitude (radians)
    gen dlon = lon2_rad - lon1_rad                                                // Calculate difference in longitude (radians)

    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2         // Compute Haversine formula intermediate term a
    gen c = 2 * asin(sqrt(a))                                                     // Compute Haversine formula angular distance c
    gen geo_distance = 6371 * c                                                   // Compute geographic distance in km (Earth radius * angular distance)

    * Log of geographic distance
    gen l_geo_distance = ln(geo_distance + 1)                                     // Calculate log of geographic distance plus 1 (to handle zeros)

    * Clean up temp variables
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j // Drop intermediate calculation variables
}
else {                                                                            // If coordinates file not found
    di "Municipality coordinates file not found. Skipping geographic distance computation." // Display warning message
    di "To enable this, provide: $ibge/municipality_coordinates.dta"              // Display instructions for adding coordinates
    di "Required variables: municipio (7-digit IBGE code), latitude, longitude"   // Display required variable names
    gen geo_distance = .                                                          // Generate missing geographic distance variable
    gen l_geo_distance = .                                                        // Generate missing log geographic distance variable
}

********************************************************************************
* STEP 9: Summary statistics
********************************************************************************

di _newline(2) "=== Summary Statistics for Bilateral Connectivity ==="            // Display section header with two blank lines
summarize bilateral_conn_pw flows_total_bilateral, detail                         // Display detailed summary statistics for connectivity measures

di _newline(2) "=== Distance Measures ==="                                        // Display section header for distance measures
summarize same_muni same_microregion size_distance wage_distance, detail          // Display detailed summary statistics for distance measures

if !missing(geo_distance) {                                                       // If geographic distance was computed
    summarize geo_distance, detail                                                // Display detailed summary statistics for geographic distance
}

* Tabulate same municipality and microregion
tab same_muni, missing                                                            // Tabulate same municipality dummy, including missing values
tab same_microregion, missing                                                     // Tabulate same microregion dummy, including missing values

********************************************************************************
* STEP 10: Save final bilateral pairs dataset
********************************************************************************

order identificad_i identificad_j bilateral_conn_pw flows_total_bilateral ///
      same_muni same_microregion geo_distance ///
      avg_firm_emp_i avg_firm_emp_j med_r_remdezr_i med_r_remdezr_j ///
      size_distance wage_distance                                                 // Reorder variables: IDs first, then connectivity, geography, firm chars, distances

compress                                                                          // Reduce dataset memory footprint by optimizing storage types
save "$rais_aux/bilateral_pairs_descriptives.dta", replace                        // Save final bilateral pairs dataset with all variables

di _newline "Saved: $rais_aux/bilateral_pairs_descriptives.dta"                   // Display confirmation message with file path
di "Number of pairs: " _N                                                         // Display number of observations (pairs) in final dataset

********************************************************************************
* STEP 11: Generate binned scatterplots
********************************************************************************

* Install binscatter if needed (ssc install binscatter)
capture which binscatter                                                          // Check if binscatter command is installed
if _rc != 0 {                                                                     // If binscatter not found (return code != 0)
    di "binscatter not installed. Please run: ssc install binscatter"             // Display installation instructions
}

* Plot 1: Bilateral connectivity vs same municipality
binscatter bilateral_conn_pw same_muni, ///
    xtitle("Same Municipality") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity by Same Municipality") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel") // Create binned scatterplot of connectivity by same municipality
graph export "$graphs/binscatter_conn_same_muni.pdf", replace                     // Export graph as PDF file

* Plot 2: Bilateral connectivity vs same microregion
binscatter bilateral_conn_pw same_microregion, ///
    xtitle("Same Microregion") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity by Same Microregion") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel") // Create binned scatterplot of connectivity by same microregion
graph export "$graphs/binscatter_conn_same_microregion.pdf", replace              // Export graph as PDF file

* Plot 3: Bilateral connectivity vs geographic distance (if available)
capture confirm variable geo_distance                                             // Check if geo_distance variable exists
if _rc == 0 & !missing(geo_distance[1]) {                                         // If variable exists and has non-missing values
    binscatter bilateral_conn_pw l_geo_distance, nquantiles(20) ///
        xtitle("Log Geographic Distance (km)") ///
        ytitle("Bilateral Connectivity (per worker)") ///
        title("Bilateral Connectivity vs Geographic Distance") ///
        note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel") // Create binned scatterplot with 20 bins
    graph export "$graphs/binscatter_conn_geo_distance.pdf", replace              // Export graph as PDF file
}

* Plot 4: Bilateral connectivity vs size distance
binscatter bilateral_conn_pw size_distance, nquantiles(20) ///
    xtitle("Size Distance (|log emp_i - log emp_j|)") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity vs Size Distance") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel") // Create binned scatterplot with 20 bins
graph export "$graphs/binscatter_conn_size_distance.pdf", replace                 // Export graph as PDF file

* Plot 5: Bilateral connectivity vs wage distance
binscatter bilateral_conn_pw l_wage_distance, nquantiles(20) ///
    xtitle("Log Wage Distance (|median wage_i - median wage_j| + 1)") ///
    ytitle("Bilateral Connectivity (per worker)") ///
    title("Bilateral Connectivity vs Wage Distance") ///
    note("Sample: Pairs where both establishments in lagos_sample_avg and in_balanced_panel") // Create binned scatterplot with 20 bins
graph export "$graphs/binscatter_conn_wage_distance.pdf", replace                 // Export graph as PDF file

********************************************************************************
* STEP 12: Clean up temporary files
********************************************************************************

capture erase "$rais_aux/sample_flags_i.dta"                                      // Delete temporary sample flags file for establishment i
capture erase "$rais_aux/sample_flags_j.dta"                                      // Delete temporary sample flags file for establishment j
capture erase "$rais_aux/firm_chars_2009.dta"                                     // Delete temporary 2009 firm characteristics file
capture erase "$rais_aux/firm_chars_2010.dta"                                     // Delete temporary 2010 firm characteristics file
capture erase "$rais_aux/firm_chars_2011.dta"                                     // Delete temporary 2011 firm characteristics file
capture erase "$rais_aux/firm_chars_avg_i.dta"                                    // Delete temporary averaged firm characteristics for establishment i
capture erase "$rais_aux/firm_chars_avg_j.dta"                                    // Delete temporary averaged firm characteristics for establishment j
capture erase "$rais_aux/coords_i.dta"                                            // Delete temporary coordinates file for establishment i
capture erase "$rais_aux/coords_j.dta"                                            // Delete temporary coordinates file for establishment j
capture erase "$rais_aux/bilateral_connectivity_raw.dta"                          // Delete temporary raw bilateral connectivity file

timer off 1                                                                       // Stop timer 1
timer list                                                                        // Display elapsed time from timer 1

di _newline(2) "=== Bilateral Descriptives Complete ==="                          // Display completion message
di "Output files:"                                                                // Display header for output file list
di "  - $rais_aux/bilateral_pairs_descriptives.dta"                               // Display path to main output dataset
di "  - $graphs/binscatter_conn_same_muni.pdf"                                    // Display path to same municipality plot
di "  - $graphs/binscatter_conn_same_microregion.pdf"                             // Display path to same microregion plot
di "  - $graphs/binscatter_conn_size_distance.pdf"                                // Display path to size distance plot
di "  - $graphs/binscatter_conn_wage_distance.pdf"                                // Display path to wage distance plot
capture confirm variable geo_distance                                             // Check if geo_distance variable exists
if _rc == 0 & !missing(geo_distance[1]) {                                         // If variable exists and has non-missing values
    di "  - $graphs/binscatter_conn_geo_distance.pdf"                             // Display path to geographic distance plot
}
