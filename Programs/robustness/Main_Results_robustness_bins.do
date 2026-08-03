********************************************************************************
* ROBUSTNESS: BIN COUNT SENSITIVITY TEST
* Purpose: Test sensitivity of direct and spillover results to the number of
*          pre-treatment quantile bins used in the absorb specification.
*          Runs main regressions with nbins ∈ {10, 20, 50, 100}.
* Output:  4 CSV files in Tables/robustness/
*           results_direct_panelA_robustness_bins.csv
*           results_direct_panelB_robustness_bins.csv
*           results_direct_panelC_robustness_bins.csv
*           results_spill_robustness_bins.csv
* Note:    Event study plots are skipped to reduce runtime.
*          pre_pval reports the p-value from the pre-treatment placebo DiD.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_robustness_bins_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── MERGE TURNOVER DATA ──────────────────────────────────────────────────────

di as result "Merging turnover data..."

preserve
	import delimited "$rais_aux/corrected_turnover_sample.csv", clear
	keep identificad year separations_u hired_u avg_emp
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

gen double churn_u = separations_u + hired_u
label var churn_u "Total churn (separations + hires, uncensored)"

gen double churn_rate_u = (separations_u + hired_u) / avg_emp if avg_emp > 0
label var churn_rate_u "Churn rate (churn / avg employment, uncensored)"

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

* Average per-worker pairwise flows 2007-2011 (missing-safe)
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
* SECTION 2: VARIABLE CREATION (once, before bin loop)
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

* ── c) PERCENTILE PRE-TREATMENT MEANS ───────────────────────────────────────

di as result "Creating percentile pre-treatment means..."

foreach v in lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 ///
             lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 ///
             lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 ///
             lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 {

	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* ── d) LOG WAGE RATIO VARIABLES + PRE-TREATMENT MEANS ───────────────────────

di as result "Creating wage ratio variables and pre-treatment means..."

