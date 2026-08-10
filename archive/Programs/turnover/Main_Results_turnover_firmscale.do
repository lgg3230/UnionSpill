********************************************************************************
* UNION SPILLOVERS — EMPLOYMENT FLOWS & TURNOVER, FIRM-SCALE SPEC (tfpw_07_11)
* Purpose: Regressions on raw count numerators scaled by each firm's own
*          pretreatment (2009-2011) average of that same count.
*          For firm i and year t:
*            fs_v_it = v_it / mean(v_i, 2009-2011)
*          The denominator is firm-specific and time-invariant. A value of 1.2
*          means the count is 20% above the firm's own pretreatment baseline.
*          The mean is NaN-aware: missing years are ignored in the average.
*          Firms where the pretreatment mean is zero or missing are excluded
*          for that outcome (division yields missing, dropped by reghdfe).
*          Outcomes:
*            fs_hired_u, fs_separations_u, fs_layoffs_u, fs_quits_u,
*            fs_churn_count_u, fs_jan_dec_count, fs_dec_yoy_count,
*            fs_total_hours, fs_firm_emp
*          Pre-treatment bins in absorb() use the raw (unscaled) variable
*          because the firm-specific scaling does not preserve cross-firm
*          rank order in levels.
* Output:  4 CSV files (panelA, panelB, panelC, spill)
*          results_direct_panelA_turnover_firmscale.csv
*          results_direct_panelB_turnover_firmscale.csv
*          results_direct_panelC_turnover_firmscale.csv
*          results_spill_turnover_firmscale.csv
* NOTE:    Flow outcomes (totalflows_pw, outflows_pw, inflows_pw) excluded.
* Panels:  A (zero-connectivity controls), B (<=1% connectivity controls),
*          C (all untreated controls), D (spillover effects)
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/turnover/FinalResults_turnover_firmscale_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAMES (uncomment and edit if running standalone without 0000_master.do)
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
	keep identificad year hired_u separations_u layoffs_u quits_u ///
	     jan_dec_count dec_yoy_count total_hours
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

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

* ── MERGE FLOW OUTCOMES PANEL (annual, 2009-2016) ────────────────────────────

di as result "Merging flow outcomes panel..."

preserve
	import delimited "$rais_aux/totalflows_panel_2009_2016.csv", clear
	tostring identificad, replace format(%014.0f) force
	keep identificad year totalflows outflows inflows totalflows_pw outflows_pw inflows_pw
	tempfile flows_panel
	save `flows_panel'
restore

cap drop totalflows_pw
cap drop outflows_pw
cap drop inflows_pw

merge 1:1 identificad year using `flows_panel', keep(master match) nogen
label var totalflows    "Total bilateral flow count"
label var outflows      "Total outflow count"
label var inflows       "Total inflow count"
label var totalflows_pw "Total bilateral flows per worker"
label var outflows_pw   "Total outflows per worker"
label var inflows_pw    "Total inflows per worker"

di as result "Flow outcomes panel merged."

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

* ── c) RAW COUNT VARIABLES + CHURN ───────────────────────────────────────────

cap drop churn_count_u
gen double churn_count_u = hired_u + separations_u ///
	if !missing(hired_u) & !missing(separations_u)
label var churn_count_u "Churn count (hires + separations)"

* List of raw numerator variables to firm-scale
global turnover_fs_raw "hired_u separations_u layoffs_u quits_u churn_count_u jan_dec_count dec_yoy_count total_hours firm_emp"

* ── d) FIRM-SPECIFIC PRETREATMENT MEANS (NaN-aware) + PRE4 BINS ───────────────
*
* For each raw variable v:
*   fm_v  = mean of v over 2009-2011 FOR THAT FIRM (missing years skipped).
*   fs_v  = v / fm_v  (firm-scale outcome; missing if fm_v = 0 or missing).
*   v_pre4 = quartile bins of the raw variable's pretreatment mean (not fs_v),
*            used in absorb() to control for pre-treatment level heterogeneity.

di as result "Computing firm-specific pretreatment means and firm-scaled outcomes..."

