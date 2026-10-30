********************************************************************************
* UNION SPILLOVERS — MAIN RESULTS, SEs CLUSTERED BY UNION (tfpw_07_11 spec)
* Purpose: Re-estimate the four main outcomes of 3012_pct_tfpw.do (log wages,
*          log hourly wages, log employment, number of clauses), direct and
*          spillover effects, clustering standard errors by the establishment's
*          modal union (mode_union) instead of by establishment (identificad).
*          Samples, fixed effects and controls are exactly those of 3012, so
*          point estimates and N must match its CSVs; only SEs, p-values and
*          stars change.
* Output:  4 CSV files (panelA, panelB, panelC, spill) in $tables
* Auto-runs: 4011_table_direct_modeunion.py, 4021_table_spill_modeunion.py
* Panels:  A (zero-connectivity controls), B (<=1% connectivity controls),
*          C (all untreated controls), D (spillover effects)
* Run via: 3013_main_modeunion.do (sets globals)
*
* Differences from 3012 besides the cluster variable:
*   - percentile / ratio outcomes and their bins are not built;
*   - the turnover merge is skipped (churn_u was never used downstream);
*   - no event-study figures;
*   - n_estab counts distinct establishments in e(sample), since e(N_clust)
*     now counts unions; the union count is written as a separate n_clust row.
* mode_union is time-invariant within establishment (checked 2026-10-29: never
* missing, never varies, 1,810 unions in the balanced Lagos sample), so the
* establishment FE is nested in the cluster variable.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/FinalResults_modeunion_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ===============================
* MERGE TOTALFLOWS DATA (per-worker, 2007-2011 only)
* ===============================

di as result "Merging totalflows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe: average over
* non-missing year pairs only; NaN means zero flows, not truly missing).
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

* Cluster variable must be present and non-missing wherever we estimate.
quietly count if missing(mode_union) & in_balanced_panel == 1
if r(N) > 0 {
	di as error "mode_union missing for " r(N) " balanced-panel rows; reghdfe would drop them."
	exit 459
}

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables..."

* ── a) TREATMENT & CBA PERIOD INDICATORS ────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
label var cba_period "CBA negotiation period (1=earliest, 2=second, 3-6=post-treatment years)"

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

* ── CONNECTIVITY SCALING ────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
 sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── b) PRE-TREATMENT MEANS FOR BASE OUTCOMES ────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

* numb_clauses pre-treatment mean (CBA period based)
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── 4-BIN CONTROLS FOR BASE OUTCOMES ────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

* Totalflows per-worker pre 07-11 bins (zero-fill missing → reference category)
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── c) OUTCOME GLOBALS ───────────────────────────────────────────────────────

global base_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION (SEs clustered by mode_union)"
di as result "======================================================================="

* ── FIXED EFFECTS & SPEC MACROS ─────────────────────────────────────────────

local spec       "tfpw_07_11_modeunion"
local cvar       "mode_union"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── SAMPLE MACROS ───────────────────────────────────────────────────────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── INITIALIZE OUTPUT CSV FILES ─────────────────────────────────────────────

