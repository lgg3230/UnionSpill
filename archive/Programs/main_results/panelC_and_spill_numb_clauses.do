********************************************************************************
* panelC_and_spill_numb_clauses.do
* Two things main_results.do doesn't cover:
*   1. Panel C direct effects for the 4 main outcomes
*   2. Numb_clauses spillover (CBA-period structure)
*
* Output:
*   Tables/main_results/panelC.csv
*   Tables/main_results/spill_numb_clauses.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/main_results"
log using "$logs/main_results/panelC_numb_clauses_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap mkdir "$tables/main_results"

********************************************************************************
* SECTION 1: LOAD AND MERGE
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11     = 0
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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLES
********************************************************************************

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* ── Connectivity (same normalization as main_results.do) ─────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment means ───────────────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

* ── 4-bin controls ───────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
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

di as result "All variables created."

********************************************************************************
* SECTION 3: PANEL C — DIRECT EFFECTS
********************************************************************************

local spec       "tfpw_07_11_pct"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

capture erase "$tables/main_results/panelC.csv"
tempname fh
file open `fh' using "$tables/main_results/panelC.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di as result "--- Panel C direct: `outcome' ---"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_C', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_ultra#1.treat_year]
	local se_post = _se[1.treat_ultra#1.treat_year]
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_C' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.treat_ultra#1.placebo_year]
	local se_pre = _se[1.treat_ultra#1.placebo_year]
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_C', ///
		absorb(`absorb') vce(cluster identificad)
	testparm 1.treat_ultra#i(2009 2010).year
	local pre_ftest_pval = r(p)

	local stars_post ""
	if `p_post' < 0.01                             local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' >= 0.01)  local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' >= 0.05)  local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                             local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' >= 0.01)   local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' >= 0.05)   local stars_pre "*"

	tempname fh
	file open `fh' using "$tables/main_results/panelC.csv", write append
	file write `fh' `""`spec'";"direct_C";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""'  _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"direct_C";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'
}

* ── numb_clauses Panel C (CBA-period structure) ─────────────────────────────

di as result "--- Panel C direct: numb_clauses ---"

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

reghdfe numb_clauses i.treat_ultra##post_treat_cba ///
	if `s_direct_C' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)

local b_post  = _b[1.treat_ultra#1.post_treat_cba]
local se_post = _se[1.treat_ultra#1.post_treat_cba]
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe numb_clauses i.treat_ultra##pre_treat_cba ///
	if `s_direct_C' & !missing(cba_period) & cba_period <= 2, ///
	absorb(`absorb_cba') vce(cluster identificad)

local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                             local stars_post "***"
else if (`p_post' < 0.05 & `p_post' >= 0.01)  local stars_post "**"
else if (`p_post' < 0.10 & `p_post' >= 0.05)  local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                             local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' >= 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' >= 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "$tables/main_results/panelC.csv", write append
file write `fh' `""`spec'";"direct_C";"numb_clauses";"main";"'   %9.4f (`b_post') `"`stars_post'""'  _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""'            _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre_pval";"' %9.4f (`p_pre') `"""'             _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
file write `fh' `""`spec'";"direct_C";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
file close `fh'

di as result "Panel C done."

********************************************************************************
* SECTION 4: NUMB_CLAUSES SPILLOVER
********************************************************************************

di as result "--- Spillover: numb_clauses ---"

local conn "totaltreat_pw_norm"

capture erase "$tables/main_results/spill_numb_clauses.csv"
tempname fh
file open `fh' using "$tables/main_results/spill_numb_clauses.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

* Post
reghdfe numb_clauses c.`conn'##post_treat_cba ///
	if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)

local b_post  = _b[1.post_treat_cba#c.`conn']
local se_post = _se[1.post_treat_cba#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-trend placebo
reghdfe numb_clauses c.`conn'##pre_treat_cba ///
	if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
	absorb(`absorb_cba') vce(cluster identificad)

local b_pre  = _b[1.pre_treat_cba#c.`conn']
local se_pre = _se[1.pre_treat_cba#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                             local stars_post "***"
else if (`p_post' < 0.05 & `p_post' >= 0.01)  local stars_post "**"
else if (`p_post' < 0.10 & `p_post' >= 0.05)  local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                             local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' >= 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' >= 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "$tables/main_results/spill_numb_clauses.csv", write append
file write `fh' `""`spec'";"spill";"numb_clauses";"main";"'   %9.4f (`b_post') `"`stars_post'""'  _n
file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""'            _n
file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`p_pre') `"""'             _n
file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
file close `fh'

di as result "Numb_clauses spillover done."

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "Stata done" "panelC_and_spill_numb_clauses.do finished"

log close
