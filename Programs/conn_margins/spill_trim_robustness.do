********************************************************************************
* spill_trim_robustness.do
* Runs the main spillover regression for lr_remdezr_w (from
* Main_Results_pct_tfpw_07_11.do) on both the full untreated sample and
* after dropping the top-1% connectivity firms, then exports a comparison CSV.
*
* Spec: reghdfe lr_remdezr_w c.totaltreat_pw_norm##i.treat_year if s_spill,
*       absorb(estab + industry#year + month#year + microregion#year +
*              outcome_pre4#year + emp_pre4#year + flows_pre4#year)
*       vce(cluster identificad)
*
* Output: Tables/conn_margins/results_spill_trim_robustness.csv
********************************************************************************

set more off
set varabbrev off

* ── Auto-detect machine ───────────────────────────────────────────────────────
if "`c(username)'" == "lgg3230" {
	global main "/kellogg/proj/lgg3230"
}
else if "`c(username)'" == "luisg" {
	global main "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster"
}
else {
	di as error "Unknown username: `c(username)'. Set global main manually."
	exit 1
}

global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global programs  "$main/UnionSpill/Programs"

cap mkdir "$tables/conn_margins"

********************************************************************************
* SECTION 1: LOAD AND MERGE (identical to Main_Results_pct_tfpw_07_11.do)
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
* SECTION 2: VARIABLES
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── Connectivity (same as Main_Results: cap drop BEFORE sum to avoid r() bug)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── p99 trim flag ────────────────────────────────────────────────────────────

sum totaltreat_pw_norm if `s_spill' & year == 2009, detail
local p99_conn = r(p99)
di as result "P99 of normalized connectivity (s_spill, 2009): `p99_conn'"

cap drop trim_ok
gen byte trim_ok = (totaltreat_pw_norm <= `p99_conn') if !missing(totaltreat_pw_norm)
replace  trim_ok = 1 if totaltreat_pw_n == 0 & !missing(totaltreat_pw_n)
cap drop trim_ok_min
bys identificad: egen trim_ok_min = min(trim_ok)
drop trim_ok
rename trim_ok_min trim_ok

* ── Winsorized connectivity (cap at p99, keep all firms) ─────────────────────

cap drop totaltreat_pw_norm_w
gen double totaltreat_pw_norm_w = min(totaltreat_pw_norm, `p99_conn')
label var totaltreat_pw_norm_w "Connectivity winsorized at p99 of s_spill sample"

* ── Pre-treatment means & 4-bin controls ─────────────────────────────────────

local outcome "lr_remdezr_w"

cap drop `outcome'_pre_o
cap drop `outcome'_pre
quietly {
	bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
	bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
	drop `outcome'_pre_o
}

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}

cap drop `outcome'_pre4_o
cap drop `outcome'_pre4
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen `outcome'_pre4_o = cut(`outcome'_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
	drop `outcome'_pre4_o

	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o

	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

********************************************************************************
* SECTION 3: ESTIMATION
********************************************************************************

local conn      "totaltreat_pw_norm"
local base_fe   "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb    "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

* ── Initialize output CSV ────────────────────────────────────────────────────

capture erase "$tables/conn_margins/results_spill_trim_robustness.csv"
tempname fh
file open `fh' using "$tables/conn_margins/results_spill_trim_robustness.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

* ── Helper macro for writing results ─────────────────────────────────────────

* (run three times: baseline, trimmed, winsorized)

foreach sample_label in baseline trim winsorized {

	if "`sample_label'" == "baseline" {
		local s_use  "`s_spill'"
		local conn_use "`conn'"
	}
	else if "`sample_label'" == "trim" {
		local s_use  "`s_spill' & trim_ok == 1"
		local conn_use "`conn'"
	}
	else {
		local s_use  "`s_spill'"
		local conn_use "totaltreat_pw_norm_w"
	}

	di as result "--- `sample_label' ---"

	* Post-treatment
	reghdfe `outcome' c.`conn_use'##i.treat_year if `s_use', ///
		absorb(`absorb') vce(cluster identificad)

	local b_post  = _b[1.treat_year#c.`conn_use']
	local se_post = _se[1.treat_year#c.`conn_use']
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	local stars_post ""
	if `p_post' < 0.01                           local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

	* Pre-treatment placebo
	reghdfe `outcome' c.`conn_use'##i.placebo_year if `s_use' & year <= 2011, ///
		absorb(`absorb') vce(cluster identificad)

	local b_pre  = _b[1.placebo_year#c.`conn_use']
	local se_pre = _se[1.placebo_year#c.`conn_use']
	local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	local stars_pre ""
	if `p_pre' < 0.01                           local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

	* Event study F-test
	reghdfe `outcome' c.`conn_use'##ib2011.year if `s_use', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn_use'#i(2009 2010).year
	local pre_ftest_pval = r(p)

	* Write
	tempname fh
	file open `fh' using "$tables/conn_margins/results_spill_trim_robustness.csv", write append
	file write `fh' `""`sample_label'";"spill";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
	file write `fh' `""`sample_label'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
	file close `fh'

	di as result "`sample_label' done: b=`b_post', se=`se_post'"
}

di as result "Exported → Tables/conn_margins/results_spill_trim_robustness.csv"

* ── Auto-run Python table ─────────────────────────────────────────────────────
if "`c(username)'" == "lgg3230" {
	shell ~/.conda/envs/venv_python312/bin/python "$programs/conn_margins/spill_trim_robustness_table.py"
}
else {
	shell python3 "$programs/conn_margins/spill_trim_robustness_table.py"
}
