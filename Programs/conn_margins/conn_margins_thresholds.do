********************************************************************************
* UNION SPILLOVERS — CONNECTIVITY THRESHOLD DUMMIES
* Purpose: Replace continuous connectivity with above-median / above-p65 /
*          above-p75 / above-p90 dummies and run spillover regressions.
*          Same fixed-effect spec as Main_Results_pct_tfpw_07_11.do.
* Output:  Tables/conn_margins/results_thresholds.csv
* Auto-runs: Programs/conn_margins/generate_thresholds_latex.py
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/conn_margins/conn_margins_thresholds_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge per-worker pairwise flows (2007-2011) ─────────────────────────────

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

* ── Treatment & period indicators ───────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── Connectivity scaling ─────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── Pre-treatment means & 4-bin controls ─────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
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

* l_firm_emp_pre4 doubles as its own pre4 control
cap drop l_firm_emp_pre4_o
quietly {
	cap drop l_firm_emp_pre4_tmp
	gen l_firm_emp_pre4_tmp = l_firm_emp_pre4
	drop l_firm_emp_pre4_tmp
}

* ── Totalflows 4-bin control ─────────────────────────────────────────────────

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
* SECTION 3: CONNECTIVITY THRESHOLD DUMMIES
********************************************************************************

* Compute thresholds from spillover sample in pre-treatment year 2009

_pctile totaltreat_pw_norm if `s_spill' & year == 2009, p(50 65 75 90)
local cut_p50 = r(r1)
local cut_p65 = r(r2)
local cut_p75 = r(r3)
local cut_p90 = r(r4)

di as result "Connectivity thresholds (spillover sample, 2009):"
di as result "  Median (p50): `cut_p50'"
di as result "  p65:          `cut_p65'"
di as result "  p75:          `cut_p75'"
di as result "  p90:          `cut_p90'"

cap drop above_p50
cap drop above_p65
cap drop above_p75
cap drop above_p90

gen byte above_p50 = (totaltreat_pw_norm > `cut_p50') if !missing(totaltreat_pw_norm)
gen byte above_p65 = (totaltreat_pw_norm > `cut_p65') if !missing(totaltreat_pw_norm)
gen byte above_p75 = (totaltreat_pw_norm > `cut_p75') if !missing(totaltreat_pw_norm)
gen byte above_p90 = (totaltreat_pw_norm > `cut_p90') if !missing(totaltreat_pw_norm)

label var above_p50 "Above-median connectivity"
label var above_p65 "Above-p65 connectivity"
label var above_p75 "Above-p75 connectivity"
label var above_p90 "Above-p90 connectivity"

********************************************************************************
* SECTION 4: ESTIMATION
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

* Initialize output CSV

capture erase "$tables/conn_margins/results_thresholds.csv"
tempname fh
file open `fh' using "$tables/conn_margins/results_thresholds.csv", write replace
file write `fh' "threshold,outcome,row_type,value" _n
file close `fh'

* Loop over thresholds and outcomes

foreach thr in p50 p65 p75 p90 {
	foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

		di as result "Estimating: `outcome' | above_`thr'"

		* For l_firm_emp, pre4 control is l_firm_emp_pre4 (same as size control)
		if "`outcome'" == "l_firm_emp" {
			local absorb "`base_fe' ib0.l_firm_emp_pre4#i.year `extra_year'"
		}
		else {
			local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
		}

		* ── Post-treatment ───────────────────────────────────────────────────

		reghdfe `outcome' i.above_`thr'##i.treat_year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)

		local b_post  = _b[1.above_`thr'#1.treat_year]
		local se_post = _se[1.above_`thr'#1.treat_year]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		local stars_post ""
		if `p_post' < 0.01                           local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

		* ── Pre-treatment placebo ────────────────────────────────────────────

		reghdfe `outcome' i.above_`thr'##i.placebo_year if `s_spill' & year <= 2011, ///
			absorb(`absorb') vce(cluster identificad)

		local b_pre  = _b[1.above_`thr'#1.placebo_year]
		local se_pre = _se[1.above_`thr'#1.placebo_year]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_pre ""
		if `p_pre' < 0.01                           local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

		* ── Pre-trend F-test (event study) ──────────────────────────────────

		reghdfe `outcome' i.above_`thr'##ib2011.year if `s_spill', ///
			absorb(`absorb') vce(cluster identificad)
		testparm 1.above_`thr'#i(2009 2010).year
		local pre_ftest_pval = r(p)

		* ── Write ────────────────────────────────────────────────────────────

		tempname fh
		file open `fh' using "$tables/conn_margins/results_thresholds.csv", write append
		file write `fh' `""`thr'";"`outcome'";"post_coef";"' %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`thr'";"`outcome'";"post_se";"'   %9.4f (`se_post') `"""' _n
		file write `fh' `""`thr'";"`outcome'";"pre_coef";"'  %9.4f (`b_pre')  `"`stars_pre'""' _n
		file write `fh' `""`thr'";"`outcome'";"pre_se";"'    %9.4f (`se_pre')  `"""' _n
		file write `fh' `""`thr'";"`outcome'";"n_obs";"'     %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`thr'";"`outcome'";"n_estab";"'   %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`thr'";"`outcome'";"pre_ftest";"' %9.4f (`pre_ftest_pval') `"""' _n
		file close `fh'

	}
}

di as result "All estimates complete."

* ── Auto-generate LaTeX table ────────────────────────────────────────────────

shell ~/.conda/envs/venv_python312/bin/python ///
	"$programs/conn_margins/generate_thresholds_latex.py"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "conn_margins_thresholds complete"

log close
