********************************************************************************
* main_results.do
* Main spillover event study — lr_remdezr_w (and other base outcomes).
* Exports year-by-year coefficients and 95% CIs from the event study
* regression, plus the DiD summary row (post coefficient, pre-trend, Ns).
*
* Spec: reghdfe outcome c.totaltreat_pw_norm##ib2011.year if s_spill,
*       absorb(estab + industry#year + month#year + microregion#year +
*              outcome_pre4#year + emp_pre4#year + flows_pre4#year)
*       vce(cluster identificad)
*
* Output:
*   Tables/main_results/es_spill_{outcome}.csv   — event study coefficients
*   Tables/main_results/did_spill.csv            — DiD summary (post, pre, Ns)
* Auto-runs: Programs/main_results/main_results_es_plot.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/main_results"
log using "$logs/main_results/main_results_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap mkdir "$tables/main_results"
cap mkdir "$graphs/main_results"

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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLES
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── Connectivity ──────────────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment means & 4-bin controls ─────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
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

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		egen `outcome'_pre4_o = cut(`outcome'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
	}
}

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

local spec        "tfpw_07_11"
local conn        "totaltreat_pw_norm"
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"

global mr_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"

* ── Initialize DiD summary CSV ────────────────────────────────────────────────

capture erase "$tables/main_results/did_spill.csv"
tempname fh
file open `fh' using "$tables/main_results/did_spill.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

* ── Loop over outcomes ────────────────────────────────────────────────────────

foreach outcome in $mr_outcomes {

	di as result "--- Spillover ES: `outcome' ---"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ── Event study regression (base year = 2011) ────────────────────────────

	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local df_r   = e(df_r)
	local n_obs  = e(N)
	local n_estab = e(N_clust)

	* ── Export year-by-year coefficients ─────────────────────────────────────

	capture erase "$tables/main_results/es_spill_`outcome'.csv"
	tempname fh
	file open `fh' using "$tables/main_results/es_spill_`outcome'.csv", write replace
	file write `fh' "spec,outcome,year,coef,se,ci_lower,ci_upper" _n
	file close `fh'

	foreach yr in 2009 2010 2011 2012 2013 2014 2015 2016 {
		if `yr' == 2011 {
			* Base year: coefficient is exactly zero by construction
			local b  = 0
			local se = 0
			local cil = 0
			local ciu = 0
		}
		else {
			local b   = _b[`yr'.year#c.`conn']
			local se  = _se[`yr'.year#c.`conn']
			local t95 = invttail(`df_r', 0.025)
			local cil = `b' - `t95' * `se'
			local ciu = `b' + `t95' * `se'
		}
		tempname fh
		file open `fh' using "$tables/main_results/es_spill_`outcome'.csv", write append
		file write `fh' `""`spec'","`outcome'",`yr',"' ///
			%9.6f (`b') `","' %9.6f (`se') `","' ///
			%9.6f (`cil') `","' %9.6f (`ciu') _n
		file close `fh'
	}

	di as result "  Event study exported: es_spill_`outcome'.csv"

	* ── DiD summary: post and pre coefficients ───────────────────────────────

	* Post: treat_year interaction
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))

	local stars_post ""
	if `p_post' < 0.01                           local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

	* Pre-trend placebo
	reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.placebo_year#c.`conn']
	local se_pre = _se[1.placebo_year#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                           local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

	* Pre-trend F-test
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Write DiD summary
	tempname fh
	file open `fh' using "$tables/main_results/did_spill.csv", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "  DiD summary written."
}

di as result "All outcomes done."

* ── Auto-run Python plot ──────────────────────────────────────────────────────
if "`c(username)'" == "lgg3230" {
	shell ~/.conda/envs/venv_python312/bin/python "$programs/main_results/main_results_es_plot.py"
}
else {
	shell python3 "$programs/main_results/main_results_es_plot.py"
}

log close
