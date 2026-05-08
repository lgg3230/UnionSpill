********************************************************************************
* cba_similarity_sample_check.do
*
* Tests whether the union x period FE result in cba_similarity_avg is driven
* by sample selection from the bilateral exercise.
*
* Strategy: for each outcome, run the bilateral (base-spec) regression first
* to tag e(sample) -- firms with positive bilateral connectivity not dropped
* as singletons. Then run the average-treated similarity regression on that
* restricted sample with and without union x period FE.
*
* Interpretation:
*   - If avg base is significant but avg+union is not → union FE is doing real
*     work even on the bilateral sample (NOT a sample-selection story)
*   - If avg base is already insignificant on the bilateral sample → sample
*     selection is partly driving the full-sample avg result
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/cba_similarity_sample_check_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD DATA + TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

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

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
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

********************************************************************************
* SECTION 3: MERGE BOTH SIMILARITY PANELS
********************************************************************************

* Bilateral (flow-weighted) → rename to avoid collision with avg vars
merge m:1 identificad cba_period using "$rais_aux/cba_similarity_panel.dta", ///
	keep(master match) gen(m_bilat)
drop m_bilat
foreach v in cosine bray_curtis total_variation ruzicka {
	rename `v' `v'_b
}

* Average-treated → keep original names
merge m:1 identificad cba_period using "$rais_aux/cba_similarity_avg_panel.dta", ///
	keep(master match) gen(m_avg)
drop m_avg

********************************************************************************
* SECTION 4: PRE-TREATMENT BINS FOR BOTH SIMILARITY SETS
********************************************************************************

