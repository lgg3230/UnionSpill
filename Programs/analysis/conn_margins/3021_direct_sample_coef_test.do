* Wrapper: direct-effect Panel A vs Panel C equality test, CURRENT-CONNECTIVITY.
*
* Created 2026-08-01. The Replication document's Direct Effects table prints a
* $p$-value row ([0.009] [0.013] [0.741] [0.386]) that no committed script
* reproduced: 3022_direct_sample_coef_test.do ran against the frozen panel and its
* saved CSV covered only 2 of the 4 outcomes. This wrapper runs the same script
* on the overlay for all four, writing a suffixed CSV so the legacy output is
* preserved for comparison.
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
global rais_firm "$root/Data/CBA_RAIS_firm_level"
global rais_aux  "$root/Data/RAIS_aux"
global tables    "$root/Tables"
global logs      "$root/Logs"
global testsuf   "_currentconn"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$root/Programs/analysis/conn_margins/3022_direct_sample_coef_test.do"
