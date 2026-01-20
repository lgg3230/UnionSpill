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

* Note: bilateral_conn_pw already exists from MATLAB output (average connectivity per worker)
* flows_total contains total bilateral flows across all year pairs

* Keep essential variables
keep identificad_i identificad_j bilateral_conn_pw flows_total ///
     flows_0708 flows_0809 flows_0910 flows_1011                                  // Keep only establishment IDs, connectivity measure, and year-pair flow variables

save "$rais_aux/bilateral_connectivity_raw.dta", replace                          // Save raw bilateral connectivity data as Stata dataset

********************************************************************************
* STEP 2: Merge sample flags for establishment i
********************************************************************************

* Get lagos_sample_avg and in_balanced_panel from main dataset
* These are time-invariant at the firm level

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load main firm-level dataset with CBA and RAIS merged data
keep if year == 2009                                                              // Keep only 2009 observations (sample flags are time-invariant)
keep identificad lagos_sample_avg in_balanced_panel municipio microregion ///
     big_industry mode_union                                                      // Keep establishment ID, sample flags, geographic IDs, industry, and union

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
rename big_industry big_industry_i                                                // Rename industry code with _i suffix for establishment i
rename mode_union mode_union_i                                                    // Rename modal union with _i suffix for establishment i

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
keep identificad lagos_sample_avg in_balanced_panel municipio microregion ///
     big_industry mode_union                                                      // Keep establishment ID, sample flags, geographic IDs, industry, and union

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
rename big_industry big_industry_j                                                // Rename industry code with _j suffix for establishment j
rename mode_union mode_union_j                                                    // Rename modal union with _j suffix for establishment j

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
    rename `var'_i `var'_j                                                        // Rename variable from _i suffix to _j suffix
}

save "$rais_aux/firm_chars_avg_j.dta", replace                                    // Save firm characteristics for establishment j

********************************************************************************
* STEP 6: Merge firm characteristics to bilateral pairs
********************************************************************************

use "$rais_aux/bilateral_pairs_sample.dta", clear                                 // Load filtered bilateral pairs dataset

merge m:1 identificad_i using "$rais_aux/firm_chars_avg_i.dta", nogen keep(match master) // Merge firm characteristics for establishment i
merge m:1 identificad_j using "$rais_aux/firm_chars_avg_j.dta", nogen keep(match master) // Merge firm characteristics for establishment j

********************************************************************************
* STEP 7: Compute distance measures and industry categories
********************************************************************************

* Create broad_industry from big_industry for establishment i (18 categories)
gen broad_industry_i = .                                                          // Initialize broad industry variable for establishment i
label define broad_ind_lbl ///
    1 "Farming/fishing" ///
    2 "Extractive ind." ///
    3 "Manufacturing" ///
    4 "Utilities" ///
    5 "Construction" ///
    6 "Trade/commerce" ///
    7 "Transportation" ///
    8 "Hospitality" ///
    9 "Communication" ///
    10 "Banking/finance" ///
    11 "Real estate" ///
    12 "Professional act." ///
    13 "Administrative act." ///
    14 "Public admin." ///
    15 "Education" ///
    16 "Health" ///
    17 "Culture/sports" ///
    18 "Other"                                                                    // Define value labels for 18 broad industry categories
label values broad_industry_i broad_ind_lbl                                       // Apply labels to broad_industry_i

