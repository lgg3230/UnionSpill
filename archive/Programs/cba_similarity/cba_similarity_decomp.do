********************************************************************************
* cba_similarity_decomp.do
*
* Ordered decomposition of the CBA similarity headline (weighted reference).
*
* For each measure S in {cosine, bray_curtis, total_variation, ruzicka} the
* underlying data give us three scores per (focal i, period t):
*
*   curr_S  = S(u_{it}, T_{it})    headline
*   uref2_S = S(u_{it}, T_{i2})    focal moves, reference frozen at p2
*   u2ref_S = S(u_{i2}, T_{it})    focal frozen at p2, reference moves
*
* With firm FE the constant S(u_{i2}, T_{i2}) is absorbed; we therefore use:
*
*   delta_S = curr_S                          (= headline; baseline absorbed)
*   um_S    = uref2_S                         (UntreatedMove)
*   tm_S    = u2ref_S                         (TreatedMove)
*   ta_S    = curr_S - uref2_S                (TreatedAdditional)
*   ua_S    = curr_S - u2ref_S                (UntreatedAdditional)
*
* All five regressions share the same firm-period sample, so OLS linearity
* delivers, to machine precision,
*
*   beta(delta) = beta(um) + beta(ta) = beta(tm) + beta(ua).
*
* Prerequisites (must have been run already):
*   Programs/cba_similarity/cba_similarity.do                    (Ref A panel)
*   Programs/cba_similarity/cba_similarity_pretreat_ref_uncorr_w.do
*   Programs/cba_similarity/cba_similarity_focal_frozen.do
*
* Outputs:
*   Data/RAIS_aux/cba_similarity_decomp_panel.dta
*   Tables/cba_similarity/results_spill_cba_similarity_decomp.csv
*   Tables/cba_similarity/results_es_cba_similarity_decomp.csv
*   Tables/cba_similarity/cba_similarity_decomp_table.tex
*   Tables/cba_similarity/cba_similarity_decomp_full_table.tex
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/cba_similarity_decomp_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS (mirrors cba_similarity.do)
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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION (mirrors cba_similarity.do)
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
label var cba_period "CBA negotiation period"

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile"

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
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
* SECTION 3: BUILD THE 12-COLUMN DECOMP PANEL (Python merge of three upstreams)
********************************************************************************

di as result "Running Python decomp prep (merges three similarity panels)..."
shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/cba_similarity_decomp_prep.py"
di as result "Decomp prep complete."

********************************************************************************
* SECTION 4: MERGE DECOMP PANEL + DERIVE FIVE OUTCOMES PER MEASURE
********************************************************************************

di as result "Merging decomp panel..."

merge m:1 identificad cba_period using "$rais_aux/cba_similarity_decomp_panel.dta", ///
	keep(master match) gen(m_dec)
drop m_dec

local measures "cosine bray_curtis total_variation ruzicka"

* Drop any prior definitions to make the .do re-runnable
foreach m of local measures {
	cap drop delta_`m'
	cap drop um_`m'
	cap drop tm_`m'
	cap drop ta_`m'
	cap drop ua_`m'
}

foreach m of local measures {
	gen double delta_`m' = `m'_curr
	gen double um_`m'    = `m'_uref2
	gen double tm_`m'    = `m'_u2ref
	gen double ta_`m'    = `m'_curr - `m'_uref2
	gen double ua_`m'    = `m'_curr - `m'_u2ref
	label var delta_`m' "DeltaS, `m'"
	label var um_`m'    "UntreatedMove, `m'"
	label var tm_`m'    "TreatedMove, `m'"
	label var ta_`m'    "TreatedAdditional, `m'"
	label var ua_`m'    "UntreatedAdditional, `m'"
}

* Sample of decomp outcomes is the merged decomp panel
local sample_filter "`s_spill' & !missing(cba_period) & !missing(delta_cosine) & !missing(um_cosine) & !missing(tm_cosine)"

local sim_outcomes ""
foreach prefix in delta um tm ta ua {
	foreach m of local measures {
		local sim_outcomes "`sim_outcomes' `prefix'_`m'"
	}
}
di as text "Outcomes: `sim_outcomes'"

********************************************************************************
* SECTION 5: ALGEBRAIC IDENTITY CHECKS (must hold at machine precision)
********************************************************************************

