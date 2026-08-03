********************************************************************************
* duration_connectivity_check.do
*
* v2 is the only periodization that drops continuation years, and it is the only
* one whose clause-count spillover diverges (-0.0432 vs +0.019 to +0.036).
*
* Mechanism under test: under v1/v3 a firm with a long agreement contributes
* several post observations carrying the SAME clause count, so those definitions
* reweight toward firms with longer agreements. That reweighting only changes
* the estimate if agreement duration correlates with connectivity.
*
* This script measures that correlation directly, on the spillover sample.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/max_clause_row/duration_connectivity_`d'_`t'.log", replace text

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if year >= 2009
keep if lagos_sample_avg == 1

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

keep if `s_spill'

********************************************************************************
* Post-2012 agreement duration, per establishment
********************************************************************************

* Rows the firm contributes to post-treatment Decembers (v3-style: every year)
cap drop post_rows
gen byte post_row = inrange(year, 2012, 2016) & !missing(numb_clauses)
bysort identificad: egen long post_rows = total(post_row)

* Distinct agreements in force over those Decembers (v2-style: new starts only)
sort identificad year
cap drop new_agr
by identificad: gen byte new_agr = (start_date_stata != start_date_stata[_n-1]) ///
	if !missing(start_date_stata)
cap drop post_agreements
bysort identificad: egen long post_agreements = total(new_agr * inrange(year, 2012, 2016))

* Average Decembers per agreement = the reweighting factor v1/v3 apply
cap drop rows_per_agreement
gen double rows_per_agreement = post_rows / post_agreements if post_agreements > 0

preserve
	bysort identificad: keep if _n == 1
	keep if !missing(totaltreat_pw_norm)

	di as result "=== Distribution of post-2012 Decembers per agreement ==="
	tab post_agreements if post_agreements > 0
	summ rows_per_agreement, detail

	di as result ""
	di as result "=== Does the reweighting factor correlate with connectivity? ==="
	corr totaltreat_pw_norm rows_per_agreement post_rows post_agreements

	di as result ""
	di as result "=== Mean connectivity by number of post-2012 agreements ==="
	table post_agreements if post_agreements > 0, ///
		statistic(mean totaltreat_pw_norm) statistic(sd totaltreat_pw_norm) statistic(n totaltreat_pw_norm)

	di as result ""
	di as result "=== Regression: connectivity on the reweighting factor ==="
	reg totaltreat_pw_norm rows_per_agreement if post_agreements > 0, robust
restore

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Duration-connectivity check done" "does agreement length correlate with connectivity"