* Industry category assignments based on CNAE 2.0 classification
replace broad_industry_i = 1 if inlist(big_industry_i, 1, 2, 3)                   // Farming/fishing: Agriculture, livestock, forestry
replace broad_industry_i = 2 if inrange(big_industry_i, 5, 9)                     // Extractive industries: Mining, oil/gas
replace broad_industry_i = 3 if inrange(big_industry_i, 10, 33)                   // Manufacturing: All manufacturing sectors
replace broad_industry_i = 4 if inrange(big_industry_i, 35, 39)                   // Utilities: Electricity, gas, water, sewage
replace broad_industry_i = 5 if inrange(big_industry_i, 41, 43)                   // Construction: Building, civil engineering
replace broad_industry_i = 6 if inrange(big_industry_i, 45, 47)                   // Trade/commerce: Wholesale and retail
replace broad_industry_i = 7 if inrange(big_industry_i, 49, 53)                   // Transportation: Land, water, air, postal
replace broad_industry_i = 8 if inrange(big_industry_i, 55, 56)                   // Hospitality: Accommodation, food services
replace broad_industry_i = 9 if inrange(big_industry_i, 58, 63)                   // Communication: Publishing, telecom, IT
replace broad_industry_i = 10 if inrange(big_industry_i, 64, 66)                  // Banking/finance: Financial services, insurance
replace broad_industry_i = 11 if big_industry_i == 68                             // Real estate: Real estate activities
replace broad_industry_i = 12 if (inrange(big_industry_i, 69, 75) | inrange(big_industry_i, 77, 79)) // Professional activities: Legal, accounting, consulting, travel
replace broad_industry_i = 13 if inrange(big_industry_i, 80, 82)                  // Administrative activities: Security, temp agencies, office support
replace broad_industry_i = 14 if big_industry_i == 84                             // Public administration: Government
replace broad_industry_i = 15 if big_industry_i == 85                             // Education: Schools, universities
replace broad_industry_i = 16 if inrange(big_industry_i, 86, 88)                  // Health: Hospitals, clinics, social services
replace broad_industry_i = 17 if inrange(big_industry_i, 90, 91)                  // Culture/sports: Arts, entertainment
replace broad_industry_i = 18 if inrange(big_industry_i, 92, 99)                  // Other: Gambling, personal services, domestic workers

* Same municipality dummy
gen same_muni = (municipio_i == municipio_j) if !missing(municipio_i) & !missing(municipio_j) // Create dummy = 1 if both establishments in same municipality

* Same microregion dummy
gen same_microregion = (microregion_i == microregion_j) if !missing(microregion_i) & !missing(microregion_j) // Create dummy = 1 if both establishments in same microregion

* Same modal union dummy
gen same_mode_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j) // Create dummy = 1 if both establishments have same modal union

* Size distance (absolute difference in log employment)
gen size_distance = abs(l_avg_firm_emp_i - l_avg_firm_emp_j)                      // Calculate absolute difference in log employment between establishments

* Size distance in levels (absolute difference in employment, not logged)
gen size_distance_levels = abs(avg_firm_emp_i - avg_firm_emp_j)                   // Calculate absolute difference in employment levels between establishments

* Wage distance (absolute difference in median wages)
gen wage_distance = abs(med_r_remdezr_i - med_r_remdezr_j)                        // Calculate absolute difference in median wages between establishments

* Log of wage distance (for visualization)
gen l_wage_distance = ln(wage_distance + 1)                                       // Calculate log of wage distance plus 1 (to handle zeros)

* Female proportion distance (absolute difference in proportion female)
gen female_distance = abs(avg_prop_female_i - avg_prop_female_j)                  // Calculate absolute difference in proportion female between establishments

* Non-white proportion distance (absolute difference in proportion non-white)
gen nonwhite_distance = abs(avg_prop_nonwhite_i - avg_prop_nonwhite_j)            // Calculate absolute difference in proportion non-white between establishments

* Higher education proportion distance (absolute difference in proportion with higher education)
gen educ_distance = abs(avg_prop_sup_i - avg_prop_sup_j)                          // Calculate absolute difference in proportion with higher education between establishments

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
summarize bilateral_conn_pw flows_total, detail                         // Display detailed summary statistics for connectivity measures

di _newline(2) "=== Distance Measures ==="                                        // Display section header for distance measures
summarize same_muni same_microregion size_distance wage_distance, detail          // Display detailed summary statistics for distance measures

