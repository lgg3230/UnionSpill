clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local W "`R'/Data/sample_gap_investigation/wide_2007_2016"
import delimited using "../discrepant_ids.csv",clear stringcols(1)
isid identificad
tempfile cases
save `cases'
use identificad year municipio firm_emp union_id avg_file_date min_file_date max_file_date start_date_stata end_date_stata cba2009_avg cba_pre2012_avg cba_post2012_avg lagos_sample_avg in_balanced_panel pos_emp treat_ultra using "`W'/rais_firm/cba_rais_firm_2007_2016.dta",clear
merge m:1 identificad using `cases'
keep if _merge==3
drop _merge
isid identificad year
export delimited using "wide_case_panel.csv",replace
save "`W'/rais_firm/discrepancy_case_panel.dta",replace
use identificad identificad_8 municipio state pair_id contract_id union_id start_year file_year end_year start_date_stata file_date_stata end_date_stata codigo_municipio using "`W'/CBA/cba_estab_firm.dta",clear
merge m:1 identificad using `cases'
keep if _merge==3
drop _merge
export delimited using "wide_case_cba_matches.csv",replace
display "WIDE CASE EXTRACTION COMPLETE"
