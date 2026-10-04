clear all
set more off
version 17.0
local base "/gpfs/kellogg/proj/lgg3230/UnionSpill"
forvalues y=2007/2016 {
 use identificad identificad_8 municipio firm_emp clascnae20 using "`base'/archive/Data/baseline_2026-09-06/rais_firm_rawmuni_backup/rais_firm_`y'.dta",clear
 gen year=`y'
 save "`base'/Data/sample_gap_investigation/wide_2007_2016/rais_firm/rais_firm_`y'.dta",replace
}
display "FULL ANNUAL INPUTS COMPLETE"
