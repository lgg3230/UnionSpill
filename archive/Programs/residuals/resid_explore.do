********************************************************************************
* UNION SPILLOVERS — RESIDUALIZATION EXPLORATION
* Purpose: Compare the main spillover-wage result across four residualization
*          specifications. Col 1 = raw (no residualization). Cols 2-4 use
*          progressively richer Mincer cell definitions.
*
*   Col 1 (raw):    lr_remdezr_w       — no residualization
*   Col 2 (base):   lr_remdezr_resid   — race × educ × gender × year + age1-4
*   Col 3 (ocup):   lr_remdezr_resid   — base × 4-dig ocup2002 + age1-4
*   Col 4 (tenure): lr_remdezr_resid   — base × tenure_bin + age1-4
*
* Output: 12 CSVs in Tables/residuals/:
*   resid_explore_panelA_col{raw|base|ocup|tenure}.csv
*   resid_explore_panelB_col{raw|base|ocup|tenure}.csv
*   resid_explore_panelspill_col{raw|base|ocup|tenure}.csv
* Auto-runs: Programs/residuals/resid_explore_table.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/residuals/resid_explore_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows (per-worker, 2007-2011) ─────────────────────────────────

di as result "Merging totalflows data..."

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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

di as result "Totalflows merged."

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION (non-residual-dependent)
********************************************************************************

di as result "Creating variables..."

* ── Treatment indicators ─────────────────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── Connectivity scaling ─────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th pctile of total flows to treated (spillover sample, 2009)"
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── Pre-treatment means for base outcomes ────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

