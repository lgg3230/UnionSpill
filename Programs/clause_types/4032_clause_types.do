********************************************************************************
* 4032_clause_types.do
* Direct and spillover effects for grouped clause-count outcomes using the
* exact clause-count specification from 4012_pct_tfpw.do.
*
* Outcomes / table columns:
*   numb_clauses
*   wage_clauses
*   emp_clauses
*   other_clauses
*   wage_clause_prop
*   emp_clause_prop
*   other_clause_prop
*
* Output:
*   Tables/clause_types/results_direct_panelA_clause_counts_tfpw_07_11.csv
*   Tables/clause_types/results_direct_panelB_clause_counts_tfpw_07_11.csv
*   Tables/clause_types/results_direct_panelC_clause_counts_tfpw_07_11.csv
*   Tables/clause_types/results_spill_clause_counts_tfpw_07_11.csv
*   Tables/clause_types/results_direct_panelA_clause_props_tfpw_07_11.csv
*   Tables/clause_types/results_direct_panelB_clause_props_tfpw_07_11.csv
*   Tables/clause_types/results_direct_panelC_clause_props_tfpw_07_11.csv
*   Tables/clause_types/results_spill_clause_props_tfpw_07_11.csv
*   Tables/clause_types/clause_count_direct_effects.tex
*   Tables/clause_types/clause_count_spillover_effects.tex
*   Tables/clause_types/clause_prop_direct_effects.tex
*   Tables/clause_types/clause_prop_spillover_effects.tex
*   Tables/clause_types/numb_clause_spill_pretrend_diagnostics.csv
*   Tables/clause_types/numb_clause_spill_pretrend_top_connectivity.csv
*   Tables/clause_types/numb_clause_spill_pretrend_top_delta.csv
*   Tables/clause_types/numb_clause_spill_pretrend_top_influence_candidates.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/clause_types"
log using "$logs/clause_types/clause_types_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/clause_types"
cap mkdir "$graphs/clause_types"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: CLAUSE COUNT VARIABLES
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

label var wage_clauses  "Count of wage-related clauses"
label var emp_clauses   "Count of employment clauses"
label var other_clauses "Count of other clauses"

gen double wage_clause_prop  = wage_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double emp_clause_prop   = emp_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)
gen double other_clause_prop = other_clauses / numb_clauses if numb_clauses > 0 & !missing(numb_clauses)

label var wage_clause_prop  "Wage clauses as share of all clauses"
label var emp_clause_prop   "Employment clauses as share of all clauses"
label var other_clause_prop "Other clauses as share of all clauses"

********************************************************************************
* SECTION 3: VARIABLE CREATION
* Mirrors the clause-count specification in 4012_pct_tfpw.do
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

