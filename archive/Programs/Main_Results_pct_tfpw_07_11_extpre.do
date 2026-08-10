********************************************************************************
* UNION SPILLOVERS — WAGE PERCENTILES & INEQUALITY RATIOS (tfpw_07_11 spec)
* Purpose: Test direct and spillover effects on wage distribution outcomes
*          (wage percentiles and inequality ratios) using per-worker pairwise
*          flows (2007-2011) as the extra pre-treatment control.
* Output:  4 CSV files with regression results (panelA, panelB, panelC, spill)
* Auto-runs: Programs/5160_table_pct_latex.py
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
log using "$logs/FinalResults_pct_tfpw_07_11_extpre_`d'_`t'.log", replace text

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

* ── INITIALIZE OUTPUT CSV FILES ─────────────────────────────────────────────

foreach panel in A B C {
	capture erase "$tables/results_direct_panel`panel'_tfpw_07_11_pct_extpre.csv"
	tempname fh
	file open `fh' using "$tables/results_direct_panel`panel'_tfpw_07_11_pct_extpre.csv", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'
}

capture erase "$tables/results_spill_tfpw_07_11_pct_extpre.csv"
tempname fh
file open `fh' using "$tables/results_spill_tfpw_07_11_pct_extpre.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* ── PARTS A-C: DIRECT EFFECTS ───────────────────────────────────────────────

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

	local csv_out "$tables/results_direct_panel`panel'_tfpw_07_11_pct_extpre.csv"

	di _newline(1)
	di as result "--- Panel `panel' ---"

	* ── Year-based outcomes ─────────────────────────────────────────────────

	foreach outcome in $base_outcomes $pct_outcomes_dec $pct_outcomes_hr $ratio_outcomes_dec $ratio_outcomes_hr {

		di as text "  Estimating: `outcome' (Panel `panel')"

		local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

		* Post-treatment  (GUARDED to year>=2009 -> reproduces headline 2x2)
		reghdfe `outcome' treat_ultra##i.treat_year if `s_use' & extpre_row==0, ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment placebo  (GUARDED: 2009-2010 vs 2011, as in headline)
		reghdfe `outcome' treat_ultra##i.placebo_year if `s_use' & extpre_row==0 & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.placebo_year]
		local se_pre = _se[1.treat_ultra#1.placebo_year]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* Stars
		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		* Event study — FULL 2007-2016 window (gains pre-periods 2007 & 2008)
		 reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		* original 2-period pre-trend test (2009-2010), for comparability with headline
		testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = r(p)
		* extended 4-period pre-trend test (2007-2010) — the de-fragilized diagnostic
		testparm 1.treat_ultra#i(2007 2008 2009 2010).year
		local pre_ftest_ext_pval = r(p)
		local n_es = e(N)

		di as result "    [`outcome' / `section'] pre-trend F: 2-period p=" %6.4f `pre_ftest_pval' "  4-period(2007-10) p=" %6.4f `pre_ftest_ext_pval'

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"`section'";"`outcome'";"pre_pval_ext0710";"' %9.4f (`pre_ftest_ext_pval') `"""' _n
		file close `fh'

		* Event study plot — main outcomes only (base_outcomes)
		local is_main 0
		foreach mo in $base_outcomes {
			if "`mo'" == "`outcome'" local is_main 1
		}
		if `is_main' {
			estimates store _es_d_tmp
			local post_coef_s = string(`b_post', "%9.4f")
			local post_se_s   = string(`se_post', "%9.4f")
			local pre_pval_s  = string(`p_pre',   "%9.3f")

			local preext_s = string(`pre_ftest_ext_pval', "%9.3f")
			coefplot _es_d_tmp, ///
				keep(1.treat_ultra#2007.year 1.treat_ultra#2008.year ///
				     1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
				     1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
				     1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
				coeflabels(1.treat_ultra#2007.year = "2007" ///
				           1.treat_ultra#2008.year = "2008" ///
				           1.treat_ultra#2009.year = "2009" ///
				           1.treat_ultra#2010.year = "2010" ///
				           1.treat_ultra#2011.year = "2011" ///
				           1.treat_ultra#2012.year = "2012" ///
				           1.treat_ultra#2013.year = "2013" ///
				           1.treat_ultra#2014.year = "2014" ///
				           1.treat_ultra#2015.year = "2015" ///
				           1.treat_ultra#2016.year = "2016") ///
				vert omitted baselevels yline(0) xline(5.5, lpattern(dash)) ///
				ytitle("Dynamic DiD coefficients", size(small)) ///
				note("Pre-trend p: 2009-10 = `pre_pval_s'  |  2007-10 = `preext_s'") ///
				graphregion(color(white)) bgcolor(white) ///
				ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
				text(0.05 8 "`post_coef_s' (`post_se_s')", color(blue) size(small))

			cap graph export "$graphs/es_`outcome'_direct`panel'_extpre_`d'.pdf", as(pdf) replace
			estimates drop _es_d_tmp
		}
	}

	* ── numb_clauses (CBA-period structure) ─────────────────────────────────

	capture confirm variable numb_clauses
	if _rc == 0 {

		di as text "  Estimating: numb_clauses (CBA periods, Panel `panel')"

		local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		* Post-treatment
		 reghdfe numb_clauses i.treat_ultra##post_treat_cba ///
			if `s_use' & extpre_row==0 & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.treat_ultra#1.post_treat_cba]
		local se_post = _se[1.treat_ultra#1.post_treat_cba]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment
		 reghdfe numb_clauses i.treat_ultra##pre_treat_cba ///
			if `s_use' & extpre_row==0 & !missing(cba_period) & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
		local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		* Stars
		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		* Event study for pre-trend F-test
		 reghdfe numb_clauses i.treat_ultra##ib2.cba_period ///
			if `s_use' & extpre_row==0 & !missing(cba_period), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm 1.treat_ultra#1.cba_period
		local pre_ftest_pval = r(p)

		* Write
		tempname fh
		file open `fh' using "`csv_out'", write append
		file write `fh' `""`spec'";"`section'";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"`section'";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'

		* Event study plot — numb_clauses (CBA periods)
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

		cap graph export "$graphs/es_numb_clauses_direct`panel'_`d'.pdf", as(pdf) replace
		estimates drop _es_d_tmp
	}

	di as result "Panel `panel' complete."
}

