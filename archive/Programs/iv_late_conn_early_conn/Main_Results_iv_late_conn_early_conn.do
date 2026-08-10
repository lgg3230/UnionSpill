********************************************************************************
* UNION SPILLOVERS — IV: LATE PRE-TREATMENT CONNECTIVITY INSTRUMENTED BY
*                         EARLY PRE-TREATMENT CONNECTIVITY
*
* Purpose: Spillover effects using IV strategy. Both connectivity measures are
*          from the PRE-treatment period (2007-2011), split into:
*            - Early: avg of year-pairs 2007-08 and 2008-09 (instrument)
*            - Late:  avg of year-pairs 2009-10 and 2010-11 (endogenous)
*          This mirrors the bilateral early/late split in conn_descriptives
*          (06_bilateral_data_prep.py: early_pre = avg(ratio_0708, ratio_0809),
*                                      late_pre  = avg(ratio_0910, ratio_1011)).
*
* FE spec: Same as 4012_pct_tfpw.do (firm, industry×year,
*           month×year, microregion×year, outcome_pre4×year, emp_pre4×year,
*           totalflows_pw_pre_07_11 bins×year)
* IV ref:  Main_Results_IV.do lines 1867–2229
* Sample:  Spillover sample only (untreated, lagos_sample_avg, in_balanced_panel)
* Output:  Tables/iv_late_conn_early_conn/
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/iv_late_conn_early_conn/FinalResults_iv_late_conn_early_conn_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAMES (uncomment if running standalone without _run wrapper)
* ===============================
// global main      "/kellogg/proj/lgg3230"
// global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
// global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
// global tables    "$main/UnionSpill/Tables"
// global graphs    "$main/UnionSpill/Graphs"
// global logs      "$main/UnionSpill/Logs"
// global programs  "$main/UnionSpill/Programs"
* ===============================

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ===============================
* MERGE TOTALFLOWS DATA (2007–2011, for flow-control bins)
* ===============================

di as result "Merging totalflows (2007–2011) for flow-control bins..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007–2011 (for quartile-bin controls)
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

* ===============================
* MERGE YEARLY CONNECTIVITY TO TREATED (2007-2011)
* — needed to construct early (0708+0809) and late (0910+1011) splits
* ===============================

di as result "Merging yearly connectivity to treated (2007-2011)..."

preserve
	import delimited "$rais_aux/connectivity_treat_2007_2011.csv", clear

	* Strip leading "1" from MATLAB 15-digit identifier to get 14-digit CNPJ
	format identificad1 %21.0f
	gen str15 identificad1_s = string(identificad1, "%015.0f")
	gen identificad = substr(identificad1_s, 2, 14)
	drop identificad1 identificad1_s

	* Keep only the year-pair per-worker flows to treated
	keep identificad ///
		totaltreat_pw_2007_2008 totaltreat_pw_2008_2009 ///
		totaltreat_pw_2009_2010 totaltreat_pw_2010_2011

	tempfile conn_yearly
	save `conn_yearly'
restore

merge m:1 identificad using `conn_yearly', keep(master match) nogen

di as result "Yearly connectivity merged."

* ── Construct early and late connectivity (missing-safe averages) ─────────────

