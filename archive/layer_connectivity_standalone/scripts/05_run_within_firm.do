********************************************************************************
* 05_run_within_firm.do
* Within-firm group-level exhibits (A6/A7/A8) on LOG MONTHLY WAGES.
* Produces the estimates behind Tables 10, 11 and 12.
*
* Uses the CURRENT recomputable firm connectivity measure.
*
* Run from Stata:   do "scripts/05_run_within_firm.do"
* Run from shell:   stata-mp -b do scripts/05_run_within_firm.do
*
* MUST BE ITS OWN STATA PROCESS. Do not call this from run_all.do and do not
* run it after another estimation exercise in the same session: reghdfe's
* solver picks up session state and the ten2 group-level coefficients move in
* the 6th significant digit. "clear all" between exercises is NOT sufficient.
* run_all.sh invokes this in a separate Stata process for exactly this reason.
********************************************************************************

version 17.0
clear all
set more off

********************************************************************************
* AUTO-DETECT STANDALONE ROOT
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

* Strip /scripts/05_run_within_firm.do
local root = subinstr(`"`this'"', "/scripts/05_run_within_firm.do", "", 1)

global standalone `"`root'"'
global scripts    "$standalone/scripts"
global output     "$standalone/output"

capture mkdir "$output"

capture log close within_firm_log
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$output/within_firm_`d'_`t'.log", replace text name(within_firm_log)

di as result "--- Within-firm exhibits (A6/A7/A8): log monthly wages ---"
di as result "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* MONTHLY PASS -> a6_group.csv, a6_partition.csv, a7.csv, a8.csv
********************************************************************************

global wf_wage_firm  "lr_remdezr_w"
global wf_wage_layer "lr_remdezr_layer"
global wf_suffix     ""
global wf_partitions "edu2 gender ten2"

do "$scripts/05a_within_firm_estimates.do"

di as result "Finished: `c(current_date)' `c(current_time)'"

log close within_firm_log

********************************************************************************
* END
********************************************************************************
