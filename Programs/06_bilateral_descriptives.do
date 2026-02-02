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
* STEP 2: Create list of sample establishments and their characteristics
********************************************************************************

* Get lagos_sample_avg and in_balanced_panel from main dataset
* These are time-invariant at the firm level

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load main firm-level dataset with CBA and RAIS merged data
keep if year == 2009                                                              // Keep only 2009 observations (sample flags are time-invariant)
keep identificad lagos_sample_avg in_balanced_panel municipio microregion ///
     big_industry industry1 mode_union                                            // Keep establishment ID, sample flags, geographic IDs, industries, and union

* Ensure unique observations
duplicates drop identificad, force                                                // Remove duplicate establishment observations, keeping first occurrence

* Restrict to sample establishments
keep if lagos_sample_avg == 1 & in_balanced_panel == 1                            // Keep only establishments in Lagos sample and balanced panel

* Ensure municipio is numeric for merging with coordinates
capture confirm string variable municipio                                         // Check if municipio is stored as string
if _rc == 0 {                                                                     // If municipio is string (return code 0 means string confirmed)
    destring municipio, replace force                                             // Convert municipality code from string to numeric, forcing conversion even with non-numeric characters
}

* Count sample establishments
count                                                                             // Count number of sample establishments
local n_estabs = r(N)                                                             // Store count in local macro
di "Number of sample establishments: `n_estabs'"                                  // Display number of establishments in sample

save "$rais_aux/sample_establishments.dta", replace                               // Save sample establishments

********************************************************************************
* STEP 3: Create ALL possible pairs (cross-join of sample establishments)
********************************************************************************

* Create establishment i file
use "$rais_aux/sample_establishments.dta", clear                                  // Load sample establishments
rename identificad identificad_i                                                  // Rename establishment ID for establishment i
rename lagos_sample_avg lagos_sample_i                                            // Rename Lagos sample flag with _i suffix
rename in_balanced_panel balanced_panel_i                                         // Rename balanced panel flag with _i suffix
rename municipio municipio_i                                                      // Rename municipality code with _i suffix
rename microregion microregion_i                                                  // Rename microregion code with _i suffix
rename big_industry big_industry_i                                                // Rename 2-digit industry code with _i suffix
rename industry1 industry1_i                                                      // Rename 3-digit industry code with _i suffix
rename mode_union mode_union_i                                                    // Rename modal union with _i suffix

save "$rais_aux/sample_flags_i.dta", replace                                      // Save sample flags for establishment i

* Create establishment j file
use "$rais_aux/sample_establishments.dta", clear                                  // Load sample establishments
rename identificad identificad_j                                                  // Rename establishment ID for establishment j
rename lagos_sample_avg lagos_sample_j                                            // Rename Lagos sample flag with _j suffix
rename in_balanced_panel balanced_panel_j                                         // Rename balanced panel flag with _j suffix
rename municipio municipio_j                                                      // Rename municipality code with _j suffix
rename microregion microregion_j                                                  // Rename microregion code with _j suffix
rename big_industry big_industry_j                                                // Rename 2-digit industry code with _j suffix
rename industry1 industry1_j                                                      // Rename 3-digit industry code with _j suffix
rename mode_union mode_union_j                                                    // Rename modal union with _j suffix

save "$rais_aux/sample_flags_j.dta", replace                                      // Save sample flags for establishment j

* Cross-join: create all possible i-j pairs
use "$rais_aux/sample_flags_i.dta", clear                                         // Load establishment i data
gen _crossjoin = 1                                                                // Create dummy variable for cross-join
save "$rais_aux/sample_flags_i.dta", replace                                      // Save with cross-join key

use "$rais_aux/sample_flags_j.dta", clear                                         // Load establishment j data
gen _crossjoin = 1                                                                // Create dummy variable for cross-join
save "$rais_aux/sample_flags_j.dta", replace                                      // Save with cross-join key

* Perform cross-join (creates N^2 pairs)
use "$rais_aux/sample_flags_i.dta", clear                                         // Load establishment i data
joinby _crossjoin using "$rais_aux/sample_flags_j.dta"                            // Cross-join with establishment j data
drop _crossjoin                                                                   // Drop cross-join key

* Remove self-pairs (i == j)
drop if identificad_i == identificad_j                                            // Remove pairs where establishment i equals establishment j

* Count all possible pairs
count                                                                             // Count number of pairs
local n_all_pairs = r(N)                                                          // Store count in local macro
di "Number of all possible pairs (excluding self-pairs): `n_all_pairs'"           // Display total number of pairs

********************************************************************************
* STEP 4: Merge bilateral connectivity data (zero for pairs without flows)
********************************************************************************

* Merge connectivity data from MATLAB output
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_connectivity_raw.dta", keep(master match) // Merge connectivity; keep all pairs

* Set connectivity to zero for pairs without flows
replace bilateral_conn_pw = 0 if _merge == 1                                      // Set bilateral connectivity to 0 for pairs not in MATLAB output
replace flows_total = 0 if _merge == 1                                            // Set total flows to 0 for pairs not in MATLAB output
replace flows_0708 = 0 if _merge == 1                                             // Set 2007-08 flows to 0 for pairs not in MATLAB output
replace flows_0809 = 0 if _merge == 1                                             // Set 2008-09 flows to 0 for pairs not in MATLAB output
replace flows_0910 = 0 if _merge == 1                                             // Set 2009-10 flows to 0 for pairs not in MATLAB output
replace flows_1011 = 0 if _merge == 1                                             // Set 2010-11 flows to 0 for pairs not in MATLAB output

* Create indicator for positive connectivity
gen has_positive_flow = (_merge == 3)                                             // Indicator = 1 if pair has at least one worker flow
drop _merge                                                                       // Drop merge indicator