di _newline(2) "=== Workforce Composition Distance Measures ==="                  // Display section header for workforce composition distances
summarize female_distance nonwhite_distance educ_distance, detail                 // Display detailed summary statistics for workforce composition distance measures

if !missing(geo_distance) {                                                       // If geographic distance was computed
    summarize geo_distance, detail                                                // Display detailed summary statistics for geographic distance
}

* Tabulate same municipality and microregion
tab same_muni, missing                                                            // Tabulate same municipality dummy, including missing values
tab same_microregion, missing                                                     // Tabulate same microregion dummy, including missing values

********************************************************************************
* STEP 10: Save final bilateral pairs dataset
********************************************************************************

order identificad_i identificad_j bilateral_conn_pw flows_total ///
      same_muni same_microregion same_mode_union geo_distance ///
      big_industry_i broad_industry_i mode_union_i ///
      big_industry_j mode_union_j ///
      avg_firm_emp_i avg_firm_emp_j med_r_remdezr_i med_r_remdezr_j ///
      avg_prop_female_i avg_prop_female_j avg_prop_nonwhite_i avg_prop_nonwhite_j ///
      avg_prop_sup_i avg_prop_sup_j ///
      size_distance wage_distance female_distance nonwhite_distance educ_distance // Reorder variables: IDs first, then connectivity, geography, industry, firm chars, distances

compress                                                                          // Reduce dataset memory footprint by optimizing storage types
save "$rais_aux/bilateral_pairs_descriptives.dta", replace                        // Save final bilateral pairs dataset with all variables

di _newline "Saved: $rais_aux/bilateral_pairs_descriptives.dta"                   // Display confirmation message with file path
di "Number of pairs: " _N                                                         // Display number of observations (pairs) in final dataset

********************************************************************************
* STEP 11: Generate publication-quality binned scatterplots
********************************************************************************

* Install binscatter if needed (ssc install binscatter)
capture which binscatter                                                          // Check if binscatter command is installed
if _rc != 0 {                                                                     // If binscatter not found (return code != 0)
    di "binscatter not installed. Please run: ssc install binscatter"             // Display installation instructions
}

* Set publication-quality graph scheme
set scheme s2color                                                                // Use s2color scheme as base for clean plots

* Plot 1: Bilateral connectivity vs geographic distance (if available)
capture confirm variable geo_distance                                             // Check if geo_distance variable exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_distance)                                               // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        binscatter bilateral_conn_pw l_geo_distance, nquantiles(20) ///
            xtitle("Absolute difference in log geographic distance (km)") ///
            ytitle("Bilateral Connectivity") ///
            mcolor(navy) lcolor(navy) ///
            plotregion(color(white)) graphregion(color(white))                    // Publication-quality: navy color, white background
        graph export "$graphs/binscatter_conn_geo_distance.pdf", replace          // Export graph as PDF file
    }
}

* Plot 2: Bilateral connectivity vs size distance (log)
binscatter bilateral_conn_pw size_distance, nquantiles(20) ///
    xtitle("Absolute difference in log employment") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_size_distance.pdf", replace                 // Export graph as PDF file

* Plot 3: Bilateral connectivity vs size distance (levels)
binscatter bilateral_conn_pw size_distance_levels, nquantiles(20) ///
    xtitle("Absolute difference in employment (levels)") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_size_distance_levels.pdf", replace          // Export graph as PDF file

* Plot 4: Bilateral connectivity vs wage distance
binscatter bilateral_conn_pw l_wage_distance, nquantiles(20) ///
    xtitle("Absolute difference in log median wages") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_wage_distance.pdf", replace                 // Export graph as PDF file

* Plot 5: Bilateral connectivity vs female proportion distance
binscatter bilateral_conn_pw female_distance, nquantiles(20) ///
    xtitle("Absolute difference in share female") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_female_distance.pdf", replace               // Export graph as PDF file

* Plot 6: Bilateral connectivity vs non-white proportion distance
binscatter bilateral_conn_pw nonwhite_distance, nquantiles(20) ///
    xtitle("Absolute difference in share non-white") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_nonwhite_distance.pdf", replace             // Export graph as PDF file

