clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local W "`R'/Data/sample_gap_investigation/wide_2007_2016"
local fields union_id avg_file_date min_file_date max_file_date start_date_stata end_date_stata
use identificad active_year `fields' treat_ultra using "`W'/CBA_verified/collapsed_cba_firm_updated.dta",clear
keep if inrange(active_year,2009,2016) & identificad!=""
rename active_year year
isid identificad year
foreach v of local fields {
 rename `v' `v'_expected
}
rename treat_ultra treat_cba_expected
tempfile expected keys
save `expected'
use identificad year firm_emp municipio `fields' treat_cba using "`W'/rais_firm/cba_rais_firm_2007_2016.dta",clear
drop if identificad==""
isid identificad year
merge 1:1 identificad year using `expected'
keep if _merge!=2
foreach v of local fields {
 assert `v'==`v'_expected
}
assert treat_cba==treat_cba_expected
display "FULL POPULATION CBA MERGE VALUES MATCH INDEPENDENT ISOLATED BUILD"
keep identificad year firm_emp municipio
rename firm_emp firm_emp_output
rename municipio municipio_output
save `keys'
use "`W'/rais_firm/rais_firm_2007.dta",clear
forvalues y=2008/2016 {
 append using "`W'/rais_firm/rais_firm_`y'.dta"
}
merge 1:1 identificad year using `keys'
assert _merge==3
assert firm_emp==firm_emp_output
assert municipio==municipio_output
count
display "FULL POPULATION RAIS KEYS AND EMPLOYMENT MATCH: " r(N)
display "FULL MERGE CONSISTENCY COMPLETE"
