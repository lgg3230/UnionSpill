* Run 3112_mincer.do with CURRENT connectivity and NATIONAL
* age-ONLY full-RAIS Mincer residuals (tenure removed from the residualization).
*
* Companion to _run_currentconn_mincer_ten_fullrais.do, which uses the
* age+tenure residuals. Firm tenure is plausibly an outcome of the reform, so
* this variant drops it from the Mincer projection and keeps only the quartic
* age polynomial within race x education x gender x year cells.
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

do "$root/Programs/analysis/_setup.do"   // Python, output folders, root memory

cap mkdir "$tables/residuals"
cap mkdir "$graphs/residuals"
cap mkdir "$logs/residuals"

* NOTE on the "_rb" file. The pre-existing mincer_residuals_firm_year_age_fullrais.csv
* is NOT used here. It does not reproduce from Programs/residuals/fullrais/, and the
* deviation is numerical (median ~1e-6, 11 firm-years above 1e-3, max 3.0e-2 in 2011)
* rather than a specification difference. Reusing it would mean the age and age+tenure
* arms were computed by different code paths, confounding the very comparison this
* run exists to make. "_rb" is the rebuilt file from the reconstructed pipeline; the
* historical file is left untouched because other tables were produced from it.
global resid_csv_name "mincer_residuals_firm_year_age_fullrais_rb.csv"
global results_suffix "_currentconn_age_fullrais_rb"

do "$programs/analysis/residuals/3112_mincer.do"
