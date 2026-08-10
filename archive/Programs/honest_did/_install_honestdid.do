********************************************************************************
* _install_honestdid.do
* One-time install of the Stata honestdid package (Rambachan-Roth sensitivity
* analysis, Caceres port) plus coefplot for plotting. Not on SSC; pulled from
* the author's GitHub. Safe to re-run (replace).
********************************************************************************

version 17.0
set more off

di as result "=== Installing honestdid from GitHub ==="
cap net install honestdid, ///
    from("https://raw.githubusercontent.com/mcaceresb/stata-honestdid/main") replace
di as result "net install rc = " _rc

di as result "=== Ensuring coefplot is installed ==="
cap which coefplot
if _rc {
    cap ssc install coefplot, replace
    di as result "coefplot ssc rc = " _rc
}

di as result "=== Verifying honestdid loads ==="
which honestdid
honestdid _plugin_check

di as result "=== DONE ==="
