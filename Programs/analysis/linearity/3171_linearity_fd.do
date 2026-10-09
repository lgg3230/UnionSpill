* Wrapper: set globals then run 3172_linearity_fd.do (first-difference
* linearity test with the same bins as the TWFE test 3142, both run side by
* side).
*
* PANEL: the canonical Data/CBA_RAIS_firm_level, which now holds the July 2026
* current-connectivity overlay (copied there 2026-10-08), the vintage behind the
* published spillover table (Draft.tex: 0.0050 / 0.0065 / 0.0009 / 0.0227), not
* the Sep-14 panel rebuilt from raw RAIS. 3162 rebuilds totaltreat_pw_norm from
* this panel's own p90, avoiding the overlay's stale legacy-divisor column.

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
global tables    "$root/Tables/linearity"
global logs      "$root/Logs/linearity"
global programs  "$root/Programs"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/linearity/3172_linearity_fd.do"
