********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: PROCESS MUNICIPALITY CENTROID DATA
* INPUT: municipio_centroid.csv with POINT(longitude latitude) format
* OUTPUT: municipality_coordinates.dta with municipio, latitude, longitude
********************************************************************************

* This script processes the municipality centroid data from IBGE
* The centroide column contains coordinates in format: POINT(-61.88 -11.47)
* First number is longitude, second is latitude (separated by space)
*
* NOTE: Run 00_master.do first to define global paths, or define manually:
*       global ibge "/kellogg/proj/lgg3230/UnionSpill/Data/IBGE"

********************************************************************************
* STEP 1: Import the raw centroid data
********************************************************************************

import delimited "$ibge/municipio_centroid.csv", clear varnames(1)              // Import CSV with municipality centroids

* Keep only the columns we need
* NOTE: Using id_municipio_6 (6-digit) since RAIS data uses 6-digit municipality codes
keep id_municipio_6 centroide                                                    // Keep 6-digit municipality ID and centroid column
rename id_municipio_6 id_municipio                                               // Rename to standard name for processing

* Display sample of raw data
di _newline "Sample of raw centroide data:"
list id_municipio centroide in 1/5                                               // Show first 5 rows

********************************************************************************
* STEP 2: Parse the POINT format to extract longitude and latitude
********************************************************************************

* The format is: POINT(-61.8800839234306 -11.4707893352808)
* We need to extract the two numbers separated by a space

* Step 2a: Remove "POINT(" prefix and ")" suffix
gen coords = subinstr(centroide, "POINT(", "", .)                                // Remove "POINT(" from the beginning
replace coords = subinstr(coords, ")", "", .)                                    // Remove ")" from the end

* Display intermediate result
di _newline "After removing POINT():"
list id_municipio coords in 1/5                                                  // Show first 5 rows

* Step 2b: Extract longitude (first word) and latitude (second word) using word() function
* word() splits strings by spaces, so word(coords, 1) gets first number, word(coords, 2) gets second
gen str50 longitude_str = word(coords, 1)                                        // Extract longitude as string (first space-separated word)
gen str50 latitude_str = word(coords, 2)                                         // Extract latitude as string (second space-separated word)

* Step 2c: Convert to numeric
destring longitude_str, gen(longitude) force                                     // Convert longitude string to numeric
destring latitude_str, gen(latitude) force                                       // Convert latitude string to numeric

* Display parsed results
di _newline "Parsed coordinates:"
list id_municipio longitude latitude in 1/10                                     // Show first 10 rows

********************************************************************************
* STEP 3: Clean up and prepare final dataset
********************************************************************************

* Keep only required variables
keep id_municipio longitude latitude                                             // Keep municipality ID and coordinates

* Rename to match expected format
rename id_municipio municipio                                                    // Rename to standard name

* Ensure municipio is numeric
capture confirm string variable municipio                                        // Check if municipio is string
if _rc == 0 {                                                                    // If string
    destring municipio, replace force                                            // Convert to numeric
}

* Drop observations with missing coordinates
drop if missing(longitude) | missing(latitude)                                   // Remove rows with missing coordinates

* Display summary statistics
di _newline "=== Summary Statistics ==="
summarize municipio longitude latitude                                           // Display summary stats

di _newline "Coordinate ranges:"
di "  Latitude range: " %9.4f = r(min) " to " %9.4f = r(max)
summarize latitude, meanonly
di "  Latitude range: " %9.4f `r(min)' " to " %9.4f `r(max)'
summarize longitude, meanonly
di "  Longitude range: " %9.4f `r(min)' " to " %9.4f `r(max)'

* Count municipalities
count                                                                            // Count number of municipalities
di _newline "Total municipalities with coordinates: " r(N)

********************************************************************************
* STEP 4: Save the processed data
********************************************************************************

* Order variables
order municipio latitude longitude                                               // Order variables: ID first, then coordinates

* Compress and save
compress                                                                         // Optimize storage
save "$ibge/municipality_coordinates.dta", replace                               // Save as Stata dataset

di _newline "Saved: $ibge/municipality_coordinates.dta"
di "This file is now ready for use in 06_bilateral_descriptives.do"