* Count pairs with positive vs zero connectivity
count if has_positive_flow == 1                                                   // Count pairs with positive flows
local n_pos = r(N)                                                                // Store count
count if has_positive_flow == 0                                                   // Count pairs with zero flows
local n_zero = r(N)                                                               // Store count
di "Pairs with positive connectivity: `n_pos'"                                    // Display pairs with flows
di "Pairs with zero connectivity: `n_zero'"                                       // Display pairs without flows

save "$rais_aux/bilateral_pairs_sample.dta", replace                              // Save all bilateral pairs dataset

********************************************************************************
* STEP 5: Merge firm characteristics for establishment i (2009-2011 averages)
********************************************************************************

* First, prepare firm characteristics from individual years
foreach yr in 2009 2010 2011 {                                                    // Loop through years 2009, 2010, and 2011
    use "$rais_firm/rais_firm_`yr'.dta", clear                                    // Load firm-level RAIS data for current year

    * Keep relevant variables (r_remdezr is mean December wages in 2015 prices)
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup prop_hs prop_nhs // Keep establishment ID, employment, wages, and demographic/education proportions

    * Generate prop_female and prop_nonwhite
    gen prop_female = 1 - male_prop                                               // Calculate proportion female as complement of male proportion
    gen prop_nonwhite = 1 - white_prop                                            // Calculate proportion non-white as complement of white proportion

    * Rename with year suffix
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup prop_hs prop_nhs { // Loop through firm characteristic variables
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
egen avg_prop_hs = rowmean(prop_hs_2009 prop_hs_2010 prop_hs_2011)                // Calculate average proportion with high school across 2009-2011
egen avg_prop_nhs = rowmean(prop_nhs_2009 prop_nhs_2010 prop_nhs_2011)            // Calculate average proportion with less than high school across 2009-2011

* Compute median wages across years (use rowmedian)
egen med_r_remdezr = rowmedian(r_remdezr_2009 r_remdezr_2010 r_remdezr_2011)      // Calculate median December wages across 2009-2011

* Compute average wages across years (use rowmean)
egen avg_r_remdezr = rowmean(r_remdezr_2009 r_remdezr_2010 r_remdezr_2011)        // Calculate average December wages across 2009-2011

* Log of average employment
gen l_avg_firm_emp = ln(avg_firm_emp)                                             // Generate log of average employment

* Log of median wages
gen l_med_r_remdezr = ln(med_r_remdezr)                                           // Generate log of median December wages

* Log of average wages
gen l_avg_r_remdezr = ln(avg_r_remdezr)                                           // Generate log of average December wages

* Keep only needed variables
keep identificad avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite avg_prop_hs avg_prop_nhs med_r_remdezr l_med_r_remdezr avg_r_remdezr l_avg_r_remdezr // Keep establishment ID and computed averages

********************************************************************************
* STEP 5b: Get pretreatment numb_clauses from 2009 CBA-RAIS data
********************************************************************************

* Merge numb_clauses from CBA-RAIS firm-level data (2009)
preserve                                                                          // Preserve current firm characteristics
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load CBA-RAIS merged data
keep if year == 2009                                                              // Keep only 2009 observations (pretreatment)
keep identificad numb_clauses                                                     // Keep establishment ID and number of clauses
duplicates drop identificad, force                                                // Remove duplicates, keeping first occurrence
rename numb_clauses numb_clauses_2009                                             // Rename with year suffix for clarity
save "$rais_aux/numb_clauses_2009.dta", replace                                   // Save numb_clauses data
restore                                                                           // Restore firm characteristics

* Merge numb_clauses to firm characteristics
merge 1:1 identificad using "$rais_aux/numb_clauses_2009.dta", nogen keep(master match) // Merge numb_clauses; keep all firms

* For firms without CBA in 2009, numb_clauses will be missing (should be rare in lagos_sample)
count if missing(numb_clauses_2009)                                               // Count firms without 2009 clause data
di "Firms without 2009 numb_clauses: " r(N)                                       // Display count

* Prepare for merge with establishment i
rename identificad identificad_i                                                  // Rename establishment ID for merging as establishment i
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite avg_prop_hs avg_prop_nhs med_r_remdezr l_med_r_remdezr avg_r_remdezr l_avg_r_remdezr numb_clauses_2009 { // Loop through average variables
    rename `var' `var'_i                                                          // Add _i suffix for establishment i
}

save "$rais_aux/firm_chars_avg_i.dta", replace                                    // Save firm characteristics for establishment i

* Prepare for merge with establishment j
use "$rais_aux/firm_chars_avg_i.dta", clear                                       // Load firm characteristics (currently suffixed with _i)
rename identificad_i identificad_j                                                // Rename establishment ID for establishment j
foreach var in avg_firm_emp l_avg_firm_emp avg_prop_female avg_prop_sup avg_prop_nonwhite avg_prop_hs avg_prop_nhs med_r_remdezr l_med_r_remdezr avg_r_remdezr l_avg_r_remdezr numb_clauses_2009 { // Loop through average variables
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
* STEP 7: Compute proximity measures and industry dummies
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

* Same union dummy (renamed from same_mode_union)
gen same_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j) // Create dummy = 1 if both establishments have same union

* Same big_industry dummy (2-digit CNAE)
gen same_big_industry = (big_industry_i == big_industry_j) if !missing(big_industry_i) & !missing(big_industry_j) // Create dummy = 1 if both establishments in same 2-digit industry

* Same industry1 dummy (3-digit CNAE, used for fixed effects)
gen same_industry = (industry1_i == industry1_j) if !missing(industry1_i) & !missing(industry1_j) // Create dummy = 1 if both establishments in same 3-digit industry

* Same industry x microregion cell dummy (3-digit CNAE x microregion)
gen same_industry_micro = (industry1_i == industry1_j & microregion_i == microregion_j) ///
    if !missing(industry1_i) & !missing(industry1_j) & !missing(microregion_i) & !missing(microregion_j) // Create dummy = 1 if same 3-digit industry AND same microregion

* ============================================================================
* PROXIMITY MEASURES (negative of distance: higher = more similar)
* ============================================================================

* Size proximity (negative absolute difference in log employment)
gen size_proximity = -abs(l_avg_firm_emp_i - l_avg_firm_emp_j)                    // Proximity: higher values = more similar size

* Size proximity in levels (negative absolute difference in employment)
gen size_proximity_levels = -abs(avg_firm_emp_i - avg_firm_emp_j)                 // Proximity in levels: higher values = more similar size

* Median wage proximity (negative absolute difference in log median wages)
gen med_wage_proximity = -abs(l_med_r_remdezr_i - l_med_r_remdezr_j)              // Proximity: higher values = more similar median wages

* Average wage proximity (negative absolute difference in log average wages)
gen avg_wage_proximity = -abs(l_avg_r_remdezr_i - l_avg_r_remdezr_j)              // Proximity: higher values = more similar average wages

* Female proportion proximity (negative absolute difference in proportion female)
gen female_proximity = -abs(avg_prop_female_i - avg_prop_female_j)                // Proximity: higher values = more similar % female

* Non-white proportion proximity (negative absolute difference in proportion non-white)
gen nonwhite_proximity = -abs(avg_prop_nonwhite_i - avg_prop_nonwhite_j)          // Proximity: higher values = more similar % non-white

* Higher education proportion proximity (negative absolute difference in proportion with higher education)
gen educ_proximity = -abs(avg_prop_sup_i - avg_prop_sup_j)                        // Proximity: higher values = more similar % higher education

* High school proportion proximity (negative absolute difference in proportion with high school)
gen hs_proximity = -abs(avg_prop_hs_i - avg_prop_hs_j)                            // Proximity: higher values = more similar % high school

* Less than high school proportion proximity (negative absolute difference in proportion with less than high school)
gen nhs_proximity = -abs(avg_prop_nhs_i - avg_prop_nhs_j)                         // Proximity: higher values = more similar % less than high school

* Number of clauses proximity (pretreatment 2009, negative absolute difference)
gen clauses_proximity = -abs(numb_clauses_2009_i - numb_clauses_2009_j) ///
    if !missing(numb_clauses_2009_i) & !missing(numb_clauses_2009_j)              // Proximity: higher values = more similar CBA complexity

********************************************************************************
* STEP 8: Geographic proximity (based on Haversine distance) if coordinates available
********************************************************************************

* Check if municipality coordinates file exists
capture confirm file "$ibge/municipality_coordinates.dta"                         // Check if coordinates file exists; capture suppresses error if not found

if _rc == 0 {                                                                     // If file exists (return code 0)
    di "Municipality coordinates file found. Computing geographic proximity..."   // Display status message

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

    * Geographic proximity (negative of distance: higher = closer)
    gen geo_proximity = -geo_distance                                             // Proximity: higher values = closer geographically

    * Clean up temp variables
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j // Drop intermediate calculation variables
}
else {                                                                            // If coordinates file not found
    di "Municipality coordinates file not found. Skipping geographic proximity computation." // Display warning message
    di "To enable this, provide: $ibge/municipality_coordinates.dta"              // Display instructions for adding coordinates
    di "Required variables: municipio (7-digit IBGE code), latitude, longitude"   // Display required variable names
    gen geo_distance = .                                                          // Generate missing geographic distance variable
    gen geo_proximity = .                                                         // Generate missing geographic proximity variable
}

********************************************************************************
* STEP 9: Summary statistics
********************************************************************************

di _newline(2) "=== Summary Statistics for Bilateral Connectivity ==="            // Display section header with two blank lines
summarize bilateral_conn_pw flows_total has_positive_flow, detail                 // Display detailed summary statistics for connectivity measures

di _newline(2) "=== Proximity Measures ==="                                       // Display section header for proximity measures
summarize same_muni same_microregion same_union same_industry same_big_industry same_industry_micro, detail // Display detailed summary statistics for categorical proximity measures

di _newline(2) "=== Continuous Proximity Measures ==="                            // Display section header for continuous proximity
summarize size_proximity med_wage_proximity avg_wage_proximity, detail            // Display detailed summary statistics for continuous proximity measures

di _newline(2) "=== Workforce Composition Proximity Measures ==="                 // Display section header for workforce composition proximity
summarize female_proximity nonwhite_proximity educ_proximity hs_proximity nhs_proximity, detail // Display detailed summary statistics for workforce composition proximity measures

di _newline(2) "=== CBA Clauses Proximity Measure ==="                           // Display section header for clauses proximity
summarize clauses_proximity numb_clauses_2009_i numb_clauses_2009_j, detail       // Display detailed summary statistics for clauses proximity

if !missing(geo_proximity) {                                                      // If geographic proximity was computed
    summarize geo_distance geo_proximity, detail                                  // Display detailed summary statistics for geographic measures
}

* Tabulate same municipality, microregion, and industry
tab same_muni, missing                                                            // Tabulate same municipality dummy, including missing values
tab same_microregion, missing                                                     // Tabulate same microregion dummy, including missing values
tab same_industry, missing                                                        // Tabulate same 3-digit industry dummy, including missing values
tab same_industry_micro, missing                                                  // Tabulate same industry x microregion dummy, including missing values

********************************************************************************
* STEP 10: Save final bilateral pairs dataset
********************************************************************************

order identificad_i identificad_j bilateral_conn_pw flows_total has_positive_flow ///
      same_muni same_microregion same_union same_industry same_big_industry same_industry_micro ///
      geo_distance geo_proximity ///
      big_industry_i broad_industry_i industry1_i mode_union_i ///
      big_industry_j industry1_j mode_union_j ///
      avg_firm_emp_i avg_firm_emp_j med_r_remdezr_i med_r_remdezr_j avg_r_remdezr_i avg_r_remdezr_j ///
      avg_prop_female_i avg_prop_female_j avg_prop_nonwhite_i avg_prop_nonwhite_j ///
      avg_prop_sup_i avg_prop_sup_j avg_prop_hs_i avg_prop_hs_j avg_prop_nhs_i avg_prop_nhs_j ///
      numb_clauses_2009_i numb_clauses_2009_j ///
      size_proximity med_wage_proximity avg_wage_proximity female_proximity nonwhite_proximity educ_proximity hs_proximity nhs_proximity clauses_proximity // Reorder variables: IDs first, then connectivity, proximity measures, firm chars

compress                                                                          // Reduce dataset memory footprint by optimizing storage types
save "$rais_aux/bilateral_pairs_descriptives.dta", replace                        // Save final bilateral pairs dataset with all variables

di _newline "Saved: $rais_aux/bilateral_pairs_descriptives.dta"                   // Display confirmation message with file path
di "Number of pairs: " _N                                                         // Display number of observations (pairs) in final dataset

********************************************************************************
* STEP 11: Generate publication-quality binned scatterplots
*          (with firm i FE residualized y-axis, all pairs including zeros)
********************************************************************************

* Install binscatter if needed (ssc install binscatter)
capture which binscatter                                                          // Check if binscatter command is installed
if _rc != 0 {                                                                     // If binscatter not found (return code != 0)
    di "binscatter not installed. Please run: ssc install binscatter"             // Display installation instructions
}

* Set publication-quality graph scheme
set scheme s2color                                                                // Use s2color scheme as base for clean plots

********************************************************************************
* STEP 11a: Compute residualized bilateral connectivity (firm i FE)
********************************************************************************

di _newline(2) "=== Computing residualized bilateral connectivity (firm i FE) ==="

* Use reghdfe to partial out firm i fixed effects
* This creates residuals that remove the mean connectivity for each firm i
qui reghdfe bilateral_conn_pw, absorb(identificad_i) resid(bilateral_conn_resid)  // Regress on nothing, absorb firm i FE, save residuals

* Check residuals
summarize bilateral_conn_pw bilateral_conn_resid, detail                          // Compare original and residualized connectivity

********************************************************************************
* STEP 11b: Binscatter plots - ALL PAIRS (including zeros), residualized y-axis
********************************************************************************

di _newline(2) "=== Generating binscatter plots (all pairs, residualized y-axis) ==="

* Plot 1: Bilateral connectivity vs geographic proximity (if available)
capture confirm variable geo_proximity                                            // Check if geo_proximity variable exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_proximity)                                              // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        binscatter bilateral_conn_resid geo_proximity, nquantiles(20) ///
            xtitle("Geographic Proximity (negative km)") ///
            ytitle("Bilateral Connectivity (residualized)") ///
            mcolor(navy) lcolor(navy) ///
            plotregion(color(white)) graphregion(color(white))                    // Publication-quality: navy color, white background
        graph export "$graphs/binscatter_conn_geo_proximity.pdf", replace         // Export graph as PDF file
    }
}