foreach wage in lr_remdezr_w lr_remdezr_h_w {

	gen double `wage'_p90p10 = `wage'_p90 - `wage'_p10
	gen double `wage'_p80p20 = `wage'_p80 - `wage'_p20
	gen double `wage'_p75p25 = `wage'_p75 - `wage'_p25
	gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
	gen double `wage'_p80p50 = `wage'_p80 - `wage'_p50
	gen double `wage'_p75p50 = `wage'_p75 - `wage'_p50

	foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 {
		local v "`wage'_`ratio'"

		cap drop `v'_pre_o
		cap drop `v'_pre
		quietly {
			bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
			bys identificad: egen `v'_pre = min(`v'_pre_o)
			drop `v'_pre_o
		}
	}
}

* ── e) OUTCOME GLOBALS ───────────────────────────────────────────────────────

global base_outcomes      "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
global pct_outcomes_dec   "lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90"
global pct_outcomes_hr    "lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90"
global ratio_outcomes_dec "lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50"
global ratio_outcomes_hr  "lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50"

di as result "All pre-treatment means created."

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV FILES (once, before bin loop)
********************************************************************************

di _newline(1)
di as result "Initializing output CSV files..."

foreach panel in A B C {
	capture erase "$tables/robustness/results_direct_panel`panel'_robustness_bins.csv"
	tempname fh
	file open `fh' using "$tables/robustness/results_direct_panel`panel'_robustness_bins.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/robustness/results_spill_robustness_bins.csv"
tempname fh
file open `fh' using "$tables/robustness/results_spill_robustness_bins.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

di as result "CSV files initialized."

********************************************************************************
* SECTION 4: OUTER LOOP OVER BIN COUNTS
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING BIN SENSITIVITY LOOP (nbins = 10, 20, 50, 100)"
di as result "======================================================================="

foreach nbins in 10 20 50 100 {

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "BIN COUNT: `nbins'"
	di as result "-----------------------------------------------------------------------"

	* ── CREATE BIN VARIABLES ────────────────────────────────────────────────

	di as result "Creating `nbins'-bin controls..."

	* l_firm_emp
	cap drop l_firm_emp_pre`nbins'_o
	cap drop l_firm_emp_pre`nbins'
	quietly {
		egen l_firm_emp_pre`nbins'_o = cut(l_firm_emp_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(`nbins')
		bys identificad: egen l_firm_emp_pre`nbins' = min(l_firm_emp_pre`nbins'_o)
		drop l_firm_emp_pre`nbins'_o
	}

	* lr_remdezr_w, lr_remdezr_h_w
	foreach v in lr_remdezr_w lr_remdezr_h_w {
		cap drop `v'_pre`nbins'_o
		cap drop `v'_pre`nbins'
		quietly {
			egen `v'_pre`nbins'_o = cut(`v'_pre) ///
				if year == 2009 & in_balanced_panel == 1, group(`nbins')
			bys identificad: egen `v'_pre`nbins' = min(`v'_pre`nbins'_o)
			drop `v'_pre`nbins'_o
		}
	}

	* numb_clauses (only if variable exists)
	capture confirm variable numb_clauses
	if _rc == 0 {
		cap drop numb_clauses_pre`nbins'_o
		cap drop numb_clauses_pre`nbins'
		quietly {
			egen numb_clauses_pre`nbins'_o = cut(numb_clauses_pre) ///
				if year == 2009 & in_balanced_panel == 1, group(`nbins')
			bys identificad: egen numb_clauses_pre`nbins' = min(numb_clauses_pre`nbins'_o)
			drop numb_clauses_pre`nbins'_o
		}
	}

	* totalflows per-worker pre 07-11 (zero-fill missing → reference category)
	cap drop totalflows_pw_pre_07_11`nbins'_o
	cap drop totalflows_pw_pre_07_11`nbins'
	quietly {
		egen totalflows_pw_pre_07_11`nbins'_o = cut(totalflows_pw_pre_07_11) ///
			if year == 2009 & in_balanced_panel == 1, group(`nbins')
		bys identificad: egen totalflows_pw_pre_07_11`nbins' = min(totalflows_pw_pre_07_11`nbins'_o)
		drop totalflows_pw_pre_07_11`nbins'_o
		replace totalflows_pw_pre_07_11`nbins' = 0 if missing(totalflows_pw_pre_07_11`nbins')
	}

	* Percentile outcomes (14 variables)
	foreach v in lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 ///
	             lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 ///
	             lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 ///
	             lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 {
		cap drop `v'_pre`nbins'_o
		cap drop `v'_pre`nbins'
		quietly {
			egen `v'_pre`nbins'_o = cut(`v'_pre) ///
				if year == 2009 & in_balanced_panel == 1, group(`nbins')
			bys identificad: egen `v'_pre`nbins' = min(`v'_pre`nbins'_o)
			drop `v'_pre`nbins'_o
			replace `v'_pre`nbins' = 0 if missing(`v'_pre`nbins')
		}
	}

	* Ratio outcomes (12 variables)
	foreach wage in lr_remdezr_w lr_remdezr_h_w {
		foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 {
			local v "`wage'_`ratio'"
			cap drop `v'_pre`nbins'_o
			cap drop `v'_pre`nbins'
			quietly {
				egen `v'_pre`nbins'_o = cut(`v'_pre) ///
					if year == 2009 & in_balanced_panel == 1, group(`nbins')
				bys identificad: egen `v'_pre`nbins' = min(`v'_pre`nbins'_o)
				drop `v'_pre`nbins'_o
				replace `v'_pre`nbins' = 0 if missing(`v'_pre`nbins')
			}
		}
	}

	di as result "Bin variables created for nbins=`nbins'."

	* ── SET LOCAL MACROS ────────────────────────────────────────────────────

	local spec        "tfpw_07_11_pct_bins`nbins'"
	local conn        "totaltreat_pw_norm"
	local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
	local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
	local extra_year  "ib0.totalflows_pw_pre_07_11`nbins'#i.year"
	local extra_cba   "ib0.totalflows_pw_pre_07_11`nbins'#i.cba_period"

	local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
	local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
	local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
	local s_spill     "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

	* ── DIRECT EFFECTS — PANELS A, B, C ────────────────────────────────────

	di _newline(1)
	di as result "--- Direct Effects (nbins=`nbins') ---"

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

		local csv_out "$tables/robustness/results_direct_panel`panel'_robustness_bins.csv"

		di as text "  Panel `panel' (nbins=`nbins')"

		* ── Year-based outcomes ─────────────────────────────────────────────

		foreach outcome in $base_outcomes $pct_outcomes_dec $pct_outcomes_hr $ratio_outcomes_dec $ratio_outcomes_hr {

			di as text "    Estimating: `outcome' (Panel `panel', bins=`nbins')"

			local absorb "`base_fe' ib0.`outcome'_pre`nbins'#i.year ib0.l_firm_emp_pre`nbins'#i.year `extra_year'"

			* Post-treatment
			reghdfe `outcome' treat_ultra##i.treat_year if `s_use', ///
				absorb(`absorb') vce(cluster identificad)

			local b_post  = _b[1.treat_ultra#1.treat_year]
			local se_post = _se[1.treat_ultra#1.treat_year]
			local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
			* taken before the placebo regression below replaces e(sample).
			quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
			local mean_pre_val = r(mean)

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

			* Write
			tempname fh
			file open `fh' using "`csv_out'", write append
			file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`p_pre') `"""' _n
			file close `fh'
		}

		* ── numb_clauses (CBA-period structure) ─────────────────────────────

		capture confirm variable numb_clauses
		if _rc == 0 {

			di as text "    Estimating: numb_clauses (CBA periods, Panel `panel', bins=`nbins')"

			local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre`nbins'#i.cba_period ib0.l_firm_emp_pre`nbins'#i.cba_period `extra_cba'"

			* Post-treatment
			reghdfe numb_clauses i.treat_ultra##post_treat_cba ///
				if `s_use' & !missing(cba_period), ///
				absorb(`absorb_cba') vce(cluster identificad)

			local b_post  = _b[1.treat_ultra#1.post_treat_cba]
			local se_post = _se[1.treat_ultra#1.post_treat_cba]
			local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
			* taken before the placebo regression below replaces e(sample).
			quietly sum numb_clauses if e(sample) & inrange(year, 2009, 2011)
			local mean_pre_val = r(mean)

			* Pre-treatment
			reghdfe numb_clauses i.treat_ultra##pre_treat_cba ///
				if `s_use' & !missing(cba_period) & cba_period <= 2, ///
				absorb(`absorb_cba') vce(cluster identificad)

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

			* Write
			tempname fh
			file open `fh' using "`csv_out'", write append
			file write `fh' `""`spec'";"`section'";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
			file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_pval";"' %9.4f (`p_pre') `"""' _n
			file close `fh'
		}

		di as result "  Panel `panel' complete (nbins=`nbins')."
	}

	* ── SPILLOVER EFFECTS ───────────────────────────────────────────────────

	di _newline(1)
	di as result "--- Spillover Effects (nbins=`nbins') ---"

	local csv_spill "$tables/robustness/results_spill_robustness_bins.csv"

	foreach outcome in $base_outcomes $pct_outcomes_dec $pct_outcomes_hr $ratio_outcomes_dec $ratio_outcomes_hr {

		di as text "  Estimating: `outcome' (spillover, bins=`nbins')"

		local absorb "`base_fe' ib0.`outcome'_pre`nbins'#i.year ib0.l_firm_emp_pre`nbins'#i.year `extra_year'"

		* Post-treatment
		reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_year#c.`conn']
		local se_post = _se[1.treat_year#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
		* taken before the placebo regression below replaces e(sample).
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

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

		* Write
		tempname fh
		file open `fh' using "`csv_spill'", write append
		file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`p_pre') `"""' _n
		file close `fh'
	}

	* numb_clauses spillover (CBA-period structure)
	capture confirm variable numb_clauses
	if _rc == 0 {

		di as text "  Estimating: numb_clauses (spillover, CBA periods, bins=`nbins')"

		local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre`nbins'#i.cba_period ib0.l_firm_emp_pre`nbins'#i.cba_period `extra_cba'"

		* Post-treatment
		reghdfe numb_clauses c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
		* taken before the placebo regression below replaces e(sample).
		quietly sum numb_clauses if e(sample) & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

		* Pre-treatment
		reghdfe numb_clauses c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

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

		* Write
		tempname fh
		file open `fh' using "`csv_spill'", write append
		file write `fh' `""`spec'";"spill";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`p_pre') `"""' _n
		file close `fh'
	}

	di as result "Spillover effects complete (nbins=`nbins')."

	* ── DROP BIN VARIABLES — one cap drop per line (CLAUDE.md rule) ─────────

	di as result "Dropping bin variables for nbins=`nbins'..."

	cap drop l_firm_emp_pre`nbins'
	cap drop lr_remdezr_w_pre`nbins'
	cap drop lr_remdezr_h_w_pre`nbins'
	cap drop numb_clauses_pre`nbins'
	cap drop totalflows_pw_pre_07_11`nbins'
	cap drop lr_remdezr_w_p10_pre`nbins'
	cap drop lr_remdezr_w_p20_pre`nbins'
	cap drop lr_remdezr_w_p25_pre`nbins'
	cap drop lr_remdezr_w_p50_pre`nbins'
	cap drop lr_remdezr_w_p75_pre`nbins'
	cap drop lr_remdezr_w_p80_pre`nbins'
	cap drop lr_remdezr_w_p90_pre`nbins'
	cap drop lr_remdezr_h_w_p10_pre`nbins'
	cap drop lr_remdezr_h_w_p20_pre`nbins'
	cap drop lr_remdezr_h_w_p25_pre`nbins'
	cap drop lr_remdezr_h_w_p50_pre`nbins'
	cap drop lr_remdezr_h_w_p75_pre`nbins'
	cap drop lr_remdezr_h_w_p80_pre`nbins'
	cap drop lr_remdezr_h_w_p90_pre`nbins'
	cap drop lr_remdezr_w_p90p10_pre`nbins'
	cap drop lr_remdezr_w_p80p20_pre`nbins'
	cap drop lr_remdezr_w_p75p25_pre`nbins'
	cap drop lr_remdezr_w_p90p50_pre`nbins'
	cap drop lr_remdezr_w_p80p50_pre`nbins'
	cap drop lr_remdezr_w_p75p50_pre`nbins'
	cap drop lr_remdezr_h_w_p90p10_pre`nbins'
	cap drop lr_remdezr_h_w_p80p20_pre`nbins'
	cap drop lr_remdezr_h_w_p75p25_pre`nbins'
	cap drop lr_remdezr_h_w_p90p50_pre`nbins'
	cap drop lr_remdezr_h_w_p80p50_pre`nbins'
	cap drop lr_remdezr_h_w_p75p50_pre`nbins'

	di as result "Bin variables dropped for nbins=`nbins'."
	di as result "=== COMPLETED BIN COUNT: `nbins' ==="

} // end foreach nbins in 10 20 50 100

********************************************************************************
* SECTION 5: COMPLETION + NOTIFICATION
********************************************************************************

di _newline(1)
di as result "All bin sensitivity regressions complete."
di as result "Finished: `c(current_date)' `c(current_time)'"

log close

* ── Auto-generate LaTeX tables ──────────────────────────────────────────────
shell ~/.conda/envs/venv_python312/bin/python "$programs/robustness/generate_robustness_latex.py"
di as result "LaTeX tables written to Tables/robustness/robustness_bins_tables.tex"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "Main_Results_robustness_bins.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
