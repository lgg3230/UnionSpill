********************************************************************************
* _run_tenure_hw.do
* Tenure-only hourly-wage within-firm layer exhibits using current connectivity.
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
global partitions "ten2"
global table_suffix "_ten2"

cap mkdir "$tables"
cap mkdir "$logs"

capture log close
log using "$logs/tenure_currentconn_hw.log", replace text
di as result "== Tenure within-firm exhibits: current connectivity, hourly wages =="
di as result "Started: `c(current_date)' `c(current_time)'"
do "$programs/01_within_firm_estimates_hw.do"
di as result "Finished: `c(current_date)' `c(current_time)'"
log close