* Plot 2: Bilateral connectivity vs size proximity (log)
binscatter bilateral_conn_resid size_proximity, nquantiles(20) ///
    xtitle("Size Proximity (negative |log emp diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_size_proximity.pdf", replace                // Export graph as PDF file

* Plot 3: Bilateral connectivity vs median wage proximity
binscatter bilateral_conn_resid med_wage_proximity, nquantiles(20) ///
    xtitle("Median Wage Proximity (negative |log wage diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_med_wage_proximity.pdf", replace            // Export graph as PDF file

* Plot 4: Bilateral connectivity vs average wage proximity
binscatter bilateral_conn_resid avg_wage_proximity, nquantiles(20) ///
    xtitle("Average Wage Proximity (negative |log wage diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_avg_wage_proximity.pdf", replace            // Export graph as PDF file

* Plot 5: Bilateral connectivity vs female proportion proximity
binscatter bilateral_conn_resid female_proximity, nquantiles(20) ///
    xtitle("% Female Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_female_proximity.pdf", replace              // Export graph as PDF file

* Plot 6: Bilateral connectivity vs non-white proportion proximity
binscatter bilateral_conn_resid nonwhite_proximity, nquantiles(20) ///
    xtitle("% Non-white Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_nonwhite_proximity.pdf", replace            // Export graph as PDF file

* Plot 7: Bilateral connectivity vs higher education proportion proximity
binscatter bilateral_conn_resid educ_proximity, nquantiles(20) ///
    xtitle("% Higher Education Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_educ_proximity.pdf", replace                // Export graph as PDF file

* Plot 8: Bilateral connectivity vs high school proportion proximity
binscatter bilateral_conn_resid hs_proximity, nquantiles(20) ///
    xtitle("% High School Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_hs_proximity.pdf", replace                  // Export graph as PDF file

* Plot 9: Bilateral connectivity vs less than high school proportion proximity
binscatter bilateral_conn_resid nhs_proximity, nquantiles(20) ///
    xtitle("% Less than High School Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))                            // Publication-quality: navy color, white background
graph export "$graphs/binscatter_conn_nhs_proximity.pdf", replace                 // Export graph as PDF file

* Plot 10: Bilateral connectivity vs clauses proximity (pretreatment 2009)
capture count if !missing(clauses_proximity)                                      // Check if clauses proximity is available
if r(N) > 0 {                                                                     // If there are non-missing values
    binscatter bilateral_conn_resid clauses_proximity, nquantiles(20) ///
        xtitle("CBA Clauses Proximity (negative |diff|)") ///
        ytitle("Bilateral Connectivity (residualized)") ///
        mcolor(navy) lcolor(navy) ///
        plotregion(color(white)) graphregion(color(white))                        // Publication-quality: navy color, white background
    graph export "$graphs/binscatter_conn_clauses_proximity.pdf", replace         // Export graph as PDF file
}

********************************************************************************
* STEP 11c: Binscatter plots - POSITIVE CONNECTIVITY ONLY, residualized y-axis
********************************************************************************

di _newline(2) "=== Generating binscatter plots (positive connectivity only, residualized) ==="

* Plot 1: Geographic proximity (positive connectivity only)
capture confirm variable geo_proximity                                            // Check if geo_proximity variable exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_proximity) & has_positive_flow == 1                     // Count non-missing observations with positive flows
    if r(N) > 0 {                                                                 // If there are non-missing values
        binscatter bilateral_conn_resid geo_proximity if has_positive_flow == 1, nquantiles(20) ///
            xtitle("Geographic Proximity (negative km)") ///
            ytitle("Bilateral Connectivity (residualized)") ///
            mcolor(maroon) lcolor(maroon) ///
            plotregion(color(white)) graphregion(color(white))                    // Maroon for positive-only plots
        graph export "$graphs/binscatter_conn_geo_proximity_posonly.pdf", replace // Export graph as PDF file
    }
}

* Plot 2: Size proximity (positive connectivity only)
binscatter bilateral_conn_resid size_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("Size Proximity (negative |log emp diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_size_proximity_posonly.pdf", replace        // Export graph as PDF file

* Plot 3: Median wage proximity (positive connectivity only)
binscatter bilateral_conn_resid med_wage_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("Median Wage Proximity (negative |log wage diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_med_wage_proximity_posonly.pdf", replace    // Export graph as PDF file

* Plot 4: Average wage proximity (positive connectivity only)
binscatter bilateral_conn_resid avg_wage_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("Average Wage Proximity (negative |log wage diff|)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_avg_wage_proximity_posonly.pdf", replace    // Export graph as PDF file

* Plot 5: Female proportion proximity (positive connectivity only)
binscatter bilateral_conn_resid female_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("% Female Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_female_proximity_posonly.pdf", replace      // Export graph as PDF file

* Plot 6: Non-white proportion proximity (positive connectivity only)
binscatter bilateral_conn_resid nonwhite_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("% Non-white Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_nonwhite_proximity_posonly.pdf", replace    // Export graph as PDF file

* Plot 7: Higher education proximity (positive connectivity only)
binscatter bilateral_conn_resid educ_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("% Higher Education Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_educ_proximity_posonly.pdf", replace        // Export graph as PDF file

* Plot 8: High school proximity (positive connectivity only)
binscatter bilateral_conn_resid hs_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("% High School Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_hs_proximity_posonly.pdf", replace          // Export graph as PDF file

* Plot 9: Less than high school proximity (positive connectivity only)
binscatter bilateral_conn_resid nhs_proximity if has_positive_flow == 1, nquantiles(20) ///
    xtitle("% Less than High School Proximity") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(maroon) lcolor(maroon) ///
    plotregion(color(white)) graphregion(color(white))                            // Maroon for positive-only plots
graph export "$graphs/binscatter_conn_nhs_proximity_posonly.pdf", replace         // Export graph as PDF file

* Plot 10: Clauses proximity (positive connectivity only)
capture count if !missing(clauses_proximity) & has_positive_flow == 1             // Check if clauses proximity is available
if r(N) > 0 {                                                                     // If there are non-missing values
    binscatter bilateral_conn_resid clauses_proximity if has_positive_flow == 1, nquantiles(20) ///
        xtitle("CBA Clauses Proximity (negative |diff|)") ///
        ytitle("Bilateral Connectivity (residualized)") ///
        mcolor(maroon) lcolor(maroon) ///
        plotregion(color(white)) graphregion(color(white))                        // Maroon for positive-only plots
    graph export "$graphs/binscatter_conn_clauses_proximity_posonly.pdf", replace // Export graph as PDF file
}

********************************************************************************
* STEP 12: Compute correlations and generate LaTeX correlation table
********************************************************************************

* Create temporary file to store correlations
tempname memhold                                                                  // Create temporary name for postfile handle
tempfile corr_results                                                             // Create temporary file for correlation results
postfile `memhold' str30 variable corr n using `corr_results'                     // Initialize postfile with variable name, correlation, and N

* Compute correlation with geographic proximity (if available)
capture confirm variable geo_proximity                                            // Check if geo_proximity exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_proximity)                                              // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        qui corr bilateral_conn_pw geo_proximity                                  // Compute Pearson correlation quietly
        local corr_geo = r(rho)                                                   // Store correlation coefficient
        qui count if !missing(bilateral_conn_pw) & !missing(geo_proximity)        // Count observations used
        local n_geo = r(N)                                                        // Store observation count
        post `memhold' ("Geographic proximity") (`corr_geo') (`n_geo')            // Post results to file
    }
}

* Compute correlation with size proximity
qui corr bilateral_conn_pw size_proximity                                         // Compute Pearson correlation quietly
local corr_size = r(rho)                                                          // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(size_proximity)               // Count observations used
local n_size = r(N)                                                               // Store observation count
post `memhold' ("Size proximity (log)") (`corr_size') (`n_size')                  // Post results to file

* Compute correlation with median wage proximity
qui corr bilateral_conn_pw med_wage_proximity                                     // Compute Pearson correlation quietly
local corr_med_wage = r(rho)                                                      // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(med_wage_proximity)           // Count observations used
local n_med_wage = r(N)                                                           // Store observation count
post `memhold' ("Median wage proximity") (`corr_med_wage') (`n_med_wage')         // Post results to file

* Compute correlation with average wage proximity
qui corr bilateral_conn_pw avg_wage_proximity                                     // Compute Pearson correlation quietly
local corr_avg_wage = r(rho)                                                      // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(avg_wage_proximity)           // Count observations used
local n_avg_wage = r(N)                                                           // Store observation count
post `memhold' ("Average wage proximity") (`corr_avg_wage') (`n_avg_wage')        // Post results to file

* Compute correlation with female proportion proximity
qui corr bilateral_conn_pw female_proximity                                       // Compute Pearson correlation quietly
local corr_female = r(rho)                                                        // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(female_proximity)             // Count observations used
local n_female = r(N)                                                             // Store observation count
post `memhold' ("% female proximity") (`corr_female') (`n_female')                // Post results to file

* Compute correlation with non-white proportion proximity
qui corr bilateral_conn_pw nonwhite_proximity                                     // Compute Pearson correlation quietly
local corr_nonwhite = r(rho)                                                      // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(nonwhite_proximity)           // Count observations used
local n_nonwhite = r(N)                                                           // Store observation count
post `memhold' ("% non-white proximity") (`corr_nonwhite') (`n_nonwhite')         // Post results to file

* Compute correlation with higher education proportion proximity
qui corr bilateral_conn_pw educ_proximity                                         // Compute Pearson correlation quietly
local corr_educ = r(rho)                                                          // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(educ_proximity)               // Count observations used
local n_educ = r(N)                                                               // Store observation count
post `memhold' ("% higher education proximity") (`corr_educ') (`n_educ')          // Post results to file

* Compute correlation with high school proportion proximity
qui corr bilateral_conn_pw hs_proximity                                           // Compute Pearson correlation quietly
local corr_hs = r(rho)                                                            // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(hs_proximity)                 // Count observations used
local n_hs = r(N)                                                                 // Store observation count
post `memhold' ("% high school proximity") (`corr_hs') (`n_hs')                   // Post results to file

* Compute correlation with less than high school proportion proximity
qui corr bilateral_conn_pw nhs_proximity                                          // Compute Pearson correlation quietly
local corr_nhs = r(rho)                                                           // Store correlation coefficient
qui count if !missing(bilateral_conn_pw) & !missing(nhs_proximity)                // Count observations used
local n_nhs = r(N)                                                                // Store observation count
post `memhold' ("% less than HS proximity") (`corr_nhs') (`n_nhs')                // Post results to file

* Compute correlation with clauses proximity (pretreatment 2009)
capture confirm variable clauses_proximity                                        // Check if clauses proximity exists
if _rc == 0 {                                                                     // If variable exists
    qui count if !missing(clauses_proximity)                                      // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        qui corr bilateral_conn_pw clauses_proximity                              // Compute Pearson correlation quietly
        local corr_clauses = r(rho)                                               // Store correlation coefficient
        qui count if !missing(bilateral_conn_pw) & !missing(clauses_proximity)    // Count observations used
        local n_clauses = r(N)                                                    // Store observation count
        post `memhold' ("CBA clauses proximity") (`corr_clauses') (`n_clauses')   // Post results to file
    }
}

postclose `memhold'                                                               // Close postfile

* Load correlation results and generate LaTeX table
preserve                                                                          // Preserve current dataset
use `corr_results', clear                                                         // Load correlation results

* Display correlations in console
di _newline(2) "=== Correlation Table: Bilateral Connectivity vs Proximity Measures ===" // Display section header
list variable corr n, noobs sep(0)                                                // List correlations without observation numbers

* Generate LaTeX table with threeparttable
capture file close latex_table                                                    // Close file if already open
file open latex_table using "$tables/correlation_bilateral_connectivity.txt", write replace // Open file for writing

file write latex_table "\begin{table}[htbp]" _newline                             // LaTeX table environment
file write latex_table "\centering" _newline                                      // Center the table
file write latex_table "\begin{threeparttable}" _newline                          // Begin threeparttable for notes
file write latex_table "\caption{Correlation between Bilateral Connectivity and Proximity Measures}" _newline // Table caption
file write latex_table "\label{tab:corr_bilateral}" _newline                      // Table label for cross-referencing
file write latex_table "\footnotesize" _newline                                   // Set font size to footnotesize
file write latex_table "\begin{tabular}{lcc}" _newline                            // Begin tabular with 3 columns
file write latex_table "\hline\hline" _newline                                    // Double horizontal line at top
file write latex_table "Proximity Measure & Correlation & N \\\\" _newline        // Column headers
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
file write latex_table "\item \textit{Notes:} This table reports Pearson correlation coefficients between bilateral connectivity and various proximity measures across establishment pairs. Bilateral connectivity is the average number of worker flows between establishments $i$ and $j$ over consecutive year-pairs (2007-08, 2008-09, 2009-10, 2010-11), normalized by establishment $i$'s employment. Proximity measures are computed as the negative absolute difference between establishment $i$ and $j$ characteristics (higher values = more similar). Geographic proximity is negative distance in kilometers (Haversine formula from municipality centroids). Size proximity uses log employment (2009-2011 average). Wage proximity uses log December earnings (2009-2011, deflated to 2015 prices). Sample includes all possible establishment pairs where both satisfy \texttt{lagos\_sample\_avg==1} and \texttt{in\_balanced\_panel==1}." _newline // Table notes
file write latex_table "\end{tablenotes}" _newline                                // End table notes
file write latex_table "\end{threeparttable}" _newline                            // End threeparttable
file write latex_table "\end{table}" _newline                                     // End table environment
file close latex_table                                                            // Close file

di _newline "Saved: $tables/correlation_bilateral_connectivity.txt"               // Display confirmation message
restore                                                                           // Restore bilateral pairs dataset

********************************************************************************
* STEP 13: Generate bar graph of correlation by broad industry
********************************************************************************

* Compute correlation between bilateral connectivity and geographic proximity by industry
capture confirm variable geo_proximity                                            // Check if geo_proximity exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_proximity)                                              // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values

        * Create temporary file to store industry-level correlations
        tempname ind_memhold                                                      // Create temporary name for postfile handle
        tempfile ind_corr                                                         // Create temporary file for industry correlations
        postfile `ind_memhold' broad_ind corr n using `ind_corr'                  // Initialize postfile

        * Loop through each broad industry category
        forvalues ind = 1/18 {                                                    // Loop through 18 industry categories
            qui count if broad_industry_i == `ind' & !missing(geo_proximity)      // Count observations in this industry
            if r(N) > 30 {                                                        // Only compute if sufficient observations
                qui corr bilateral_conn_pw geo_proximity if broad_industry_i == `ind' // Compute correlation for this industry
                local corr_ind = r(rho)                                           // Store correlation
                qui count if broad_industry_i == `ind' & !missing(bilateral_conn_pw) & !missing(geo_proximity) // Count observations
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
            ytitle("Corr. of Geo Proximity with bilateral conn.") ///
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
foreach var in bilateral_conn_pw geo_proximity size_proximity med_wage_proximity avg_wage_proximity ///
               female_proximity nonwhite_proximity educ_proximity hs_proximity nhs_proximity clauses_proximity { // Loop through continuous variables (including clauses)
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
* Independent variables: standardized proximity measures + same dummies

capture confirm variable z_geo_proximity                                          // Check if geographic proximity is available
if _rc == 0 {                                                                     // If geographic proximity available
    di _newline(2) "=== Regression with Geographic Proximity (with industry x microregion) ==="
    reghdfe z_bilateral_conn_pw z_geo_proximity z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
            z_female_proximity z_nonwhite_proximity z_educ_proximity ///
            z_hs_proximity z_nhs_proximity z_clauses_proximity ///
            same_muni same_microregion same_union same_industry same_industry_micro, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    * Store estimates for coefficient plot
    estimates store reg_with_geo                                                  // Store regression estimates

    * Run specification without industry x microregion interaction
    di _newline(2) "=== Regression with Geographic Proximity (without industry x microregion) ==="
    reghdfe z_bilateral_conn_pw z_geo_proximity z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
            z_female_proximity z_nonwhite_proximity z_educ_proximity ///
            z_hs_proximity z_nhs_proximity z_clauses_proximity ///
            same_muni same_microregion same_union same_industry, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    estimates store reg_with_geo_no_intx                                          // Store regression without interaction
}
else {                                                                            // If no geographic proximity
    di _newline(2) "=== Regression without Geographic Proximity (with industry x microregion) ==="
    reghdfe z_bilateral_conn_pw z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
            z_female_proximity z_nonwhite_proximity z_educ_proximity ///
            z_hs_proximity z_nhs_proximity z_clauses_proximity ///
            same_muni same_microregion same_union same_industry same_industry_micro, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    * Store estimates for coefficient plot
    estimates store reg_no_geo                                                    // Store regression estimates

    * Run specification without industry x microregion interaction
    di _newline(2) "=== Regression without Geographic Proximity (without industry x microregion) ==="
    reghdfe z_bilateral_conn_pw z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
            z_female_proximity z_nonwhite_proximity z_educ_proximity ///
            z_hs_proximity z_nhs_proximity z_clauses_proximity ///
            same_muni same_microregion same_union same_industry, ///
            absorb(identificad_i) vce(robust)                                     // FE for establishment i, robust SE

    estimates store reg_no_geo_no_intx                                            // Store regression without interaction
}

********************************************************************************
* STEP 15: Create coefficient plots with confidence intervals
********************************************************************************

* Check if coefplot is installed
capture which coefplot                                                            // Check if coefplot is installed
if _rc != 0 {                                                                     // If not installed
    di "coefplot not installed. Please run: ssc install coefplot"                 // Display installation instructions
}

* Create coefficient plot (main specification with industry x microregion)
capture confirm variable z_geo_proximity                                          // Check if geographic proximity available
if _rc == 0 {                                                                     // If geographic proximity available
    coefplot reg_with_geo, ///
        keep(z_geo_proximity z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
             z_female_proximity z_nonwhite_proximity z_educ_proximity ///
             z_hs_proximity z_nhs_proximity z_clauses_proximity ///
             same_muni same_microregion same_union same_industry same_industry_micro) ///
        xline(0, lcolor(gs10)) ///
        mcolor(navy) ciopts(lcolor(navy)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_geo_proximity = "Geographic" ///
                   z_size_proximity = "Size" ///
                   z_med_wage_proximity = "Median wage" ///
                   z_avg_wage_proximity = "Average wage" ///
                   z_female_proximity = "% female" ///
                   z_nonwhite_proximity = "% non-white" ///
                   z_educ_proximity = "% higher ed." ///
                   z_hs_proximity = "% high school" ///
                   z_nhs_proximity = "% less than HS" ///
                   z_clauses_proximity = "CBA clauses" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry" ///
                   same_industry_micro = "Same industry x microregion") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Publication-quality coefficient plot, white background
    graph export "$graphs/coefplot_bilateral_regression.pdf", replace             // Export graph as PDF

    * Coefficient plot without industry x microregion interaction
    coefplot reg_with_geo_no_intx, ///
        keep(z_geo_proximity z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
             z_female_proximity z_nonwhite_proximity z_educ_proximity ///
             z_hs_proximity z_nhs_proximity z_clauses_proximity ///
             same_muni same_microregion same_union same_industry) ///
        xline(0, lcolor(gs10)) ///
        mcolor(maroon) ciopts(lcolor(maroon)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_geo_proximity = "Geographic" ///
                   z_size_proximity = "Size" ///
                   z_med_wage_proximity = "Median wage" ///
                   z_avg_wage_proximity = "Average wage" ///
                   z_female_proximity = "% female" ///
                   z_nonwhite_proximity = "% non-white" ///
                   z_educ_proximity = "% higher ed." ///
                   z_hs_proximity = "% high school" ///
                   z_nhs_proximity = "% less than HS" ///
                   z_clauses_proximity = "CBA clauses" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Maroon color for no-interaction specification
    graph export "$graphs/coefplot_bilateral_regression_no_intx.pdf", replace     // Export graph as PDF
}
else {                                                                            // If no geographic proximity
    coefplot reg_no_geo, ///
        keep(z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
             z_female_proximity z_nonwhite_proximity z_educ_proximity ///
             z_hs_proximity z_nhs_proximity z_clauses_proximity ///
             same_muni same_microregion same_union same_industry same_industry_micro) ///
        xline(0, lcolor(gs10)) ///
        mcolor(navy) ciopts(lcolor(navy)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_size_proximity = "Size" ///
                   z_med_wage_proximity = "Median wage" ///
                   z_avg_wage_proximity = "Average wage" ///
                   z_female_proximity = "% female" ///
                   z_nonwhite_proximity = "% non-white" ///
                   z_educ_proximity = "% higher ed." ///
                   z_hs_proximity = "% high school" ///
                   z_nhs_proximity = "% less than HS" ///
                   z_clauses_proximity = "CBA clauses" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry" ///
                   same_industry_micro = "Same industry x microregion") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Publication-quality coefficient plot, white background
    graph export "$graphs/coefplot_bilateral_regression.pdf", replace             // Export graph as PDF

    * Coefficient plot without industry x microregion interaction
    coefplot reg_no_geo_no_intx, ///
        keep(z_size_proximity z_med_wage_proximity z_avg_wage_proximity ///
             z_female_proximity z_nonwhite_proximity z_educ_proximity ///
             z_hs_proximity z_nhs_proximity z_clauses_proximity ///
             same_muni same_microregion same_union same_industry) ///
        xline(0, lcolor(gs10)) ///
        mcolor(maroon) ciopts(lcolor(maroon)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_size_proximity = "Size" ///
                   z_med_wage_proximity = "Median wage" ///
                   z_avg_wage_proximity = "Average wage" ///
                   z_female_proximity = "% female" ///
                   z_nonwhite_proximity = "% non-white" ///
                   z_educ_proximity = "% higher ed." ///
                   z_hs_proximity = "% high school" ///
                   z_nhs_proximity = "% less than HS" ///
                   z_clauses_proximity = "CBA clauses" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        plotregion(color(white)) graphregion(color(white))                        // Maroon color for no-interaction specification
    graph export "$graphs/coefplot_bilateral_regression_no_intx.pdf", replace     // Export graph as PDF
}

di _newline "Saved: $graphs/coefplot_bilateral_regression.pdf"                    // Display confirmation message
di "Saved: $graphs/coefplot_bilateral_regression_no_intx.pdf"                     // Display confirmation for no-interaction plot

********************************************************************************
* STEP 16: Clean up temporary files
********************************************************************************

capture erase "$rais_aux/sample_establishments.dta"                               // Delete temporary sample establishments file
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
capture erase "$rais_aux/numb_clauses_2009.dta"                                   // Delete temporary numb_clauses file

timer off 1                                                                       // Stop timer 1
timer list                                                                        // Display elapsed time from timer 1

di _newline(2) "=== Bilateral Descriptives Complete ==="                          // Display completion message
di "Output files:"                                                                // Display header for output file list
di "  - $rais_aux/bilateral_pairs_descriptives.dta"                               // Display path to main output dataset
di _newline "Binscatter plots (all pairs, residualized):"
di "  - $graphs/binscatter_conn_size_proximity.pdf"                               // Display path to size proximity plot
di "  - $graphs/binscatter_conn_med_wage_proximity.pdf"                           // Display path to median wage proximity plot
di "  - $graphs/binscatter_conn_avg_wage_proximity.pdf"                           // Display path to average wage proximity plot
di "  - $graphs/binscatter_conn_female_proximity.pdf"                             // Display path to female proportion proximity plot
di "  - $graphs/binscatter_conn_nonwhite_proximity.pdf"                           // Display path to non-white proportion proximity plot
di "  - $graphs/binscatter_conn_educ_proximity.pdf"                               // Display path to higher education proximity plot
di "  - $graphs/binscatter_conn_hs_proximity.pdf"                                 // Display path to high school proximity plot
di "  - $graphs/binscatter_conn_nhs_proximity.pdf"                                // Display path to less than high school proximity plot
di "  - $graphs/binscatter_conn_clauses_proximity.pdf"                            // Display path to clauses proximity plot
di _newline "Binscatter plots (positive connectivity only, residualized):"
di "  - $graphs/binscatter_conn_size_proximity_posonly.pdf"                       // Display path to size proximity plot (positive only)
di "  - $graphs/binscatter_conn_med_wage_proximity_posonly.pdf"                   // Display path to median wage proximity plot (positive only)
di "  - $graphs/binscatter_conn_avg_wage_proximity_posonly.pdf"                   // Display path to average wage proximity plot (positive only)
di "  - $graphs/binscatter_conn_female_proximity_posonly.pdf"                     // Display path to female proportion proximity plot (positive only)
di "  - $graphs/binscatter_conn_nonwhite_proximity_posonly.pdf"                   // Display path to non-white proportion proximity plot (positive only)
di "  - $graphs/binscatter_conn_educ_proximity_posonly.pdf"                       // Display path to higher education proximity plot (positive only)
di "  - $graphs/binscatter_conn_hs_proximity_posonly.pdf"                         // Display path to high school proximity plot (positive only)
di "  - $graphs/binscatter_conn_nhs_proximity_posonly.pdf"                        // Display path to less than high school proximity plot (positive only)
di "  - $graphs/binscatter_conn_clauses_proximity_posonly.pdf"                    // Display path to clauses proximity plot (positive only)
di _newline "Tables and coefficient plots:"
di "  - $tables/correlation_bilateral_connectivity.txt"                           // Display path to LaTeX correlation table
di "  - $graphs/coefplot_bilateral_regression.pdf"                                // Display path to coefficient plot (with industry x microregion)
di "  - $graphs/coefplot_bilateral_regression_no_intx.pdf"                        // Display path to coefficient plot (without industry x microregion)
capture confirm variable geo_proximity                                            // Check if geo_proximity variable exists
if _rc == 0 {                                                                     // If variable exists
    count if !missing(geo_proximity)                                              // Count non-missing observations
    if r(N) > 0 {                                                                 // If there are non-missing values
        di "  - $graphs/binscatter_conn_geo_proximity.pdf"                        // Display path to geographic proximity plot
        di "  - $graphs/binscatter_conn_geo_proximity_posonly.pdf"                // Display path to geographic proximity plot (positive only)
        di "  - $graphs/corr_by_industry.pdf"                                     // Display path to industry correlation bar graph
    }
}
