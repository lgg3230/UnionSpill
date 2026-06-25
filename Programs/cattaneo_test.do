********************************************************************************
* UNION SPILLOVERS — WAGE PERCENTILES & INEQUALITY RATIOS (tfpw_07_11 spec)
* Purpose: Test direct and spillover effects on wage distribution outcomes
*          (wage percentiles and inequality ratios) using per-worker pairwise
*          flows (2007-2011) as the extra pre-treatment control.
* Output:  4 CSV files with regression results (panelA, panelB, panelC, spill)
* Auto-runs: Programs/generate_pct_latex.py
* Panels:  A (zero-connectivity controls), B (<=1% connectivity controls),
*          C (all untreated controls), D (spillover effects)
********************************************************************************


di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAMES (uncomment and edit if running standalone without 00_master.do)
* ===============================
// global main      "PATHNAME TO Replication-Mar-2"
// global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
// global tables    "$main/UnionSpill/Tables"
// global graphs    "$main/UnionSpill/Graphs"
// global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
// global logs      "$main/UnionSpill/Logs"
// global programs  "$main/UnionSpill/Programs"
* ===============================

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ===============================
* MERGE TURNOVER DATA
* ===============================

di as result "Merging turnover data..."

preserve
	import delimited "$rais_aux/corrected_turnover_sample.csv", clear
	keep identificad year separations_u hired_u avg_emp
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

gen double churn_u = separations_u + hired_u
label var churn_u "Total churn (separations + hires, uncensored)"

gen double churn_rate_u = (separations_u + hired_u) / avg_emp if avg_emp > 0
label var churn_rate_u "Churn rate (churn / avg employment, uncensored)"

di as result "Turnover data merged."

* ===============================
* MERGE TOTALFLOWS DATA (per-worker, 2007-2011 only)
* ===============================

di as result "Merging totalflows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe: average over
* non-missing year pairs only; NaN means zero flows, not truly missing).
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

* ── a) TREATMENT & CBA PERIOD INDICATORS ────────────────────────────────────

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
label var cba_period "CBA negotiation period (1=earliest, 2=second, 3-6=post-treatment years)"

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

* ── CONNECTIVITY SCALING ────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
 sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"

gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── b) PRE-TREATMENT MEANS FOR BASE OUTCOMES ────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

* numb_clauses pre-treatment mean (CBA period based)
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── 4-BIN CONTROLS FOR BASE OUTCOMES ────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

* Note: l_firm_emp_pre4 was already created above; skip it here to avoid
* the cap-drop-two-vars-at-once gotcha when the _o temp doesn't yet exist.
foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
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

* ── UNION CONTROLS ──────────────────────────────────────────────────────────

capture confirm new variable treat_union
if _rc {
	drop treat_union
}
gen treat_union = cond(treat_union_exp_all > 0, 1, 0)
label var treat_union "Firm's union also covers at least one treated firm"

cap drop geo_exp
bys microregion (year): egen geo_exp = mean(treat_ultra)
label var geo_exp "Share of treated among sample in a given microregion"

cap drop micro_ind
cap drop mic_ind_exp
egen micro_ind = group(microregion industry)
bys micro_ind (year): egen mic_ind_exp = mean(treat_ultra)
label var mic_ind_exp "Share treated within each micro-industry cell"

* ── c) PERCENTILE PRE-TREATMENT AVERAGES + 4-BIN CONTROLS ──────────────────

di as result "Creating percentile pre-treatment bins..."

foreach v in lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 ///
             lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 ///
             lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 ///
             lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 {

	cap drop `v'_pre_o `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}

	cap drop `v'_pre4_o `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

* ── d) LOG WAGE RATIO VARIABLES + PRE-TREATMENT AVERAGES + 4-BIN CONTROLS ──

di as result "Creating wage ratio variables and bins..."

