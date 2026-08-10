********************************************************************************
* numb_clauses_outliers.do
* Top-1% numb_clauses outlier investigation for the spillover clause-count
* analysis. Outliers are defined in the cba_period == 1 cross-section.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/numb_clauses_outliers"
log using "$logs/numb_clauses_outliers/numb_clauses_outliers_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/numb_clauses_outliers"
cap mkdir "$graphs/numb_clauses_outliers"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

capture confirm string variable identificad
if _rc {
	tostring identificad, replace format(%014.0f) force
}

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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: CLAUSE COUNT VARIABLES
********************************************************************************

cap drop wage_clauses
cap drop emp_clauses
cap drop other_clauses
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

label var wage_clauses  "Count of wage-related clauses"
label var emp_clauses   "Count of employment clauses"
label var other_clauses "Count of other clauses"

********************************************************************************
* SECTION 3: VARIABLE CREATION
********************************************************************************

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
label var cba_period "CBA negotiation period"

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

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

foreach v in numb_clauses wage_clauses emp_clauses other_clauses {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}

	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
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

********************************************************************************
* SECTION 4: TOP-1% FIRM FLAG + FIRM LISTS
********************************************************************************

local conn "totaltreat_pw_norm"
local outcomes "numb_clauses wage_clauses emp_clauses other_clauses"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

cap drop firm_period1_numb
cap drop period1_total_numb
cap drop firm_period1_clause_share
cap drop top1_numb_clause_firm
cap drop period1_clause_share_gt1pct_firm
cap drop prefix_10877926_firm
cap drop id8
cap drop firm_conn

