********************************************************************************
* cba_period_arms_vingtiles.do
*
* Same four arms as cba_period_arms.do, but the pre-treatment control bins are
* VINGTILES instead of quartiles: group(20) rather than group(4).
*
* Bin construction copied from Programs/robustness/Main_Results_robustness_bins.do,
* which runs the same sensitivity over nbins in {10, 20, 50, 100}:
*   egen <v>_pre<n>_o = cut(<v>_pre) if year == 2009 & in_balanced_panel == 1, group(<n>)
*   bys identificad: egen <v>_pre<n> = min(<v>_pre<n>_o)
* with the flows bin zero-filled so missing becomes the reference category.
*
* THE PROBLEM (see project_cba_period_duplicate_rows):
* 031_clean_cba.do:448 expands each agreement to every December it covers, so
* consecutive establishment-years carry the same avg_file_date and collapse onto
* the same cba_period. 1,914 of 17,742 firm x cba_period cells hold >1 row.
*
* cba_period_v2:
*   - PRE-TREATMENT (periods 1, 2): same agreement identification as v1 —
*     period 1 is the 2009 agreement, period 2 its earliest renewal (Lagos's
*     omitted category). Where that agreement spans several Decembers, keep the
*     EARLIEST. Without this the requested uniqueness test cannot pass, since
*     periods 1 and 2 are themselves duplicated under v1.
*   - POST-TREATMENT (periods 3-6): the December in which a NEW agreement is
*     first in effect, detected as a change in start_date_stata relative to the
*     establishment's previous year. Calendar year of that December gives the
*     period (2013->3, 2014->4, 2015->5, 2016->6), preserving Lagos's
*     calendar-year convention for post-treatment points.
*
* Uniqueness is automatic post-treatment: each establishment has exactly one
* December per calendar year, so at most one row can be flagged per period.
*
* FOUR ARMS, one Stata process:
*   v1_all   — current published definition, all rows
*   v1_max   — v1 periods, max-clause row per firm x cba_period
*   v1_mean  — v1 periods, CBA outcomes replaced by their within-cell MEAN,
*              then one row per cell. Neutral alternative to the max rule,
*              which selects on the outcome. Shares are averaged as shares,
*              not recomputed from averaged counts.
*   v2       — new periodization, unique by construction
*
* All pre-treatment controls are built ONCE on the full panel using v1's
* cba_period 1-2, and the SAME controls are used by all three arms, so the
* comparison isolates the periodization and nothing else.
*
* Output: Tables/max_clause_row/cba_period_arms_comparison.csv
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
log using "$logs/max_clause_row/cba_period_arms_vingtiles_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD AND MERGE
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore
cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

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
* SECTION 1b: CLAUSE-TYPE VARIABLES (verbatim from clause_types.do)
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
* SECTION 2: cba_period (v1) AND cba_period_v2
********************************************************************************

* ── v1: current definition ──────────────────────────────────────────────────
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

* ── v2: unique-by-construction definition ───────────────────────────────────
cap drop cba_period_v2
gen cba_period_v2 = .

* Pre-treatment: identical agreement identification to v1
replace cba_period_v2 = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period_v2 = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)

* Post-treatment: December in which a new agreement is first in effect.
* A change in start_date_stata relative to the establishment's previous year
* means a different agreement is now in force.
sort identificad year
cap drop new_agreement
by identificad: gen byte new_agreement = (start_date_stata != start_date_stata[_n-1]) ///
	if !missing(start_date_stata)

replace cba_period_v2 = 3 if year == 2013 & new_agreement == 1 & missing(cba_period_v2)
replace cba_period_v2 = 4 if year == 2014 & new_agreement == 1 & missing(cba_period_v2)
replace cba_period_v2 = 5 if year == 2015 & new_agreement == 1 & missing(cba_period_v2)
replace cba_period_v2 = 6 if year == 2016 & new_agreement == 1 & missing(cba_period_v2)

