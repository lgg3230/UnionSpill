********************************************************************************
* check_setup.do -- run this first. Checks everything the analysis/ scripts
* need (Stata version and packages, Python and its packages, the Data/ inputs)
* and prints what is missing and how to fix it. Its only side effects are
* those of analysis/_setup.do: it remembers the project root in
* ~/.unionspill_root.
*
* Usage: in Stata, cd anywhere inside the project, then
*          do Programs/analysis/check_setup.do
*        or from a terminal, inside the project:
*          stata-mp -b do Programs/analysis/check_setup.do
********************************************************************************

set more off
set varabbrev off

* -- Project root (same block as every wrapper) --------------------------------
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
	di as error "Project root not found. cd into the project folder in Stata and rerun."
	exit 601
}

local nfail = 0
di as result _n "Project root: $root" _n

* -- 1. Stata -----------------------------------------------------------------------
di as result "== Stata"
if c(stata_version) < 17 {
	di as error "  FAIL  Stata `c(stata_version)': version 17 or later required"
	local ++nfail
}
else di as text "  ok    Stata `c(stata_version)' (`c(edition_real)')"

* command -> install line. binstest ships with binsreg; reghdfe needs ftools.
local pk_ftools   "ssc install ftools, replace"
local pk_reghdfe  "ssc install reghdfe, replace"
local pk_binstest "ssc install binsreg, replace"
local pk_coefplot "ssc install coefplot, replace"
local pk_distinct "ssc install distinct, replace"
foreach c in ftools reghdfe binstest coefplot distinct {
	cap which `c'
	if _rc {
		di as error "  FAIL  `c' not installed -> `pk_`c''"
		local ++nfail
	}
	else di as text "  ok    `c'"
}

* -- 2. Python ----------------------------------------------------------------------
di as result _n "== Python"
run "$root/Programs/analysis/_setup.do"   // quietly: Python detection, root memory
tempfile _pyout
cap erase "`_pyout'"
shell $python_exe -I -c "import importlib.util as u, sys; req=['pandas','numpy','matplotlib']; opt=['pyfixest','fitz']; f=open(r'`_pyout'','w'); f.write(sys.version.split()[0]+'\n'); [f.write(('ok ' if u.find_spec(m) else 'missing ')+('required ' if m in req else 'optional ')+m+'\n') for m in req+opt]"
if !fileexists("`_pyout'") {
	di as error "  FAIL  could not run Python ($python_exe)."
	di as error "        Install Python 3.9+ with: pip install pandas numpy matplotlib"
	di as error "        or set env UNIONSPILL_PYTHON to an interpreter that has them."
	local ++nfail
}
else {
	tempname _fh
	file open `_fh' using "`_pyout'", read text
	file read `_fh' _ver
	di as text "  ok    Python `_ver' at $python_exe"
	file read `_fh' _line
	while r(eof) == 0 {
		local _st  : word 1 of `_line'
		local _req : word 2 of `_line'
		local _mod : word 3 of `_line'
		local _pip = cond("`_mod'" == "fitz", "pymupdf", "`_mod'")
		local _why = cond("`_mod'" == "pyfixest", " (only rand_inference/4130 figure)", ///
		             cond("`_mod'" == "fitz", " (only the optional --preview PDFs)", ""))
		if "`_st'" == "ok" di as text "  ok    `_mod'"
		else if "`_req'" == "required" {
			di as error "  FAIL  `_mod' missing -> $python_exe -m pip install `_pip'"
			local ++nfail
		}
		else di as text "  warn  `_mod' missing`_why' -> pip install `_pip'"
		file read `_fh' _line
	}
	file close `_fh'
}

* -- 3. Data/ inputs ------------------------------------------------------------------
di as result _n "== Data/ inputs read by analysis/"
local inputs ""
local inputs `"`inputs' "Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta""'
local inputs `"`inputs' "Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv""'
local inputs `"`inputs' "Data/CBA_RAIS_firm_level/avg_age_firm_year.csv""'
local inputs `"`inputs' "Data/CBA_RAIS_firm_level/cba_value_firm_year.csv""'
local inputs `"`inputs' "Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_age_fullrais_rb.csv""'
local inputs `"`inputs' "Data/RAIS_aux/totalflows_wide_2007_2011.csv""'
local inputs `"`inputs' "Data/RAIS_aux/totalflows_panel_2009_2016.csv""'
local inputs `"`inputs' "Data/RAIS_aux/network_degree_full_rais.csv""'
local inputs `"`inputs' "Data/RAIS_aux/connectivity_post_treat_agg.dta""'
local inputs `"`inputs' "Data/rand_inference/spill_frame.dta""'
local inputs `"`inputs' "Data/rand_inference/expected_exposure.dta""'
local inputs `"`inputs' "Data/layer_connectivity/firm_layer_outcomes_edu2.dta""'
local inputs `"`inputs' "Data/layer_connectivity/firm_layer_outcomes_gender.dta""'
local inputs `"`inputs' "Data/layer_connectivity/firm_layer_outcomes_ten2.dta""'
local inputs `"`inputs' "Data/layer_connectivity/final_measures/firm_layer_connectivity_edu2.dta""'
local inputs `"`inputs' "Data/layer_connectivity/final_measures/firm_layer_connectivity_gender.dta""'
local inputs `"`inputs' "Data/layer_connectivity/final_measures/firm_layer_connectivity_ten2.dta""'
local inputs `"`inputs' "Docs/fixtures/figure_A2/coef_connectivity_univ.csv""'
foreach f of local inputs {
	if fileexists(`"$root/`f'"') di as text "  ok    `f'"
	else {
		di as error "  FAIL  missing `f'"
		local ++nfail
	}
}
* the real turnover file is ~27 MB; a 47-byte header-only stub breaks 3082
tempname _tf
cap file open `_tf' using `"$root/Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv"', read binary
if !_rc {
	file seek `_tf' eof
	file seek `_tf' query
	if r(loc) < 1000000 {
		di as error "  FAIL  Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv is only `r(loc)' bytes (a stub)"
		local ++nfail
	}
	file close `_tf'
}

* -- 4. Optional: LaTeX ---------------------------------------------------------------
tempfile _tex
cap erase "`_tex'"
if c(os) == "Windows" shell where pdflatex > "`_tex'" 2>NUL
else                  shell command -v pdflatex > "`_tex'" 2>/dev/null
cap confirm file "`_tex'"
local _hastex = 0
if !_rc {
	tempname _xf
	file open `_xf' using "`_tex'", read text
	file read `_xf' _line
	file close `_xf'
	if `"`_line'"' != "" local _hastex = 1
}
di as result _n "== Optional"
if `_hastex' di as text "  ok    pdflatex (only for --preview PDFs of some tables)"
else         di as text "  warn  pdflatex not found (only needed for --preview PDFs of some tables)"

di as result _n cond(`nfail' == 0, "All required checks passed.", "`nfail' required check(s) failed; fix the FAIL lines above.")
