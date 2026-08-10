********************************************************************************
* _run_within_firm_v2.do
* Wrapper for v2 within-firm layer exhibits (A6/A7/A8).
* Leaves the original _run_within_firm.do on the old specification.
********************************************************************************

version 17.0
clear all
set more off

global main       "/kellogg/proj/lgg3230"
global root       "$main/UnionSpill"
global layer_data "$root/Data/layer_connectivity"
global conn_data  "$root/Data/layer_connectivity/final_measures"
global rais_firm  "$root/Data/CBA_RAIS_firm_level_currentconn_overlay"
global rais_aux   "$root/Data/RAIS_aux"
global programs   "$root/Programs/layer_connectivity/07_within_firm"
global tables     "$root/Tables/layer_connectivity/07_within_firm"
global logs       "$root/Logs/layer_connectivity/07_within_firm"
* Canonical output names: a6_group.csv, a6_partition.csv, a7.csv, a8.csv.
* The pre-revision CSVs are archived under
* Tables/layer_connectivity/07_within_firm/archive_oldspec_2026-07-31/
* CSVs under Tables are gitignored, so that copy is their only record.
global table_suffix "_hlogic"
global SIZE_DEF "logmean"

cap mkdir "$tables"
cap mkdir "$logs"

capture log close
log using "$logs/within_firm_hlogic_v2.log", replace text
di as result "== Within-firm exhibits (A6/A7/A8): current connectivity, v2 spec =="
di as result "Started: `c(current_date)' `c(current_time)'"
do "$programs/4122_within_firm.do"
di as result "Finished: `c(current_date)' `c(current_time)'"
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "within_firm_v2" "Monthly v2 within-firm Stata job finished"
log close
