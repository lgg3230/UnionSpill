********************************************************************************
* LAYER CONNECTIVITY — STANDALONE WRAPPER
* Runs both exercises in sequence:
*   1. Layer-level spillover (edu2, gender, race)  → 01a_layer_spillover.do
*   2. Horse race (edu2)                           → 02a_horse_race_edu2.do
*
* No setup required — the path to this package is detected automatically.
* Run from Stata:   do "scripts/run_all.do"
* Run from shell:   stata-mp -b do scripts/run_all.do
********************************************************************************

********************************************************************************
* AUTO-DETECT STANDALONE ROOT
* c(do_file) gives the path of this file as passed to `do`.
* If it is relative, prepend c(pwd) to make it absolute.
* Then strip /scripts/run_all.do to get the package root.
********************************************************************************

local this `"`c(do_file)'"'

* Make absolute if relative
if !regexm(`"`this'"', "^/") {
	local this `"`c(pwd)'/`this'"'
}

* Normalize double slashes
while regexm(`"`this'"', "//") {
	local this = regexr(`"`this'"', "//", "/")
}

* Strip /scripts/run_all.do
local root = subinstr(`"`this'"', "/scripts/run_all.do", "", 1)

global standalone `"`root'"'
global scripts    "$standalone/scripts"
global output     "$standalone/output"

capture mkdir "$output"

********************************************************************************
* LOG
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$output/run_all_`d'_`t'.log", replace text name(run_all_log)

di "======================================================================"
di "Layer connectivity standalone — `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"
di "Root: $standalone"
di "======================================================================"

********************************************************************************
* EXERCISE 1: Layer-level spillover (edu2, gender, race)
********************************************************************************

di _n "--- Exercise 1: layer-level spillover ---"
di "Started: `c(current_time)'"

do "$scripts/01a_layer_spillover.do"

di "Exercise 1 complete: `c(current_time)'"

********************************************************************************
* EXERCISE 2: Horse race (edu2)
********************************************************************************

di _n "--- Exercise 2: horse race (edu2) ---"
di "Started: `c(current_time)'"

do "$scripts/02a_horse_race_edu2.do"

di "Exercise 2 complete: `c(current_time)'"

********************************************************************************
* DONE
********************************************************************************

di _n "======================================================================"
di "All exercises complete: `c(current_date)' `c(current_time)'"
di "Results in: $output"
di "======================================================================"

log close run_all_log
