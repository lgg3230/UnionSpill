********************************************************************************
* PROJECT: UNION SPILLOVERS
* FIX: Generate missing employers transition matrices (2011-2012 and 2015-2016)
********************************************************************************

set more off
set varabbrev off
clear all
version 17.0

global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"

* Create missing transition matrices (only CSV, no .dta to save disk space)
foreach pair in "2011 2012" "2015 2016" {
    local i = word("`pair'", 1)
    local j = word("`pair'", 2)

    di "Processing transition matrix for `i'-`j'..."

    use "$rais_aux/yearly_employers_`i'.dta", clear

    merge 1:1 PIS using "$rais_aux/yearly_employers_`j'.dta"

    // Keep only workers who transitioned between establishments
    keep if _merge == 3
    drop _merge

    // Add leading 1 to identifiers (same format as pre-period)
    replace identificad_`i' = "1" + identificad_`i'
    replace identificad_`j' = "1" + identificad_`j'

    replace identificad8_`i' = "1" + identificad8_`i'
    replace identificad8_`j' = "1" + identificad8_`j'

    export delimited "$rais_aux/employers_`i'_`j'.csv", replace

    di "Created transition matrix for `i'-`j'"
}

di "Note: Not saving .dta files to conserve disk space"
di "All missing transition matrices created successfully!"
