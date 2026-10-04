clear all
set more off
version 17.0
local W "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016"
local fields identificad active_year union_id avg_file_date min_file_date max_file_date start_date_stata end_date_stata treat_ultra
use `fields' using "`W'/CBA/collapsed_cba_firm_updated.dta",clear
sort `fields'
tempfile first
save `first'
use `fields' using "`W'/CBA_verified/collapsed_cba_firm_updated.dta",clear
sort `fields'
cf _all using `first',all
display "INDEPENDENT CBA BUILDS AGREE ON ALL MEMBERSHIP INPUTS"