* Plot 7: Bilateral connectivity vs higher education proportion distance
binscatter bilateral_conn_pw educ_distance, nquantiles(20) ///
    xtitle("Absolute difference in share with higher education") ///
    ytitle("Bilateral Connectivity") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_educ_distance.pdf", replace                 // Export graph as PDF file

********************************************************************************
* STEP 12: Compute correlations and generate LaTeX correlation table
********************************************************************************

* Create temporary file to store correlations
tempname memhold                                                                  // Create temporary name for postfile handle
tempfile corr_results                                                             // Create temporary file for correlation results
postfile `memhold' str30 variable corr n using `corr_results'                     // Initialize postfile with variable name, correlation, and N

* Compute correlation with geographic distance (if available)
capture confirm variable geo_distance                                             // Check if geo_distance exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_distance)                                               // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        qui corr bilateral_conn_pw geo_distance                                   // Compute Pearson correlation quietly
        local corr_geo = r(rho)                                                   // Store correlation coefficient
        qui count if !missing(bilateral_conn_pw) & !missing(geo_distance)         // Count observations used
        local n_geo = r(N)                                                        // Store observation count
        post `memhold' ("Geographic distance") (`corr_geo') (`n_geo')             // Post results to file
    }
}

* Compute correlation with size distance
qui corr bilateral_conn_pw size_distance                                          // Compute Pearson correlation quietly
local corr_size = r(rho)                                                          // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(size_distance)                // Count observations used
local n_size = r(N)                                                               // Store observation count
post `memhold' ("Size distance (log)") (`corr_size') (`n_size')                   // Post results to file

* Compute correlation with size distance (levels)
qui corr bilateral_conn_pw size_distance_levels                                   // Compute Pearson correlation quietly
local corr_size_lev = r(rho)                                                      // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(size_distance_levels)         // Count observations used
local n_size_lev = r(N)                                                           // Store observation count
post `memhold' ("Size distance (levels)") (`corr_size_lev') (`n_size_lev')        // Post results to file

* Compute correlation with wage distance
qui corr bilateral_conn_pw wage_distance                                          // Compute Pearson correlation quietly
local corr_wage = r(rho)                                                          // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(wage_distance)                // Count observations used
local n_wage = r(N)                                                               // Store observation count
post `memhold' ("Wage distance") (`corr_wage') (`n_wage')                         // Post results to file

* Compute correlation with female proportion distance
qui corr bilateral_conn_pw female_distance                                        // Compute Pearson correlation quietly
local corr_female = r(rho)                                                        // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(female_distance)              // Count observations used
local n_female = r(N)                                                             // Store observation count
post `memhold' ("Share female distance") (`corr_female') (`n_female')             // Post results to file

* Compute correlation with non-white proportion distance
qui corr bilateral_conn_pw nonwhite_distance                                      // Compute Pearson correlation quietly
local corr_nonwhite = r(rho)                                                      // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(nonwhite_distance)            // Count observations used
local n_nonwhite = r(N)                                                           // Store observation count
post `memhold' ("Share non-white distance") (`corr_nonwhite') (`n_nonwhite')      // Post results to file

* Compute correlation with higher education proportion distance
qui corr bilateral_conn_pw educ_distance                                          // Compute Pearson correlation quietly
local corr_educ = r(rho)                                                          // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(educ_distance)                // Count observations used
local n_educ = r(N)                                                               // Store observation count
post `memhold' ("Share higher education distance") (`corr_educ') (`n_educ')       // Post results to file

postclose `memhold'                                                               // Close postfile

* Load correlation results and generate LaTeX table
preserve                                                                          // Preserve current dataset
use `corr_results', clear                                                         // Load correlation results

* Display correlations in console
di _newline(2) "=== Correlation Table: Bilateral Connectivity vs Distance Measures ===" // Display section header
list variable corr n, noobs sep(0)                                                // List correlations without observation numbers

