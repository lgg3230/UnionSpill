********************************************************************************
* max_clause_row.do
*
* One row per identificad x cba_period for CBA-outcome regressions.
*
* Motivation: CBA outcomes are measured per agreement but the panel is
* firm-year, so one agreement can occupy several rows. In the numb_clauses
* spillover sample, 1,914 of 17,742 identificad x cba_period cells hold more
* than one row (3,865 of 19,693 observations). In 1,252 of those cells the
* clause count is constant and in 962 the agreement is literally identical
* (same avg_file_date), so the extra rows add estimation weight without adding
* identifying variation.
*
* Filter: within each identificad x cba_period cell holding MORE THAN ONE row,
* keep only the row with the highest numb_clauses. Ties broken deterministically
* by (1) highest numb_clauses, (2) earliest avg_file_date, (3) earliest year.
* Cells that already hold one row are untouched.
*
* Both arms (baseline, filtered) run in this single Stata process so the
* comparison is internal and immune to session-state drift.
*
* Data prep is copied verbatim from the three source scripts:
*   Programs/main_results/panelC_and_spill_numb_clauses.do
*   Programs/clause_types/clause_types.do
*   Programs/cba_value/Main_Results_cba_value.do
* which all load the same panel and use the same cba_period FE structure.
*
* Output: Tables/max_clause_row/max_clause_comparison.csv  (CSV only; the
*         LaTeX table is built by generate_max_clause_latex.py)
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"

* Current-recomputable-connectivity overlay panel — this is the panel behind
* the published replication table (Replication_Wages vs Hourly.tex, Table 3),
* whose spillover benchmark is 0.0227 (0.1175). The legacy panel at
* .../CBA_RAIS_firm_level uses totaltreat_pw_n from the older connectivity
* build and yields 0.0180 on the identical sample.
* totaltreat_pw_norm is rebuilt below from this panel's own p90, so the
* overlay's stale legacy divisor is never used.
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/max_clause_row/max_clause_row_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD AND MERGE
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* CBA value score (from Main_Results_cba_value.do)
preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore
cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

* Total flows (all three scripts)
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 1b: CLAUSE-TYPE VARIABLES (verbatim from clause_types.do SECTION 2)
********************************************************************************

cap drop wage_clauses
cap drop emp_clauses
cap drop other_clauses
cap drop wage_clause_prop
cap drop emp_clause_prop
cap drop other_clause_prop
gen int wage_clauses  = 0
gen int emp_clauses   = 0
gen int other_clauses = 0

ds cl_*
local clause_vars `r(varlist)'

foreach v of local clause_vars {
	if substr("`v'", 4, 1) == "1" {
		replace wage_clauses = wage_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "3", "4") {
		replace emp_clauses = emp_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "2", "5", "6", "7", "8", "9") {
		replace other_clauses = other_clauses + cond(missing(`v'), 0, `v')
	}
}

gen double wage_clause_prop  = wage_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double emp_clause_prop   = emp_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double other_clause_prop = other_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)

********************************************************************************
* SECTION 2: CBA PERIOD AND TREATMENT TIMING
********************************************************************************

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

********************************************************************************
* SECTION 3: CONTROLS — BUILT ON THE FULL PANEL, BEFORE ANY FILTERING
*
* Critical: the p90 normalization reads `if year == 2009` rows and the _pre4
* bins read cba_period 1-2 rows. Filtering before this point would silently
* redefine the controls and confound the row restriction with a control change.
********************************************************************************

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* Outcome-specific pre-treatment bins (cba_period 1-2 mean, quartile at 2009)
foreach v in numb_clauses wage_clauses emp_clauses other_clauses ///
             wage_clause_prop emp_clause_prop other_clause_prop cba_value {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

di as result "Controls built on full panel."

tempfile prepped
save `prepped'

********************************************************************************
* SECTION 4: OUTPUT CSV
********************************************************************************

tempname pf
tempfile pf_data
postfile `pf' str16 regression str20 outcome str10 arm str12 stat double value ///
	using `pf_data', replace

********************************************************************************
* SECTION 5: BOTH ARMS
********************************************************************************

local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

local spill_outcomes "numb_clauses wage_clauses emp_clauses other_clauses wage_clause_prop emp_clause_prop other_clause_prop cba_value"

foreach arm in baseline filtered {

	use `prepped', clear

	di _newline(2)
	di as result "======================================================================"
	di as result "ARM: `arm'"
	di as result "======================================================================"

	if "`arm'" == "filtered" {

		* ── THE FILTER ──────────────────────────────────────────────────────
		* Within each identificad x cba_period cell with >1 row, keep the row
		* with the highest numb_clauses. Tie-break: earliest avg_file_date,
		* then earliest year. Rows with missing numb_clauses sort last, so they
		* survive only when they are the sole row in the cell.

		count
		local n_before = r(N)

		cap drop _negclauses
		gen double _negclauses = -numb_clauses

		sort identificad cba_period _negclauses avg_file_date year

		cap drop _rank
		cap drop _ncell
		by identificad cba_period: gen long _rank  = _n
		by identificad cba_period: gen long _ncell = _N

		count if !missing(cba_period) & _ncell > 1
		di as result "  rows in multi-row cells: " r(N)

		drop if !missing(cba_period) & _rank > 1

		count
		di as result "  rows before filter: `n_before'"
		di as result "  rows after  filter: " r(N)

		* Uniqueness assertion
		preserve
			keep if !missing(cba_period)
			isid identificad cba_period
			di as result "  isid identificad cba_period: PASSED"
		restore

		cap drop _negclauses
		cap drop _rank
		cap drop _ncell
	}

	* ── DIRECT EFFECTS: numb_clauses, samples A and C ───────────────────────

	foreach panel in A C {

		if "`panel'" == "A" local s_use "`s_direct_A'"
		if "`panel'" == "C" local s_use "`s_direct_C'"

		local outcome "numb_clauses"
		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		di as text "  direct_`panel': `outcome' (`arm')"

		reghdfe `outcome' i.treat_ultra##post_treat_cba ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.post_treat_cba]
		local se_post = _se[1.treat_ultra#1.post_treat_cba]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' i.treat_ultra##pre_treat_cba ///
			if `s_use' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]

		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_coef") (`b_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_se")   (`se_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_pval") (`p_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_coef")  (`b_pre')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_se")    (`se_pre')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("n_obs")     (`n_obs')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("n_estab")   (`n_estab')
	}

	* ── SPILLOVER EFFECTS: clause count, composition, value ─────────────────

	foreach outcome of local spill_outcomes {

		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		di as text "  spillover: `outcome' (`arm')"

		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']

		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_coef") (`b_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_se")   (`se_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_pval") (`p_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_coef")  (`b_pre')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_se")    (`se_pre')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("n_obs")     (`n_obs')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("n_estab")   (`n_estab')
	}
}

postclose `pf'

use `pf_data', clear
export delimited using "$tables/max_clause_row/max_clause_comparison.csv", replace

di as result "CSV written."

********************************************************************************
* SECTION 6: BASELINE VALIDATION GATE
********************************************************************************

di _newline(1)
di as result "=== Baseline validation: spillover numb_clauses ==="
di as result "Target: coef 0.0227, se 0.1175, 19,693 obs, 4,142 estabs"
list if regression == "spillover" & outcome == "numb_clauses" & arm == "baseline", ///
	noobs sepby(stat)

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Max-clause-row rerun done" "direct A/C, spillover, composition, value"
