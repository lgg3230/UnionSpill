********************************************************************************
* ROBUSTNESS: DEMOGRAPHIC CONTROLS — DIRECT EFFECTS PANEL A (lr_remdezr_w)
* Purpose: Test direct-effect estimates against pre-treatment workforce
*          composition. Mirrors demo_controls + demo_linear but for the
*          Panel A direct sample (zero-connectivity controls).
*          Three specifications:
*            (1) Baseline
*            (2) All demographics: quartile bins × year (absorbed)
*            (3) All demographics: linear × year (covariates)
* Output:   Tables/robustness/results_direct_demo_bins.csv
*           Tables/robustness/results_direct_demo_linear.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_demo_direct_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: DATA
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows (per-worker, 2007-2011) ─────────────────────────────────

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* ── Merge average worker age ─────────────────────────────────────────────────

preserve
	import delimited "$rais_firm/avg_age_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile avg_age_data
	save `avg_age_data'
restore

merge m:1 identificad year using `avg_age_data', keep(master match) nogen
label var avg_age "Average worker age at the firm (Dec employment)"

* ── Average per-worker pairwise flows 2007-2011 ──────────────────────────────

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

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── Sample restriction (Panel A: zero-connectivity controls + treated) ────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

* ── Pre-treatment means: base variables ──────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
quietly {
	bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_w_pre = min(lr_remdezr_w_pre_o)
	drop lr_remdezr_w_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── Baseline 4-bin controls ──────────────────────────────────────────────────

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

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── Compose prop_hs_plus ─────────────────────────────────────────────────────

cap drop prop_hs_plus
gen double prop_hs_plus = prop_hs + prop_sup
label var prop_hs_plus "Share with at least high school diploma"

* ── Pre-treatment means for demographics ─────────────────────────────────────

foreach v in male_prop white_prop prop_hs_plus avg_age avg_tenure {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* ── Demographic quartile bins (for spec 2) ───────────────────────────────────

foreach v in male_prop white_prop prop_hs_plus avg_age avg_tenure {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}
}

di as result "All variables created."

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSVs
********************************************************************************

local outcome "lr_remdezr_w"

capture erase "$tables/robustness/results_direct_demo_bins.csv"
tempname fh
file open `fh' using "$tables/robustness/results_direct_demo_bins.csv", write replace
file write `fh' "outcome;col;row_type;value" _n
file close `fh'

capture erase "$tables/robustness/results_direct_demo_linear.csv"
tempname fh
file open `fh' using "$tables/robustness/results_direct_demo_linear.csv", write replace
file write `fh' "outcome;col;row_type;value" _n
file close `fh'

local csv_bins   "$tables/robustness/results_direct_demo_bins.csv"
local csv_linear "$tables/robustness/results_direct_demo_linear.csv"

********************************************************************************
* SECTION 4: SPEC MACROS
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_base "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

local demo_bins_absorb ///
	"ib0.male_prop_pre4#i.year ib0.white_prop_pre4#i.year ib0.prop_hs_plus_pre4#i.year ib0.avg_age_pre4#i.year ib0.avg_tenure_pre4#i.year"

local demo_linear_covars ///
	"c.male_prop_pre#i.year c.white_prop_pre#i.year c.prop_hs_plus_pre#i.year c.avg_age_pre#i.year c.avg_tenure_pre#i.year"

********************************************************************************
* SECTION 5: REGRESSIONS
********************************************************************************

* ────────────────────────────────────────────────────────────────────────────
* SPEC: BINS (csv_bins)
* Col 1 = baseline, Col 2 = all demo bins absorbed
* ────────────────────────────────────────────────────────────────────────────

foreach col in 1 2 {

	if `col' == 1 local absorb_use "`absorb_base'"
	if `col' == 2 local absorb_use "`absorb_base' `demo_bins_absorb'"

	di as result "Bins — Col `col'"

	reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A', ///
		absorb(`absorb_use') vce(cluster identificad)

	local b_post  = _b[1.treat_ultra#1.treat_year]
	local se_post = _se[1.treat_ultra#1.treat_year]
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_A' & year <= 2011, ///
		absorb(`absorb_use') vce(cluster identificad)

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

	tempname fh
	file open `fh' using "`csv_bins'", write append
	file write `fh' `""`outcome'";`col';"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`outcome'";`col';"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`outcome'";`col';"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`outcome'";`col';"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`outcome'";`col';"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`outcome'";`col';"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file close `fh'
}

* ────────────────────────────────────────────────────────────────────────────
* SPEC: LINEAR (csv_linear)
* Col 1 = baseline (same as above), Col 2 = all demo linear covariates
* ────────────────────────────────────────────────────────────────────────────

foreach col in 1 2 {

	if `col' == 1 local covars_use ""
	if `col' == 2 local covars_use "`demo_linear_covars'"

	di as result "Linear — Col `col'"

	reghdfe `outcome' treat_ultra##i.treat_year `covars_use' if `s_direct_A', ///
		absorb(`absorb_base') vce(cluster identificad)

	local b_post  = _b[1.treat_ultra#1.treat_year]
	local se_post = _se[1.treat_ultra#1.treat_year]
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	reghdfe `outcome' treat_ultra##i.placebo_year `covars_use' if `s_direct_A' & year <= 2011, ///
		absorb(`absorb_base') vce(cluster identificad)

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

	tempname fh
	file open `fh' using "`csv_linear'", write append
	file write `fh' `""`outcome'";`col';"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`outcome'";`col';"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`outcome'";`col';"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`outcome'";`col';"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`outcome'";`col';"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`outcome'";`col';"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file close `fh'
}

********************************************************************************
* SECTION 6: COMPLETION + NOTIFICATION
********************************************************************************

di _newline(1)
di as result "All direct-effect demographic regressions complete."
di as result "Finished: `c(current_date)' `c(current_time)'"

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/robustness/generate_demo_direct_latex.py"
di as result "LaTeX table written to Tables/robustness/demo_direct_table.tex"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "Main_Results_demo_direct.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
