********************************************************************************
* UNION SPILLOVERS — WORKFORCE COMPOSITION OUTCOMES, LOG SPEC (tfpw_07_11)
* Purpose: Same regressions as 4092_composition.do but using log
*          outcomes (ln of each composition variable). Observations where the
*          outcome is zero are excluded by reghdfe automatically via missing
*          log values — no manual trimming or offset applied.
*          Extra outcome: l_prop_hs_plus = ln(prop_hs + prop_sup), i.e. log
*          share of workers with at least a high school diploma.
* Output:  4 CSV files (panelA, panelB, panelC, spill)
*          results_direct_panelA_composition_log.csv
*          results_direct_panelB_composition_log.csv
*          results_direct_panelC_composition_log.csv
*          results_spill_composition_log.csv
* NOTE:    Variables verified in 1010_rais_to_firm.do collapse block.
*          All come from lagos_sample_sep24_pct_unionexp_ext_df2.dta directly.
* Panels:  A (zero-connectivity controls), B (<=1% connectivity controls),
*          C (all untreated controls), D (spillover effects)
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/composition/FinalResults_composition_log_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA
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

* Merge average worker age
preserve
	import delimited "$rais_firm/avg_age_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile avg_age_data
	save `avg_age_data'
restore

merge m:1 identificad year using `avg_age_data', keep(master match) nogen
label var avg_age "Average worker age at the firm (Dec employment)"

* Average per-worker pairwise flows 2007-2011
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

* Log pre-treatment employment
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

foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

* Totalflows per-worker pre 07-11 bins
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── UNION CONTROLS ──────────────────────────────────────────────────────────

capture confirm new variable treat_union
if _rc {
	drop treat_union
}
gen treat_union = cond(treat_union_exp_all > 0, 1, 0)
label var treat_union "Firm's union also covers at least one treated firm"

cap drop geo_exp
bys microregion (year): egen geo_exp = mean(treat_ultra)
label var geo_exp "Share of treated among sample in a given microregion"

cap drop micro_ind
cap drop mic_ind_exp
egen micro_ind = group(microregion industry)
bys micro_ind (year): egen mic_ind_exp = mean(treat_ultra)
label var mic_ind_exp "Share treated within each micro-industry cell"

* ── c) LOG COMPOSITION OUTCOMES ─────────────────────────────────────────────
*
* Log of each composition outcome. Observations where the raw value is zero
* yield a missing log and are dropped automatically by reghdfe — no offset
* or manual exclusion is applied.
*
* prop_hs_plus = prop_hs + prop_sup is the share of workers with at least a
* high school diploma (= 1 - prop_nhs for complete education shares).

di as result "Generating log composition outcomes..."

cap drop l_avg_tenure
gen double l_avg_tenure = ln(avg_tenure)
label var l_avg_tenure "Log average tenure (months)"

cap drop l_male_prop
gen double l_male_prop = ln(male_prop)
label var l_male_prop "Log share male"

cap drop l_white_prop
gen double l_white_prop = ln(white_prop)
label var l_white_prop "Log share white"

cap drop l_prop_nhs
gen double l_prop_nhs = ln(prop_nhs)
label var l_prop_nhs "Log share with no high school"

cap drop l_prop_hs
gen double l_prop_hs = ln(prop_hs)
label var l_prop_hs "Log share with high school"

cap drop l_prop_sup
gen double l_prop_sup = ln(prop_sup)
label var l_prop_sup "Log share with college+"

cap drop prop_hs_plus
gen double prop_hs_plus = prop_hs + prop_sup
label var prop_hs_plus "Share with at least high school diploma"

cap drop l_prop_hs_plus
gen double l_prop_hs_plus = ln(prop_hs_plus)
label var l_prop_hs_plus "Log share with at least high school diploma"

cap drop l_avg_age
gen double l_avg_age = ln(avg_age)
label var l_avg_age "Log average worker age"

global composition_log_outcomes "l_avg_tenure l_male_prop l_white_prop l_prop_nhs l_prop_hs l_prop_sup l_prop_hs_plus l_avg_age"

* ── d) PRE-TREATMENT MEANS + 4-BIN CONTROLS FOR LOG OUTCOMES ────────────────
*
* Bins computed from pre-treatment mean of each log outcome. If a firm has
* no usable (non-missing) log values in 2009-2011 the bin stays missing and
* the firm is excluded by the reghdfe absorb() mechanism.

di as result "Creating log composition pre-treatment bins..."

foreach v of global composition_log_outcomes {

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

local spec       "composition_log"
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
	capture erase "$tables/composition/results_direct_panel`panel'_composition_log.csv"
	tempname fh
	file open `fh' using "$tables/composition/results_direct_panel`panel'_composition_log.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/composition/results_spill_composition_log.csv"
tempname fh
file open `fh' using "$tables/composition/results_spill_composition_log.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── PARTS A-C: DIRECT EFFECTS ───────────────────────────────────────────────

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

	local csv_out "$tables/composition/results_direct_panel`panel'_composition_log.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	foreach outcome of global composition_log_outcomes {

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
	* POOLED over the estimation sample (treated + control), per the table
	* note "average across establishments in each panel's estimation sample".
	* Was `s_use_pre' (control group only), which contradicted that note.
		quietly sum `raw_outcome' if `s_use' & year == 2011
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

* ── PART D: SPILLOVER EFFECTS ───────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/composition/results_spill_composition_log.csv"

foreach outcome of global composition_log_outcomes {

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

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "composition_log regressions complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
