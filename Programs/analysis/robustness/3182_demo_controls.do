********************************************************************************
* ROBUSTNESS: WORKFORCE-COMPOSITION CONTROLS (direct Panel A + spillover)
* Purpose: Re-estimate the main direct and spillover effects adding pre-treatment
*          workforce composition (gender, race, education, age, tenure) x year.
*          Source of column (4) "Workforce Characteristics" of tab:rob_logwages.
*          Ported 2026-10-09 from the archived, monthly-only
*            archive/Programs/robustness/Main_Results_demo_direct.do
*            archive/Programs/robustness/Main_Results_demo_controls.do
*          with the outcome parameterized ($OUTVAR / $OUTSUF, as in
*          3072_union_controls.do) so the hourly column is reproducible.
*          Data preparation and base FE are identical to 3072_union_controls.do:
*            absorb = base_fe + outcome_pre4×year + l_firm_emp_pre4×year
*                     + totalflows_pw_pre_07_114×year
*          Three specifications per panel:
*            (1) Baseline
*            (2) All demographics: quartile bins × year (absorbed)
*            (3) All demographics: linear × year (covariates)
*          The paper's column (4) is spec (2). Verified 2026-10-09 against
*          Draft.tex (hourly): direct 0.0284 (0.0050), spillover 0.0066 (0.0023).
* Output:   $tables/robustness/results_demo_controls$OUTSUF.csv
*           (columns: section;outcome;col;row_type;value, section = direct_A | spill)
********************************************************************************

if "$OUTVAR" == "" global OUTVAR "lr_remdezr_w"
if "$OUTSUF" == "" global OUTSUF ""

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/robustness"
cap mkdir "$tables/robustness"
log using "$logs/robustness/Main_Results_demo_controls${OUTSUF}_`d'_`t'.log", replace text

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

* ── Samples ──────────────────────────────────────────────────────────────────

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── Connectivity scaled to 90th pctile ───────────────────────────────────────

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

local conn "totaltreat_pw_norm"

* ── Pre-treatment means: base variables ──────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop ${OUTVAR}_pre_o
cap drop ${OUTVAR}_pre
quietly {
	bys identificad: egen ${OUTVAR}_pre_o = mean($OUTVAR) if inrange(year, 2009, 2011)
	bys identificad: egen ${OUTVAR}_pre = min(${OUTVAR}_pre_o)
	drop ${OUTVAR}_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── Baseline 4-bin controls (same as 3012_pct_tfpw.do) ───────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop ${OUTVAR}_pre4_o
cap drop ${OUTVAR}_pre4
quietly {
	egen ${OUTVAR}_pre4_o = cut(${OUTVAR}_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen ${OUTVAR}_pre4 = min(${OUTVAR}_pre4_o)
	drop ${OUTVAR}_pre4_o
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

* ── Pre-treatment means + 4-bin controls for demographics ────────────────────

foreach v in male_prop white_prop prop_hs_plus avg_age avg_tenure {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre = min(`v'_pre_o)
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

di as result "All variables created."

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV
********************************************************************************

local outcome "$OUTVAR"
local csv     "$tables/robustness/results_demo_controls$OUTSUF.csv"

capture erase "`csv'"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "section;outcome;col;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 4: REGRESSIONS
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_base "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

local demo_bins_absorb ///
	"ib0.male_prop_pre4#i.year ib0.white_prop_pre4#i.year ib0.prop_hs_plus_pre4#i.year ib0.avg_age_pre4#i.year ib0.avg_tenure_pre4#i.year"

local demo_linear_covars ///
	"c.male_prop_pre#i.year c.white_prop_pre#i.year c.prop_hs_plus_pre#i.year c.avg_age_pre#i.year c.avg_tenure_pre#i.year"

* Each section x column: post regression, then the 2009-2010 vs 2011 placebo
* on the same specification. Col 1 baseline, 2 demographic bins, 3 linear.
foreach section in direct_A spill {

	if "`section'" == "direct_A" {
		local s_use    "`s_direct_A'"
		local rhs_post "treat_ultra##i.treat_year"
		local rhs_pre  "treat_ultra##i.placebo_year"
		local k_post   "1.treat_ultra#1.treat_year"
		local k_pre    "1.treat_ultra#1.placebo_year"
	}
	else {
		local s_use    "`s_spill'"
		local rhs_post "c.`conn'##i.treat_year"
		local rhs_pre  "c.`conn'##i.placebo_year"
		local k_post   "1.treat_year#c.`conn'"
		local k_pre    "1.placebo_year#c.`conn'"
	}

	foreach col in 1 2 3 {

		local absorb_use "`absorb_base'"
		local covars_use ""
		if `col' == 2 local absorb_use "`absorb_base' `demo_bins_absorb'"
		if `col' == 3 local covars_use "`demo_linear_covars'"

		di as result "`section' — Col `col'"

		reghdfe `outcome' `rhs_post' `covars_use' if `s_use', ///
			absorb(`absorb_use') vce(cluster identificad)

		local b_post  = _b[`k_post']
		local se_post = _se[`k_post']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean on this column's estimation sample, taken before
		* the placebo regression below replaces e(sample).
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_pre_val = r(mean)

		reghdfe `outcome' `rhs_pre' `covars_use' if `s_use' & year <= 2011, ///
			absorb(`absorb_use') vce(cluster identificad)

		local b_pre  = _b[`k_pre']
		local se_pre = _se[`k_pre']
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
		file open `fh' using "`csv'", write append
		file write `fh' `""`section'";"`outcome'";`col';"main";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`section'";"`outcome'";`col';"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`section'";"`outcome'";`col';"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
		file write `fh' `""`section'";"`outcome'";`col';"pre_se";"' %9.4f (`se_pre') `"""' _n
		file write `fh' `""`section'";"`outcome'";`col';"n_obs";"' %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`section'";"`outcome'";`col';"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`section'";"`outcome'";`col';"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
		file close `fh'
	}
}

********************************************************************************
* SECTION 5: COMPLETION + NOTIFICATION
********************************************************************************

di _newline(1)
di as result "All workforce-composition regressions complete."
di as result "Finished: `c(current_date)' `c(current_time)'"

log close

if c(os) == "Unix" shell source "$root/Programs/notify.sh" && notify "Stata done" "3182_demo_controls.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
