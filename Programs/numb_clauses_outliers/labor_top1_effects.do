********************************************************************************
* labor_top1_effects.do
* Spillover effects for year-based labor outcomes using the specification in
* Main_Results_pct_tfpw_07_11.do. Compares the baseline spillover sample to a
* sample excluding firms in the top 1% of numb_clauses in cba_period == 1.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/numb_clauses_outliers"
log using "$logs/numb_clauses_outliers/labor_top1_effects_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/numb_clauses_outliers"

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

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: YEAR-BASED VARIABLES + TOP-1% CBA-PERIOD-1 FLAG
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

local s_spill_base "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill_base' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_period1_numb
cap drop top1_numb_clause_firm
bys identificad: egen firm_period1_numb = max(cond(`s_spill_base' & cba_period == 1, numb_clauses, .))
quietly summarize firm_period1_numb if `s_spill_base' & cba_period == 1 & !missing(firm_period1_numb), detail
local p99_numb = r(p99)
gen byte top1_numb_clause_firm = firm_period1_numb >= `p99_numb' if !missing(firm_period1_numb)
replace top1_numb_clause_firm = 0 if missing(top1_numb_clause_firm)

preserve
	keep if `s_spill_base' & cba_period == 1 & !missing(firm_period1_numb)
	bys identificad: keep if _n == 1
	count
	local period1_firms = r(N)
	count if top1_numb_clause_firm == 1
	local top1_firms = r(N)
	clear
	set obs 1
	gen double p99_numb_clause_cutoff = `p99_numb'
	gen long n_period1_spillover_firms = `period1_firms'
	gen long n_top1_firms = `top1_firms'
	gen double top1_firm_share = n_top1_firms / n_period1_spillover_firms
	export delimited using "$tables/numb_clauses_outliers/labor_top1_threshold.csv", replace
restore

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}

	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		egen `outcome'_pre4_o = cut(`outcome'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
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
* SECTION 3: SPILLOVER ESTIMATION
********************************************************************************

local spec "tfpw_07_11_top1_period1_numb"
local conn "totaltreat_pw_norm"
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

tempname results
tempfile results_file
postfile `results' str32 spec str32 sample str24 outcome double b_post se_post p_post ///
	double b_pre se_pre p_pre pre_ftest_pval n_obs n_estab using `results_file', replace

foreach sample in baseline drop_top1_period1_numb {
	local s_spill "`s_spill_base'"
	if "`sample'" == "drop_top1_period1_numb" {
		local s_spill "`s_spill_base' & top1_numb_clause_firm == 0"
	}

	foreach outcome of local outcomes {
		di as text "Labor spillover `sample': `outcome'"
		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)
		local b_post = _b[1.treat_year#c.`conn']
		local se_post = _se[1.treat_year#c.`conn']
		local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)
		local b_pre = _b[1.placebo_year#c.`conn']
		local se_pre = _se[1.placebo_year#c.`conn']
		local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)
		testparm c.`conn'#i(2009 2010).year
		local pre_ftest_pval = r(p)

		post `results' ("`spec'") ("`sample'") ("`outcome'") ///
			(`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') ///
			(`pre_ftest_pval') (`n_obs') (`n_estab')
	}
}

postclose `results'

preserve
	use `results_file', clear
	export delimited using "$tables/numb_clauses_outliers/labor_top1_spill_results.csv", replace
restore

di as result "Top-1%-excluded labor spillover regressions complete."
log close
