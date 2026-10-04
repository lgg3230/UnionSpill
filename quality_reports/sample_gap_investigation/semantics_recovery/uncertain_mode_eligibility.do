clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local W "`R'/Data/sample_gap_investigation/wide_2007_2016"
import delimited using "wide_mode_uncertainty.csv",clear stringcols(1)
keep identificad
gen identificad_8=substr(identificad,1,8)
isid identificad_8
tempfile uncertain annual allannual
save `uncertain'
forvalues y=2009/2016 {
 use identificad firm_emp using "`W'/rais_firm/rais_firm_`y'.dta",clear
 merge 1:1 identificad using `uncertain'
 keep if _merge==3
 drop _merge
 gen year=`y'
 if `y'>2009 append using `allannual'
 save `allannual',replace
}
collapse (count) years_present=year (min) min_emp=firm_emp,by(identificad identificad_8)
save `annual'
use identificad_8 contract_id using "`R'/Data/CBA/cba_firm_exploded.dta",clear
merge m:1 identificad_8 using `uncertain'
keep if _merge!=1
gen byte has_contract=!missing(contract_id)
collapse (sum) potential_cba_rows=has_contract,by(identificad identificad_8)
merge 1:1 identificad using `annual'
gen byte possibly_membership_relevant=years_present==8 & potential_cba_rows>0
export delimited using "uncertain_mode_eligibility.csv",replace
list,noobs
count if possibly_membership_relevant
display "UNCERTAIN POSSIBLY RELEVANT: " r(N)
display "UNCERTAIN ELIGIBILITY COMPLETE"