* Early connectivity: avg of 2007-08 and 2008-09 year-pairs
gen double early_conn_pw = 0
gen early_conn_cnt = 0
foreach yp in totaltreat_pw_2007_2008 totaltreat_pw_2008_2009 {
	replace early_conn_pw  = early_conn_pw  + `yp' if !missing(`yp')
	replace early_conn_cnt = early_conn_cnt + (!missing(`yp'))
}
replace early_conn_pw = early_conn_pw / early_conn_cnt if early_conn_cnt > 0
replace early_conn_pw = . if early_conn_cnt == 0
drop early_conn_cnt
label var early_conn_pw "Early pre-treatment conn to treated (avg 0708+0809, per worker)"

* Late connectivity: avg of 2009-10 and 2010-11 year-pairs
gen double late_conn_pw = 0
gen late_conn_cnt = 0
foreach yp in totaltreat_pw_2009_2010 totaltreat_pw_2010_2011 {
	replace late_conn_pw  = late_conn_pw  + `yp' if !missing(`yp')
	replace late_conn_cnt = late_conn_cnt + (!missing(`yp'))
}
replace late_conn_pw = late_conn_pw / late_conn_cnt if late_conn_cnt > 0
replace late_conn_pw = . if late_conn_cnt == 0
drop late_conn_cnt
label var late_conn_pw "Late pre-treatment conn to treated (avg 0910+1011, per worker)"

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating variables..."

* ── a) TREATMENT & PERIOD INDICATORS ─────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── b) EARLY AND LATE CONNECTIVITY SCALING (normalize to P90) ─────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Normalize early connectivity to its P90 in the spillover sample (year 2009)
cap drop early_conn_p90
cap drop early_conn_norm
sum early_conn_pw if `s_spill' & year == 2009, detail
gen early_conn_p90 = r(p90)
label var early_conn_p90 "P90 of early connectivity (spillover sample, 2009)"
gen early_conn_norm = early_conn_pw / r(p90)
label var early_conn_norm "Early connectivity (0708+0809) normalized to P90"

di as result "P90 of early connectivity: " %9.4f r(p90)

* Normalize late connectivity to its P90 in the spillover sample (year 2009)
cap drop late_conn_p90
cap drop late_conn_norm
sum late_conn_pw if `s_spill' & year == 2009, detail
gen late_conn_p90 = r(p90)
label var late_conn_p90 "P90 of late connectivity (spillover sample, 2009)"
gen late_conn_norm = late_conn_pw / r(p90)
label var late_conn_norm "Late connectivity (0910+1011) normalized to P90"

di as result "P90 of late connectivity:  " %9.4f r(p90)

* ── c) PRE-TREATMENT MEANS FOR BASE OUTCOMES ──────────────────────────────────

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

* Log pre-treatment employment
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── d) 4-BIN CONTROLS FOR BASE OUTCOMES ───────────────────────────────────────

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

* l_firm_emp uses l_firm_emp_pre4 already created above

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

* ── e) IV INTERACTION VARIABLES ───────────────────────────────────────────────

* Post-treatment interactions (treat_year = 1 if year >= 2012)
cap drop conn_late_X_treat
cap drop conn_early_X_treat
gen conn_late_X_treat  = late_conn_norm  * treat_year
gen conn_early_X_treat = early_conn_norm * treat_year
label var conn_late_X_treat  "Late conn (0910+1011) × Post-treat (endogenous)"
label var conn_early_X_treat "Early conn (0708+0809) × Post-treat (instrument)"

* Pre-treatment placebo interactions
cap drop conn_late_X_plac
cap drop conn_early_X_plac
gen conn_late_X_plac  = late_conn_norm  * placebo_year
gen conn_early_X_plac = early_conn_norm * placebo_year
label var conn_late_X_plac  "Late conn × Pre-treat placebo"
label var conn_early_X_plac "Early conn × Pre-treat placebo"

di as result "All variables created."

********************************************************************************
* SECTION 3: OUTPUT FILE SETUP
********************************************************************************

local tables_iv "$tables/iv_late_conn_early_conn"

* Main results (OLS and IV side-by-side)
capture erase "`tables_iv'/results_iv_spillover.csv"
tempname fh
file open `fh' using "`tables_iv'/results_iv_spillover.csv", write replace
file write `fh' "outcome;row_type;value" _n
file close `fh'

* First-stage results
capture erase "`tables_iv'/results_iv_firststage.csv"
tempname fh
file open `fh' using "`tables_iv'/results_iv_firststage.csv", write replace
file write `fh' "statistic;value" _n
file close `fh'

********************************************************************************
* SECTION 4: FE SPEC AND SAMPLE MACROS
********************************************************************************

* FE spec from 4012_pct_tfpw.do
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

********************************************************************************
* SECTION 5: FIRST STAGE (on lr_remdezr_w sample)
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "FIRST STAGE: early_conn × post → late_conn × post"
di as result "======================================================================="

local fs_outcome "lr_remdezr_w"
local fs_absorb "`base_fe' ib0.`fs_outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

* Run ivreghdfe to obtain Kleibergen-Paap diagnostics
* ivreghdfe stores: e(rkf) = KP rk Wald F-stat, e(idstat) = KP rk LM-stat
ivreghdfe `fs_outcome' (conn_late_X_treat = conn_early_X_treat) if `s_spill', ///
	absorb(`fs_absorb') cluster(identificad)

local kp_F  = e(rkf)
local kp_LM = e(idstat)

* Run first stage OLS directly for the coefficient
reghdfe conn_late_X_treat conn_early_X_treat if `s_spill', ///
	absorb(`fs_absorb') vce(cluster identificad)

local fs_coef   = _b[conn_early_X_treat]
local fs_se     = _se[conn_early_X_treat]
local fs_n_obs  = e(N)
local fs_n_clus = e(N_clust)

di as result "First-stage coef (early → late): " %9.4f `fs_coef'
di as result "First-stage SE:                  " %9.4f `fs_se'
di as result "Kleibergen-Paap F-stat:          " %9.2f `kp_F'
di as result "Kleibergen-Paap LM-stat:         " %9.2f `kp_LM'
di as result "N observations:                  " %12.0fc `fs_n_obs'
di as result "N clusters:                      " %12.0fc `fs_n_clus'

tempname fh
file open `fh' using "`tables_iv'/results_iv_firststage.csv", write append
file write `fh' "fs_coef;"  %9.4f (`fs_coef')   _n
file write `fh' "fs_se;"    %9.4f (`fs_se')     _n
file write `fh' "kp_F;"     %9.2f (`kp_F')      _n
file write `fh' "kp_LM;"    %9.2f (`kp_LM')     _n
file write `fh' "n_obs;"    %12.0f (`fs_n_obs')  _n
file write `fh' "n_clust;"  %12.0f (`fs_n_clus') _n
file close `fh'

********************************************************************************
* SECTION 6: OLS AND IV RESULTS — LOOP OVER OUTCOMES
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "OLS (late connectivity) AND IV (late instrumented by early)"
di as result "======================================================================="

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di _newline(1)
	di as text "  Estimating: `outcome'"

	* Outcome-specific pre4 bin variable
	if "`outcome'" == "l_firm_emp" {
		local outcome_pre4 "l_firm_emp_pre4"
	}
	else {
		local outcome_pre4 "`outcome'_pre4"
	}

	local absorb "`base_fe' ib0.`outcome_pre4'#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ===================
	* OLS with late (endogenous) connectivity
	* ===================

	di as text "    OLS (late connectivity, endogenous)..."

	* Post-treatment OLS
	reghdfe `outcome' c.late_conn_norm##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post_ols  = _b[1.treat_year#c.late_conn_norm]
	local se_post_ols = _se[1.treat_year#c.late_conn_norm]
	local p_post_ols  = 2*ttail(e(df_r), abs(`b_post_ols'/`se_post_ols'))
	local n_obs_ols   = e(N)
	local n_estab_ols = e(N_clust)

	* Pre-treatment OLS (placebo)
	reghdfe `outcome' c.late_conn_norm##i.placebo_year ///
		if `s_spill' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre_ols  = _b[1.placebo_year#c.late_conn_norm]
	local se_pre_ols = _se[1.placebo_year#c.late_conn_norm]
	local p_pre_ols  = 2*ttail(e(df_r), abs(`b_pre_ols'/`se_pre_ols'))

	* Stars for OLS
	local stars_post_ols ""
	if `p_post_ols' < 0.01       local stars_post_ols "***"
	else if `p_post_ols' < 0.05  local stars_post_ols "**"
	else if `p_post_ols' < 0.10  local stars_post_ols "*"

	local stars_pre_ols ""
	if `p_pre_ols' < 0.01        local stars_pre_ols "***"
	else if `p_pre_ols' < 0.05   local stars_pre_ols "**"
	else if `p_pre_ols' < 0.10   local stars_pre_ols "*"

	di as result "    OLS post (late conn): " %9.4f `b_post_ols' " `stars_post_ols'"
	di as result "    OLS pre  (late conn): " %9.4f `b_pre_ols'  " `stars_pre_ols'"

	* Write OLS results
	tempname fh
	file open `fh' using "`tables_iv'/results_iv_spillover.csv", write append
	file write `fh' `"`outcome'_ols;main;"'    %9.4f (`b_post_ols') `"`stars_post_ols'"' _n
	file write `fh' `"`outcome'_ols;main_se;"' %9.4f (`se_post_ols') _n
	file write `fh' `"`outcome'_ols;pre;"'     %9.4f (`b_pre_ols')  `"`stars_pre_ols'"' _n
	file write `fh' `"`outcome'_ols;pre_se;"'  %9.4f (`se_pre_ols') _n
	file write `fh' `"`outcome'_ols;n_obs;"'   %12.0f (`n_obs_ols') _n
	file write `fh' `"`outcome'_ols;n_estab;"' %12.0f (`n_estab_ols') _n
	file close `fh'

	* ===================
	* IV: late connectivity instrumented by early connectivity
	* ===================

	di as text "    IV (late instrumented by early)..."

	* Post-treatment IV
	ivreghdfe `outcome' (conn_late_X_treat = conn_early_X_treat) if `s_spill', ///
		absorb(`absorb') cluster(identificad)

	local b_post_iv  = _b[conn_late_X_treat]
	local se_post_iv = _se[conn_late_X_treat]
	local p_post_iv  = 2*ttail(e(df_r), abs(`b_post_iv'/`se_post_iv'))
	local n_obs_iv   = e(N)
	local n_estab_iv = e(N_clust)

	* Pre-treatment IV (placebo)
	ivreghdfe `outcome' (conn_late_X_plac = conn_early_X_plac) ///
		if `s_spill' & year <= 2011, ///
		absorb(`absorb') cluster(identificad)

	local b_pre_iv  = _b[conn_late_X_plac]
	local se_pre_iv = _se[conn_late_X_plac]
	local p_pre_iv  = 2*ttail(e(df_r), abs(`b_pre_iv'/`se_pre_iv'))

	* Stars for IV
	local stars_post_iv ""
	if `p_post_iv' < 0.01       local stars_post_iv "***"
	else if `p_post_iv' < 0.05  local stars_post_iv "**"
	else if `p_post_iv' < 0.10  local stars_post_iv "*"

	local stars_pre_iv ""
	if `p_pre_iv' < 0.01        local stars_pre_iv "***"
	else if `p_pre_iv' < 0.05   local stars_pre_iv "**"
	else if `p_pre_iv' < 0.10   local stars_pre_iv "*"

	di as result "    IV  post (late=f(early)): " %9.4f `b_post_iv' " `stars_post_iv'"
	di as result "    IV  pre  (placebo):       " %9.4f `b_pre_iv'  " `stars_pre_iv'"

	* Write IV results
	tempname fh
	file open `fh' using "`tables_iv'/results_iv_spillover.csv", write append
	file write `fh' `"`outcome'_iv;main;"'    %9.4f (`b_post_iv') `"`stars_post_iv'"' _n
	file write `fh' `"`outcome'_iv;main_se;"' %9.4f (`se_post_iv') _n
	file write `fh' `"`outcome'_iv;pre;"'     %9.4f (`b_pre_iv')  `"`stars_pre_iv'"' _n
	file write `fh' `"`outcome'_iv;pre_se;"'  %9.4f (`se_pre_iv') _n
	file write `fh' `"`outcome'_iv;n_obs;"'   %12.0f (`n_obs_iv') _n
	file write `fh' `"`outcome'_iv;n_estab;"' %12.0f (`n_estab_iv') _n
	file close `fh'
}

********************************************************************************
* SECTION 7: COMPLETION
********************************************************************************

di _newline(2)
di as result "======================================================================="
di as result "ALL REGRESSIONS COMPLETE"
di as result "======================================================================="
di as result "Outputs:"
di as result "  `tables_iv'/results_iv_spillover.csv"
di as result "  `tables_iv'/results_iv_firststage.csv"

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

* ── Auto-generate LaTeX tables ──────────────────────────────────────────────
shell ~/.conda/envs/venv_python312/bin/python ///
	"$programs/iv_late_conn_early_conn/generate_iv_late_conn_early_conn_latex.py"
di as result "LaTeX tables written to Tables/iv_late_conn_early_conn/"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "iv_late_conn_early_conn complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
