********************************************************************************
* labor_prefix_effects.do
* Direct and spillover effects for year-based labor outcomes using the
* specification in 4012_pct_tfpw.do, excluding firms whose
* identificad starts with 10877926.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/numb_clauses_outliers"
log using "$logs/numb_clauses_outliers/labor_prefix_effects_`d'_`t'.log", replace text

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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: YEAR-BASED VARIABLES FROM 4012_pct_tfpw.do
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

local s_spill_base "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill_base' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
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

cap drop id8
cap drop prefix_10877926_firm
gen str8 id8 = substr(identificad, 1, 8)
gen byte prefix_10877926_firm = id8 == "10877926"

********************************************************************************
* SECTION 3: ESTIMATION MACROS + OUTPUT FILES
********************************************************************************

local spec "tfpw_07_11_drop_prefix_10877926"
local conn "totaltreat_pw_norm"
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & prefix_10877926_firm==0"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & prefix_10877926_firm==0"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & prefix_10877926_firm==0"
local s_spill "`s_spill_base' & prefix_10877926_firm==0"

tempname direct_post spill_post
tempfile direct_results spill_results

postfile `direct_post' str32 spec str16 section str24 outcome double b_post se_post p_post ///
	double b_pre se_pre p_pre pre_ftest_pval n_obs n_estab using `direct_results', replace
postfile `spill_post' str32 spec str16 section str24 outcome double b_post se_post p_post ///
	double b_pre se_pre p_pre pre_ftest_pval n_obs n_estab using `spill_results', replace

********************************************************************************
* SECTION 4: DIRECT EFFECTS, PANELS A-C
********************************************************************************

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

	foreach outcome of local outcomes {
		di as text "Direct panel `panel': `outcome'"
		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		reghdfe `outcome' i.treat_ultra##i.treat_year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		local b_post = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
		local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs = e(N)
		local n_estab = e(N_clust)

		reghdfe `outcome' i.treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)
		local b_pre = _b[1.treat_ultra#1.placebo_year]
		local se_pre = _se[1.treat_ultra#1.placebo_year]
		local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = r(p)

		post `direct_post' ("`spec'") ("`section'") ("`outcome'") ///
			(`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') ///
			(`pre_ftest_pval') (`n_obs') (`n_estab')
	}
}

********************************************************************************
* SECTION 5: SPILLOVER EFFECTS
********************************************************************************

foreach outcome of local outcomes {
	di as text "Spillover: `outcome'"
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

	post `spill_post' ("`spec'") ("spill") ("`outcome'") ///
		(`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') ///
		(`pre_ftest_pval') (`n_obs') (`n_estab')
}

postclose `direct_post'
postclose `spill_post'

preserve
	use `direct_results', clear
	export delimited using "$tables/numb_clauses_outliers/labor_prefix_direct_results.csv", replace
restore

preserve
	use `spill_results', clear
	export delimited using "$tables/numb_clauses_outliers/labor_prefix_spill_results.csv", replace
restore

di as result "Prefix-excluded labor outcome regressions complete."
log close
