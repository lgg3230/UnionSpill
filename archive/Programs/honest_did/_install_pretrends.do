********************************************************************************
* _install_pretrends.do
* One-time install of the Stata pretrends package (Roth 2022 power diagnostics,
* Caceres port). Not on SSC; pulled from the author's GitHub. No solver plugins
* required. Safe to re-run (replace).
********************************************************************************
version 17.0
set more off

di as result "=== Installing pretrends from GitHub ==="
cap net install pretrends, ///
    from("https://raw.githubusercontent.com/mcaceresb/stata-pretrends/main") replace
di as result "net install rc = " _rc

di as result "=== Verifying pretrends loads ==="
cap which pretrends
di as result "which rc = " _rc
if _rc == 0 which pretrends

di as result "=== DONE ==="
