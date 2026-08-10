********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: EXPORT SAMPLE ESTABLISHMENT IDs FOR MATLAB FILTERING
* INPUT: FIRM-LEVEL RAIS DATA WITH SAMPLE FLAGS
* OUTPUT: CSV WITH VALID ESTABLISHMENT IDs (lagos_sample_avg==1 & in_balanced_panel==1)
********************************************************************************

* This script exports the list of establishment IDs that meet sample criteria
* so MATLAB can filter bilateral connectivity computation to only these firms

********************************************************************************
* Load firm-level data and extract sample establishments
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear                       // Load main firm-level dataset with CBA and RAIS merged data
keep if year == 2009                                                              // Keep only 2009 observations (sample flags are time-invariant)
keep identificad lagos_sample_avg in_balanced_panel                               // Keep establishment ID and sample restriction flags

duplicates drop identificad, force                                                // Remove duplicate establishment observations

* Apply sample restrictions
keep if lagos_sample_avg == 1                                                     // Keep only establishments in Lagos sample
keep if in_balanced_panel == 1                                                    // Keep only establishments in balanced panel

* Keep only the establishment ID
keep identificad                                                                  // Keep only establishment identifier

* Add "1" prefix to match format in employers CSV files
* This prefix was added during employers export to avoid precision loss
gen str15 identificad_prefixed = "1" + identificad                                // Add "1" prefix to establishment ID
drop identificad                                                                  // Drop original ID
rename identificad_prefixed identificad                                           // Rename prefixed ID back to identificad

* Count establishments meeting criteria
count                                                                             // Count number of establishments
di "Number of establishments meeting sample criteria: " r(N)                      // Display count

* Export to CSV for MATLAB
export delimited "$rais_aux/sample_establishments.csv", replace                   // Export establishment IDs to CSV

di _newline "Saved: $rais_aux/sample_establishments.csv"                          // Display confirmation message
di "This file will be used by MATLAB to filter bilateral connectivity computation"
