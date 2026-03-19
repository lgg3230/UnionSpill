********************************************************************************
* UNION SPILLOVERS — EMPLOYMENT FLOWS & TURNOVER RATES, LOG SPEC (tfpw_07_11)
* Purpose: Same regressions as Main_Results_turnover.do but using log outcomes.
*          Observations where the raw rate is zero yield a missing log and are
*          dropped automatically by reghdfe — no manual trimming or offset.
*          l_total_hours is already in logs and is included as-is.
* Output:  4 CSV files (panelA, panelB, panelC, spill)
*          results_direct_panelA_turnover_log.csv
*          results_direct_panelB_turnover_log.csv
*          results_direct_panelC_turnover_log.csv
*          results_spill_turnover_log.csv
* NOTE:    Flow outcomes (totalflows_pw, outflows_pw, inflows_pw) excluded.
* Panels:  A (zero-connectivity controls), B (<=1% connectivity controls),
*          C (all untreated controls), D (spillover effects)
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/turnover/FinalResults_turnover_log_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAMES (uncomment and edit if running standalone without 00_master.do)
* ===============================
// global main      "PATHNAME TO Replication-Mar-2"
// global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
// global tables    "$main/UnionSpill/Tables"
// global graphs    "$main/UnionSpill/Graphs"
// global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
// global logs      "$main/UnionSpill/Logs"
// global programs  "$main/UnionSpill/Programs"
* ===============================

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── MERGE TURNOVER DATA ──────────────────────────────────────────────────────

di as result "Merging turnover data..."

preserve
	import delimited "$rais_firm/corrected_turnover_sample.csv", clear
	keep identificad year separations_u avg_emp turnover_u ///
	     layoff_rate_u quit_rate_u hiring_rate_u retention_u hired_u total_hours
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

label var turnover_u "Separation rate (separations / avg employment, uncensored)"

gen double churn_rate_u = (separations_u + hired_u) / avg_emp if avg_emp > 0
label var churn_rate_u "Churn rate ((hires + separations) / avg employment, uncensored)"

gen double l_total_hours = ln(total_hours) if total_hours > 0
label var l_total_hours "Log total contracted hours (Dec. employment)"

di as result "Turnover data merged."

* ── MERGE TOTALFLOWS DATA (per-worker, 2007-2011 only) ───────────────────────

di as result "Merging totalflows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

di as result "Totalflows data merged."

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables..."

* ── a) TREATMENT INDICATORS ──────────────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── CONNECTIVITY SCALING ─────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── b) PRE-TREATMENT MEANS + 4-BIN CONTROLS FOR BASE OUTCOMES ────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
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

* ── c) LOG TURNOVER OUTCOMES ─────────────────────────────────────────────────
*
* Log of each rate outcome. Firms with a zero rate in a given year have a
* missing log and are dropped automatically by reghdfe for that outcome.
* l_total_hours is already in logs — included as-is.

di as result "Generating log turnover outcomes..."

cap drop l_retention_u
gen double l_retention_u = ln(retention_u)
label var l_retention_u "Log retention rate"

cap drop l_hiring_rate_u
gen double l_hiring_rate_u = ln(hiring_rate_u)
label var l_hiring_rate_u "Log hiring rate"

cap drop l_turnover_u
gen double l_turnover_u = ln(turnover_u)
label var l_turnover_u "Log separation rate"

cap drop l_quit_rate_u
gen double l_quit_rate_u = ln(quit_rate_u)
label var l_quit_rate_u "Log quit rate"

cap drop l_layoff_rate_u
gen double l_layoff_rate_u = ln(layoff_rate_u)
label var l_layoff_rate_u "Log layoff rate"

cap drop l_churn_rate_u
gen double l_churn_rate_u = ln(churn_rate_u)
label var l_churn_rate_u "Log churn rate"

global turnover_log_outcomes "l_retention_u l_hiring_rate_u l_turnover_u l_quit_rate_u l_layoff_rate_u l_churn_rate_u l_total_hours"

* ── d) PRE-TREATMENT MEANS + 4-BIN CONTROLS FOR LOG OUTCOMES ─────────────────

di as result "Creating log turnover pre-treatment bins..."

foreach v of global turnover_log_outcomes {

	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}

	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION"
di as result "======================================================================="

* ── FIXED EFFECTS & SPEC MACROS ─────────────────────────────────────────────

local spec       "turnover_log"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.year i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* ── SAMPLE MACROS ───────────────────────────────────────────────────────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── INITIALIZE OUTPUT CSV FILES ─────────────────────────────────────────────

foreach panel in A B C {
	capture erase "$tables/turnover/results_direct_panel`panel'_turnover_log.csv"
	tempname fh
	file open `fh' using "$tables/turnover/results_direct_panel`panel'_turnover_log.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/turnover/results_spill_turnover_log.csv"
tempname fh
file open `fh' using "$tables/turnover/results_spill_turnover_log.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── DIRECT EFFECTS — PANELS A, B, C ─────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "DIRECT EFFECTS — PANELS A, B, C"
di as result "-----------------------------------------------------------------------"

foreach panel in A B C {

	if "`panel'" == "A" {
		local s_use     "`s_direct_A'"
		local s_use_pre "treat_ultra==0 & totaltreat_pw_n==0 & lagos_sample_avg==1 & in_balanced_panel==1"
		local section   "direct_A"
	}
	if "`panel'" == "B" {
		local s_use     "`s_direct_B'"
		local s_use_pre "treat_ultra==0 & totaltreat_pw_n<=0.01 & lagos_sample_avg==1 & in_balanced_panel==1"
		local section   "direct_B"
	}
	if "`panel'" == "C" {
		local s_use     "`s_direct_C'"
		local s_use_pre "treat_ultra==0 & lagos_sample_avg==1 & in_balanced_panel==1"
		local section   "direct_C"
	}

	local csv_out "$tables/turnover/results_direct_panel`panel'_turnover_log.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	foreach outcome of global turnover_log_outcomes {

		di as text "  Estimating: `outcome' (Panel `panel')"

		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		* Post-treatment
		reghdfe `outcome' treat_ultra##i.treat_year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment placebo
		reghdfe `outcome' treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.placebo_year]
		local se_pre = _se[1.treat_ultra#1.placebo_year]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* Stars
		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		* Event study for pre-trend F-test
		reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* Baseline mean of the RAW outcome (untreated control group, 2011)
		local raw_outcome = subinstr("`outcome'", "l_", "", 1)
		quietly sum `raw_outcome' if `s_use_pre' & year == 2011
		local mean_pre_val = r(mean)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file close `fh'
	}

	di as result "Panel `panel' complete."
}

* ── SPILLOVER EFFECTS ────────────────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/turnover/results_spill_turnover_log.csv"

foreach outcome of global turnover_log_outcomes {

	di as text "  Estimating: `outcome' (spillover)"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment placebo
	reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.placebo_year#c.`conn']
	local se_pre = _se[1.placebo_year#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	* Stars
	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study for pre-trend F-test
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Baseline mean of the RAW outcome (spillover sample, 2011)
	local raw_outcome = subinstr("`outcome'", "l_", "", 1)
	quietly sum `raw_outcome' if `s_spill' & year == 2011
	local mean_pre_val = r(mean)

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
	file close `fh'
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "turnover_log regressions complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
