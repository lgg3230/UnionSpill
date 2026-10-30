* Wrapper: set globals then run 3152_linearity_bins.do with the baseline group
* set to establishments with raw connectivity totaltreat_pw_n < 0.01 (the
* "<= 1% connectivity" control cut used in 3012 Panel B, here strict). The
* connectivity groups (median, terciles, quartiles) split the establishments
* at or above 0.01. Outputs carry the suffix _lt01.

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
global graphs    "$root/Graphs/linearity"
global logs      "$root/Logs/linearity"
global programs  "$root/Programs"

global base_lt    "0.01"
global out_suffix "_lt01"
global bin_ks     ""

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/linearity/3152_linearity_bins.do"
