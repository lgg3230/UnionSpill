* Wrapper: workforce-composition robustness, LOG HOURLY WAGES, CURRENT-CONNECTIVITY
* panel. Produces column (4) "Workforce Characteristics" of tab:rob_logwages.
*
* Created 2026-10-09. Until then that column existed only as a frozen snapshot
* (quality_reports/replication/hourly_variant_currentconn/frag/t_rob_hw.6col.orig.tex);
* the scripts behind it were archived and monthly-only. 3182_demo_controls.do
* reads $OUTVAR / $OUTSUF, following the 3071/3072 pattern.
set more off
set varabbrev off

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
global rais_aux  "$root/Data/RAIS_aux"
global rais_firm "$root/Data/CBA_RAIS_firm_level"
global tables    "$root/Tables/currentconn_full"
global graphs    "$root/Graphs/currentconn_full"
global logs      "$root/Logs/currentconn_full"
global programs  "$root/Programs"

global OUTVAR "lr_remdezr_h_w"
global OUTSUF "_hw"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/robustness/3182_demo_controls.do"
