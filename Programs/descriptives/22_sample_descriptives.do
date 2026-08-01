********************************************************************************
* UNION SPILLOVERS — SAMPLE DESCRIPTIVE STATISTICS
* Purpose: Generate descriptive statistics tables (two versions)
*          Table 1: values at 2011 (last pre-treatment year)
*          Table 2: pre-treatment firm-level averages (2009-2011)
* Output:  Tables/descriptives/descriptive_stats_2011.csv
*          Tables/descriptives/descriptive_stats_pretreat.csv
* Notes:   totalflows_pw_n_07_11 (pre-treatment flows) is identical in both
*          tables. Age data merged from avg_age_firm_year.csv.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/descriptives/descriptives_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: LOAD DATA AND MERGES
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
drop _merge

* ── Merge connectivity (post-treatment agg) ──────────────────────────────────
merge m:1 identificad using "$rais_aux/connectivity_post_treat_agg.dta", nogen keep(master match)

* ── Merge totalflows wide 2007-2011 ──────────────────────────────────────────
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* ── Merge average worker age ─────────────────────────────────────────────────
preserve
	import delimited "$rais_firm/avg_age_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile avg_age_data
	save `avg_age_data'
restore
merge m:1 identificad year using `avg_age_data', keep(master match) nogen
label var avg_age "Average worker age at the firm (Dec employment)"

* ── Merge network size ───────────────────────────────────────────────────────
preserve
	import delimited "$rais_aux/network_degree_full_rais.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile network_size
	save `network_size'
restore
merge m:1 identificad using `network_size', keep(master match) nogen

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 1b: CBA ESTIMATION-SAMPLE FLAG  ($EST_SAMPLE_ONLY)
********************************************************************************
* The clause / CBA-value effects are estimated on CBA negotiation periods, not
* calendar years, so their estimation sample is smaller than the full untreated
* panel. When $EST_SAMPLE_ONLY == "1" the descriptive columns are restricted to
* establishments that actually contribute to those regressions: firms observed
* with non-missing CBA data in BOTH a pre period (cba_period 1-2) and a post
* period (cba_period 3-6).
*
* cba_period is copied verbatim from Programs/clause_types/clause_types.do.

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
label var cba_period "CBA negotiation period"

cap drop has_cba_pre_o
cap drop has_cba_post_o
cap drop has_cba_pre
cap drop has_cba_post
cap drop cba_est_sample
quietly {
	gen byte has_cba_pre_o  = inrange(cba_period, 1, 2)
	gen byte has_cba_post_o = inrange(cba_period, 3, 6)
	bys identificad: egen byte has_cba_pre  = max(has_cba_pre_o)
	bys identificad: egen byte has_cba_post = max(has_cba_post_o)
	gen byte cba_est_sample = (has_cba_pre == 1 & has_cba_post == 1)
	drop has_cba_pre_o
	drop has_cba_post_o
}
label var cba_est_sample "Firm has CBA data in both a pre and a post negotiation period"

* Diagnostics: untreated establishment counts under each candidate restriction
local dbase "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
quietly distinct identificad if `dbase' & year == 2009
di as result "Untreated estabs, no CBA restriction:        " r(ndistinct)
quietly distinct identificad if `dbase' & year == 2009 & !missing(cba_period)
di as result "Untreated estabs, any non-missing cba_period: " r(ndistinct)
quietly distinct identificad if `dbase' & year == 2009 & cba_est_sample == 1
di as result "Untreated estabs, pre AND post cba_period:    " r(ndistinct)

if "$EST_SAMPLE_ONLY" == "1" {
	di as result "EST_SAMPLE_ONLY=1 -> restricting descriptives to cba_est_sample"
}

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

* ── CBA period ───────────────────────────────────────────────────────────────
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

* ── Log employment ───────────────────────────────────────────────────────────
cap drop l_firm_emp
gen double l_firm_emp = ln(firm_emp)

* ── Wage inequality ratios ────────────────────────────────────────────────────
foreach wage in lr_remdezr_w {
	cap drop `wage'_p90p10
	cap drop `wage'_p90p50
	cap drop `wage'_p50p10
	gen double `wage'_p90p10 = `wage'_p90 - `wage'_p10
	gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
	gen double `wage'_p50p10 = `wage'_p50 - `wage'_p10
}

