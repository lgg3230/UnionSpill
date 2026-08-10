********************************************************************************
* CBA VALUE — LAGOS-STYLE DIRECT EFFECT
* Mirrors Table 7 of Lagos (2026): simple 2x2 DiD using post_treat_cba,
* Panel C sample, establishment + industry x cba_period + microregion x
* cba_period + mode_base_month x cba_period FEs. No pre-treatment bin controls.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/cba_value/lagos_spec_direct_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

* ── Data ─────────────────────────────────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore

cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

keep if year >= 2009
keep if lagos_sample_avg == 1

* ── CBA period ───────────────────────────────────────────────────────────────

cap drop cba_period
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* ── Sample ───────────────────────────────────────────────────────────────────

local s_C "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(cba_period)"
local fe  "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"

* ── Baseline means ───────────────────────────────────────────────────────────

quietly sum cba_value    if `s_C' & inrange(cba_period, 1, 2)
local mean_cba   = r(mean)
quietly sum numb_clauses if `s_C' & inrange(cba_period, 1, 2)
local mean_nc    = r(mean)

di as result "Baseline mean cba_value:    " %9.4f (`mean_cba')
di as result "Baseline mean numb_clauses: " %9.4f (`mean_nc')

* ── Regressions ──────────────────────────────────────────────────────────────

foreach outcome in cba_value numb_clauses {

	di _newline(1)
	di as result "Outcome: `outcome'"

	reghdfe `outcome' i.treat_ultra##post_treat_cba if `s_C', ///
		absorb(`fe') vce(cluster identificad)

	di as result "  Post effect (treat x post): " %9.4f (_b[1.treat_ultra#1.post_treat_cba]) ///
		"  SE: " %9.4f (_se[1.treat_ultra#1.post_treat_cba])
	di as result "  N obs: "    e(N) "   N estab: " e(N_clust)
}

* ── Done ─────────────────────────────────────────────────────────────────────

log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "lagos_spec done" "lagos_spec_direct.do finished"
