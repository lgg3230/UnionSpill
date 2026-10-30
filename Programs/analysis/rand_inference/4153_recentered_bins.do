********************************************************************************
* Wrapper: 4152_recentered_eventstudy.do for each reshuffle scheme (Referee 3).
* Counterfactual connectivity from industry x negotiation-month cells, alone and
* split by pre-treatment size or hourly-wage quartiles, deciles and vingtiles
* (mu_C_* from 2108_expected_exposure_bins.py). ind_month is the draft's scheme.
*
* Usage:  stata-mp -b do 4153_recentered_bins.do
* Output: Tables/rand_inference/recentered_bins.csv  (one row per outcome x scheme)
*         Tables/rand_inference/recentered_bins.tex  (4154)
*         Graphs/rand_inference/bins/es_{spill,counterfactual}_<outcome>_<scheme>.pdf
********************************************************************************

set more off
set varabbrev off

* -- Project root (as 4151) ----------------------------------------------------
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

if "$tables" == "" global tables "$root/Tables/rand_inference"
if "$graphs" == "" global graphs "$root/Graphs/rand_inference/bins"
if "$logs"   == "" global logs   "$root/Logs/rand_inference"
do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

global rec_mufile "expected_exposure_bins.dta"
global rec_csv    "$tables/recentered_bins.csv"
tempname fh
file open `fh' using "$rec_csv", write replace
file write `fh' "outcome,mu,b_main,se_main,b_adj,se_adj,b_mu,se_mu,p_main,p_adj,p_mu,n_obs,n_estab" _n
file close `fh'

local schemes "ind_month ind_month_size4 ind_month_size10 ind_month_size20 ind_month_wage4 ind_month_wage10 ind_month_wage20"
foreach out in lr_remdezr_h_w lr_remdezr_w {
	foreach s of local schemes {
		global rec_outcome "`out'"
		global rec_mu      "mu_C_`s'"
		global rec_tag     "_`s'"
		do "$root/Programs/analysis/rand_inference/4152_recentered_eventstudy.do"
	}
}
global rec_tag ""
global rec_csv ""

shell "$python_exe" "$root/Programs/analysis/rand_inference/4154_recentered_bins_table.py" "$randdir" "$tables"
di as result "Table written to $tables/recentered_bins.tex"
if c(os) == "Unix" shell source "$root/Programs/notify.sh" && notify "Recentered bins done" "4153 recentered_bins"
