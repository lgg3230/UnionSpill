********************************************************************************
* UNION SPILLOVERS — CONNECTIVITY MARGINS ANALYSIS
* Purpose: Decompose spillover effects by margin of connectivity to test
*          whether the extensive margin (any connection), the intensive margin
*          (how much connectivity), or both drive the wage spillover result.
*
*   Exercise 1 (Panel A): Replace continuous connectivity with a binary
*     indicator of positive vs. zero connectivity (extensive margin).
*     Sample: all untreated establishments.
*
*   Exercise 2 (Panel B): Restrict to positive-connectivity firms and run
*     the baseline continuous spec (intensive margin).
*     Sample: untreated establishments with totaltreat_pw_n > 0.
*
*   Exercise 3 (Panel C): Saturated model — both pos_conn and conn interacted
*     with post. Note: conn x pos_conn = conn identically (since conn = 0
*     whenever pos_conn = 0), so the triple interaction adds nothing; the
*     correct saturated spec is pos_conn + conn, each interacted with post.
*     Sample: all untreated establishments.
*
* Outcomes:  lr_remdezr_w, lr_remdezr_h_w, l_firm_emp, numb_clauses
*            (numb_clauses uses CBA negotiation periods instead of calendar years)
* Output:    Tables/conn_margins/results_conn_margins_ex{1,2,3}.csv
* Auto-runs: Programs/conn_margins/generate_conn_margins_latex.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/conn_margins"
log using "$logs/conn_margins/conn_margins_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ── PATHS (uncomment if running standalone without 00_master.do) ─────────────
// global main      "PATHNAME TO Replication-Mar-2"
// global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
// global tables    "$main/UnionSpill/Tables"
// global graphs    "$main/UnionSpill/Graphs"
// global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
// global logs      "$main/UnionSpill/Logs"
// global programs  "$main/UnionSpill/Programs"

* ── OUTPUT FOLDER ────────────────────────────────────────────────────────────
cap mkdir "$tables/conn_margins"

* ── LOAD BASE DATA ───────────────────────────────────────────────────────────
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── MERGE TOTALFLOWS DATA (per-worker, 2007-2011) ────────────────────────────
di as result "Merging totalflows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe)
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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

di as result "Totalflows data merged."

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables..."

* ── PERIOD INDICATORS ────────────────────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period (year < 2011)"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period (year >= 2012)"

* ── CBA PERIOD INDICATORS (for numb_clauses) ─────────────────────────────────

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
label var cba_period "CBA negotiation period (1=pre-reform, 2=second pre-period, 3-6=post-reform)"

