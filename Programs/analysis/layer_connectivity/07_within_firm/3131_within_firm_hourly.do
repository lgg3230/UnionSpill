********************************************************************************
* _run_within_firm_hw_v2.do
* Wrapper for v2 hourly-wage within-firm layer exhibits (A6/A7/A8).
* Leaves the original _run_within_firm_hw.do on the old specification.
********************************************************************************

version 17.0
clear all
set more off

* -- Project root ------------------------------------------------------------
* $root if already set (e.g. by 0000_master.do), else env UNIONSPILL_ROOT, else
* the nearest folder at or above the working directory holding
* Programs/0000_master.do, else the root remembered in ~/.unionspill_root by
* the last successful run (so Stata may also be started outside the project).
if `"$root"' == "" global root : env UNIONSPILL_ROOT
if `"$root"' == "" {
	local _d = subinstr(`"`c(pwd)'"', "\", "/", .)
	while `"`_d'"' != "" & !fileexists(`"`_d'/Programs/0000_master.do"') {
		local _d = substr(`"`_d'"', 1, max(strrpos(`"`_d'"', "/") - 1, 0))
	}
	global root `"`_d'"'
}
if !fileexists(`"$root/Programs/0000_master.do"') {
	local _h : env HOME
	if `"`_h'"' == "" local _h : env USERPROFILE
	tempname _rf
	cap file open `_rf' using `"`_h'/.unionspill_root"', read text
	if !_rc {
		file read `_rf' _d
		file close `_rf'
		if fileexists(`"`_d'/Programs/0000_master.do"') global root `"`_d'"'
	}
}
if !fileexists(`"$root/Programs/0000_master.do"') {
	di as error "Project root not found. Once, start Stata inside the project folder"
	di as error "(cd there), or set env UNIONSPILL_ROOT to the folder holding Programs/."
	exit 601
}
global layer_data "$root/Data/layer_connectivity"
global conn_data  "$root/Data/layer_connectivity/final_measures"
global rais_firm  "$root/Data/CBA_RAIS_firm_level"
global rais_aux   "$root/Data/RAIS_aux"
global programs   "$root/Programs/analysis/layer_connectivity/07_within_firm"
global tables     "$root/Tables/layer_connectivity/07_within_firm"
global logs       "$root/Logs/layer_connectivity/07_within_firm"
* Canonical output names: a6_group_hw.csv, a6_partition_hw.csv, a7_hw.csv, a8_hw.csv.
* The pre-revision CSVs are archived under
* Tables/layer_connectivity/07_within_firm/archive_oldspec_2026-07-31/
* CSVs under Tables are gitignored, so that copy is their only record.
global table_suffix "_hlogic"
global SIZE_DEF "logmean"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

cap mkdir "$tables"
cap mkdir "$logs"

capture log close
log using "$logs/within_firm_hlogic_hw_v2.log", replace text
di as result "== Within-firm exhibits (A6/A7/A8): current connectivity, hourly wages, v2 spec =="
di as result "Started: `c(current_date)' `c(current_time)'"
do "$programs/3132_within_firm_hourly.do"
di as result "Finished: `c(current_date)' `c(current_time)'"
if c(os) == "Unix" shell source "$root/Programs/notify.sh" && notify "within_firm_hw_v2" "Hourly v2 within-firm Stata job finished"
log close