foreach v of global turnover_fs_raw {

	* Firm-specific pretreatment mean (NaN-aware: stata mean ignores missing)
	cap drop fm_`v'_o
	cap drop fm_`v'
	quietly {
		bys identificad: egen fm_`v'_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen fm_`v' = min(fm_`v'_o)
		drop fm_`v'_o
	}
	label var fm_`v' "Firm pretreatment mean of `v' (2009-2011, NaN-aware)"

	* Firm-scaled outcome
	cap drop fs_`v'
	gen double fs_`v' = `v' / fm_`v' if fm_`v' > 0 & !missing(fm_`v')
	label var fs_`v' "`v' / firm pretreatment mean (2009-2011)"

	* Pre-treatment bins on the RAW variable (not the scaled one)
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

* ── Flow outcomes (spillover regressions only) ────────────────────────────────

global turnover_fs_spill_extra "totalflows outflows inflows"

di as result "Computing firm-specific pretreatment means for flow outcomes (spill-only)..."

foreach v of global turnover_fs_spill_extra {

	cap drop fm_`v'_o
	cap drop fm_`v'
	quietly {
		bys identificad: egen fm_`v'_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen fm_`v' = min(fm_`v'_o)
		drop fm_`v'_o
	}
	label var fm_`v' "Firm pretreatment mean of `v' (2009-2011, NaN-aware)"

	cap drop fs_`v'
	gen double fs_`v' = `v' / fm_`v' if fm_`v' > 0 & !missing(fm_`v')
	label var fs_`v' "`v' / firm pretreatment mean (2009-2011)"

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

local spec       "turnover_firmscale"
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
	capture erase "$tables/turnover/results_direct_panel`panel'_turnover_firmscale.csv"
	tempname fh
	file open `fh' using "$tables/turnover/results_direct_panel`panel'_turnover_firmscale.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/turnover/results_spill_turnover_firmscale.csv"
tempname fh
file open `fh' using "$tables/turnover/results_spill_turnover_firmscale.csv", write replace
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

	local csv_out "$tables/turnover/results_direct_panel`panel'_turnover_firmscale.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	foreach v of global turnover_fs_raw {

		di as text "  Estimating: fs_`v' (Panel `panel')"

		* Absorb references the raw variable's pre4 bins (not the scaled variable)
		local absorb "`base_fe' ib0.`v'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		* Post-treatment
		reghdfe fs_`v' treat_ultra##i.treat_year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment placebo
		reghdfe fs_`v' treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
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
		reghdfe fs_`v' i.treat_ultra##ib2011.year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		capture testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		* Baseline mean of the RAW count (untreated control group, 2011)
	* POOLED over the estimation sample (treated + control), per the table
	* note "average across establishments in each panel's estimation sample".
	* Was `s_use_pre' (control group only), which contradicted that note.
		quietly sum `v' if `s_use' & year == 2011
		local mean_pre_val = r(mean)

		* Write (outcome key is the raw variable name for consistent CSV lookup)
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"fs_`v'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"`section'";"fs_`v'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file close `fh'
	}

	di as result "Panel `panel' complete."
}

* ── SPILLOVER EFFECTS ────────────────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/turnover/results_spill_turnover_firmscale.csv"

foreach v in $turnover_fs_raw $turnover_fs_spill_extra {

	di as text "  Estimating: fs_`v' (spillover)"

	* Flow outcomes: no pre-treatment totalflows per worker control (circular)
	if inlist("`v'", "totalflows", "outflows", "inflows") {
		local absorb "`base_fe' ib0.`v'_pre4#i.year ib0.l_firm_emp_pre4#i.year"
	}
	else {
		local absorb "`base_fe' ib0.`v'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
	}

	* Post-treatment
	reghdfe fs_`v' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment placebo
	reghdfe fs_`v' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
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
	reghdfe fs_`v' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	capture testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = cond(_rc == 0, r(p), .)

	* Baseline mean of the RAW count (spillover sample, 2011)
	quietly sum `v' if `s_spill' & year == 2011
	local mean_pre_val = r(mean)

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"fs_`v'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file write `fh' `""`spec'";"spill";"fs_`v'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
	file close `fh'
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "turnover_firmscale regressions complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
