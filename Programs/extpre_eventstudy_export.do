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

* ===============================================================================
* EXTPRE VARIANT of 4012_pct_tfpw.do
* Pre-period extended back to 2007 (2007-2008 firm-year outcomes rebuilt from raw
* RAIS parquet, validated vs live 2009 to machine precision; see extpre_build.do).
* Design: the static (2x2) post & pre estimates and numb_clauses are GUARDED to
* year>=2009 (extpre_row==0) so they reproduce the headline exactly. The dynamic
* EVENT STUDY uses the full 2007-2016 window, gaining pre-periods 2007 & 2008, and
* the joint pre-trend F-test now spans 2007-2010. New outputs suffixed _extpre.
* ===============================================================================

version 17.0

* ---- local Mac globals (see unionspill-local-stata-run memory) -----------------
global root      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$root/Data/CBA_rais_firm_level"
global rais_aux  "$root/Data/RAIS_aux"
global tables    "$root/Tables"
global graphs    "$root/Graphs"
global logs      "$root/Logs"
global programs  "$root/Programs"
cap mkdir "$logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/FinalResults_pct_tfpw_07_11_extpre_ES_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAMES (uncomment and edit if running standalone without 0000_master.do)
* ===============================
// global main      "PATHNAME TO Replication-Mar-2"
// global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
// global tables    "$main/UnionSpill/Tables"
// global graphs    "$main/UnionSpill/Graphs"
// global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
// global logs      "$main/UnionSpill/Logs"
// global programs  "$main/UnionSpill/Programs"
* ===============================

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta", clear

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

keep if year >= 2007
keep if lagos_sample_avg == 1

* extpre_row: 1 for the rebuilt 2007-2008 pre-period rows, 0 for headline 2009-2016.
* Used to GUARD the static (2x2) estimates so they reproduce the headline sample.
capture confirm variable extpre_row
if _rc {
	gen byte extpre_row = inlist(year,2007,2008)
}

di as result "Sample size after restrictions: " _N
di as result "Year coverage:"
tab year

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

* ── e) OUTCOME GLOBALS ───────────────────────────────────────────────────────

global base_outcomes      "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
global pct_outcomes_dec   "lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90"
global pct_outcomes_hr    "lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90"
global ratio_outcomes_dec "lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50"
global ratio_outcomes_hr  "lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50"

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "STARTING ESTIMATION"
di as result "======================================================================="

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


* =============================================================================
* FOCUSED EVENT-STUDY EXPORT  (base outcomes; direct Panel A + spillover)
* TWO SAMPLES shown side by side:
*   unbal = headline balanced-2009-16 firms + 2007-08 where present (pre-period unbalanced)
*   bal   = balanced THROUGHOUT 2007-16 (firm operated, i.e. l_firm_emp non-missing, in 2007 AND 2008)
* For each sample: pooled DiD on 2009-16 (guarded) and 2007-16 (extended), per-period coefs, pre-trend F.
* Outputs: Tables/es_coefs_extpre.csv (sample column); figures es_<outcome>_<effect>_extpre[_bal].pdf
* =============================================================================

local conn2 "totaltreat_pw_norm"
local es_years 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016

* balanced-2007-16 flag: firm operated in BOTH 2007 and 2008
cap drop _h07
cap drop _h08
bys identificad: egen _h07 = max(year==2007 & !missing(l_firm_emp))
bys identificad: egen _h08 = max(year==2008 & !missing(l_firm_emp))
gen byte bal0716 = (_h07==1 & _h08==1)
drop _h07
drop _h08
di as result "Firms balanced throughout 2007-16:"
count if year==2009 & bal0716==1

cap erase "$tables/es_coefs_extpre.csv"
tempname ch
file open `ch' using "$tables/es_coefs_extpre.csv", write replace
file write `ch' "sample,effect,outcome,year,coef,se,ci_lo,ci_hi,pF_2009_10,pF_2007_10,post_head_b,post_head_se,post_head_p,post_ext_b,post_ext_se,post_ext_p,pre_head_b,pre_head_se,pre_head_p,pre_ext_b,pre_ext_se,pre_ext_p,n_obs,n_estab" _n

