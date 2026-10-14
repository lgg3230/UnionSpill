* Wrapper: set globals then run 3162_pure_control_cutoff.do with the FINE
* cutoff set.
*
* Direct effects (4 headline outcomes) re-estimated with the pure-control group
* widened from zero connectivity to totaltreat_pw_n <= c, for c at the
* vingtiles (p05 ... p95; the deciles are the even ones) of positive
* connectivity among untreated firms, plus wage event studies at p05, p10,
* p20 and p50. Outputs go to Tables/ and Graphs/pure_control_cutoff_fine/, so
* the coarse run of 3161 (terciles/quartiles) is left untouched.
*
* INPUT PANEL and replication gate: as in 3161_pure_control_cutoff.do.

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
global tables    "$root/Tables/pure_control_cutoff_fine"
global graphs    "$root/Graphs/pure_control_cutoff_fine"
global logs      "$root/Logs/pure_control_cutoff_fine"
global programs  "$root/Programs"
global pcc_set   "fine"     // vingtiles; 3161 runs the coarse set

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/pure_control_cutoff/3162_pure_control_cutoff.do"