* ── PART D: SPILLOVER EFFECTS ───────────────────────────────────────────────

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/results_spill_tfpw_07_11_pct_extpre.csv"

foreach outcome in $base_outcomes $pct_outcomes_dec $pct_outcomes_hr $ratio_outcomes_dec $ratio_outcomes_hr {

	di as text "  Estimating: `outcome' (spillover)"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Post-treatment  (GUARDED to year>=2009 -> reproduces headline 2x2)
	 reghdfe `outcome' c.`conn'##i.treat_year if `s_spill' & extpre_row==0, ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment placebo  (GUARDED: 2009-2010 vs 2011, as in headline)
	 reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & extpre_row==0 & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.placebo_year#c.`conn']
	local se_pre = _se[1.placebo_year#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	* Stars
	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study — FULL 2007-2016 window (gains pre-periods 2007 & 2008)
	 reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)
	testparm c.`conn'#i(2007 2008 2009 2010).year
	local pre_ftest_ext_pval = r(p)

	di as result "    [`outcome' / spill] pre-trend F: 2-period p=" %6.4f `pre_ftest_pval' "  4-period(2007-10) p=" %6.4f `pre_ftest_ext_pval'

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval_ext0710";"' %9.4f (`pre_ftest_ext_pval') `"""' _n
	file close `fh'

	* Event study plot — main outcomes only (base_outcomes)
	local is_main 0
	foreach mo in $base_outcomes {
		if "`mo'" == "`outcome'" local is_main 1
	}
	if `is_main' {
		estimates store _es_sp_tmp
		local post_coef_s = string(`b_post', "%9.4f")
		local post_se_s   = string(`se_post', "%9.4f")
		local pre_pval_s  = string(`p_pre',   "%9.3f")

		local preext_s = string(`pre_ftest_ext_pval', "%9.3f")
		coefplot _es_sp_tmp, ///
			keep(*#*c.`conn') ///
			msymbol(diamond) ///
			coeflabels(2007.year#c.`conn' = "2007" ///
			           2008.year#c.`conn' = "2008" ///
			           2009.year#c.`conn' = "2009" ///
			           2010.year#c.`conn' = "2010" ///
			           2011.year#c.`conn' = "2011" ///
			           2012.year#c.`conn' = "2012" ///
			           2013.year#c.`conn' = "2013" ///
			           2014.year#c.`conn' = "2014" ///
			           2015.year#c.`conn' = "2015" ///
			           2016.year#c.`conn' = "2016") ///
			vert omitted baselevels yline(0) xline(5.5, lpattern(dash)) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("Pre-trend p: 2009-10 = `pre_pval_s'  |  2007-10 = `preext_s'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
			text(0.015 7 "`post_coef_s' (`post_se_s')", color(blue) size(small))

		cap graph export "$graphs/es_`outcome'_spill_extpre_`d'.pdf", as(pdf) replace
		estimates drop _es_sp_tmp
	}
}

* numb_clauses spillover (CBA-period structure)
capture confirm variable numb_clauses
if _rc == 0 {

	di as text "  Estimating: numb_clauses (spillover, CBA periods)"

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Post-treatment
	 reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill' & extpre_row==0 & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_post  = _b[1.post_treat_cba#c.`conn']
	local se_post = _se[1.post_treat_cba#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment
	 reghdfe numb_clauses c.`conn'##pre_treat_cba ///
		if `s_spill' & extpre_row==0 & !missing(cba_period) & cba_period <= 2, ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_pre = _se[1.pre_treat_cba#c.`conn']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	* Stars
	local stars_post ""
	if `p_post' < 0.01                              local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                               local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

	* Event study for pre-trend F-test
	 reghdfe numb_clauses c.`conn'##ib2.cba_period ///
		if `s_spill' & extpre_row==0 & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	testparm c.`conn'#1.cba_period
	local pre_ftest_pval = r(p)

	* Write
	tempname fh
	file open `fh' using "`csv_spill'", write append
	file write `fh' `""`spec'";"spill";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
	file close `fh'

	* Event study plot — numb_clauses spillover (CBA periods)
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

	cap graph export "$graphs/es_numb_clauses_spill_`d'.pdf", as(pdf) replace
	estimates drop _es_sp_tmp
}

di _newline(1)
di as result "All regressions complete."

********************************************************************************
* SECTION 4: COMPLETION + AUTO-RUN PYTHON
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

* ── Auto-run LaTeX generation DISABLED for the extpre variant ───────────────
* (would hang on local python3 per unionspill-local-stata-run memory, and would
*  regenerate the headline tables. extpre CSVs are *_extpre.csv; render separately.)
* shell python3 "$programs/5160_table_pct_latex.py"

********************************************************************************
* END OF DO-FILE
********************************************************************************