gen byte pre_treat_cba  = cond(cba_period <  2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator (cba_period == 1)"

gen byte post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator (cba_period >= 3)"

* ── CONNECTIVITY SCALING ─────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen double totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── BINARY CONNECTIVITY INDICATOR ────────────────────────────────────────────

cap drop pos_conn
gen byte pos_conn = (totaltreat_pw_n > 0) if !missing(totaltreat_pw_n)
label var pos_conn "Indicator: positive pre-reform connectivity to treated firms"

* ── PRE-TREATMENT MEANS FOR BASE OUTCOMES ────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* numb_clauses pre-treatment mean (averaged over CBA periods 1 and 2)
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* ── 4-BIN CONTROLS ───────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

* l_firm_emp_pre4 is the outcome bin for l_firm_emp (already created above)

* numb_clauses 4-bin control (based on pre-treatment CBA mean)
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre4_o
	cap drop numb_clauses_pre4
	quietly {
		egen numb_clauses_pre4_o = cut(numb_clauses_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
		drop numb_clauses_pre4_o
		replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
	}
}

* Totalflows per-worker pre 07-11 bins (zero-fill missing → reference category)
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
* SECTION 3: ESTIMATION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION — CONNECTIVITY MARGINS"
di as result "======================================================================="

* ── FIXED EFFECTS & CONNECTIVITY MACROS ──────────────────────────────────────

local spec       "conn_margins"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
* CBA-period FEs for numb_clauses regressions
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── SAMPLE MACROS ────────────────────────────────────────────────────────────

* Full spillover sample (all untreated)
local s_spill     "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
* Restricted to positive-connectivity firms only
local s_spill_pos "`s_spill' & totaltreat_pw_n > 0"

* ── INITIALIZE OUTPUT CSV FILES ──────────────────────────────────────────────

foreach ex in ex1 ex2 ex3 ex4 {
	capture erase "$tables/conn_margins/results_conn_margins_`ex'.csv"
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_`ex'.csv", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'
}

* ── OUTCOMES ─────────────────────────────────────────────────────────────────

global cm_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"

********************************************************************************
* EXERCISE 1: EXTENSIVE MARGIN — BINARY CONNECTIVITY (FULL SAMPLE)
* Replaces continuous connectivity with a binary indicator.
* Identifies: does having *any* connection matter, regardless of magnitude?
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "EXERCISE 1: Extensive margin — binary pos_conn (full spillover sample)"
di as result "-----------------------------------------------------------------------"

foreach outcome in $cm_outcomes {

	di as text "  Ex1: `outcome'"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	reghdfe `outcome' i.pos_conn##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.pos_conn#1.treat_year]
	local se_post = _se[1.pos_conn#1.treat_year]
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	* Pre-treatment placebo
	reghdfe `outcome' i.pos_conn##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.pos_conn#1.placebo_year]
	local se_pre = _se[1.pos_conn#1.placebo_year]
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study F-test for pre-trends
	reghdfe `outcome' i.pos_conn##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm 1.pos_conn#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex1.csv", write append
	file write `fh' `""`spec'";"ex1";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"ex1";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "  Ex1 `outcome' done."
}

* ── numb_clauses (CBA-period structure) ──────────────────────────────────────
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Ex1: numb_clauses (CBA periods)"

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	reghdfe numb_clauses i.pos_conn##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.pos_conn#1.post_treat_cba]
	local se_post = _se[1.pos_conn#1.post_treat_cba]
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	* Pre-treatment placebo (CBA periods 1-2 only; base is period 2)
	reghdfe numb_clauses i.pos_conn##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pos_conn#1.pre_treat_cba]
	local se_pre = _se[1.pos_conn#1.pre_treat_cba]
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study F-test (period 1 is the only pre-period; base = period 2)
	reghdfe numb_clauses i.pos_conn##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	testparm 1.pos_conn#1.cba_period
	local pre_ftest_pval = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex1.csv", write append
	file write `fh' `""`spec'";"ex1";"numb_clauses";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"ex1";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "  Ex1 numb_clauses done."
}

********************************************************************************
* EXERCISE 2: INTENSIVE MARGIN — CONTINUOUS CONN, POSITIVE-CONNECTIVITY SAMPLE
* Runs the baseline continuous spec on the restricted sample.
* Identifies: conditional on any connection, does more connectivity yield
*             higher wages?
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "EXERCISE 2: Intensive margin — continuous conn (positive-conn sample)"
di as result "-----------------------------------------------------------------------"

foreach outcome in $cm_outcomes {

	di as text "  Ex2: `outcome'"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	* Pre-treatment placebo
	reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill_pos' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.placebo_year#c.`conn']
	local se_pre = _se[1.placebo_year#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study F-test for pre-trends
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex2.csv", write append
	file write `fh' `""`spec'";"ex2";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"ex2";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "  Ex2 `outcome' done."
}

* ── numb_clauses (CBA-period structure) ──────────────────────────────────────
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Ex2: numb_clauses (CBA periods, positive-conn sample)"

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill_pos' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	* Pre-treatment placebo
	reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill_pos' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study F-test
	reghdfe numb_clauses c.`conn'##ib2.cba_period ///
		if `s_spill_pos' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex2.csv", write append
	file write `fh' `""`spec'";"ex2";"numb_clauses";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`spec'";"ex2";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "  Ex2 numb_clauses done."
}

********************************************************************************
* EXERCISE 3: SATURATED MODEL — EXTENSIVE + INTENSIVE (FULL SAMPLE)
* Includes both pos_conn and conn interacted with post, jointly on the full
* sample. Note: conn x pos_conn ≡ conn always, so the triple interaction is
* collinear and omitted. The identified coefficients are:
*   post x pos_conn  → residual extensive-margin effect after partialling conn
*   post x conn      → intensive-margin gradient
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "EXERCISE 3: Saturated model — pos_conn + conn (full spillover sample)"
di as result "-----------------------------------------------------------------------"

foreach outcome in $cm_outcomes {

	di as text "  Ex3: `outcome'"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	reghdfe `outcome' i.pos_conn##i.treat_year c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post_pos   = _b[1.pos_conn#1.treat_year]
	local se_post_pos  = _se[1.pos_conn#1.treat_year]
	local p_post_pos   = 2*ttail(e(df_r), abs(`b_post_pos'/`se_post_pos'))
	local b_post_conn  = _b[1.treat_year#c.`conn']
	local se_post_conn = _se[1.treat_year#c.`conn']
	local p_post_conn  = 2*ttail(e(df_r), abs(`b_post_conn'/`se_post_conn'))
	local n_obs        = e(N)
	local n_estab      = e(N_clust)

	local stars_post_pos ""
	if `p_post_pos' < 0.01                               local stars_post_pos "***"
	else if (`p_post_pos' < 0.05 & `p_post_pos' > 0.01) local stars_post_pos "**"
	else if (`p_post_pos' < 0.10 & `p_post_pos' > 0.05) local stars_post_pos "*"

	local stars_post_conn ""
	if `p_post_conn' < 0.01                                local stars_post_conn "***"
	else if (`p_post_conn' < 0.05 & `p_post_conn' > 0.01) local stars_post_conn "**"
	else if (`p_post_conn' < 0.10 & `p_post_conn' > 0.05) local stars_post_conn "*"

	* Pre-treatment placebo
	reghdfe `outcome' i.pos_conn##i.placebo_year c.`conn'##i.placebo_year ///
		if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre_pos   = _b[1.pos_conn#1.placebo_year]
	local se_pre_pos  = _se[1.pos_conn#1.placebo_year]
	local p_pre_pos   = 2*ttail(e(df_r), abs(`b_pre_pos'/`se_pre_pos'))
	local b_pre_conn  = _b[1.placebo_year#c.`conn']
	local se_pre_conn = _se[1.placebo_year#c.`conn']
	local p_pre_conn  = 2*ttail(e(df_r), abs(`b_pre_conn'/`se_pre_conn'))

	local stars_pre_pos ""
	if `p_pre_pos' < 0.01                               local stars_pre_pos "***"
	else if (`p_pre_pos' < 0.05 & `p_pre_pos' > 0.01)  local stars_pre_pos "**"
	else if (`p_pre_pos' < 0.10 & `p_pre_pos' > 0.05)  local stars_pre_pos "*"

	local stars_pre_conn ""
	if `p_pre_conn' < 0.01                                local stars_pre_conn "***"
	else if (`p_pre_conn' < 0.05 & `p_pre_conn' > 0.01)  local stars_pre_conn "**"
	else if (`p_pre_conn' < 0.10 & `p_pre_conn' > 0.05)  local stars_pre_conn "*"

	* Event study — separate F-tests for each component
	reghdfe `outcome' i.pos_conn##ib2011.year c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	testparm 1.pos_conn#i(2009 2010).year
	local pre_ftest_pos = r(p)

	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_conn = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex3.csv", write append
	file write `fh' `""`spec'";"ex3";"`outcome'";"main_pos";"'    %9.4f (`b_post_pos')   `"`stars_post_pos'""'  _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"main_pos_se";"' %9.4f (`se_post_pos')  `"""'                  _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"main_conn";"'   %9.4f (`b_post_conn')  `"`stars_post_conn'""' _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"main_conn_se";"' %9.4f (`se_post_conn') `"""'                 _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pos";"'     %9.4f (`b_pre_pos')    `"`stars_pre_pos'""'   _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pos_se";"'  %9.4f (`se_pre_pos')   `"""'                  _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_conn";"'    %9.4f (`b_pre_conn')   `"`stars_pre_conn'""'  _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_conn_se";"' %9.4f (`se_pre_conn')  `"""'                  _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pval_pos";"'  %9.4f (`pre_ftest_pos')  `"""'              _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pval_conn";"' %9.4f (`pre_ftest_conn') `"""'              _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"n_obs";"'        %12.0fc (`n_obs')   `"""'                    _n
	file write `fh' `""`spec'";"ex3";"`outcome'";"n_estab";"'      %12.0fc (`n_estab') `"""'                    _n
	file close `fh'

	di as result "  Ex3 `outcome' done."
}

* ── numb_clauses (CBA-period structure) ──────────────────────────────────────
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Ex3: numb_clauses (CBA periods, full sample)"

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	reghdfe numb_clauses i.pos_conn##post_treat_cba c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post_pos   = _b[1.pos_conn#1.post_treat_cba]
	local se_post_pos  = _se[1.pos_conn#1.post_treat_cba]
	local p_post_pos   = 2*ttail(e(df_r), abs(`b_post_pos'/`se_post_pos'))
	local b_post_conn  = _b[1.post_treat_cba#c.`conn']
	local se_post_conn = _se[1.post_treat_cba#c.`conn']
	local p_post_conn  = 2*ttail(e(df_r), abs(`b_post_conn'/`se_post_conn'))
	local n_obs        = e(N)
	local n_estab      = e(N_clust)

	local stars_post_pos ""
	if `p_post_pos' < 0.01                               local stars_post_pos "***"
	else if (`p_post_pos' < 0.05 & `p_post_pos' > 0.01) local stars_post_pos "**"
	else if (`p_post_pos' < 0.10 & `p_post_pos' > 0.05) local stars_post_pos "*"

	local stars_post_conn ""
	if `p_post_conn' < 0.01                                local stars_post_conn "***"
	else if (`p_post_conn' < 0.05 & `p_post_conn' > 0.01) local stars_post_conn "**"
	else if (`p_post_conn' < 0.10 & `p_post_conn' > 0.05) local stars_post_conn "*"

	* Pre-treatment placebo
	reghdfe numb_clauses i.pos_conn##pre_treat_cba c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre_pos   = _b[1.pos_conn#1.pre_treat_cba]
	local se_pre_pos  = _se[1.pos_conn#1.pre_treat_cba]
	local p_pre_pos   = 2*ttail(e(df_r), abs(`b_pre_pos'/`se_pre_pos'))
	local b_pre_conn  = _b[1.pre_treat_cba#c.`conn']
	local se_pre_conn = _se[1.pre_treat_cba#c.`conn']
	local p_pre_conn  = 2*ttail(e(df_r), abs(`b_pre_conn'/`se_pre_conn'))

	local stars_pre_pos ""
	if `p_pre_pos' < 0.01                               local stars_pre_pos "***"
	else if (`p_pre_pos' < 0.05 & `p_pre_pos' > 0.01)  local stars_pre_pos "**"
	else if (`p_pre_pos' < 0.10 & `p_pre_pos' > 0.05)  local stars_pre_pos "*"

	local stars_pre_conn ""
	if `p_pre_conn' < 0.01                                local stars_pre_conn "***"
	else if (`p_pre_conn' < 0.05 & `p_pre_conn' > 0.01)  local stars_pre_conn "**"
	else if (`p_pre_conn' < 0.10 & `p_pre_conn' > 0.05)  local stars_pre_conn "*"

	* Event study — separate F-tests for each component
	reghdfe numb_clauses i.pos_conn##ib2.cba_period c.`conn'##ib2.cba_period ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	testparm 1.pos_conn#1.cba_period
	local pre_ftest_pos = r(p)

	testparm c.`conn'#1.cba_period
	local pre_ftest_conn = r(p)

	* Write CSV
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex3.csv", write append
	file write `fh' `""`spec'";"ex3";"numb_clauses";"main_pos";"'    %9.4f (`b_post_pos')   `"`stars_post_pos'""'  _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"main_pos_se";"' %9.4f (`se_post_pos')  `"""'                  _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"main_conn";"'   %9.4f (`b_post_conn')  `"`stars_post_conn'""' _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"main_conn_se";"' %9.4f (`se_post_conn') `"""'                 _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_pos";"'     %9.4f (`b_pre_pos')    `"`stars_pre_pos'""'   _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_pos_se";"'  %9.4f (`se_pre_pos')   `"""'                  _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_conn";"'    %9.4f (`b_pre_conn')   `"`stars_pre_conn'""'  _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_conn_se";"' %9.4f (`se_pre_conn')  `"""'                  _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_pval_pos";"'  %9.4f (`pre_ftest_pos')  `"""'              _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"pre_pval_conn";"' %9.4f (`pre_ftest_conn') `"""'              _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"n_obs";"'        %12.0fc (`n_obs')   `"""'                    _n
	file write `fh' `""`spec'";"ex3";"numb_clauses";"n_estab";"'      %12.0fc (`n_estab') `"""'                    _n
	file close `fh'

	di as result "  Ex3 numb_clauses done."
}

*===============================================================================
* EXERCISE 4: FULL-SAMPLE RESIDUALIZATION + INTENSIVE MARGIN (ROBUSTNESS)
* Step 1: Residualize outcome on the FULL untreated sample, absorbing the same
*         FEs (including pre-treatment bin controls) as the main spec. FE
*         estimates are thus identified from all untreated firms, not only from
*         the positive-connectivity subsample.
* Step 2: Regress the residualized outcome on connectivity × treat_year in the
*         positive-connectivity subsample.
*
* Standard errors are obtained by bootstrapping the full two-step procedure
* (B=200 replications, resampling establishments with replacement). This
* corrects for the generated-regressors problem: naive cluster SEs from step 2
* ignore sampling variance in the step-1 FE estimates, creating a small
* downward bias (primarily from establishment FEs with T ≈ 8; industry×year
* and other high-level FEs contribute negligibly). Point estimates are
* consistent regardless.
*
* Reduce `local B' for exploratory runs; increase to 500+ for publication.
*===============================================================================

local B 200   // bootstrap replications

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "EXERCISE 4: Full-sample residualization + intensive margin (bootstrap SE)"
di as result "-----------------------------------------------------------------------"

foreach outcome in $cm_outcomes {

	* FEs to absorb in step 1 (same set as main spec)
	local absorb_e "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ── STEP 1: Residualize on full untreated sample ─────────────────────────
	di as text "  Ex4: `outcome' — step 1 residualize"
	cap drop e_`outcome'
	reghdfe `outcome' if `s_spill', absorb(`absorb_e') residuals(e_`outcome')

	* ── STEP 2 (point estimates): regress residuals on positive-conn sample ───
	* Post-treatment
	qui regress e_`outcome' c.`conn'##i.treat_year if `s_spill_pos', ///
		vce(cluster identificad)
	local b_post     = _b[1.treat_year#c.`conn']
	local se_post_cl = _se[1.treat_year#c.`conn']
	local n_obs      = e(N)
	local n_estab    = e(N_clust)

	* Pre-treatment placebo
	qui regress e_`outcome' c.`conn'##i.placebo_year ///
		if `s_spill_pos' & year <= 2011, vce(cluster identificad)
	local b_pre    = _b[1.placebo_year#c.`conn']
	local se_pre_cl = _se[1.placebo_year#c.`conn']

	* Event-study F-test (cluster SE acceptable — correction is second-order)
	qui regress e_`outcome' c.`conn'##ib2011.year if `s_spill_pos', ///
		vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* ── BOOTSTRAP: resample establishments, re-run full two-step ─────────────
	di as text "  Ex4: `outcome' — bootstrap (B=`B')"
	matrix bs_post = J(`B', 1, .)
	matrix bs_pre  = J(`B', 1, .)
	local b_ok = 0

	forvalues b = 1/`B' {
		preserve
		qui bsample, cluster(identificad)

		cap drop _e_bs
		qui cap reghdfe `outcome' if `s_spill', absorb(`absorb_e') residuals(_e_bs)
		if !_rc {
			qui cap regress _e_bs c.`conn'##i.treat_year if `s_spill_pos'
			if !_rc matrix bs_post[`b', 1] = _b[1.treat_year#c.`conn']

			qui cap regress _e_bs c.`conn'##i.placebo_year ///
				if `s_spill_pos' & year <= 2011
			if !_rc matrix bs_pre[`b', 1] = _b[1.placebo_year#c.`conn']

			local b_ok = `b_ok' + 1
		}
		restore
	}
	di as text "  Bootstrap: `b_ok'/`B' successful iterations"

	* Bootstrap SE = std dev of bootstrap coefficient distribution
	mata: st_numscalar("_bs_se_post", sqrt(variance( ///
		select(st_matrix("bs_post"), rownonmissing(st_matrix("bs_post")) :> 0))[1,1]))
	mata: st_numscalar("_bs_se_pre",  sqrt(variance( ///
		select(st_matrix("bs_pre"),  rownonmissing(st_matrix("bs_pre"))  :> 0))[1,1]))
	local bs_se_post_v = _bs_se_post
	local bs_se_pre_v  = _bs_se_pre

	* Stars based on bootstrap SE (z-test)
	local p_post_bs = 2*(1-normal(abs(`b_post'/`bs_se_post_v')))
	local p_pre_bs  = 2*(1-normal(abs(`b_pre'/`bs_se_pre_v')))

	local stars_post ""
	if `p_post_bs' < 0.01                               local stars_post "***"
	else if (`p_post_bs' < 0.05 & `p_post_bs' > 0.01)  local stars_post "**"
	else if (`p_post_bs' < 0.10 & `p_post_bs' > 0.05)  local stars_post "*"

	local stars_pre ""
	if `p_pre_bs' < 0.01                               local stars_pre "***"
	else if (`p_pre_bs' < 0.05 & `p_pre_bs' > 0.01)   local stars_pre "**"
	else if (`p_pre_bs' < 0.10 & `p_pre_bs' > 0.05)   local stars_pre "*"

	* Write CSV — bootstrap SEs in main_se/pre_se; cluster SEs in _cl rows
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex4.csv", write append
	file write `fh' `""`spec'";"ex4";"`outcome'";"main";"'      %9.4f (`b_post')       `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"main_se";"'   %9.4f (`bs_se_post_v') `"""'             _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"main_se_cl";"' %9.4f (`se_post_cl')  `"""'             _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"pre";"'       %9.4f (`b_pre')        `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"pre_se";"'    %9.4f (`bs_se_pre_v')  `"""'             _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"pre_se_cl";"' %9.4f (`se_pre_cl')    `"""'             _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"pre_pval";"'  %9.4f (`pre_ftest_pval') `"""'           _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"n_obs";"'     %12.0fc (`n_obs')      `"""'             _n
	file write `fh' `""`spec'";"ex4";"`outcome'";"n_estab";"'   %12.0fc (`n_estab')    `"""'             _n
	file close `fh'

	di as result "  Ex4 `outcome' done."
}

* ── numb_clauses (CBA-period structure) ──────────────────────────────────────
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Ex4: numb_clauses — step 1 residualize"

	local absorb_cba_e "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Step 1
	cap drop e_numb_clauses
	reghdfe numb_clauses if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba_e') residuals(e_numb_clauses)

	* Step 2 point estimates
	qui regress e_numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill_pos' & !missing(cba_period), vce(cluster identificad)
	local b_post     = _b[1.post_treat_cba#c.`conn']
	local se_post_cl = _se[1.post_treat_cba#c.`conn']
	local n_obs      = e(N)
	local n_estab    = e(N_clust)

	qui regress e_numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill_pos' & !missing(cba_period) & cba_period <= 2, ///
		vce(cluster identificad)
	local b_pre     = _b[1.pre_treat_cba#c.`conn']
	local se_pre_cl = _se[1.pre_treat_cba#c.`conn']

	qui regress e_numb_clauses c.`conn'##ib2.cba_period ///
		if `s_spill_pos' & !missing(cba_period), vce(cluster identificad)
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	* Bootstrap
	di as text "  Ex4: numb_clauses — bootstrap (B=`B')"
	matrix bs_post = J(`B', 1, .)
	matrix bs_pre  = J(`B', 1, .)
	local b_ok = 0

	forvalues b = 1/`B' {
		preserve
		qui bsample, cluster(identificad)

		cap drop _e_bs
		qui cap reghdfe numb_clauses if `s_spill' & !missing(cba_period), ///
			absorb(`absorb_cba_e') residuals(_e_bs)
		if !_rc {
			qui cap regress _e_bs c.`conn'##post_treat_cba ///
				if `s_spill_pos' & !missing(cba_period)
			if !_rc matrix bs_post[`b', 1] = _b[1.post_treat_cba#c.`conn']

			qui cap regress _e_bs c.`conn'##pre_treat_cba ///
				if `s_spill_pos' & !missing(cba_period) & cba_period <= 2
			if !_rc matrix bs_pre[`b', 1] = _b[1.pre_treat_cba#c.`conn']

			local b_ok = `b_ok' + 1
		}
		restore
	}
	di as text "  Bootstrap: `b_ok'/`B' successful iterations"

	mata: st_numscalar("_bs_se_post", sqrt(variance( ///
		select(st_matrix("bs_post"), rownonmissing(st_matrix("bs_post")) :> 0))[1,1]))
	mata: st_numscalar("_bs_se_pre",  sqrt(variance( ///
		select(st_matrix("bs_pre"),  rownonmissing(st_matrix("bs_pre"))  :> 0))[1,1]))
	local bs_se_post_v = _bs_se_post
	local bs_se_pre_v  = _bs_se_pre

	local p_post_bs = 2*(1-normal(abs(`b_post'/`bs_se_post_v')))
	local p_pre_bs  = 2*(1-normal(abs(`b_pre'/`bs_se_pre_v')))

	local stars_post ""
	if `p_post_bs' < 0.01                               local stars_post "***"
	else if (`p_post_bs' < 0.05 & `p_post_bs' > 0.01)  local stars_post "**"
	else if (`p_post_bs' < 0.10 & `p_post_bs' > 0.05)  local stars_post "*"

	local stars_pre ""
	if `p_pre_bs' < 0.01                               local stars_pre "***"
	else if (`p_pre_bs' < 0.05 & `p_pre_bs' > 0.01)   local stars_pre "**"
	else if (`p_pre_bs' < 0.10 & `p_pre_bs' > 0.05)   local stars_pre "*"

	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_ex4.csv", write append
	file write `fh' `""`spec'";"ex4";"numb_clauses";"main";"'      %9.4f (`b_post')       `"`stars_post'""' _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"main_se";"'   %9.4f (`bs_se_post_v') `"""'             _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"main_se_cl";"' %9.4f (`se_post_cl')  `"""'             _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"pre";"'       %9.4f (`b_pre')        `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"pre_se";"'    %9.4f (`bs_se_pre_v')  `"""'             _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"pre_se_cl";"' %9.4f (`se_pre_cl')    `"""'             _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"pre_pval";"'  %9.4f (`pre_ftest_pval') `"""'           _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"n_obs";"'     %12.0fc (`n_obs')      `"""'             _n
	file write `fh' `""`spec'";"ex4";"numb_clauses";"n_estab";"'   %12.0fc (`n_estab')    `"""'             _n
	file close `fh'

	di as result "  Ex4 numb_clauses done."
}

di _newline(2)
di as result "======================================================================="
di as result "ALL CONNECTIVITY MARGINS EXERCISES COMPLETE"
di as result "CSVs → $tables/conn_margins/"
di as result "======================================================================="

* ── AUTO-RUN LATEX GENERATOR ─────────────────────────────────────────────────
* Cluster: conda env; Mac: system python3 via Homebrew
if "`c(username)'" == "lgg3230" {
	shell ~/.conda/envs/venv_python312/bin/python "$programs/conn_margins/generate_conn_margins_latex.py"
}
else {
	shell python3 "$programs/conn_margins/generate_conn_margins_latex.py"
}
di as result "LaTeX tables generated → Tables/conn_margins/conn_margins_tables.tex"

capture log close