foreach samp in unbal bal {
	if "`samp'"=="unbal" {
		local balc ""
		local fsuf ""
	}
	else {
		local balc "& bal0716==1"
		local fsuf "_bal"
	}
	di as result _newline "================ SAMPLE = `samp' ================"

	* ---------------- DIRECT (Panel A) ----------------
	foreach outcome in $base_outcomes {
		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A' & extpre_row==0 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local pb  = _b[1.treat_ultra#1.treat_year]
		local ps  = _se[1.treat_ultra#1.treat_year]
		local pb_p = 2*ttail(e(df_r), abs(`pb'/`ps'))

		reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A' `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local pbe = _b[1.treat_ultra#1.treat_year]
		local pse = _se[1.treat_ultra#1.treat_year]
		local pe_p = 2*ttail(e(df_r), abs(`pbe'/`pse'))
		local pe_star = ""
		if `pe_p'<0.01                          local pe_star = "***"
		else if (`pe_p'<0.05 & `pe_p'>=0.01)    local pe_star = "**"
		else if (`pe_p'<0.10 & `pe_p'>=0.05)    local pe_star = "*"

		* placebo Pre x Treatment, headline window (2009-10 vs 2011)
		reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_A' & extpre_row==0 & year<=2011 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local prh_b  = _b[1.treat_ultra#1.placebo_year]
		local prh_se = _se[1.treat_ultra#1.placebo_year]
		local prh_p  = 2*ttail(e(df_r), abs(`prh_b'/`prh_se'))

		* placebo Pre x Treatment, extended window (2007-10 vs 2011)
		reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_A' & year<=2011 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local prx_b  = _b[1.treat_ultra#1.placebo_year]
		local prx_se = _se[1.treat_ultra#1.placebo_year]
		local prx_p  = 2*ttail(e(df_r), abs(`prx_b'/`prx_se'))
		local prx_star = ""
		if `prx_p'<0.01                          local prx_star = "***"
		else if (`prx_p'<0.05 & `prx_p'>=0.01)    local prx_star = "**"
		else if (`prx_p'<0.10 & `prx_p'>=0.05)    local prx_star = "*"

		reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_A' `balc', ///
			absorb(`absorb') vce(cluster identificad)
		testparm 1.treat_ultra#i(2009 2010).year
		local pf2 = r(p)
		testparm 1.treat_ultra#i(2007 2008 2009 2010).year
		local pf4 = r(p)
		local nobs = e(N)
		local nclust = e(N_clust)
		estimates store _esd

		foreach yr of local es_years {
			if `yr'==2011 {
				local b = 0
				local s = 0
			}
			else {
				local b = _b[1.treat_ultra#`yr'.year]
				local s = _se[1.treat_ultra#`yr'.year]
			}
			local lo = `b' - 1.96*`s'
			local hi = `b' + 1.96*`s'
			file write `ch' "`samp',direct_A,`outcome',`yr'," %12.6f (`b') "," %12.6f (`s') "," ///
				%12.6f (`lo') "," %12.6f (`hi') "," %9.4f (`pf2') "," %9.4f (`pf4') "," ///
				%12.6f (`pb') "," %12.6f (`ps') "," %9.4f (`pb_p') "," ///
				%12.6f (`pbe') "," %12.6f (`pse') "," %9.4f (`pe_p') "," ///
				%12.6f (`prh_b') "," %12.6f (`prh_se') "," %9.4f (`prh_p') "," ///
				%12.6f (`prx_b') "," %12.6f (`prx_se') "," %9.4f (`prx_p') "," ///
				%12.0f (`nobs') "," %12.0f (`nclust') _n
		}

		local pf2_s = string(`pf2', "%9.3f")
		local pf4_s = string(`pf4', "%9.3f")
		local pb_s  = string(`pbe', "%9.4f")
		local ps_s  = string(`pse', "%9.4f")
		local prx_s    = string(`prx_b', "%9.4f")
		local prx_se_s = string(`prx_se', "%9.4f")
		coefplot _esd, ///
			keep(1.treat_ultra#2007.year 1.treat_ultra#2008.year 1.treat_ultra#2009.year ///
			     1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year ///
			     1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year ///
			     1.treat_ultra#2016.year) ///
			coeflabels(1.treat_ultra#2007.year="2007" 1.treat_ultra#2008.year="2008" ///
			           1.treat_ultra#2009.year="2009" 1.treat_ultra#2010.year="2010" ///
			           1.treat_ultra#2011.year="2011" 1.treat_ultra#2012.year="2012" ///
			           1.treat_ultra#2013.year="2013" 1.treat_ultra#2014.year="2014" ///
			           1.treat_ultra#2015.year="2015" 1.treat_ultra#2016.year="2016") ///
			vert omitted baselevels yline(0) xline(5.5, lpattern(dash)) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("Pooled (2007-16 sample):  Post = `pb_s'`pe_star' (`ps_s')    Pre = `prx_s'`prx_star' (`prx_se_s')" ///
			     "Pre-trend joint-F p:  2009-10 = `pf2_s'   |   2007-10 = `pf4_s'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
		cap graph export "$graphs/es_`outcome'_directA_extpre`fsuf'.pdf", as(pdf) replace
		estimates drop _esd
	}

	* ---------------- SPILLOVER ----------------
	foreach outcome in $base_outcomes {
		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		reghdfe `outcome' c.`conn2'##i.treat_year if `s_spill' & extpre_row==0 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local pb  = _b[1.treat_year#c.`conn2']
		local ps  = _se[1.treat_year#c.`conn2']
		local pb_p = 2*ttail(e(df_r), abs(`pb'/`ps'))

		reghdfe `outcome' c.`conn2'##i.treat_year if `s_spill' `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local pbe = _b[1.treat_year#c.`conn2']
		local pse = _se[1.treat_year#c.`conn2']
		local pe_p = 2*ttail(e(df_r), abs(`pbe'/`pse'))
		local pe_star = ""
		if `pe_p'<0.01                          local pe_star = "***"
		else if (`pe_p'<0.05 & `pe_p'>=0.01)    local pe_star = "**"
		else if (`pe_p'<0.10 & `pe_p'>=0.05)    local pe_star = "*"

		* placebo Pre x Connectivity, headline window (2009-10 vs 2011)
		reghdfe `outcome' c.`conn2'##i.placebo_year if `s_spill' & extpre_row==0 & year<=2011 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local prh_b  = _b[1.placebo_year#c.`conn2']
		local prh_se = _se[1.placebo_year#c.`conn2']
		local prh_p  = 2*ttail(e(df_r), abs(`prh_b'/`prh_se'))

		* placebo Pre x Connectivity, extended window (2007-10 vs 2011)
		reghdfe `outcome' c.`conn2'##i.placebo_year if `s_spill' & year<=2011 `balc', ///
			absorb(`absorb') vce(cluster identificad)
		local prx_b  = _b[1.placebo_year#c.`conn2']
		local prx_se = _se[1.placebo_year#c.`conn2']
		local prx_p  = 2*ttail(e(df_r), abs(`prx_b'/`prx_se'))
		local prx_star = ""
		if `prx_p'<0.01                          local prx_star = "***"
		else if (`prx_p'<0.05 & `prx_p'>=0.01)    local prx_star = "**"
		else if (`prx_p'<0.10 & `prx_p'>=0.05)    local prx_star = "*"

		reghdfe `outcome' c.`conn2'##ib2011.year if `s_spill' `balc', ///
			absorb(`absorb') vce(cluster identificad)
		testparm c.`conn2'#i(2009 2010).year
		local pf2 = r(p)
		testparm c.`conn2'#i(2007 2008 2009 2010).year
		local pf4 = r(p)
		local nobs = e(N)
		local nclust = e(N_clust)
		estimates store _ess

		foreach yr of local es_years {
			if `yr'==2011 {
				local b = 0
				local s = 0
			}
			else {
				local b = _b[`yr'.year#c.`conn2']
				local s = _se[`yr'.year#c.`conn2']
			}
			local lo = `b' - 1.96*`s'
			local hi = `b' + 1.96*`s'
			file write `ch' "`samp',spill,`outcome',`yr'," %12.6f (`b') "," %12.6f (`s') "," ///
				%12.6f (`lo') "," %12.6f (`hi') "," %9.4f (`pf2') "," %9.4f (`pf4') "," ///
				%12.6f (`pb') "," %12.6f (`ps') "," %9.4f (`pb_p') "," ///
				%12.6f (`pbe') "," %12.6f (`pse') "," %9.4f (`pe_p') "," ///
				%12.6f (`prh_b') "," %12.6f (`prh_se') "," %9.4f (`prh_p') "," ///
				%12.6f (`prx_b') "," %12.6f (`prx_se') "," %9.4f (`prx_p') "," ///
				%12.0f (`nobs') "," %12.0f (`nclust') _n
		}

		local pf2_s = string(`pf2', "%9.3f")
		local pf4_s = string(`pf4', "%9.3f")
		local pb_s  = string(`pbe', "%9.4f")
		local ps_s  = string(`pse', "%9.4f")
		local prx_s    = string(`prx_b', "%9.4f")
		local prx_se_s = string(`prx_se', "%9.4f")
		coefplot _ess, keep(*#*c.`conn2') msymbol(diamond) ///
			coeflabels(2007.year#c.`conn2'="2007" 2008.year#c.`conn2'="2008" ///
			           2009.year#c.`conn2'="2009" 2010.year#c.`conn2'="2010" ///
			           2011.year#c.`conn2'="2011" 2012.year#c.`conn2'="2012" ///
			           2013.year#c.`conn2'="2013" 2014.year#c.`conn2'="2014" ///
			           2015.year#c.`conn2'="2015" 2016.year#c.`conn2'="2016") ///
			vert omitted baselevels yline(0) xline(5.5, lpattern(dash)) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("Pooled (2007-16 sample):  Post = `pb_s'`pe_star' (`ps_s')    Pre = `prx_s'`prx_star' (`prx_se_s')" ///
			     "Pre-trend joint-F p:  2009-10 = `pf2_s'   |   2007-10 = `pf4_s'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
		cap graph export "$graphs/es_`outcome'_spill_extpre`fsuf'.pdf", as(pdf) replace
		estimates drop _ess
	}
}

file close `ch'
log close
di as result "Two-sample event-study export done. Coefs -> $tables/es_coefs_extpre.csv"
