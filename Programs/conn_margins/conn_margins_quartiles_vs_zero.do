********************************************************************************
* UNION SPILLOVERS — CONNECTIVITY QUARTILE GROUPS vs. ZERO CONNECTIVITY
* Purpose: Segment the spillover sample by quartiles of positive pre-treatment
*          connectivity (totaltreat_pw_n > 0). Each regression compares one
*          quartile group against the zero-connectivity group only.
*          Quartile thresholds are computed exclusively from positive-connectivity
*          firms in 2009 within the spillover sample.
* Outcomes: lr_remdezr_w, lr_remdezr_h_w
* Output:   Tables/conn_margins/results_quartiles_vs_zero.csv
* Auto-runs: Programs/conn_margins/generate_quartiles_vs_zero_latex.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/conn_margins/conn_margins_quartiles_vs_zero_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
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
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
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

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w {
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
* SECTION 3: QUARTILE GROUPS OF POSITIVE CONNECTIVITY
* Quartile thresholds computed from spillover firms with totaltreat_pw_n > 0
* at year == 2009.
********************************************************************************

_pctile totaltreat_pw_n if `s_spill' & year == 2009 & totaltreat_pw_n > 0, p(25 50 75)
local q1_cut = r(r1)
local q2_cut = r(r2)
local q3_cut = r(r3)

di as result "Positive-connectivity quartile thresholds (spillover sample, 2009):"
di as result "  Q1/Q2 cutpoint (p25): `q1_cut'"
di as result "  Q2/Q3 cutpoint (p50): `q2_cut'"
di as result "  Q3/Q4 cutpoint (p75): `q3_cut'"

* quartile_g: 0 = zero connectivity, 1-4 = quartile among positive-conn firms
cap drop quartile_g
gen byte quartile_g = .
replace quartile_g = 0 if totaltreat_pw_n == 0
replace quartile_g = 1 if totaltreat_pw_n > 0  & totaltreat_pw_n <= `q1_cut'
replace quartile_g = 2 if totaltreat_pw_n > `q1_cut' & totaltreat_pw_n <= `q2_cut'
replace quartile_g = 3 if totaltreat_pw_n > `q2_cut' & totaltreat_pw_n <= `q3_cut'
replace quartile_g = 4 if totaltreat_pw_n > `q3_cut' & !missing(totaltreat_pw_n)

di as result "Quartile group distribution (spillover sample, 2009):"
tab quartile_g if `s_spill' & year == 2009

********************************************************************************
* SECTION 4: ESTIMATION
* For each outcome x quartile (1-4): compare against zero-connectivity (0).
* Each regression restricts to (quartile_g == q | quartile_g == 0).
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

capture erase "$tables/conn_margins/results_quartiles_vs_zero.csv"
tempname fh
file open `fh' using "$tables/conn_margins/results_quartiles_vs_zero.csv", write replace
file write `fh' "quartile,outcome,row_type,value" _n
file close `fh'

foreach outcome in lr_remdezr_w lr_remdezr_h_w {

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	foreach q in 1 2 3 4 {

		local s_q "`s_spill' & (quartile_g == `q' | quartile_g == 0)"

		cap drop in_quartile
		gen byte in_quartile = (quartile_g == `q') if (quartile_g == `q' | quartile_g == 0)

		di as result "--- `outcome' | Q`q' vs. zero-connectivity ---"

		* ── Post-treatment ───────────────────────────────────────────────────

		reghdfe `outcome' i.in_quartile##i.treat_year if `s_q', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.in_quartile#1.treat_year]
		local se_post = _se[1.in_quartile#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		* ── Pre-treatment placebo ────────────────────────────────────────────

		reghdfe `outcome' i.in_quartile##i.placebo_year if `s_q' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.in_quartile#1.placebo_year]
		local se_pre = _se[1.in_quartile#1.placebo_year]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_pre ""
		if `p_pre' < 0.01                           local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

		* ── Pre-trend F-test (event study) ──────────────────────────────────

		reghdfe `outcome' i.in_quartile##ib2011.year if `s_q', ///
			absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
		testparm 1.in_quartile#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* ── Write ────────────────────────────────────────────────────────────

		tempname fh
		file open `fh' using "$tables/conn_margins/results_quartiles_vs_zero.csv", write append
		file write `fh' `""`q'";"`outcome'";"post_coef";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`q'";"`outcome'";"post_se";"'   %9.4f (`se_post') `"""' _n
		file write `fh' `""`q'";"`outcome'";"pre_coef";"'  %9.4f (`b_pre')  `"`stars_pre'""' _n
		file write `fh' `""`q'";"`outcome'";"pre_se";"'    %9.4f (`se_pre')  `"""' _n
		file write `fh' `""`q'";"`outcome'";"n_obs";"'     %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`q'";"`outcome'";"n_estab";"'   %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`q'";"`outcome'";"pre_ftest";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'

	}
}

cap drop in_quartile
cap drop quartile_g

di as result "All estimates complete."

shell ~/.conda/envs/venv_python312/bin/python ///
	"$programs/conn_margins/generate_quartiles_vs_zero_latex.py"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "conn_margins_quartiles_vs_zero complete"

log close
