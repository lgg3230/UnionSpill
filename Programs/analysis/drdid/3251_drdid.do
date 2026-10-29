* Wrapper: doubly robust DiD (Sant'Anna & Zhao 2020) for the main direct and
* spillover effects, CURRENT-CONNECTIVITY panel. Sets globals, then runs
* 3252_drdid.do. Outputs go to Tables/drdid/, Graphs/drdid/, Logs/drdid/.
* it feeds the main draft.
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
global tables    "$root/Tables/drdid"
global graphs    "$root/Graphs/drdid"
global logs      "$root/Logs/drdid"
global programs  "$root/Programs"

global DRDID_GEO "uf"
global DRDID_IND "ind2"
global DRDID_TAG ""

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/drdid/3252_drdid.do"