* Pre-treatment periods 1-2: keep the EARLIEST December of the agreement.
* (Post-treatment periods are already unique: one December per calendar year.)
sort identificad cba_period_v2 year
cap drop pre_rank
by identificad cba_period_v2: gen long pre_rank = _n
count if inlist(cba_period_v2, 1, 2) & pre_rank > 1
di as result "Pre-period rows dropped for uniqueness: " r(N)
replace cba_period_v2 = . if inlist(cba_period_v2, 1, 2) & pre_rank > 1

gen pre_treat_cba_v2  = cond(cba_period_v2 < 2,  1, 0)
gen post_treat_cba_v2 = cond(cba_period_v2 >= 3, 1, 0) if !missing(cba_period_v2)

********************************************************************************
* SECTION 3: UNIQUENESS TEST — at most one row per establishment x period
********************************************************************************

di _newline(1)
di as result "=== cba_period_v2 distribution ==="
tab cba_period_v2, missing

di as result "=== v1 vs v2 rows per establishment x period ==="
cap drop n_cell_v1
bysort identificad cba_period: gen long n_cell_v1 = _N if !missing(cba_period)
cap drop n_cell_v2
bysort identificad cba_period_v2: gen long n_cell_v2 = _N if !missing(cba_period_v2)
di as result "v1:"
tab n_cell_v1, missing
di as result "v2:"
tab n_cell_v2, missing

di as result "=== UNIQUENESS TEST ==="
preserve
	keep if !missing(cba_period_v2)
	isid identificad cba_period_v2
	di as result "PASSED: isid identificad cba_period_v2"
restore

********************************************************************************
* SECTION 4: CONTROLS — built ONCE on the full panel, shared by all three arms
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

cap drop l_firm_emp_pre20_o
cap drop l_firm_emp_pre20
quietly {
	egen l_firm_emp_pre20_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(20)
	bys identificad: egen l_firm_emp_pre20 = min(l_firm_emp_pre20_o)
	drop l_firm_emp_pre20_o
}

cap drop totalflows_pw_pre_07_11_20_o
cap drop totalflows_pw_pre_07_11_20
quietly {
	egen totalflows_pw_pre_07_11_20_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(20)
	bys identificad: egen totalflows_pw_pre_07_11_20 = min(totalflows_pw_pre_07_11_20_o)
	drop totalflows_pw_pre_07_11_20_o
	replace totalflows_pw_pre_07_11_20 = 0 if missing(totalflows_pw_pre_07_11_20)
}

