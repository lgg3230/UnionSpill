********************************************************************************
* Wrapper: 4152_recentered_eventstudy.do for one outcome.
*
* Usage:  stata-mp -b do 4151_recentered_eventstudy.do <outcome>
*   e.g.  stata-mp -b do 4151_recentered_eventstudy.do lr_remdezr_w      (monthly)
*         stata-mp -b do 4151_recentered_eventstudy.do lr_remdezr_h_w    (hourly)
*
* Defaults to the monthly outcome when called with no argument, matching the
* script's historical behaviour. Draft.tex cites the HOURLY pair
* (h_recentered_spill.pdf, h_recentered_cf.pdf), which could not be produced
* before the export filenames were parameterized in 2026-08.
********************************************************************************

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

local outcome "`1'"
if "`outcome'" == "" local outcome "lr_remdezr_w"

if !inlist("`outcome'", "lr_remdezr_w", "lr_remdezr_h_w") {
    di as error "Unrecognized outcome '`outcome''."
    di as error "Expected lr_remdezr_w (monthly) or lr_remdezr_h_w (hourly)."
    exit 198
}

global rec_outcome "`outcome'"
di as result "[_run_recentered] outcome = $rec_outcome"

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

do "$root/Programs/analysis/rand_inference/4152_recentered_eventstudy.do"