bys identificad: egen firm_period1_numb = max(cond(`s_spill' & cba_period == 1, numb_clauses, .))
quietly summarize firm_period1_numb if `s_spill' & cba_period == 1 & !missing(firm_period1_numb), detail
local p99_numb = r(p99)
quietly summarize numb_clauses if `s_spill' & cba_period == 1 & !missing(numb_clauses), meanonly
local period1_total_numb = r(sum)

gen byte top1_numb_clause_firm = firm_period1_numb >= `p99_numb' if !missing(firm_period1_numb)
replace top1_numb_clause_firm = 0 if missing(top1_numb_clause_firm)
gen double period1_total_numb = `period1_total_numb'
gen double firm_period1_clause_share = firm_period1_numb / period1_total_numb if !missing(firm_period1_numb)
gen byte period1_clause_share_gt1pct_firm = firm_period1_clause_share > 0.01 if !missing(firm_period1_clause_share)
replace period1_clause_share_gt1pct_firm = 0 if missing(period1_clause_share_gt1pct_firm)
gen str8 id8 = substr(identificad, 1, 8)
gen byte prefix_10877926_firm = id8 == "10877926"
bys identificad: egen firm_conn = max(`conn')

preserve
	keep if `s_spill' & cba_period == 1 & !missing(firm_period1_numb)
	bys identificad: keep if _n == 1
	count
	local period1_firms = r(N)
	count if top1_numb_clause_firm == 1
	local top1_firms = r(N)
	count if period1_clause_share_gt1pct_firm == 1
	local share_gt1pct_firms = r(N)
	clear
	set obs 1
	gen double p99_numb_clause_cutoff = `p99_numb'
	gen double period1_total_numb_clauses = `period1_total_numb'
	gen long n_period1_spillover_firms = `period1_firms'
	gen long n_top1_firms = `top1_firms'
	gen double top1_firm_share = n_top1_firms / n_period1_spillover_firms
	gen long n_share_gt1pct_firms = `share_gt1pct_firms'
	export delimited using "$tables/numb_clauses_outliers/top1_numb_clause_threshold.csv", replace
restore

preserve
	keep if `s_spill' & cba_period == 1 & top1_numb_clause_firm == 1 & !missing(firm_period1_numb)
	bys identificad: keep if _n == 1
	keep identificad id8 firm_period1_numb firm_conn firm_emp_pre industry1 ///
		microregion mode_base_month totalflows_pw_pre_07_11
	gsort -firm_period1_numb -firm_conn identificad
	gen rank_top1_numb = _n
	export delimited using "$tables/numb_clauses_outliers/top1_numb_clause_firms.csv", replace
restore

preserve
	keep if `s_spill' & cba_period == 1 & top1_numb_clause_firm == 1 & !missing(firm_period1_numb)
	bys identificad: keep if _n == 1
	collapse (count) n_firms=firm_period1_numb ///
		(mean) mean_period1_numb=firm_period1_numb mean_conn=firm_conn ///
		(max) max_period1_numb=firm_period1_numb max_conn=firm_conn, by(id8)
	egen total_top1_firms = total(n_firms)
	gen double share_top1_firms = n_firms / total_top1_firms
	gsort -n_firms -max_period1_numb id8
	gen rank_prefix = _n
	export delimited using "$tables/numb_clauses_outliers/top1_numb_clause_prefix_summary.csv", replace
restore

preserve
	keep if `s_spill' & cba_period == 1 & period1_clause_share_gt1pct_firm == 1 ///
		& !missing(firm_period1_clause_share)
	bys identificad: keep if _n == 1
	keep identificad id8 firm_period1_numb firm_period1_clause_share period1_total_numb ///
		top1_numb_clause_firm prefix_10877926_firm firm_conn firm_emp_pre ///
		industry1 microregion mode_base_month totalflows_pw_pre_07_11
	gsort -firm_period1_clause_share -firm_conn identificad
	gen rank_period1_share_gt1pct = _n
	export delimited using "$tables/numb_clauses_outliers/period1_clause_share_gt1pct_firms.csv", replace
restore

preserve
	keep if `s_spill' & prefix_10877926_firm == 1
	bys identificad: keep if _n == 1
	keep identificad id8 firm_period1_numb firm_period1_clause_share top1_numb_clause_firm ///
		period1_clause_share_gt1pct_firm firm_conn firm_emp_pre ///
		industry1 microregion mode_base_month totalflows_pw_pre_07_11
	gsort -top1_numb_clause_firm -firm_period1_numb -firm_conn identificad
	gen rank_prefix_10877926 = _n
	export delimited using "$tables/numb_clauses_outliers/prefix_10877926_firms.csv", replace
restore

********************************************************************************
* SECTION 5: BASELINE VS TOP-1% FIRM-TRIMMED SPILLOVER REGRESSIONS
********************************************************************************

capture erase "$tables/numb_clauses_outliers/spillover_clause_count_outlier_results.csv"
tempname results
tempfile results_file
postfile `results' str40 sample str24 outcome double b_post se_post p_post ///
	double b_pre se_pre p_pre pre_ftest_pval n_obs n_estab using `results_file', replace

foreach sample in baseline drop_top1_firms drop_prefix_10877926 drop_period1_share_gt1pct {
	local trim_if ""
	if "`sample'" == "drop_top1_firms" {
		local trim_if "& top1_numb_clause_firm == 0"
	}
	if "`sample'" == "drop_prefix_10877926" {
		local trim_if "& prefix_10877926_firm == 0"
	}
	if "`sample'" == "drop_period1_share_gt1pct" {
		local trim_if "& period1_clause_share_gt1pct_firm == 0"
	}

	foreach outcome of local outcomes {
		di as text "Estimating `outcome' (`sample')"
		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period) `trim_if', ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2 `trim_if', ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		reghdfe `outcome' c.`conn'##ib2.cba_period ///
			if `s_spill' & !missing(cba_period) `trim_if', ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		post `results' ("`sample'") ("`outcome'") (`b_post') (`se_post') (`p_post') ///
			(`b_pre') (`se_pre') (`p_pre') (`pre_ftest_pval') (`n_obs') (`n_estab')
	}
}

postclose `results'

preserve
	use `results_file', clear
	export delimited using "$tables/numb_clauses_outliers/spillover_clause_count_outlier_results.csv", replace
restore

di as result "numb_clauses outlier analysis complete."
log close
