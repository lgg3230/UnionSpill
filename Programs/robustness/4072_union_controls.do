********************************************************************************
* ROBUSTNESS: UNION CONTROLS (outcome: lr_remdezr_w)
* Purpose: Test spillover estimates against union-level confounders.
*          FE spec identical to 4012_pct_tfpw.do:
*            absorb = base_fe + outcome_pre4×year + l_firm_emp_pre4×year
*                     + totalflows_pw_pre_07_114×year
*          Ten specifications:
*            (1) Baseline
*            (2) Union × Year FE  (added to absorb)
*            (3) Union Exposure (firm share)  × Year (added as covariate)
*            (4) Union Exposure (worker share) × Year (added as covariate)
*            (5) Union Exposure (firm share),   quartile bins
*            (6) Union Exposure (worker share), quartile bins
*            (7) Union Exposure (firm share),   decile bins
*            (8) Union Exposure (worker share), decile bins
*            (9) Union Exposure (firm share),   vingtile bins
*           (10) Union Exposure (worker share), vingtile bins
*          Columns 7-10 reconstructed 2026-08-01; see the note above them.
* Output:   $tables/robustness/results_spill_union_controls.csv
********************************************************************************

* Outcome and CSV suffix are parameterized (2026-08-01) so the hourly variant is
* reproducible from a committed wrapper. Previously the outcome was hardcoded to
* lr_remdezr_w and the _hw CSV in the currentconn tree had no script that could
* produce it. Defaults preserve the original monthly behaviour. Set here, before
* SECTION 2 builds the ${OUTVAR}_pre and ${OUTVAR}_pre4 bin controls.
if "$OUTVAR" == "" global OUTVAR "lr_remdezr_w"
if "$OUTSUF" == "" global OUTSUF ""

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_union_controls${OUTSUF}_`d'_`t'.log", replace text

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

* Connectivity scaled to 90th pctile
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

local conn "totaltreat_pw_norm"

* Pre-treatment means
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

* Bin controls (4 bins each, same as 4012_pct_tfpw.do)
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

* Union-exposure quartile bins (firm distribution at 2009, balanced panel)
* treat_union_exp_all = exposure to treated firms (union firm share)
* union_emp_exp       = exposure to treated employees (union worker share)
* Both are union-level (time-invariant), so binned exactly like the pre-treat
* controls above: cut into 4 quartiles at 2009, then min over firm.
cap drop treat_union_exp_all_q4_o
cap drop treat_union_exp_all_q4
quietly {
	egen treat_union_exp_all_q4_o = cut(treat_union_exp_all) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen treat_union_exp_all_q4 = min(treat_union_exp_all_q4_o)
	drop treat_union_exp_all_q4_o
}
label var treat_union_exp_all_q4 "Quartile of union exposure to treated firms"

cap drop union_emp_exp_q4_o
cap drop union_emp_exp_q4
quietly {
	egen union_emp_exp_q4_o = cut(union_emp_exp) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen union_emp_exp_q4 = min(union_emp_exp_q4_o)
	drop union_emp_exp_q4_o
}
label var union_emp_exp_q4 "Quartile of union exposure to treated employees"