* Generate LaTeX table with threeparttable
capture file close latex_table                                                    // Close file if already open
file open latex_table using "$tables/correlation_bilateral_connectivity.txt", write replace // Open file for writing

file write latex_table "\begin{table}[htbp]" _newline                             // LaTeX table environment
file write latex_table "\centering" _newline                                      // Center the table
file write latex_table "\begin{threeparttable}" _newline                          // Begin threeparttable for notes
file write latex_table "\caption{Correlation between Bilateral Connectivity and Distance Measures}" _newline // Table caption
file write latex_table "\label{tab:corr_bilateral}" _newline                      // Table label for cross-referencing
file write latex_table "\footnotesize" _newline                                   // Set font size to footnotesize
file write latex_table "\begin{tabular}{lcc}" _newline                            // Begin tabular with 3 columns
file write latex_table "\hline\hline" _newline                                    // Double horizontal line at top
file write latex_table "Distance Measure & Correlation & N \\\\" _newline         // Column headers
file write latex_table "\hline" _newline                                          // Horizontal line after header

* Loop through rows and write to LaTeX
local nrows = _N                                                                  // Get number of rows
forvalues i = 1/`nrows' {                                                         // Loop through each row
    local var = variable[`i']                                                     // Get variable name
    local c = corr[`i']                                                           // Get correlation
    local n_obs = n[`i']                                                          // Get observation count
    file write latex_table "`var' & " %6.3f (`c') " & " %9.0fc (`n_obs') " \\\\" _newline // Write row with 3 decimals
}

file write latex_table "\hline\hline" _newline                                    // Double horizontal line at bottom
file write latex_table "\end{tabular}" _newline                                   // End tabular
file write latex_table "\begin{tablenotes}" _newline                              // Begin table notes
file write latex_table "\footnotesize" _newline                                   // Set notes font size
file write latex_table "\item \textit{Notes:} This table reports Pearson correlation coefficients between bilateral connectivity and various distance measures across establishment pairs. Bilateral connectivity is the average number of worker flows between establishments $i$ and $j$ over consecutive year-pairs (2007-08, 2008-09, 2009-10, 2010-11), normalized by establishment $i$'s employment. Distance measures are computed as the absolute difference between establishment $i$ and $j$ characteristics. Geographic distance is in kilometers, computed using the Haversine formula from municipality centroids. Size distance is measured in log employment (2009-2011 average). Wage distance uses median December earnings (2009-2011, deflated to 2015 prices). Workforce composition distances use 2009-2011 averages. Sample restricted to pairs where both establishments satisfy \texttt{lagos\_sample\_avg==1} and \texttt{in\_balanced\_panel==1}, with at least one worker transition during 2007-2011." _newline // Table notes
file write latex_table "\end{tablenotes}" _newline                                // End table notes
file write latex_table "\end{threeparttable}" _newline                            // End threeparttable
file write latex_table "\end{table}" _newline                                     // End table environment
file close latex_table                                                            // Close file

di _newline "Saved: $tables/correlation_bilateral_connectivity.txt"               // Display confirmation message
restore                                                                           // Restore bilateral pairs dataset

********************************************************************************
* STEP 13: Generate bar graph of correlation by broad industry
********************************************************************************

* Compute correlation between bilateral connectivity and geographic distance by industry
capture confirm variable geo_distance                                             // Check if geo_distance exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_distance)                                               // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values

        * Create temporary file to store industry-level correlations
        tempname ind_memhold                                                      // Create temporary name for postfile handle
        tempfile ind_corr                                                         // Create temporary file for industry correlations
        postfile `ind_memhold' broad_ind corr n using `ind_corr'                  // Initialize postfile

        * Loop through each broad industry category
        forvalues ind = 1/18 {                                                    // Loop through 18 industry categories
            qui count if broad_industry_i == `ind' & !missing(geo_distance)       // Count observations in this industry
            if r(N) > 30 {                                                        // Only compute if sufficient observations
                qui corr bilateral_conn_pw geo_distance if broad_industry_i == `ind' // Compute correlation for this industry
                local corr_ind = r(rho)                                           // Store correlation
                qui count if broad_industry_i == `ind' & !missing(bilateral_conn_pw) & !missing(geo_distance) // Count observations
                local n_ind = r(N)                                                // Store count
                post `ind_memhold' (`ind') (`corr_ind') (`n_ind')                 // Post results
            }
            else {                                                                // If insufficient observations
                post `ind_memhold' (`ind') (.) (0)                                // Post missing correlation
            }
        }

        postclose `ind_memhold'                                                   // Close postfile

        * Load industry correlations and create bar graph
        preserve                                                                  // Preserve current dataset
        use `ind_corr', clear                                                     // Load industry correlation results

        * Apply industry labels
        label define broad_ind_lbl2 ///
            1 "Farming/fishing" ///
            2 "Extractive ind." ///
            3 "Manufacturing" ///
            4 "Utilities" ///
            5 "Construction" ///
            6 "Trade/commerce" ///
            7 "Transportation" ///
            8 "Hospitality" ///
            9 "Communication" ///
            10 "Banking/finance" ///
            11 "Real estate" ///
            12 "Professional act." ///
            13 "Administrative act." ///
            14 "Public admin." ///
            15 "Education" ///
            16 "Health" ///
            17 "Culture/sports" ///
            18 "Other"                                                            // Define value labels
        label values broad_ind broad_ind_lbl2                                     // Apply labels

        * Create bar graph with value labels
        graph bar corr, over(broad_ind, label(angle(45) labsize(vsmall))) ///
            ytitle("Corr. of Distance (km) with bilateral conn.") ///
            bar(1, color(navy)) ///
            ylabel(, angle(0) format(%4.2f)) ///
            blabel(bar, format(%4.2f) size(vsmall)) ///
            plotregion(color(white)) graphregion(color(white))                    // Publication-quality bar graph with value labels, white background
        graph export "$graphs/corr_by_industry.pdf", replace                      // Export graph as PDF

        di _newline "Saved: $graphs/corr_by_industry.pdf"                         // Display confirmation message
        restore                                                                   // Restore bilateral pairs dataset
    }
}