foreach wage in lr_remdezr_w lr_remdezr_h_w {

	gen double `wage'_p90p10 = `wage'_p90 - `wage'_p10
	gen double `wage'_p80p20 = `wage'_p80 - `wage'_p20
	gen double `wage'_p75p25 = `wage'_p75 - `wage'_p25
	gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
	gen double `wage'_p80p50 = `wage'_p80 - `wage'_p50
	gen double `wage'_p75p50 = `wage'_p75 - `wage'_p50

	foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 {
		local v "`wage'_`ratio'"

		cap drop `v'_pre_o `v'_pre
		quietly {
			bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
			bys identificad: egen `v'_pre = min(`v'_pre_o)
			drop `v'_pre_o
		}

		cap drop `v'_pre4_o `v'_pre4
		quietly {
			egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
			bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
			drop `v'_pre4_o
			replace `v'_pre4 = 0 if missing(`v'_pre4)
		}
	}
}

* ── FIXED EFFECTS & SPEC MACROS ─────────────────────────────────────────────

local spec       "tfpw_07_11_pct"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── SAMPLE MACROS ───────────────────────────────────────────────────────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── e) OUTCOME GLOBALS ───────────────────────────────────────────────────────

global base_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"

di as result "All variables created."

* ── PART D: SPILLOVER EFFECTS ───────────────────────────────────────────────


foreach outcome in $base_outcomes{

	di as text "  Estimating: `outcome' (spillover)"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment
	 reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	
	* Pre-treatment placebo
	 reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)



	
	}


* numb_clauses spillover (CBA-period structure)
capture confirm variable numb_clauses
if _rc == 0 {

	
	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	 reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	* Pre-treatment
	 reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill' & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	

}

* Generate first difference approach:

*******************************************************************************
* FIRST-DIFFERENCE VALIDATION
* Collapse the panel DiD to a cross-firm first difference and check that the
* connectivity coefficient reproduces the panel  c.conn#1.treat_year.
********************************************************************************

* ---- (1) FD pre/post means computed directly from the outcome --------------
foreach outcome in $base_outcomes {

	cap drop `outcome'_fdpre_o
	cap drop `outcome'_fdpre
	cap drop `outcome'_fdpost_o
	cap drop `outcome'_fdpost
	quietly {
		bys identificad: egen `outcome'_fdpre_o  = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_fdpre    = min(`outcome'_fdpre_o)
		drop `outcome'_fdpre_o

		bys identificad: egen `outcome'_fdpost_o = mean(`outcome') if inrange(year, 2012, 2016)
		bys identificad: egen `outcome'_fdpost   = min(`outcome'_fdpost_o)
		drop `outcome'_fdpost_o
	}

	cap drop `outcome'_fd
	gen double `outcome'_fd = `outcome'_fdpost - `outcome'_fdpre
	label var `outcome'_fd "Post(2012-16) minus pre(2009-11) mean of `outcome'"
}

 

order identificad year lr_remdezr_w lr_remdezr_w_post lr_remdezr_w_fd


local spec       "tfpw_07_11_pct"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"
local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"


foreach outcome in $base_outcomes {

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Target: the panel DiD coefficient
	quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	local b_panel = _b[1.treat_year#c.`conn']
	local se_panel = _se[1.treat_year#c.`conn']


	* First difference: one row per firm (use the year==2009 rows).
	* The group dummies below are the differenced counterparts of the panel's
	* group-by-year FEs; the firm FE is removed by the differencing itself.
	quietly reghdfe `outcome'_fd c.`conn' ///
		ib0.`outcome'_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114 ///
		if `s_spill' & year == 2009, ///
		absorb(industry1 mode_base_month microregion) vce(robust)
	local b_fd = _b[`conn']
	local se_fd = _se[`conn']
	
	di _newline as result ///
  "outcome           panel_b     fd_b        diff       panel_se    fd_se      se_ratio"

	di as result %-15s "`outcome'" "  " %9.6f `b_panel' "  " %9.6f `b_fd' ///
		"  " %9.2e (`b_panel'-`b_fd') "  " %9.6f `se_panel' "  " %9.6f `se_fd' ///
		"  " %6.3f (`se_fd'/`se_panel')
		}
		
local spec       "tfpw_07_11_pct"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"
local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"		
		
foreach outcome in $base_outcomes{
	binstest `outcome'_fd `conn' ///
    i.industry1 i.mode_base_month i.microregion ///
    ib0.`outcome'_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114 ///
    if `s_spill' & year == 2009, ///
    testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
    nsims(2000) simsgrid(50) simsseed(12345) vce(robust)
}

********************************************************************************
* END OF DO-FILE
********************************************************************************