foreach panel in A B C {
	capture erase "$tables/results_direct_panel`panel'_`spec'.csv"
	tempname fh
	file open `fh' using "$tables/results_direct_panel`panel'_`spec'.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/results_spill_`spec'.csv"
tempname fh
file open `fh' using "$tables/results_spill_`spec'.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── PARTS A-C: DIRECT EFFECTS ───────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "DIRECT EFFECTS — PANELS A, B, C"
di as result "-----------------------------------------------------------------------"

foreach panel in A B C {

	if "`panel'" == "A" {
		local s_use "`s_direct_A'"
		local section "direct_A"
	}
	if "`panel'" == "B" {
		local s_use "`s_direct_B'"
		local section "direct_B"
	}
	if "`panel'" == "C" {
		local s_use "`s_direct_C'"
		local section "direct_C"
	}

	local csv_out "$tables/results_direct_panel`panel'_`spec'.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	* ── Year-based outcomes ─────────────────────────────────────────────────

	foreach outcome in $base_outcomes {

		di as text "  Estimating: `outcome' (Panel `panel')"

		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		* Post-treatment
		reghdfe `outcome' treat_ultra##i.treat_year if `s_use', ///
			absorb(`absorb') vce(cluster `cvar')

		local b_post  = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_clust = e(N_clust)

		* Establishments in the estimation sample (e(N_clust) now counts unions)
		cap drop _estab_tag
		egen byte _estab_tag = tag(identificad) if e(sample)
		quietly count if _estab_tag == 1
		local n_estab = r(N)
		drop _estab_tag

		* Pre-treatment mean on this column's estimation sample, taken before
		* the placebo regression replaces e(sample).
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_pre = r(mean)

		* Pre-treatment placebo
		reghdfe `outcome' treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
			absorb(`absorb') vce(cluster `cvar')

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
			absorb(`absorb') vce(cluster `cvar')
		testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_clust";"' %12.0fc (`n_clust') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'
	}

	* ── numb_clauses (CBA-period structure) ─────────────────────────────────

	capture confirm variable numb_clauses
	if _rc == 0 {

		di as text "  Estimating: numb_clauses (CBA periods, Panel `panel')"

		local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		* Post-treatment
		 reghdfe numb_clauses i.treat_ultra##post_treat_cba ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster `cvar')

		local b_post  = _b[1.treat_ultra#1.post_treat_cba]
		local se_post = _se[1.treat_ultra#1.post_treat_cba]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_clust = e(N_clust)

		cap drop _estab_tag
		egen byte _estab_tag = tag(identificad) if e(sample)
		quietly count if _estab_tag == 1
		local n_estab = r(N)
		drop _estab_tag

		quietly sum numb_clauses if e(sample) & inrange(year, 2009, 2011)
		local mean_pre = r(mean)

		* Pre-treatment
		 reghdfe numb_clauses i.treat_ultra##pre_treat_cba ///
			if `s_use' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster `cvar')

		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
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
		 reghdfe numb_clauses i.treat_ultra##ib2.cba_period ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster `cvar')
		testparm 1.treat_ultra#1.cba_period
		local pre_ftest_pval = r(p)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"n_clust";"' %12.0fc (`n_clust') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'
	}

	di as result "Panel `panel' complete."
}

* ── PART D: SPILLOVER EFFECTS ───────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/results_spill_`spec'.csv"

foreach outcome in $base_outcomes {

	di as text "  Estimating: `outcome' (spillover)"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	 reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster `cvar')

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_clust = e(N_clust)

	cap drop _estab_tag
	egen byte _estab_tag = tag(identificad) if e(sample)
	quietly count if _estab_tag == 1
	local n_estab = r(N)
	drop _estab_tag

	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre = r(mean)

	* Pre-treatment placebo
	 reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster `cvar')

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
		absorb(`absorb') vce(cluster `cvar')
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_clust";"' %12.0fc (`n_clust') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file close `fh'
}

* numb_clauses spillover (CBA-period structure)
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Estimating: numb_clauses (spillover, CBA periods)"

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	 reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster `cvar')

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_clust = e(N_clust)

	cap drop _estab_tag
	egen byte _estab_tag = tag(identificad) if e(sample)
	quietly count if _estab_tag == 1
	local n_estab = r(N)
	drop _estab_tag

	quietly sum numb_clauses if e(sample) & inrange(year, 2009, 2011)
	local mean_pre = r(mean)

	* Pre-treatment
	 reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster `cvar')

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
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
	 reghdfe numb_clauses c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster `cvar')
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"n_clust";"' %12.0fc (`n_clust') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file close `fh'
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION + AUTO-RUN PYTHON
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

* ── Auto-generate LaTeX tables ──────────────────────────────────────────────
* Pass $tables so the LaTeX is built from the CSVs this run just wrote.
if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/main_results/4011_table_direct_modeunion.py" "$tables"
shell $python_exe "$programs/analysis/main_results/4021_table_spill_modeunion.py" "$tables"
di as result "LaTeX tables written to $tables/t_direct_modeunion.tex and t_spill_modeunion.tex"

********************************************************************************
* END OF DO-FILE
********************************************************************************