********************************************************************************
* STEP 14: Run regression with standardized coefficients and firm FE
********************************************************************************

* Check if reghdfe is installed
capture which reghdfe                                                             // Check if reghdfe is installed
if _rc != 0 {                                                                     // If not installed
    di "reghdfe not installed. Please run: ssc install reghdfe"                   // Display installation instructions
}

* Standardize variables for comparable coefficients
foreach var in bilateral_conn_pw geo_distance size_distance wage_distance ///
               female_distance nonwhite_distance educ_distance {                  // Loop through continuous variables
    capture confirm variable `var'                                                // Check if variable exists
    if _rc == 0 {                                                                 // If exists
        qui sum `var'                                                             // Get summary statistics
        if r(sd) > 0 & !missing(r(sd)) {                                          // If has positive standard deviation
            gen z_`var' = (`var' - r(mean)) / r(sd)                               // Standardize: (x - mean) / sd
            label var z_`var' "Standardized `var'"                                // Label standardized variable
        }
    }
}

* Run regression with firm i fixed effects (no clustering)
* Dependent variable: standardized bilateral connectivity
* Independent variables: standardized distance measures + same_muni, same_microregion, same_mode_union dummies

capture confirm variable z_geo_distance                                           // Check if geographic distance is available
if _rc == 0 {                                                                     // If geographic distance available
    di _newline(2) "=== Regression with Geographic Distance ==="                  // Display section header
    reghdfe z_bilateral_conn_pw z_geo_distance z_size_distance z_wage_distance ///
            z_female_distance z_nonwhite_distance z_educ_distance ///
            same_muni same_microregion same_mode_union, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    * Store estimates for coefficient plot
    estimates store reg_with_geo                                                  // Store regression estimates
}
else {                                                                            // If no geographic distance
    di _newline(2) "=== Regression without Geographic Distance ==="               // Display section header
    reghdfe z_bilateral_conn_pw z_size_distance z_wage_distance ///
            z_female_distance z_nonwhite_distance z_educ_distance ///
            same_muni same_microregion same_mode_union, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    * Store estimates for coefficient plot
    estimates store reg_no_geo                                                    // Store regression estimates
}