di _newline
di as result "Algebraic identity check (DeltaS = UM + TA = TM + UA):"
foreach m of local measures {
	cap drop ident1_`m'
	cap drop ident2_`m'
	gen double ident1_`m' = abs(delta_`m' - um_`m' - ta_`m') if !missing(delta_`m')
	gen double ident2_`m' = abs(delta_`m' - tm_`m' - ua_`m') if !missing(delta_`m')
	qui sum ident1_`m', meanonly
	local max1 = r(max)
	qui sum ident2_`m', meanonly
	local max2 = r(max)
	di as text "  `m':  max|delta-um-ta| = " %12.4e (`max1') "    max|delta-tm-ua| = " %12.4e (`max2')
}

********************************************************************************
* SECTION 6: PRE4 BINS (per measure; common across the 5 outcomes of that
* measure so the FE absorb list is identical and the coefficient identity
* beta(delta) = beta(um) + beta(ta) = beta(tm) + beta(ua) holds exactly).
********************************************************************************

foreach m of local measures {
	local v "delta_`m'"
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
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

********************************************************************************
* SECTION 7: SPECIFICATION MACROS
********************************************************************************

local spec             "cba_similarity_decomp"
local conn             "totaltreat_pw_norm"
local base_fe_cba       "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local base_fe_cba_union "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period i.mode_union#i.cba_period"
local extra_cba        "ib0.totalflows_pw_pre_07_114#i.cba_period"

********************************************************************************
* SECTION 8: INITIALIZE CSVS
********************************************************************************

capture erase "$tables/cba_similarity/results_spill_cba_similarity_decomp.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_spill_cba_similarity_decomp.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

capture erase "$tables/cba_similarity/results_es_cba_similarity_decomp.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_es_cba_similarity_decomp.csv", write replace
file write `fh' "spec;outcome;cba_period;coef;se" _n
file close `fh'

local csv_main "$tables/cba_similarity/results_spill_cba_similarity_decomp.csv"
local csv_es   "$tables/cba_similarity/results_es_cba_similarity_decomp.csv"

********************************************************************************
* SECTION 9: REGRESSIONS — POOLED-POST DiD + EVENT STUDY
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "SPILLOVER EFFECTS — DECOMPOSITION OUTCOMES"
di as result "-----------------------------------------------------------------------"

foreach fe_variant in base union {
	if "`fe_variant'" == "base" {
		local cur_base_fe "`base_fe_cba'"
		local cur_spec    "`spec'"
	}
	else {
		local cur_base_fe "`base_fe_cba_union'"
		local cur_spec    "`spec'_union"
	}

	foreach outcome of local sim_outcomes {

		di as text "  Estimating: `outcome' (spillover, `fe_variant')"

		* Common pre4 bin per measure (identity requires identical FE across the 5 outcomes)
		local measure_for_outcome ""
		foreach mtest of local measures {
			if regexm("`outcome'", "_`mtest'$") local measure_for_outcome "`mtest'"
		}
		local absorb_cba "`cur_base_fe' ib0.delta_`measure_for_outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

		* Pooled post-period DiD
		reghdfe `outcome' c.`conn'##post_treat_cba ///
			if `sample_filter' & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		qui sum `outcome' if e(sample) & cba_period == 2
		local base_mean = cond(r(N) > 0, r(mean), .)

		* Pre-treatment placebo
		reghdfe `outcome' c.`conn'##pre_treat_cba ///
			if `sample_filter' & !missing(`outcome') & cba_period <= 2, ///
			absorb(`absorb_cba') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_post ""
		if `p_post' < 0.01                          local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		local stars_pre ""
		if `p_pre' < 0.01                           local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

		* Event study + pre-trend testparm
		reghdfe `outcome' c.`conn'##ib2.cba_period ///
			if `sample_filter' & !missing(`outcome'), ///
			absorb(`absorb_cba') vce(cluster identificad)
		testparm c.`conn'#1.cba_period
		local pre_ftest_pval = r(p)

		* Write pooled-post and pre-trend results
		tempname fh
		file open `fh' using "`csv_main'", write append
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main";"'    %9.4f (`b_post')  `"`stars_post'"' _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre";"'     %9.4f (`b_pre')   `"`stars_pre'"'  _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
		file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
		file close `fh'

		* Write event-study coefficients for every cba_period (period 2 omitted)
		tempname fh_es
		file open `fh_es' using "`csv_es'", write append
		forvalues p = 1/6 {
			if `p' != 2 {
				cap local b_p  = _b[`p'.cba_period#c.`conn']
				cap local se_p = _se[`p'.cba_period#c.`conn']
				file write `fh_es' `""`cur_spec'";"`outcome'";`p';"' %9.6f (`b_p') ";" %9.6f (`se_p') _n
			}
			else {
				file write `fh_es' `""`cur_spec'";"`outcome'";`p';"' "0;0" _n
			}
		}
		file close `fh_es'
	}
}

di as result _newline "All regressions complete."

********************************************************************************
* SECTION 10: COEFFICIENT-IDENTITY DIAGNOSTIC (parse CSV via dataset)
* For each measure: should have beta(delta) ≈ beta(um) + beta(ta), beta(tm) + beta(ua)
* Check is done at table-generation time in Python.
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_cba_similarity_decomp_latex.py"
di as result "LaTeX tables written to Tables/cba_similarity/"

shell source "$programs/notify.sh" && notify "cba_similarity_decomp done" "Ordered decomposition (weighted ref) complete"

********************************************************************************
* END
********************************************************************************