foreach v in cosine_b bray_curtis_b total_variation_b ruzicka_b ///
             cosine bray_curtis total_variation ruzicka {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
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

********************************************************************************
* SECTION 5: SPEC MACROS
********************************************************************************

local conn             "totaltreat_pw_norm"
local base_fe_cba      "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local base_fe_cba_union "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period i.mode_union#i.cba_period"
local extra_cba        "ib0.totalflows_pw_pre_07_114#i.cba_period"

* Paired lists: bilateral outcome → avg outcome
local bilat_list "cosine_b bray_curtis_b total_variation_b ruzicka_b"
local avg_list   "cosine   bray_curtis   total_variation   ruzicka"

********************************************************************************
* SECTION 6: INITIALIZE OUTPUT CSV
********************************************************************************

local csv "$tables/cba_similarity/results_sample_check_cba_similarity.csv"
capture erase "`csv'"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 7: MAIN LOOP
* For each outcome:
*   1. Run bilateral (base FE) to tag estimation sample
*   2. Run avg base FE on that sample
*   3. Run avg + union FE on that sample
* This tests whether union FE still kills the avg effect on the bilateral sample.
********************************************************************************

di _newline(2)
di as result "====================================================================="
di as result "SAMPLE CHECK: AVG SIMILARITY ON BILATERAL SAMPLE"
di as result "====================================================================="

local n_outcomes = wordcount("`bilat_list'")
forvalues i = 1/`n_outcomes' {
	local bilat_o = word("`bilat_list'", `i')
	local avg_o   = word("`avg_list'",   `i')

	di _newline as result "--- Outcome: `avg_o' ---"

	* ---- Step 1: Bilateral base regression → tag sample ----
	local absorb_bilat "`base_fe_cba' ib0.`bilat_o'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	cap drop bilat_sample
	reghdfe `bilat_o' c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period) & !missing(`bilat_o'), ///
		absorb(`absorb_bilat') vce(cluster identificad)
	gen byte bilat_sample = e(sample)

	local n_bilat = e(N)
	di as text "  Bilateral sample size: `n_bilat'"

	* ---- Step 2: Avg, base FE, bilateral sample ----
	local absorb_avg_base "`base_fe_cba' ib0.`avg_o'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	reghdfe `avg_o' c.`conn'##post_treat_cba ///
		if bilat_sample == 1 & !missing(`avg_o'), ///
		absorb(`absorb_avg_base') vce(cluster identificad)

	local b_base    = _b[1.post_treat_cba#c.`conn']
	local se_base   = _se[1.post_treat_cba#c.`conn']
	local p_base    = 2*ttail(e(df_r), abs(`b_base'/`se_base'))
	local n_base    = e(N)
	local nest_base = e(N_clust)

	qui sum `avg_o' if e(sample) & cba_period == 2
	local base_mean_b = cond(r(N) > 0, r(mean), .)

	reghdfe `avg_o' c.`conn'##pre_treat_cba ///
		if bilat_sample == 1 & !missing(`avg_o') & cba_period <= 2, ///
		absorb(`absorb_avg_base') vce(cluster identificad)

	local b_base_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_base_pre = _se[1.pre_treat_cba#c.`conn']

	local stars_base ""
	if `p_base' < 0.01                           local stars_base "***"
	else if (`p_base' < 0.05 & `p_base' > 0.01) local stars_base "**"
	else if (`p_base' < 0.10 & `p_base' > 0.05) local stars_base "*"

	di as text "  Avg base on bilat sample: b = " %6.4f (`b_base') " `stars_base'"

	* ---- Step 3: Avg, union FE, bilateral sample ----
	local absorb_avg_union "`base_fe_cba_union' ib0.`avg_o'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	reghdfe `avg_o' c.`conn'##post_treat_cba ///
		if bilat_sample == 1 & !missing(`avg_o'), ///
		absorb(`absorb_avg_union') vce(cluster identificad)

	local b_union    = _b[1.post_treat_cba#c.`conn']
	local se_union   = _se[1.post_treat_cba#c.`conn']
	local p_union    = 2*ttail(e(df_r), abs(`b_union'/`se_union'))
	local n_union    = e(N)
	local nest_union = e(N_clust)

	qui sum `avg_o' if e(sample) & cba_period == 2
	local base_mean_u = cond(r(N) > 0, r(mean), .)

	reghdfe `avg_o' c.`conn'##pre_treat_cba ///
		if bilat_sample == 1 & !missing(`avg_o') & cba_period <= 2, ///
		absorb(`absorb_avg_union') vce(cluster identificad)

	local b_union_pre  = _b[1.pre_treat_cba#c.`conn']
	local se_union_pre = _se[1.pre_treat_cba#c.`conn']

	local stars_union ""
	if `p_union' < 0.01                           local stars_union "***"
	else if (`p_union' < 0.05 & `p_union' > 0.01) local stars_union "**"
	else if (`p_union' < 0.10 & `p_union' > 0.05) local stars_union "*"

	di as text "  Avg union on bilat sample: b = " %6.4f (`b_union') " `stars_union'"

	* ---- Write to CSV ----
	tempname fh
	file open `fh' using "`csv'", write append
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"main";"'     %9.4f (`b_base')    `"`stars_base'"'  _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"main_se";"'  %9.4f (`se_base')   _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"pre";"'      %9.4f (`b_base_pre') _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"pre_se";"'   %9.4f (`se_base_pre') _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"baseline_mean";"' %9.4f (`base_mean_b') _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"n_obs";"'    %12.0fc (`n_base')   _n
	file write `fh' `""avg_bilat_sample";"spill";"`avg_o'";"n_estab";"'  %12.0fc (`nest_base') _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"main";"'     %9.4f (`b_union')    `"`stars_union'"'  _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"main_se";"'  %9.4f (`se_union')   _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"pre";"'      %9.4f (`b_union_pre') _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"pre_se";"'   %9.4f (`se_union_pre') _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"baseline_mean";"' %9.4f (`base_mean_u') _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"n_obs";"'    %12.0fc (`n_union')   _n
	file write `fh' `""avg_bilat_sample_union";"spill";"`avg_o'";"n_estab";"'  %12.0fc (`nest_union') _n
	file close `fh'
}

di as result _newline "Sample check complete."

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_sample_check_latex.py"
di as result "LaTeX table written."

shell source "$programs/notify.sh" && notify "sample_check done" "CBA similarity sample check complete"

********************************************************************************
* END
********************************************************************************