foreach v in numb_clauses wage_clauses emp_clauses other_clauses wage_clause_prop emp_clause_prop other_clause_prop {
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
* SECTION 4: SPECIFICATION MACROS
********************************************************************************

local spec "clause_counts_tfpw_07_11"
local conn "totaltreat_pw_norm"

local count_outcomes "numb_clauses wage_clauses emp_clauses other_clauses"
local prop_outcomes "wage_clause_prop emp_clause_prop other_clause_prop"
local outcomes "`count_outcomes' `prop_outcomes'"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

********************************************************************************
* SECTION 5: INITIALIZE OUTPUT CSV FILES
********************************************************************************

foreach panel in A B C {
	capture erase "$tables/clause_types/results_direct_panel`panel'_clause_counts_tfpw_07_11.csv"
	tempname fh
	file open `fh' using "$tables/clause_types/results_direct_panel`panel'_clause_counts_tfpw_07_11.csv", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'

	capture erase "$tables/clause_types/results_direct_panel`panel'_clause_props_tfpw_07_11.csv"
	tempname fh
	file open `fh' using "$tables/clause_types/results_direct_panel`panel'_clause_props_tfpw_07_11.csv", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'
}

capture erase "$tables/clause_types/results_spill_clause_counts_tfpw_07_11.csv"
tempname fh
file open `fh' using "$tables/clause_types/results_spill_clause_counts_tfpw_07_11.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

capture erase "$tables/clause_types/results_spill_clause_props_tfpw_07_11.csv"
tempname fh
file open `fh' using "$tables/clause_types/results_spill_clause_props_tfpw_07_11.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 6: DIRECT EFFECTS
********************************************************************************

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

	local csv_count_out "$tables/clause_types/results_direct_panel`panel'_clause_counts_tfpw_07_11.csv"
	local csv_prop_out "$tables/clause_types/results_direct_panel`panel'_clause_props_tfpw_07_11.csv"

	foreach outcome of local outcomes {

		di as text "  Estimating: `outcome' (Panel `panel')"

		local csv_out "`csv_count_out'"
		if inlist("`outcome'", "wage_clause_prop", "emp_clause_prop", "other_clause_prop") {
			local csv_out "`csv_prop_out'"
		}

		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' i.treat_ultra##post_treat_cba ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.post_treat_cba]
		local se_post = _se[1.treat_ultra#1.post_treat_cba]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean on this column's estimation sample (plan
		* 2026-08-01). The CBA-period spec runs on firm-YEAR rows, so the
		* 2009-2011 window matches the other tables. Taken before the
		* regression below replaces e(sample).
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

		reghdfe `outcome' i.treat_ultra##pre_treat_cba ///
			if `s_use' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                            local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

		reghdfe `outcome' i.treat_ultra##ib2.cba_period ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm 1.treat_ultra#1.cba_period
		local pre_ftest_pval = r(p)

		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'
	}
}

********************************************************************************
* SECTION 7: SPILLOVER EFFECTS
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/clause_types/results_spill_clause_counts_tfpw_07_11.csv"
local csv_spill_prop "$tables/clause_types/results_spill_clause_props_tfpw_07_11.csv"

foreach outcome of local outcomes {

	di as text "  Estimating: `outcome' (spillover)"

	local csv_out "`csv_spill'"
	if inlist("`outcome'", "wage_clause_prop", "emp_clause_prop", "other_clause_prop") {
		local csv_out "`csv_spill_prop'"
	}

	local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	reghdfe `outcome' c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
	* taken before the regressions below replace e(sample).
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre_val = r(mean)

	reghdfe `outcome' c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_post ""
	if `p_post' < 0.01                           local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                            local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

	reghdfe `outcome' c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	tempname fh
	file open `fh' using "`csv_out'", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file close `fh'
}

********************************************************************************
* SECTION 8: NUMB_CLAUSES SPILLOVER PRE-TREND OUTLIER DIAGNOSTICS
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "NUMB_CLAUSES SPILLOVER PRE-TREND DIAGNOSTICS"
di as result "-----------------------------------------------------------------------"

cap drop numb_precell
cap drop numb_pre_early
cap drop numb_pre_late
cap drop numb_pre_delta
cap drop abs_numb_pre_delta
cap drop influence_candidate_score

bys identificad pre_treat_cba: egen numb_precell = mean(numb_clauses) ///
	if `s_spill' & !missing(cba_period) & cba_period <= 2
bys identificad: egen numb_pre_early = max(cond(pre_treat_cba == 1, numb_precell, .))
bys identificad: egen numb_pre_late = max(cond(pre_treat_cba == 0, numb_precell, .))
gen double numb_pre_delta = numb_pre_early - numb_pre_late ///
	if !missing(numb_pre_early, numb_pre_late)
gen double abs_numb_pre_delta = abs(numb_pre_delta)
gen double influence_candidate_score = abs_numb_pre_delta * `conn'

local diag_base_if "`s_spill' & !missing(cba_period) & cba_period <= 2"
local diag_absorb "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

tempname diagpost
tempfile diag_results
postfile `diagpost' str40 diagnostic str80 restriction double cutoff b se p n_obs n_estab ///
	using `diag_results', replace

quietly reghdfe numb_clauses c.`conn'##pre_treat_cba ///
	if `diag_base_if', ///
	absorb(`diag_absorb') vce(cluster identificad)
local b = _b[1.pre_treat_cba#c.`conn']
local se = _se[1.pre_treat_cba#c.`conn']
local pval = 2*ttail(e(df_r), abs(`b'/`se'))
post `diagpost' ("baseline") ("none") (.) (`b') (`se') (`pval') (e(N)) (e(N_clust))

quietly summarize `conn' if `diag_base_if', detail
local conn_p90 = r(p90)
local conn_p95 = r(p95)
local conn_p99 = r(p99)

foreach pct in 99 95 90 {
	local cutoff = `conn_p`pct''
	local dropped = 100 - `pct'
	quietly reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `diag_base_if' & `conn' <= `cutoff', ///
		absorb(`diag_absorb') vce(cluster identificad)
	local b = _b[1.pre_treat_cba#c.`conn']
	local se = _se[1.pre_treat_cba#c.`conn']
	local pval = 2*ttail(e(df_r), abs(`b'/`se'))
	post `diagpost' ("trim_connectivity") ("drop top `dropped' pct of connectivity") ///
		(`cutoff') (`b') (`se') (`pval') (e(N)) (e(N_clust))
}

quietly summarize numb_clauses if `diag_base_if', detail
local numb_p95 = r(p95)
local numb_p99 = r(p99)

foreach pct in 99 95 {
	local cutoff = `numb_p`pct''
	quietly reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `diag_base_if' & numb_clauses <= `cutoff', ///
		absorb(`diag_absorb') vce(cluster identificad)
	local b = _b[1.pre_treat_cba#c.`conn']
	local se = _se[1.pre_treat_cba#c.`conn']
	local pval = 2*ttail(e(df_r), abs(`b'/`se'))
	post `diagpost' ("trim_clause_count") ("drop observations above p`pct' numb_clauses") ///
		(`cutoff') (`b') (`se') (`pval') (e(N)) (e(N_clust))
}

quietly summarize abs_numb_pre_delta if `diag_base_if', detail
local delta_p90 = r(p90)
local delta_p95 = r(p95)
local delta_p99 = r(p99)

foreach pct in 99 95 90 {
	local cutoff = `delta_p`pct''
	quietly reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `diag_base_if' & (missing(abs_numb_pre_delta) | abs_numb_pre_delta <= `cutoff'), ///
		absorb(`diag_absorb') vce(cluster identificad)
	local b = _b[1.pre_treat_cba#c.`conn']
	local se = _se[1.pre_treat_cba#c.`conn']
	local pval = 2*ttail(e(df_r), abs(`b'/`se'))
	post `diagpost' ("trim_pre_delta") ("drop firms above p`pct' absolute pre-period clause change") ///
		(`cutoff') (`b') (`se') (`pval') (e(N)) (e(N_clust))
}

postclose `diagpost'

preserve
	use `diag_results', clear
	export delimited using "$tables/clause_types/numb_clause_spill_pretrend_diagnostics.csv", replace
restore

preserve
	keep if `diag_base_if'
	bys identificad: keep if _n == 1
	keep identificad `conn' numb_pre_early numb_pre_late numb_pre_delta ///
		abs_numb_pre_delta influence_candidate_score firm_emp_pre industry1 ///
		microregion mode_base_month totalflows_pw_pre_07_11
	gsort -`conn'
	gen rank_conn = _n
	keep if rank_conn <= 50
	export delimited using "$tables/clause_types/numb_clause_spill_pretrend_top_connectivity.csv", replace
restore

preserve
	keep if `diag_base_if' & !missing(abs_numb_pre_delta)
	bys identificad: keep if _n == 1
	keep identificad `conn' numb_pre_early numb_pre_late numb_pre_delta ///
		abs_numb_pre_delta influence_candidate_score firm_emp_pre industry1 ///
		microregion mode_base_month totalflows_pw_pre_07_11
	gsort -abs_numb_pre_delta
	gen rank_abs_delta = _n
	keep if rank_abs_delta <= 50
	export delimited using "$tables/clause_types/numb_clause_spill_pretrend_top_delta.csv", replace
restore

preserve
	keep if `diag_base_if' & !missing(influence_candidate_score)
	bys identificad: keep if _n == 1
	keep identificad `conn' numb_pre_early numb_pre_late numb_pre_delta ///
		abs_numb_pre_delta influence_candidate_score firm_emp_pre industry1 ///
		microregion mode_base_month totalflows_pw_pre_07_11
	gsort -influence_candidate_score
	gen rank_influence_candidate = _n
	keep if rank_influence_candidate <= 50
	export delimited using "$tables/clause_types/numb_clause_spill_pretrend_top_influence_candidates.csv", replace
restore

di as result "All clause-count regressions complete."
log close