foreach outcome in lr_remdezr_w l_firm_emp {
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

* ── Pre-treatment 4-bin controls ─────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
quietly {
	egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
	drop lr_remdezr_w_pre4_o
}

* Totalflows per-worker pre 07-11 bins (zero-fill → reference category)
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── Union and geo controls ───────────────────────────────────────────────────

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

di as result "All base variables created."

********************************************************************************
* SECTION 3: SPEC MACROS
********************************************************************************

local spec     "resid_explore"
local conn     "totaltreat_pw_norm"
local base_fe  "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* Sample macros
local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

local s_direct_A_pre "treat_ultra==0 & totaltreat_pw_n==0 & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B_pre "treat_ultra==0 & lagos_sample_avg==1 & in_balanced_panel==1"

********************************************************************************
* SECTION 4: COLUMN LOOP
********************************************************************************

forval col = 1/6 {

	* ── Set column-specific locals ───────────────────────────────────────────

	if `col' == 1 {
		local col_label "raw"
		local col_csv   ""
		local outcome   "lr_remdezr_w"
	}
	else if `col' == 2 {
		local col_label "base"
		local col_csv   "mincer_residuals_firm_year_python.csv"
		local outcome   "lr_remdezr_resid"
	}
	else if `col' == 3 {
		local col_label "ocup2"
		local col_csv   "mincer_residuals_firm_year_ocup2.csv"
		local outcome   "lr_remdezr_resid"
	}
	else if `col' == 4 {
		local col_label "ocup"
		local col_csv   "mincer_residuals_firm_year_ocup.csv"
		local outcome   "lr_remdezr_resid"
	}
	else if `col' == 5 {
		local col_label "tenure"
		local col_csv   "mincer_residuals_firm_year_tenure.csv"
		local outcome   "lr_remdezr_resid"
	}
	else if `col' == 6 {
		local col_label "tenpoly"
		local col_csv   "mincer_residuals_firm_year_tenpoly.csv"
		local outcome   "lr_remdezr_resid"
	}

	di _newline(2)
	di as result "======================================================================="
	di as result "COLUMN `col': label=`col_label'  outcome=`outcome'"
	di as result "======================================================================="

	* ── Import residuals to tempfile (before preserve) ───────────────────────

	if "`col_csv'" != "" {
		preserve
			import delimited "$rais_firm/`col_csv'", clear
			tostring identificad, replace format(%014.0f) force
			keep identificad year lr_remdezr_resid
			tempfile resid_col`col'
			save `resid_col`col''
		restore
	}

	* ── Begin column-specific preserve ───────────────────────────────────────

	preserve

	* ── Merge residuals and create pre-treatment variables ───────────────────

	if "`col_csv'" != "" {
		merge 1:1 identificad year using `resid_col`col'', keep(master match) nogen
		label var lr_remdezr_resid "Mincer-residualized log December wage"

		* Pre-treatment mean of residualized outcome
		cap drop lr_remdezr_resid_pre_o
		cap drop lr_remdezr_resid_pre
		quietly {
			bys identificad: egen lr_remdezr_resid_pre_o = mean(lr_remdezr_resid) ///
				if inrange(year, 2009, 2011)
			bys identificad: egen lr_remdezr_resid_pre = min(lr_remdezr_resid_pre_o)
			drop lr_remdezr_resid_pre_o
		}

		* Quartile bins (zero-fill → reference category 0)
		cap drop lr_remdezr_resid_pre4_o
		cap drop lr_remdezr_resid_pre4
		quietly {
			egen lr_remdezr_resid_pre4_o = cut(lr_remdezr_resid_pre) ///
				if year == 2009 & in_balanced_panel == 1, group(4)
			bys identificad: egen lr_remdezr_resid_pre4 = min(lr_remdezr_resid_pre4_o)
			drop lr_remdezr_resid_pre4_o
			replace lr_remdezr_resid_pre4 = 0 if missing(lr_remdezr_resid_pre4)
		}
	}

	* ── Absorb macro (depends on outcome name for the pre4 bins) ─────────────

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ── Initialize output CSVs ───────────────────────────────────────────────

	local csv_A    "$tables/residuals/resid_explore_panelA_col`col_label'.csv"
	local csv_B    "$tables/residuals/resid_explore_panelB_col`col_label'.csv"
	local csv_spill "$tables/residuals/resid_explore_panelspill_col`col_label'.csv"

	foreach panel in A B spill {
		capture erase "`csv_`panel''"
		tempname fh
		file open `fh' using "`csv_`panel''", write replace
		file write `fh' "spec,section,outcome,row_type,value" _n
		file close `fh'
	}

	* ─────────────────────────────────────────────────────────────────────────
	* PANELS A AND B: DIRECT EFFECTS
	* ─────────────────────────────────────────────────────────────────────────

	foreach panel in A B {

		if "`panel'" == "A" {
			local s_use     "`s_direct_A'"
			local s_use_pre "`s_direct_A_pre'"
			local section   "direct_A"
			local csv_out   "`csv_A'"
		}
		if "`panel'" == "B" {
			local s_use     "`s_direct_B'"
			local s_use_pre "`s_direct_B_pre'"
			local section   "direct_B"
			local csv_out   "`csv_B'"
		}

		di _newline(1)
		di as text "--- Col `col' Panel `panel': `outcome' ---"

		* Post-treatment DiD
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

		* Stars
		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                            local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

		* Event study for pre-trend F-test
		reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
			absorb(`absorb') vce(cluster identificad)
		testparm 1.treat_ultra#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* Baseline mean (untreated control group, 2009)
	* POOLED over the estimation sample (treated + control), per the table
	* note "average across establishments in each panel's estimation sample".
	* Was `s_use_pre' (control group only), which contradicted that note.
		quietly sum `outcome' if `s_use' & year == 2009
		local mean_pre_val = r(mean)

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
		file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file close `fh'
	}

	* ─────────────────────────────────────────────────────────────────────────
	* SPILLOVER EFFECTS
	* ─────────────────────────────────────────────────────────────────────────

	di _newline(1)
	di as text "--- Col `col' Spillover: `outcome' ---"

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

	* Stars
	local stars_post ""
	if `p_post' < 0.01                           local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                            local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

	* Event study for pre-trend F-test
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Baseline mean (spillover sample, 2009)
	quietly sum `outcome' if `s_spill' & year == 2009
	local mean_pre_val = r(mean)

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
	file write `fh' `""`spec'";"spill";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
	file close `fh'

	restore

	di as result "Column `col' (`col_label') complete."
}

********************************************************************************
* SECTION 5: COMPLETION + AUTO-RUN PYTHON
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell ~/.conda/envs/venv_python312/bin/python "$programs/residuals/resid_explore_table.py"
di as result "LaTeX table written to Tables/residuals/resid_explore_table.tex"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "resid_explore done" "Residualization exploration table complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
