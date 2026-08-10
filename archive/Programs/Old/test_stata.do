* Test Stata script to verify environment

set more off
clear all

display "Testing Stata execution..."

* Set globals
global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"

display "Globals set successfully"
display "rais_raw_dir = $rais_raw_dir"
display "rais_aux = $rais_aux"

* Check if input files exist
capture confirm file "$rais_raw_dir/RAIS_2012.dta"
if _rc == 0 {
    display "RAIS_2012.dta exists"
}
else {
    display "ERROR: RAIS_2012.dta not found"
}

* Check if output directory exists
capture confirm file "$rais_aux/yearly_employers_2011.dta"
if _rc == 0 {
    display "yearly_employers_2011.dta exists (pre-treatment file)"
}

display "Test completed successfully!"
