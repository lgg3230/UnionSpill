********************************************************************************
* UNION SPILLOVERS — CBA VALUE (year-level version)
* Same as 4042_cba_value.do but runs at calendar year instead of
* cba_period. Outcomes: cba_value (subgroup weights) and numb_clauses.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/cba_value/FinalResults_cba_value_year_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore

cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

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

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = (totaltreat_pw_n / totaltreat_pw_n_p90)

cap drop l_firm_emp_pre_o
cap drop l_firm_emp_pre
qui {
	bys identificad: egen l_firm_emp_pre_o = mean(l_firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen l_firm_emp_pre   = min(l_firm_emp_pre_o)
	drop l_firm_emp_pre_o
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
qui {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
	replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
qui {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

foreach v in cba_value numb_clauses {
	cap drop `v'_pre_o
	cap drop `v'_pre
	qui {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	qui {
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

local spec       "cba_value_year"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

foreach panel in A B C {
	capture erase "$tables/cba_value/results_direct_panel`panel'_cba_value_year.csv"
	tempname fh
	file open `fh' using "$tables/cba_value/results_direct_panel`panel'_cba_value_year.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/cba_value/results_spill_cba_value_year.csv"
tempname fh
file open `fh' using "$tables/cba_value/results_spill_cba_value_year.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── PARTS A–C: DIRECT EFFECTS ────────────────────────────────────────────────

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

	local csv_out "$tables/cba_value/results_direct_panel`panel'_cba_value_year.csv"

	di as result "--- Panel `panel' ---"

	foreach outcome in cba_value numb_clauses {

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
			absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
		capture testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		* Baseline mean
	* POOLED over the estimation sample (treated + control), per the table
	* note "average across establishments in each panel's estimation sample".
	* Was `s_use_pre' (control group only), which contradicted that note.
		quietly sum `outcome' if `s_use' & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

		* Write CSV
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

		* Event study plot
		estimates store _es_d_tmp
		local post_coef_s = string(`b_post', "%9.4f")
		local post_se_s   = string(`se_post', "%9.4f")
		local pre_pval_s  = string(`p_pre',   "%9.3f")

		coefplot _es_d_tmp, ///
			keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
			     1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
			     1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
			coeflabels(1.treat_ultra#2009.year = "2009" ///
			           1.treat_ultra#2010.year = "2010" ///
			           1.treat_ultra#2011.year = "2011" ///
			           1.treat_ultra#2012.year = "2012" ///
			           1.treat_ultra#2013.year = "2013" ///
			           1.treat_ultra#2014.year = "2014" ///
			           1.treat_ultra#2015.year = "2015" ///
			           1.treat_ultra#2016.year = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("P-value for placebo pre-trend = `pre_pval_s'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
			text(0.05 6 "`post_coef_s' (`post_se_s')", color(blue) size(small))

		graph export "$graphs/cba_value/es_`outcome'_year_direct`panel'_`d'.pdf", as(pdf) replace
		estimates drop _es_d_tmp
	}

	di as result "Panel `panel' complete."
}

* ── SPILLOVER EFFECTS ────────────────────────────────────────────────────────

local csv_spill "$tables/cba_value/results_spill_cba_value_year.csv"

foreach outcome in cba_value numb_clauses {

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
		absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
	capture testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = cond(_rc == 0, r(p), .)

	quietly sum `outcome' if `s_spill' & inrange(year, 2009, 2011)
	local mean_pre_val = r(mean)

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

	estimates store _es_sp_tmp
	local post_coef_s = string(`b_post', "%9.4f")
	local post_se_s   = string(`se_post', "%9.4f")
	local pre_pval_s  = string(`p_pre',   "%9.3f")

	coefplot _es_sp_tmp, ///
		keep(*#*c.`conn') ///
		msymbol(diamond) ///
		coeflabels(2009.year#c.`conn' = "2009" ///
		           2010.year#c.`conn' = "2010" ///
		           2011.year#c.`conn' = "2011" ///
		           2012.year#c.`conn' = "2012" ///
		           2013.year#c.`conn' = "2013" ///
		           2014.year#c.`conn' = "2014" ///
		           2015.year#c.`conn' = "2015" ///
		           2016.year#c.`conn' = "2016") ///
		vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
		ytitle("Dynamic DiD coefficients", size(small)) ///
		note("P-value for placebo pre-trend = `pre_pval_s'") ///
		graphregion(color(white)) bgcolor(white) ///
		ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
		text(0.015 5 "`post_coef_s' (`post_se_s')", color(blue) size(small))

	graph export "$graphs/cba_value/es_`outcome'_year_spill_`d'.pdf", as(pdf) replace
	estimates drop _es_sp_tmp
}

di as result "All regressions complete."

log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "cba_value_year done" "Main_Results_cba_value_year.do finished"
