clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local X "`R'/Data/recovered_sample_validation"
local W "`R'/Data/sample_gap_investigation/wide_2007_2016"
use if lagos_sample_avg==1 using "`W'/rais_firm/cba_rais_firm_2007_2016.dta",clear
isid identificad year
save "`X'/firm/recovered_cba_panel.dta",replace
preserve
keep identificad
duplicates drop
tempfile ids
save `ids'
export delimited using "recovered_unbalanced_ids.csv",replace
restore
forvalues y=2007/2016 {
 use "`R'/archive/Data/baseline_2026-09-06/rais_firm_rawmuni_backup/rais_firm_`y'.dta",clear
 merge 1:1 identificad using `ids',keep(match) nogen
 if `y'>2007 append using "`X'/firm/annual_outcomes.dta"
 save "`X'/firm/annual_outcomes.dta",replace
}
use "`X'/firm/recovered_cba_panel.dta",clear
merge 1:1 identificad year using "`X'/firm/annual_outcomes.dta",keep(master match)
assert _merge==3
drop _merge
save "`X'/firm/recovered_preconnectivity.dta",replace
display "RECOVERED ANNUAL OUTCOMES EXTRACTED"