* ── Female and non-white proportions ─────────────────────────────────────────
cap drop prop_female
cap drop prop_nonwhite
gen double prop_female   = 1 - male_prop
gen double prop_nonwhite = 1 - white_prop

* ── Total flows per worker 2007-2011 (firm-level constant) ───────────────────
* Already in the wide file: average of year-pair ratios
cap drop totalflows_pw_n_07_11
gen double totalflows_pw_n_07_11 = 0
cap drop _tf_cnt
gen _tf_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_n_07_11 = totalflows_pw_n_07_11 + `yp' if !missing(`yp')
	replace _tf_cnt = _tf_cnt + (!missing(`yp'))
}
replace totalflows_pw_n_07_11 = totalflows_pw_n_07_11 / _tf_cnt if _tf_cnt > 0
replace totalflows_pw_n_07_11 = . if _tf_cnt == 0
drop _tf_cnt
label var totalflows_pw_n_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

* ── Pre-treatment averages of time-varying variables (used for Table 2) ──────
* Outcomes averaged over 2009-2011
foreach v in firm_emp r_remdezr prop_hs prop_sup prop_female prop_nonwhite ///
             avg_tenure avg_age {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* Wage inequality ratios pre-treatment averages
foreach v in lr_remdezr_w_p90p10 lr_remdezr_w_p90p50 lr_remdezr_w_p50p10 {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* Within-firm median wage pre-treatment average
cap drop lr_remdezr_w_p50_pre_o
cap drop lr_remdezr_w_p50_pre
quietly {
	bys identificad: egen lr_remdezr_w_p50_pre_o = mean(lr_remdezr_w_p50) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_w_p50_pre   = min(lr_remdezr_w_p50_pre_o)
	drop lr_remdezr_w_p50_pre_o
}

* Connectivity pre-treatment average (for group definition in Table 2)
cap drop totaltreat_pw_n_pre_o
cap drop totaltreat_pw_n_pre
quietly {
	bys identificad: egen totaltreat_pw_n_pre_o = mean(totaltreat_pw_n) if inrange(year, 2009, 2011)
	bys identificad: egen totaltreat_pw_n_pre   = min(totaltreat_pw_n_pre_o)
	drop totaltreat_pw_n_pre_o
}

di as result "Variables created successfully."

********************************************************************************
* SECTION 3: GROUP DEFINITIONS
********************************************************************************
* Groups use firm-invariant characteristics; connectivity split uses the
* reference year of each table (2011 for Table 1, pretreat avg for Table 2).

local base "lagos_sample_avg==1 & in_balanced_panel==1"
if "$EST_SAMPLE_ONLY" == "1" local base "`base' & cba_est_sample==1"

* Table 1 (year==2011) groups
local g1_cond_t1 "`base'"
local g2_cond_t1 "`base' & treat_ultra==1"
local g3_cond_t1 "`base' & treat_ultra==0"
local g4_cond_t1 "`base' & treat_ultra==0 & totaltreat_pw_n>0"
local g5_cond_t1 "`base' & treat_ultra==0 & totaltreat_pw_n==0"

* Table 2 (pretreat avg) groups — connectivity split on pretreat average
local g1_cond_t2 "`base'"
local g2_cond_t2 "`base' & treat_ultra==1"
local g3_cond_t2 "`base' & treat_ultra==0"
local g4_cond_t2 "`base' & treat_ultra==0 & totaltreat_pw_n_pre>0"
local g5_cond_t2 "`base' & treat_ultra==0 & totaltreat_pw_n_pre==0"

********************************************************************************
* SECTION 4: COMPUTE STATISTICS — MACRO TO RUN FOR EACH TABLE
********************************************************************************

* We loop over the two table versions. Within each, we loop over 5 groups.
* tver = 1 => use year==2011; tver = 2 => use _pre variables

foreach tver in 1 2 {

	if `tver' == 1 {
		local ref_year 2011
		local tab_suffix "2011"
		local tab_label  "2011 (last pre-treatment year)"
	}
	else {
		local ref_year 2009   // placeholder; pretreat uses _pre vars, not a single year
		local tab_suffix "pretreat"
		local tab_label  "Pre-treatment average 2009-2011"
	}

	di _newline(2)
	di as result "{hline 70}"
	di as result "TABLE VERSION: `tab_label'"
	di as result "{hline 70}"

	forvalues g = 1/5 {

		local cond "`g`g'_cond_t`tver''"

		di _newline(1)
		di as result "  Group `g' [Table `tver']"
		di as result "  Condition: `cond'"

		* ── (a) Choose reference observations ────────────────────────────────
		* Table 1: single cross-section at year==ref_year
		* Table 2: collapse to firm level already done via _pre vars;
		*          we pick year==2009 to get one row per firm with _pre vars

		if `tver' == 1 {
			local yr_cond "& year==`ref_year'"
		}
		else {
			local yr_cond "& year==2009"
		}

		* Helper macro: get the right variable (current vs pretreat-average)
		* For Table 2, time-varying outcomes use the _pre version

		* ── 1. Number of establishments ──────────────────────────────────────
		count if `cond' `yr_cond'
		local n_estab_g`g' = r(N)

		* ── 2. Total workers ──────────────────────────────────────────────────
		if `tver' == 1 {
			sum firm_emp if `cond' `yr_cond', meanonly
		}
		else {
			sum firm_emp_pre if `cond' `yr_cond', meanonly
		}
		local n_workers_g`g' = r(sum)

		* ── 3. Mean establishment size ────────────────────────────────────────
		if `tver' == 1 {
			sum firm_emp if `cond' `yr_cond', meanonly
		}
		else {
			sum firm_emp_pre if `cond' `yr_cond', meanonly
		}
		local mean_emp_g`g' = r(mean)

		* ── 4. Size bins (% of firms) ─────────────────────────────────────────
		* Use current-year employment for bin sorting in Table 1,
		* pre-treatment average employment for Table 2.
		count if `cond' `yr_cond'
		local N_g = r(N)

		if `tver' == 1 {
			local emp_v "firm_emp"
		}
		else {
			local emp_v "firm_emp_pre"
		}

		count if `cond' `yr_cond' & `emp_v' >= 1   & `emp_v' <= 10
		local prop_bin1_g`g' = r(N) / `N_g'
		count if `cond' `yr_cond' & `emp_v' >= 11  & `emp_v' <= 30
		local prop_bin2_g`g' = r(N) / `N_g'
		count if `cond' `yr_cond' & `emp_v' >= 31  & `emp_v' <= 100
		local prop_bin3_g`g' = r(N) / `N_g'
		count if `cond' `yr_cond' & `emp_v' >= 101 & !missing(`emp_v')
		local prop_bin4_g`g' = r(N) / `N_g'

		* ── 5. Demographics ───────────────────────────────────────────────────
		if `tver' == 1 {
			sum prop_hs       if `cond' `yr_cond', meanonly
			local prop_hs_g`g' = r(mean)
			sum prop_sup      if `cond' `yr_cond', meanonly
			local prop_sup_g`g' = r(mean)
			sum prop_female   if `cond' `yr_cond', meanonly
			local prop_female_g`g' = r(mean)
			sum prop_nonwhite if `cond' `yr_cond', meanonly
			local prop_nonwhite_g`g' = r(mean)
			sum avg_age       if `cond' `yr_cond', meanonly
			local mean_age_g`g' = r(mean)
			sum avg_tenure    if `cond' `yr_cond', meanonly
			local mean_tenure_g`g' = r(mean) / 12
		}
		else {
			sum prop_hs_pre       if `cond' `yr_cond', meanonly
			local prop_hs_g`g' = r(mean)
			sum prop_sup_pre      if `cond' `yr_cond', meanonly
			local prop_sup_g`g' = r(mean)
			sum prop_female_pre   if `cond' `yr_cond', meanonly
			local prop_female_g`g' = r(mean)
			sum prop_nonwhite_pre if `cond' `yr_cond', meanonly
			local prop_nonwhite_g`g' = r(mean)
			sum avg_age_pre       if `cond' `yr_cond', meanonly
			local mean_age_g`g' = r(mean)
			sum avg_tenure_pre    if `cond' `yr_cond', meanonly
			local mean_tenure_g`g' = r(mean) / 12
		}

		* ── 6. Mean December wages ────────────────────────────────────────────
		if `tver' == 1 {
			sum r_remdezr if `cond' `yr_cond', meanonly
		}
		else {
			sum r_remdezr_pre if `cond' `yr_cond', meanonly
		}
		local mean_wage_g`g' = r(mean)

		* ── 7. Mean of within-firm median wages ──────────────────────────────
		if `tver' == 1 {
			cap drop _temp_med
			gen double _temp_med = exp(lr_remdezr_w_p50)
			sum _temp_med if `cond' `yr_cond', meanonly
			local mean_med_wage_g`g' = r(mean)
			drop _temp_med
		}
		else {
			cap drop _temp_med
			gen double _temp_med = exp(lr_remdezr_w_p50_pre)
			sum _temp_med if `cond' `yr_cond', meanonly
			local mean_med_wage_g`g' = r(mean)
			drop _temp_med
		}

		* ── 8. Mean clause count (CBA period 1) ──────────────────────────────
		* CBA clause count is a pre-treatment characteristic; same for both
		sum numb_clauses if `cond' & cba_period == 1, meanonly
		local mean_clauses_g`g' = r(mean)

		* ── 9. Wage inequality ratios (exponentiated log differences) ─────────
		if `tver' == 1 {
			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p90p10)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p90p10_g`g' = r(mean)
			drop _tmp

			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p90p50)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p90p50_g`g' = r(mean)
			drop _tmp

			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p50p10)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p50p10_g`g' = r(mean)
			drop _tmp
		}
		else {
			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p90p10_pre)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p90p10_g`g' = r(mean)
			drop _tmp

			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p90p50_pre)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p90p50_g`g' = r(mean)
			drop _tmp

			cap drop _tmp
			gen double _tmp = exp(lr_remdezr_w_p50p10_pre)
			sum _tmp if `cond' `yr_cond', meanonly
			local mean_p50p10_g`g' = r(mean)
			drop _tmp
		}

		* ── 10. Connectivity ──────────────────────────────────────────────────
		if `tver' == 1 {
			sum totaltreat_pw_n if `cond' `yr_cond', detail
		}
		else {
			sum totaltreat_pw_n_pre if `cond' `yr_cond', detail
		}
		local mean_conn_g`g'   = r(mean)
		local median_conn_g`g' = r(p50)

		* ── 11. Total flows per worker 2007-2011 (same for both tables) ───────
		sum totalflows_pw_n_07_11 if `cond' `yr_cond', meanonly
		local mean_tfpw_g`g' = r(mean)

		* ── 12. Network size and treated connections ──────────────────────────
		capture confirm variable n_connected_4yr
		if _rc == 0 {
			sum n_connected_4yr if `cond' `yr_cond', detail
			local mean_netsize_g`g'   = r(mean)
			local median_netsize_g`g' = r(p50)
		}
		else {
			local mean_netsize_g`g'   = .
			local median_netsize_g`g' = .
		}

		capture confirm variable totaltreat_n
		if _rc == 0 {
			if `tver' == 1 {
				sum totaltreat_n if `cond' `yr_cond', meanonly
			}
			else {
				* use 2009 obs (pretreat average of totaltreat_n is in main data)
				sum totaltreat_n if `cond' `yr_cond', meanonly
			}
			local mean_treat_conn_g`g' = r(mean)
		}
		else {
			local mean_treat_conn_g`g' = .
		}

		di as text "  n_estab=`n_estab_g`g'', mean_emp=`: display %6.1f `mean_emp_g`g'''"
	}

	* ── Write CSV ─────────────────────────────────────────────────────────────
	local est_suffix ""
	if "$EST_SAMPLE_ONLY" == "1" local est_suffix "_estsample"
	local outfile "$tables/descriptives/descriptive_stats_`tab_suffix'`est_suffix'.csv"
	capture erase "`outfile'"
	tempname fh
	file open `fh' using "`outfile'", write replace
	file write `fh' "statistic;Overall;Treated;Untreated;Untreated_Conn;Untreated_Zero" _n

	* Panel A
	file write `fh' "N establishments" ";" %12.0f (`n_estab_g1') ";" %12.0f (`n_estab_g2') ";" %12.0f (`n_estab_g3') ";" %12.0f (`n_estab_g4') ";" %12.0f (`n_estab_g5') _n
	file write `fh' "Total workers"    ";" %12.0f (`n_workers_g1') ";" %12.0f (`n_workers_g2') ";" %12.0f (`n_workers_g3') ";" %12.0f (`n_workers_g4') ";" %12.0f (`n_workers_g5') _n
	file write `fh' "Mean estab size"  ";" %9.2f (`mean_emp_g1') ";" %9.2f (`mean_emp_g2') ";" %9.2f (`mean_emp_g3') ";" %9.2f (`mean_emp_g4') ";" %9.2f (`mean_emp_g5') _n

	* Panel B
	file write `fh' "Share 1-10 emp"   ";" %9.4f (`prop_bin1_g1') ";" %9.4f (`prop_bin1_g2') ";" %9.4f (`prop_bin1_g3') ";" %9.4f (`prop_bin1_g4') ";" %9.4f (`prop_bin1_g5') _n
	file write `fh' "Share 11-30 emp"  ";" %9.4f (`prop_bin2_g1') ";" %9.4f (`prop_bin2_g2') ";" %9.4f (`prop_bin2_g3') ";" %9.4f (`prop_bin2_g4') ";" %9.4f (`prop_bin2_g5') _n
	file write `fh' "Share 31-100 emp" ";" %9.4f (`prop_bin3_g1') ";" %9.4f (`prop_bin3_g2') ";" %9.4f (`prop_bin3_g3') ";" %9.4f (`prop_bin3_g4') ";" %9.4f (`prop_bin3_g5') _n
	file write `fh' "Share 101+ emp"   ";" %9.4f (`prop_bin4_g1') ";" %9.4f (`prop_bin4_g2') ";" %9.4f (`prop_bin4_g3') ";" %9.4f (`prop_bin4_g4') ";" %9.4f (`prop_bin4_g5') _n

	* Panel C
	file write `fh' "Prop high school"   ";" %9.4f (`prop_hs_g1')       ";" %9.4f (`prop_hs_g2')       ";" %9.4f (`prop_hs_g3')       ";" %9.4f (`prop_hs_g4')       ";" %9.4f (`prop_hs_g5')       _n
	file write `fh' "Prop higher ed"     ";" %9.4f (`prop_sup_g1')      ";" %9.4f (`prop_sup_g2')      ";" %9.4f (`prop_sup_g3')      ";" %9.4f (`prop_sup_g4')      ";" %9.4f (`prop_sup_g5')      _n
	file write `fh' "Prop female"        ";" %9.4f (`prop_female_g1')   ";" %9.4f (`prop_female_g2')   ";" %9.4f (`prop_female_g3')   ";" %9.4f (`prop_female_g4')   ";" %9.4f (`prop_female_g5')   _n
	file write `fh' "Prop non-white"     ";" %9.4f (`prop_nonwhite_g1') ";" %9.4f (`prop_nonwhite_g2') ";" %9.4f (`prop_nonwhite_g3') ";" %9.4f (`prop_nonwhite_g4') ";" %9.4f (`prop_nonwhite_g5') _n
	file write `fh' "Mean worker age"    ";" %9.2f (`mean_age_g1')      ";" %9.2f (`mean_age_g2')      ";" %9.2f (`mean_age_g3')      ";" %9.2f (`mean_age_g4')      ";" %9.2f (`mean_age_g5')      _n
	file write `fh' "Mean worker tenure" ";" %9.2f (`mean_tenure_g1')   ";" %9.2f (`mean_tenure_g2')   ";" %9.2f (`mean_tenure_g3')   ";" %9.2f (`mean_tenure_g4')   ";" %9.2f (`mean_tenure_g5')   _n

	* Panel D
	file write `fh' "Mean dec wages"       ";" %9.2f (`mean_wage_g1')      ";" %9.2f (`mean_wage_g2')      ";" %9.2f (`mean_wage_g3')      ";" %9.2f (`mean_wage_g4')      ";" %9.2f (`mean_wage_g5')      _n
	file write `fh' "Mean median wages" ";" %9.2f (`mean_med_wage_g1')  ";" %9.2f (`mean_med_wage_g2')  ";" %9.2f (`mean_med_wage_g3')  ";" %9.2f (`mean_med_wage_g4')  ";" %9.2f (`mean_med_wage_g5')  _n
	file write `fh' "Mean clause count"    ";" %9.2f (`mean_clauses_g1')   ";" %9.2f (`mean_clauses_g2')   ";" %9.2f (`mean_clauses_g3')   ";" %9.2f (`mean_clauses_g4')   ";" %9.2f (`mean_clauses_g5')   _n

	* Panel E
	file write `fh' "p90/p10" ";" %9.2f (`mean_p90p10_g1') ";" %9.2f (`mean_p90p10_g2') ";" %9.2f (`mean_p90p10_g3') ";" %9.2f (`mean_p90p10_g4') ";" %9.2f (`mean_p90p10_g5') _n
	file write `fh' "p90/p50" ";" %9.2f (`mean_p90p50_g1') ";" %9.2f (`mean_p90p50_g2') ";" %9.2f (`mean_p90p50_g3') ";" %9.2f (`mean_p90p50_g4') ";" %9.2f (`mean_p90p50_g5') _n
	file write `fh' "p50/p10" ";" %9.2f (`mean_p50p10_g1') ";" %9.2f (`mean_p50p10_g2') ";" %9.2f (`mean_p50p10_g3') ";" %9.2f (`mean_p50p10_g4') ";" %9.2f (`mean_p50p10_g5') _n

	* Panel F
	file write `fh' "Mean connectivity"         ";" %9.4f (`mean_conn_g1')       ";" %9.4f (`mean_conn_g2')       ";" %9.4f (`mean_conn_g3')       ";" %9.4f (`mean_conn_g4')       ";" %9.4f (`mean_conn_g5')       _n
	file write `fh' "Median connectivity"       ";" %9.4f (`median_conn_g1')     ";" %9.4f (`median_conn_g2')     ";" %9.4f (`median_conn_g3')     ";" %9.4f (`median_conn_g4')     ";" %9.4f (`median_conn_g5')     _n
	file write `fh' "Mean total flows pw 07-11" ";" %9.4f (`mean_tfpw_g1')       ";" %9.4f (`mean_tfpw_g2')       ";" %9.4f (`mean_tfpw_g3')       ";" %9.4f (`mean_tfpw_g4')       ";" %9.4f (`mean_tfpw_g5')       _n
	file write `fh' "Mean network size"         ";" %9.2f (`mean_netsize_g1')    ";" %9.2f (`mean_netsize_g2')    ";" %9.2f (`mean_netsize_g3')    ";" %9.2f (`mean_netsize_g4')    ";" %9.2f (`mean_netsize_g5')    _n
	file write `fh' "Median network size"       ";" %9.2f (`median_netsize_g1')  ";" %9.2f (`median_netsize_g2')  ";" %9.2f (`median_netsize_g3')  ";" %9.2f (`median_netsize_g4')  ";" %9.2f (`median_netsize_g5')  _n
	file write `fh' "Mean treated connections"  ";" %9.2f (`mean_treat_conn_g1') ";" %9.2f (`mean_treat_conn_g2') ";" %9.2f (`mean_treat_conn_g3') ";" %9.2f (`mean_treat_conn_g4') ";" %9.2f (`mean_treat_conn_g5') _n

	file close `fh'

	di as result "Saved: `outfile'"
}

di _newline(2)
di as result "{hline 60}"
di as result "All descriptive stats saved to Tables/descriptives/"
di as result "{hline 60}"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "22_sample_descriptives.do complete"

capture log close