* Decile and vingtile bins for columns 7-10. RECONSTRUCTED 2026-08-01: these
* columns appear in the published table and in the currentconn CSV, but the
* code that produced them was never committed (the last commit to this file,
* a2c5b74, added only the quartile columns 5-6). Built here "in the same manner
* as the quartile controls", per the table note: cut on the 2009 balanced-panel
* firm distribution, then min over firm so the bin is time-invariant.
foreach g in 10 20 {
	cap drop treat_union_exp_all_q`g'_o
	cap drop treat_union_exp_all_q`g'
	quietly {
		egen treat_union_exp_all_q`g'_o = cut(treat_union_exp_all) ///
			if year == 2009 & in_balanced_panel == 1, group(`g')
		bys identificad: egen treat_union_exp_all_q`g' = min(treat_union_exp_all_q`g'_o)
		drop treat_union_exp_all_q`g'_o
	}

	cap drop union_emp_exp_q`g'_o
	cap drop union_emp_exp_q`g'
	quietly {
		egen union_emp_exp_q`g'_o = cut(union_emp_exp) ///
			if year == 2009 & in_balanced_panel == 1, group(`g')
		bys identificad: egen union_emp_exp_q`g' = min(union_emp_exp_q`g'_o)
		drop union_emp_exp_q`g'_o
	}
}
label var treat_union_exp_all_q10 "Decile of union exposure to treated firms"
label var union_emp_exp_q10       "Decile of union exposure to treated employees"
label var treat_union_exp_all_q20 "Vingtile of union exposure to treated firms"
label var union_emp_exp_q20       "Vingtile of union exposure to treated employees"

di as result "All variables created."

********************************************************************************
* SECTION 3: INITIALIZE OUTPUT CSV
********************************************************************************

local outcome "$OUTVAR"
local csv     "$tables/robustness/results_spill_union_controls$OUTSUF.csv"

capture erase "`csv'"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome;col;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 4: REGRESSIONS
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_base "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

* ── Col 1: Baseline ──────────────────────────────────────────────────────────

di as result "Col 1 (baseline)"

reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";1;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";1;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";1;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";1;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";1;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";1;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";1;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

* ── Col 2: Union × Year FE ───────────────────────────────────────────────────

di as result "Col 2 (union FE)"

reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_base' i.mode_union#i.year) vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base' i.mode_union#i.year) vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";2;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";2;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";2;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";2;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";2;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";2;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";2;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

* ── Col 3: Union Exposure (firm share) ───────────────────────────────────────

di as result "Col 3 (union exp firm)"

reghdfe `outcome' c.`conn'##i.treat_year c.treat_union_exp_all#i.year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year c.treat_union_exp_all#i.year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";3;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";3;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";3;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";3;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";3;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";3;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";3;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

* ── Col 4: Union Exposure (worker share) ─────────────────────────────────────

di as result "Col 4 (union emp exp)"

reghdfe `outcome' c.`conn'##i.treat_year c.union_emp_exp#i.treat_year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year c.union_emp_exp#i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";4;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";4;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";4;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";4;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";4;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";4;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";4;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

* ── Col 5: Union Exposure (firm share) — quartiles ───────────────────────────

di as result "Col 5 (union exp firm, quartiles)"

reghdfe `outcome' c.`conn'##i.treat_year i.treat_union_exp_all_q4#i.year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year i.treat_union_exp_all_q4#i.year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";5;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";5;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";5;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";5;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";5;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";5;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";5;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

* ── Col 6: Union Exposure (worker share) — quartiles ─────────────────────────

di as result "Col 6 (union emp exp, quartiles)"

reghdfe `outcome' c.`conn'##i.treat_year i.union_emp_exp_q4#i.treat_year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
* taken before the placebo regression below replaces e(sample).
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)

reghdfe `outcome' c.`conn'##i.placebo_year i.union_emp_exp_q4#i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

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

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""`outcome'";6;"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`outcome'";6;"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`outcome'";6;"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""`outcome'";6;"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""`outcome'";6;"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""`outcome'";6;"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`outcome'";6;"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
file close `fh'

********************************************************************************
* Cols 7-10: deciles and vingtiles of the same two exposure measures
*
* RECONSTRUCTED 2026-08-01 -- see the bin-construction note above. Each column
* mirrors its quartile counterpart exactly: the firm-share columns follow col 5
* and interact the bins with full year fixed effects; the worker-share columns
* follow col 6 and interact with treat_year (placebo_year in the placebo
* regression). Only the number of bins differs.
*
* Whether these reproduce the published 0.0057 / 0.0048 / 0.0046 / 0.0046 is
* the test of the reconstruction, not an assumption of it.
********************************************************************************

* col : bin variable stem : granularity label : interaction style (year|treat)
foreach spec in "7 treat_union_exp_all_q10 deciles year" ///
                "8 union_emp_exp_q10 deciles treat" ///
                "9 treat_union_exp_all_q20 vingtiles year" ///
                "10 union_emp_exp_q20 vingtiles treat" {

	local col   : word 1 of `spec'
	local binvar: word 2 of `spec'
	local gran  : word 3 of `spec'
	local style : word 4 of `spec'

	di as result "Col `col' (`binvar', `gran')"

	if "`style'" == "year" {
		local ctrl_post "i.`binvar'#i.year"
		local ctrl_pre  "i.`binvar'#i.year"
	}
	else {
		local ctrl_post "i.`binvar'#i.treat_year"
		local ctrl_pre  "i.`binvar'#i.placebo_year"
	}

	reghdfe `outcome' c.`conn'##i.treat_year `ctrl_post' if `s_spill', ///
		absorb(`absorb_base') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn']
	local se_post = _se[1.treat_year#c.`conn']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
	* taken before the placebo regression below replaces e(sample).
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre_val = r(mean)

	reghdfe `outcome' c.`conn'##i.placebo_year `ctrl_pre' if `s_spill' & year <= 2011, ///
		absorb(`absorb_base') vce(cluster identificad)

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

	tempname fh
	file open `fh' using "`csv'", write append
	file write `fh' `""`outcome'";`col';"main";"' %9.4f (`b_post') `"`stars_post'""' _n
	file write `fh' `""`outcome'";`col';"main_se";"' %9.4f (`se_post') `"""' _n
	file write `fh' `""`outcome'";`col';"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
	file write `fh' `""`outcome'";`col';"pre_se";"' %9.4f (`se_pre') `"""' _n
	file write `fh' `""`outcome'";`col';"n_obs";"' %12.0fc (`n_obs') `"""' _n
	file write `fh' `""`outcome'";`col';"n_estab";"' %12.0fc (`n_estab') `"""' _n
	file write `fh' `""`outcome'";`col';"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
	file close `fh'
}

********************************************************************************
* SECTION 5: COMPLETION + NOTIFICATION
********************************************************************************

di _newline(1)
di as result "All union controls regressions complete."
di as result "Finished: `c(current_date)' `c(current_time)'"

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/robustness/5180_table_union_controls_latex.py"
di as result "LaTeX table written to Tables/robustness/union_controls_table.tex"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "4072_union_controls.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
