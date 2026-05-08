********************************************************************************
* cba_similarity_avg_pos_conn.do
*
* Replicates the average-treated similarity exercise replacing the continuous
* connectivity measure (totaltreat_pw_norm) with a binary indicator for having
* ANY positive pre-treatment worker flow to treated firms (pos_conn).
*
* If the full-sample avg effect is driven by a level difference between
* connected and unconnected firms (rather than dose-response), the dummy
* should recover the effect at similar or larger magnitude. If that dummy
* effect then disappears with union x period FE, sample selection into the
* bilateral sample (not the union FE per se) is the driver.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/cba_similarity_avg_pos_conn_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD DATA + TOTALFLOWS
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
* SECTION 2: VARIABLE CREATION
********************************************************************************

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

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Binary connectivity indicator: any positive pre-treatment flow to treated firms
cap drop pos_conn
gen byte pos_conn = (totaltreat_pw_n > 0) if !missing(totaltreat_pw_n)
label var pos_conn "Any positive flow to treated firms (pre-treatment)"

di as result "Share with positive connectivity (spillover sample, 2009):"
sum pos_conn if `s_spill' & year == 2009

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
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
* SECTION 3: MERGE AVERAGE SIMILARITY PANEL + COMPUTE SIMILARITY PRE-BINS
********************************************************************************

merge m:1 identificad cba_period using "$rais_aux/cba_similarity_avg_panel.dta", ///
	keep(master match) gen(m_sim)
drop m_sim

label var cosine          "Cosine similarity to avg treated CBA"
label var bray_curtis     "Bray-Curtis similarity to avg treated CBA"
label var total_variation "Total variation similarity to avg treated CBA"
label var ruzicka         "Ruzicka similarity to avg treated CBA"

local sim_outcomes "cosine bray_curtis total_variation ruzicka"

foreach v of local sim_outcomes {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
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

********************************************************************************
* SECTION 4: SPEC MACROS
********************************************************************************

local spec             "avg_pos_conn"
local conn             "pos_conn"
local base_fe_cba      "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local base_fe_cba_union "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period i.mode_union#i.cba_period"
local extra_cba        "ib0.totalflows_pw_pre_07_114#i.cba_period"

********************************************************************************
* SECTION 5: INITIALIZE OUTPUT CSV
********************************************************************************

local csv "$tables/cba_similarity/results_spill_cba_similarity_avg_pos_conn.csv"
capture erase "`csv'"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 6: REGRESSIONS — BASE AND UNION FE
********************************************************************************

di _newline(2)
di as result "====================================================================="
di as result "AVG SIMILARITY vs POS_CONN DUMMY — SPILLOVER"
di as result "====================================================================="

foreach fe_variant in base union {
	if "`fe_variant'" == "base" {
		local cur_base_fe "`base_fe_cba'"
		local cur_spec    "`spec'"
	}
	else {
		local cur_base_fe "`base_fe_cba_union'"
		local cur_spec    "`spec'_union"
	}

	foreach outcome of local sim_outcomes {

		di as text "  Estimating: `outcome' (`fe_variant' FE)"

		local absorb_cba "`cur_base_fe' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		qui sum `outcome' if e(sample) & cba_period == 2
		local base_mean = cond(r(N) > 0, r(mean), .)

		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `s_spill' & !missing(cba_period) & cba_period <= 2 & !missing(`outcome'), ///
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
			if `s_spill' & !missing(cba_period) & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		di as text "    Post: " %6.4f (`b_post') " `stars_post'" ///
		           "   Pre: " %6.4f (`b_pre') " `stars_pre'"

		tempname fh
		file open `fh' using "`csv'", write append
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main";"'    %9.4f (`b_post') `"`stars_post'"' _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'"'  _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
		file close `fh'
	}
}

di as result _newline "All pos_conn regressions complete."

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_similarity_avg_pos_conn_latex.py"
di as result "LaTeX table written."

shell source "$programs/notify.sh" && notify "avg_pos_conn done" "Avg similarity pos_conn exercise complete"

********************************************************************************
* END
********************************************************************************
