* Wrapper: set globals then run 3012_pct_tfpw.do (cluster,
* CURRENT CONNECTIVITY).
*
* Identical to _run_pct_tfpw_07_11_cluster.do except that rais_firm points at
* the current-connectivity overlay panel instead of the frozen one. The Lagos
* firm panel ships a frozen totaltreat_pw_n; the overlay directory carries the
* recomputable measure. 3012_pct_tfpw.do rebuilds
* totaltreat_pw_norm from totaltreat_pw_n's 2009 p90 itself (lines 140-146), so
* swapping the input directory is sufficient - the regressor is renormalized on
* the current measure rather than left on the legacy p90.
*
* Tables, graphs, and logs are written to dedicated pct_tfpw_cc/ subfolders so
* this run cannot overwrite the frozen-connectivity outputs already tracked.

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
global tables    "$root/Tables/pct_tfpw_cc"
global graphs    "$root/Graphs/pct_tfpw_cc"
global logs      "$root/Logs/pct_tfpw_cc"
global programs  "$root/Programs"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$programs/analysis/main_results/3012_pct_tfpw.do"