********************************************************************************
* STEP 15: Create coefficient plot with confidence intervals
********************************************************************************

* Check if coefplot is installed
capture which coefplot                                                            // Check if coefplot is installed
if _rc != 0 {                                                                     // If not installed
    di "coefplot not installed. Please run: ssc install coefplot"                 // Display installation instructions
}

* Create coefficient plot
capture confirm variable z_geo_distance                                           // Check if geographic distance available
if _rc == 0 {                                                                     // If geographic distance available
    coefplot reg_with_geo, ///
        keep(z_geo_distance z_size_distance z_wage_distance ///
             z_female_distance z_nonwhite_distance z_educ_distance ///
             same_muni same_microregion same_mode_union) ///
        xline(0, lcolor(gs10)) ///
        mcolor(navy) ciopts(lcolor(navy)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_geo_distance = "Geographic distance" ///
                   z_size_distance = "Size distance" ///
                   z_wage_distance = "Wage distance" ///
                   z_female_distance = "Share female distance" ///
                   z_nonwhite_distance = "Share non-white distance" ///
                   z_educ_distance = "Share higher ed. distance" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_mode_union = "Same modal union") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Publication-quality coefficient plot, white background
    graph export "$graphs/coefplot_bilateral_regression.pdf", replace             // Export graph as PDF
}
else {                                                                            // If no geographic distance
    coefplot reg_no_geo, ///
        keep(z_size_distance z_wage_distance ///
             z_female_distance z_nonwhite_distance z_educ_distance ///
             same_muni same_microregion same_mode_union) ///
        xline(0, lcolor(gs10)) ///
        mcolor(navy) ciopts(lcolor(navy)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_size_distance = "Size distance" ///
                   z_wage_distance = "Wage distance" ///
                   z_female_distance = "Share female distance" ///
                   z_nonwhite_distance = "Share non-white distance" ///
                   z_educ_distance = "Share higher ed. distance" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_mode_union = "Same modal union") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Publication-quality coefficient plot, white background
    graph export "$graphs/coefplot_bilateral_regression.pdf", replace             // Export graph as PDF
}

di _newline "Saved: $graphs/coefplot_bilateral_regression.pdf"                    // Display confirmation message

********************************************************************************
* STEP 16: Clean up temporary files
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
di "  - $graphs/binscatter_conn_size_distance.pdf"                                // Display path to size distance (log) plot
di "  - $graphs/binscatter_conn_size_distance_levels.pdf"                         // Display path to size distance (levels) plot
di "  - $graphs/binscatter_conn_wage_distance.pdf"                                // Display path to wage distance plot
di "  - $graphs/binscatter_conn_female_distance.pdf"                              // Display path to female proportion distance plot
di "  - $graphs/binscatter_conn_nonwhite_distance.pdf"                            // Display path to non-white proportion distance plot
di "  - $graphs/binscatter_conn_educ_distance.pdf"                                // Display path to higher education distance plot
di "  - $tables/correlation_bilateral_connectivity.txt"                           // Display path to LaTeX correlation table
di "  - $graphs/coefplot_bilateral_regression.pdf"                                // Display path to coefficient plot
capture confirm variable geo_distance                                             // Check if geo_distance variable exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_distance)                                               // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        di "  - $graphs/binscatter_conn_geo_distance.pdf"                         // Display path to geographic distance plot
        di "  - $graphs/corr_by_industry.pdf"                                     // Display path to industry correlation bar graph
    }
}
