********************************************************************************
* UNION SPILLOVERS — CBA VALUE (wage-equivalent score)
* Purpose: Test whether CBAs become more valuable after Súmula 277 (direct
*          effects on treated firms) and whether more-connected untreated firms
*          also see their own CBA value rise (spillover effects).
*          Outcome 1: cba_value (wage-equivalent weighted clause score)
*          Outcome 2: numb_clauses (unweighted clause count, for comparison)
*          Both outcomes run at the CBA-period level (not calendar year).
* Output:  4 CSV files + event-study PDFs
* Auto-runs: Programs/cba_value/generate_cba_value_latex.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/cba_value/FinalResults_cba_value_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge pre-computed CBA value score ──────────────────────────────────────

di as result "Merging CBA value score …"

preserve
	import delimited "$rais_firm/cba_value_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile cba_val
	save `cba_val'
restore

cap drop cba_value
merge 1:1 identificad year using `cba_val', keep(master match) nogen

di as result "CBA value merged."

* ── Merge totalflows_wide for extra_year control ─────────────────────────────

di as result "Merging totalflows_wide …"

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

di as result "totalflows_wide merged."

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables …"

* ── Treatment & CBA period indicators ───────────────────────────────────────

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

* ── Connectivity normalization (to 90th pctile of spillover sample, 2009) ────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile (untreated, 2009)"

* ── Pre-treatment means + 4-bin controls ─────────────────────────────────────

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

* Pre-treatment means (CBA-period based) + 4-bin controls
foreach v in cba_value numb_clauses {
	cap drop `v'_pre_o
	cap drop `v'_pre
	qui {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
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

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION"
di as result "======================================================================="

* ── Fixed effects & spec macros ──────────────────────────────────────────────

local spec       "cba_value"
local conn       "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── Sample macros ────────────────────────────────────────────────────────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── Initialize output CSV files ──────────────────────────────────────────────

foreach panel in A B C {
	capture erase "$tables/cba_value/results_direct_panel`panel'_cba_value.csv"
	tempname fh
	file open `fh' using "$tables/cba_value/results_direct_panel`panel'_cba_value.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/cba_value/results_spill_cba_value.csv"
tempname fh
file open `fh' using "$tables/cba_value/results_spill_cba_value.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── PARTS A–C: DIRECT EFFECTS ────────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "DIRECT EFFECTS — PANELS A, B, C"
di as result "-----------------------------------------------------------------------"

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

	local csv_out "$tables/cba_value/results_direct_panel`panel'_cba_value.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	foreach outcome in cba_value numb_clauses {

		di as text "  Estimating: `outcome' (CBA periods, Panel `panel')"

		local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		* Post-treatment
		reghdfe `outcome' i.treat_ultra##post_treat_cba ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.post_treat_cba]
		local se_post = _se[1.treat_ultra#1.post_treat_cba]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean on this column's estimation sample (plan
		* 2026-08-01). Window is CALENDAR 2009-2011, not cba_period 1-2 as
		* before, so this column matches the clause-count columns it sits
		* beside in the CBA composition and value table. Taken before the
		* placebo regression replaces e(sample).
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

		* Pre-treatment placebo
		reghdfe `outcome' i.treat_ultra##pre_treat_cba ///
			if `s_use' & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
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
		reghdfe `outcome' i.treat_ultra##ib2.cba_period ///
			if `s_use' & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad) tolerance(1e-2)
		capture testparm 1.treat_ultra#1.cba_period
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		* Baseline mean (untreated, pre-treatment CBA periods)
	* POOLED over the estimation sample (treated + control), per the table
	* note "average across establishments in each panel's estimation sample".
	* Was `s_use_pre' (control group only), which contradicted that note.
		quietly sum `outcome' if `s_use' & inrange(cba_period, 1, 2)
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
			msymbol(square) ///
			keep(1.treat_ultra#*.cba_period) ///
			coeflabels(1.treat_ultra#1.cba_period = "2009" ///
			           1.treat_ultra#2.cba_period = "2010-2012" ///
			           1.treat_ultra#3.cba_period = "2013" ///
			           1.treat_ultra#4.cba_period = "2014" ///
			           1.treat_ultra#5.cba_period = "2015" ///
			           1.treat_ultra#6.cba_period = "2016") ///
			vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("P-value for placebo pre-trend = `pre_pval_s'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
			text(2.5 4 "`post_coef_s' (`post_se_s')", color(blue) size(small))

		graph export "$graphs/cba_value/es_`outcome'_direct`panel'_`d'.pdf", as(pdf) replace
		estimates drop _es_d_tmp
	}

	di as result "Panel `panel' complete."
}

* ── SPILLOVER EFFECTS ────────────────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/cba_value/results_spill_cba_value.csv"

foreach outcome in cba_value numb_clauses {

	di as text "  Estimating: `outcome' (spillover, CBA periods)"

	local absorb_cba "`base_fe_cba' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	reghdfe `outcome' c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment placebo
	reghdfe `outcome' c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
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
	reghdfe `outcome' c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad) tolerance(1e-2)
	capture testparm c.`conn'#1.cba_period
	local pre_ftest_pval = cond(_rc == 0, r(p), .)

	* Baseline mean (spillover sample, pre-treatment CBA periods)
	quietly sum `outcome' if `s_spill' & inrange(cba_period, 1, 2)
	local mean_pre_val = r(mean)

	* Write CSV
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

	* Event study plot
	estimates store _es_sp_tmp
	local post_coef_s = string(`b_post', "%9.4f")
	local post_se_s   = string(`se_post', "%9.4f")
	local pre_pval_s  = string(`p_pre',   "%9.3f")

	coefplot _es_sp_tmp, ///
		msymbol(square) ///
		keep(*.cba_period#c.`conn') ///
		coeflabels(1.cba_period#c.`conn' = "2009" ///
		           2.cba_period#c.`conn' = "2010-2012" ///
		           3.cba_period#c.`conn' = "2013" ///
		           4.cba_period#c.`conn' = "2014" ///
		           5.cba_period#c.`conn' = "2015" ///
		           6.cba_period#c.`conn' = "2016") ///
		vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
		ytitle("Dynamic DiD coefficients", size(small)) ///
		note("P-value for placebo pre-trend = `pre_pval_s'") ///
		graphregion(color(white)) bgcolor(white) ///
		ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
		text(0.6 4 "`post_coef_s' (`post_se_s')", color(blue) size(small))

	graph export "$graphs/cba_value/es_`outcome'_spill_`d'.pdf", as(pdf) replace
	estimates drop _es_sp_tmp
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION + AUTO-RUN PYTHON
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell "$programs/cba_value/generate_cba_value_latex.py"
di as result "LaTeX tables written to Tables/cba_value/"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "cba_value done" "Main_Results_cba_value.do finished"

********************************************************************************
* END OF DO-FILE
********************************************************************************
