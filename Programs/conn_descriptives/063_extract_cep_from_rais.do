/*==============================================================================
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: 063_extract_cep_from_rais.do
PURPOSE: Extract CEP (zip codes) from RAIS 2016 for sample establishments
INPUT: RAIS_2016.dta, cba_rais_firm_2009_2016_flows_1.dta
OUTPUT: establishment_cep.dta
==============================================================================*/

version 17.0
clear all
set more off

* Paths
global main "/kellogg/proj/lgg3230"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"

* ============================================================================
* STEP 1: Get list of sample establishments
* ============================================================================

di "Loading sample establishments..."
use identificad lagos_sample_avg in_balanced_panel using "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear

* Keep sample establishments (same filter as bilateral analysis)
keep if lagos_sample_avg == 1 & in_balanced_panel == 1

* Get unique establishments
duplicates drop identificad, force
count
local n_estabs = r(N)
di "Sample establishments: `n_estabs'"

* Save temp file with sample IDs
tempfile sample_estabs
save `sample_estabs'

* ============================================================================
* STEP 2: Extract CEP from RAIS 2016
* ============================================================================

di "Loading RAIS 2016 (this may take a while)..."
use identificad cepestab using "$rais_raw_dir/RAIS_2016.dta", clear

* Keep only sample establishments
di "Merging with sample establishments..."
merge m:1 identificad using `sample_estabs', keep(match) nogen

* Get one CEP per establishment (mode = most common)
di "Finding modal CEP per establishment..."
bysort identificad cepestab: gen cep_count = _N
bysort identificad (cep_count cepestab): keep if _n == _N
drop cep_count

* Keep unique establishment-CEP pairs
duplicates drop identificad, force

* Check results
count
di "Establishments with CEP: `r(N)' out of `n_estabs' sample establishments"

* Check for missing CEP
count if missing(cepestab) | cepestab == "" | cepestab == "0"
di "Missing CEP: `r(N)'"

* ============================================================================
* STEP 3: Clean CEP format
* ============================================================================

* CEP should be 8 digits - ensure it's a string and pad if needed
* If cepestab is numeric, convert to string
capture confirm string variable cepestab
if _rc {
    * It's numeric - convert to string with zero-padding
    tostring cepestab, gen(cep) format(%08.0f)
    replace cep = "" if cepestab == 0 | missing(cepestab)
}
else {
    * It's already a string - just clean it
    gen cep = cepestab
    replace cep = "" if cep == "" | cep == "0" | cep == "."
    * Pad with leading zeros if needed
    replace cep = "0" * (8 - length(cep)) + cep if length(cep) < 8 & cep != ""
}

* Keep relevant variables
keep identificad cep

* ============================================================================
* STEP 4: Save output
* ============================================================================

di "Saving establishment CEP data..."
save "$rais_aux/establishment_cep.dta", replace
export delimited "$rais_aux/establishment_cep.csv", replace

di "Done!"
di "Output: $rais_aux/establishment_cep.dta"
di "Output: $rais_aux/establishment_cep.csv"