* Outcome bins keyed on v1's cba_period 1-2 for ALL arms, so the controls are
* held fixed and only the periodization varies.
foreach v in numb_clauses wage_clauses emp_clauses other_clauses ///
             wage_clause_prop emp_clause_prop other_clause_prop cba_value {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
	cap drop `v'_pre20_o
	cap drop `v'_pre20
	quietly {
		egen `v'_pre20_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(20)
		bys identificad: egen `v'_pre20 = min(`v'_pre20_o)
		drop `v'_pre20_o
	}
}

tempfile prepped
save `prepped'

********************************************************************************
* SECTION 5: THREE ARMS
********************************************************************************

tempname pf
tempfile pf_data
postfile `pf' str16 regression str20 outcome str10 arm str12 stat double value ///
	using `pf_data', replace

local conn "totaltreat_pw_norm"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

local spill_outcomes "numb_clauses wage_clauses emp_clauses other_clauses wage_clause_prop emp_clause_prop other_clause_prop cba_value"

foreach arm in v1_all v1_max v1_mean v2 {

	use `prepped', clear

	* period variable and pre/post indicators for this arm
	if "`arm'" == "v2" {
		local per  "cba_period_v2"
		local pre  "pre_treat_cba_v2"
		local post "post_treat_cba_v2"
	}
	else {
		local per  "cba_period"
		local pre  "pre_treat_cba"
		local post "post_treat_cba"
	}

	di _newline(2)
	di as result "======================================================================"
	di as result "ARM: `arm'   (period = `per')"
	di as result "======================================================================"

	if "`arm'" == "v1_max" {
		cap drop negclauses
		gen double negclauses = -numb_clauses
		sort identificad cba_period negclauses avg_file_date year
		cap drop rank_cell
		by identificad cba_period: gen long rank_cell = _n
		drop if !missing(cba_period) & rank_cell > 1
		cap drop negclauses
		cap drop rank_cell
	}

	if "`arm'" == "v1_mean" {
		* Replace each CBA outcome by its within-cell mean, then keep one row
		* per establishment x cba_period. Unlike the max rule this does not
		* select on the outcome.
		foreach v in numb_clauses wage_clauses emp_clauses other_clauses ///
		             wage_clause_prop emp_clause_prop other_clause_prop cba_value {
			cap drop cellmean
			bysort identificad cba_period: egen double cellmean = mean(`v') if !missing(cba_period)
			replace `v' = cellmean if !missing(cba_period)
			cap drop cellmean
		}
		sort identificad cba_period year
		cap drop rank_cell
		by identificad cba_period: gen long rank_cell = _n
		drop if !missing(cba_period) & rank_cell > 1
		cap drop rank_cell
	}

	local base_fe_cba "identificad i.industry1#i.`per' i.mode_base_month#i.`per' i.microregion#i.`per'"
	local extra_cba   "ib0.totalflows_pw_pre_07_11_20#i.`per'"

	* ── DIRECT EFFECTS: numb_clauses, samples A and C ───────────────────────
	foreach panel in A C {

		if "`panel'" == "A" local s_use "`s_direct_A'"
		if "`panel'" == "C" local s_use "`s_direct_C'"

		local outcome "numb_clauses"
		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre20#i.`per' ib0.l_firm_emp_pre20#i.`per' `extra_cba'"

		di as text "  direct_`panel': `outcome' (`arm')"

		reghdfe `outcome' i.treat_ultra##`post' ///
			if `s_use' & !missing(`per'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.`post']
		local se_post = _se[1.treat_ultra#1.`post']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' i.treat_ultra##`pre' ///
			if `s_use' & !missing(`per') & `per' <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre   = _b[1.treat_ultra#1.`pre']
		local se_pre  = _se[1.treat_ultra#1.`pre']
		local p_pre   = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
		local pn_obs  = e(N)
		local pn_est  = e(N_clust)

		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_coef")   (`b_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_se")     (`se_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("post_pval")   (`p_post')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("n_obs")       (`n_obs')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("n_estab")     (`n_estab')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_coef")    (`b_pre')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_se")      (`se_pre')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_pval")    (`p_pre')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_n_obs")   (`pn_obs')
		post `pf' ("direct_`panel'") ("`outcome'") ("`arm'") ("pre_n_estab") (`pn_est')
	}

	* ── SPILLOVER EFFECTS ───────────────────────────────────────────────────
	foreach outcome of local spill_outcomes {

		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre20#i.`per' ib0.l_firm_emp_pre20#i.`per' `extra_cba'"

		di as text "  spillover: `outcome' (`arm')"

		reghdfe `outcome' c.`conn'##`post' ///
			if `s_spill' & !missing(`per'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.`post'#c.`conn']
		local se_post = _se[1.`post'#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' c.`conn'##`pre' ///
			if `s_spill' & !missing(`per') & `per' <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre   = _b[1.`pre'#c.`conn']
		local se_pre  = _se[1.`pre'#c.`conn']
		local p_pre   = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
		local pn_obs  = e(N)
		local pn_est  = e(N_clust)

		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_coef")   (`b_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_se")     (`se_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("post_pval")   (`p_post')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("n_obs")       (`n_obs')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("n_estab")     (`n_estab')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_coef")    (`b_pre')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_se")      (`se_pre')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_pval")    (`p_pre')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_n_obs")   (`pn_obs')
		post `pf' ("spillover") ("`outcome'") ("`arm'") ("pre_n_estab") (`pn_est')
	}
}

postclose `pf'

use `pf_data', clear
export delimited using "$tables/max_clause_row/cba_period_arms_vingtiles_comparison.csv", replace

di as result "=== v1_all spillover numb_clauses (VINGTILE bins — will NOT match the quartile table) ==="
di as result "Quartile-spec reference was 0.0227 (0.1175), 19,693 obs, 4,142 estabs"
list if regression == "spillover" & outcome == "numb_clauses", noobs

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "cba_period_arms VINGTILES done" "four arms, vingtile control bins"
