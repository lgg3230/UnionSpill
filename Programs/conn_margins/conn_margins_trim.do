********************************************************************************
* conn_margins_trim.do
* Robustness check: re-runs Ex1/Ex2/Ex3 for lr_remdezr_w after dropping firms
* in the top 1% of normalized connectivity (size-artifact outliers).
*
* Output: Tables/conn_margins/results_conn_margins_trim_ex{1,2,3}.csv
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
* SECTION 1: LOAD AND MERGE
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

* ── Connectivity ──────────────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
local p90_conn = r(p90)
gen double totaltreat_pw_n_p90 = `p90_conn'
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Compute p99 cutoff and flag outliers ──────────────────────────────────────

sum totaltreat_pw_norm if `s_spill' & year == 2009, detail
local p99_conn = r(p99)
di as result "P99 of normalized connectivity: `p99_conn'"

cap drop trim_ok
gen byte trim_ok = (totaltreat_pw_norm <= `p99_conn') if !missing(totaltreat_pw_norm)
replace  trim_ok = 1 if totaltreat_pw_n == 0 & !missing(totaltreat_pw_n)  // zero-conn firms always kept

* Propagate to all years within firm
cap drop trim_ok_min
bys identificad: egen trim_ok_min = min(trim_ok)
drop trim_ok
rename trim_ok_min trim_ok

di as result "Firms flagged as outliers (trim_ok==0): " ///
	_N - (`:di _N - sum(trim_ok == 0 & year == 2009 & `s_spill')')

* ── Connectivity indicator ────────────────────────────────────────────────────

cap drop pos_conn
gen byte pos_conn = (totaltreat_pw_n > 0) if !missing(totaltreat_pw_n)

* ── Pre-treatment means and 4-bin controls ────────────────────────────────────

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

* Trimmed sample macros
local s_trim     "`s_spill' & trim_ok == 1"
local s_trim_pos "`s_trim' & totaltreat_pw_n > 0"

* ── Initialize output CSVs ────────────────────────────────────────────────────

foreach ex in ex1 ex2 ex3 {
	capture erase "$tables/conn_margins/results_conn_margins_trim_`ex'.csv"
	tempname fh
	file open `fh' using "$tables/conn_margins/results_conn_margins_trim_`ex'.csv", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'
}

local spec "trim"

********************************************************************************
* EXERCISE 1 (TRIMMED): EXTENSIVE MARGIN
********************************************************************************

di as result "Exercise 1 (trimmed): `outcome'"

local absorb1 "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

reghdfe `outcome' i.pos_conn##i.treat_year if `s_trim', ///
	absorb(`absorb1') vce(cluster identificad)

local b_post  = _b[1.pos_conn#1.treat_year]
local se_post = _se[1.pos_conn#1.treat_year]
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

reghdfe `outcome' i.pos_conn##i.placebo_year if `s_trim' & year <= 2011, ///
	absorb(`absorb1') vce(cluster identificad)

local b_pre  = _b[1.pos_conn#1.placebo_year]
local se_pre = _se[1.pos_conn#1.placebo_year]
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_pre ""
if `p_pre' < 0.01                           local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

reghdfe `outcome' i.pos_conn##ib2011.year if `s_trim', ///
	absorb(`absorb1') vce(cluster identificad)
testparm 1.pos_conn#i(2009 2010).year
local pre_ftest_pval = r(p)

tempname fh
file open `fh' using "$tables/conn_margins/results_conn_margins_trim_ex1.csv", write append
file write `fh' `""`spec'";"ex1";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
file write `fh' `""`spec'";"ex1";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
file write `fh' `""`spec'";"ex1";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
file write `fh' `""`spec'";"ex1";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
file write `fh' `""`spec'";"ex1";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
file write `fh' `""`spec'";"ex1";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
file write `fh' `""`spec'";"ex1";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
file close `fh'

di as result "Ex1 done."

********************************************************************************
* EXERCISE 2 (TRIMMED): INTENSIVE MARGIN
********************************************************************************

di as result "Exercise 2 (trimmed): `outcome'"

reghdfe `outcome' c.`conn'##i.treat_year if `s_trim_pos', ///
	absorb(`absorb') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

reghdfe `outcome' c.`conn'##i.placebo_year if `s_trim_pos' & year <= 2011, ///
	absorb(`absorb') vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_pre ""
if `p_pre' < 0.01                           local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)  local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)  local stars_pre "*"

reghdfe `outcome' c.`conn'##ib2011.year if `s_trim_pos', ///
	absorb(`absorb') vce(cluster identificad)
testparm c.`conn'#i(2009 2010).year
local pre_ftest_pval = r(p)

tempname fh
file open `fh' using "$tables/conn_margins/results_conn_margins_trim_ex2.csv", write append
file write `fh' `""`spec'";"ex2";"`outcome'";"main";"'   %9.4f (`b_post')  `"`stars_post'""' _n
file write `fh' `""`spec'";"ex2";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'            _n
file write `fh' `""`spec'";"ex2";"`outcome'";"pre";"'    %9.4f (`b_pre')   `"`stars_pre'""'  _n
file write `fh' `""`spec'";"ex2";"`outcome'";"pre_se";"' %9.4f (`se_pre')  `"""'             _n
file write `fh' `""`spec'";"ex2";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""'    _n
file write `fh' `""`spec'";"ex2";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')  `"""'           _n
file write `fh' `""`spec'";"ex2";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'          _n
file close `fh'

di as result "Ex2 done."

********************************************************************************
* EXERCISE 3 (TRIMMED): SATURATED
********************************************************************************

di as result "Exercise 3 (trimmed): `outcome'"

reghdfe `outcome' i.pos_conn##i.treat_year c.`conn'##i.treat_year if `s_trim', ///
	absorb(`absorb') vce(cluster identificad)

local b_post_pos   = _b[1.pos_conn#1.treat_year]
local se_post_pos  = _se[1.pos_conn#1.treat_year]
local p_post_pos   = 2*ttail(e(df_r), abs(`b_post_pos'/`se_post_pos'))
local b_post_conn  = _b[1.treat_year#c.`conn']
local se_post_conn = _se[1.treat_year#c.`conn']
local p_post_conn  = 2*ttail(e(df_r), abs(`b_post_conn'/`se_post_conn'))
local n_obs        = e(N)
local n_estab      = e(N_clust)

local stars_post_pos ""
if `p_post_pos' < 0.01                               local stars_post_pos "***"
else if (`p_post_pos' < 0.05 & `p_post_pos' > 0.01) local stars_post_pos "**"
else if (`p_post_pos' < 0.10 & `p_post_pos' > 0.05) local stars_post_pos "*"

local stars_post_conn ""
if `p_post_conn' < 0.01                                local stars_post_conn "***"
else if (`p_post_conn' < 0.05 & `p_post_conn' > 0.01) local stars_post_conn "**"
else if (`p_post_conn' < 0.10 & `p_post_conn' > 0.05) local stars_post_conn "*"

reghdfe `outcome' i.pos_conn##i.placebo_year c.`conn'##i.placebo_year ///
	if `s_trim' & year <= 2011, absorb(`absorb') vce(cluster identificad)

local b_pre_pos   = _b[1.pos_conn#1.placebo_year]
local se_pre_pos  = _se[1.pos_conn#1.placebo_year]
local p_pre_pos   = 2*ttail(e(df_r), abs(`b_pre_pos'/`se_pre_pos'))
local b_pre_conn  = _b[1.placebo_year#c.`conn']
local se_pre_conn = _se[1.placebo_year#c.`conn']
local p_pre_conn  = 2*ttail(e(df_r), abs(`b_pre_conn'/`se_pre_conn'))

local stars_pre_pos ""
if `p_pre_pos' < 0.01                               local stars_pre_pos "***"
else if (`p_pre_pos' < 0.05 & `p_pre_pos' > 0.01)  local stars_pre_pos "**"
else if (`p_pre_pos' < 0.10 & `p_pre_pos' > 0.05)  local stars_pre_pos "*"

local stars_pre_conn ""
if `p_pre_conn' < 0.01                                local stars_pre_conn "***"
else if (`p_pre_conn' < 0.05 & `p_pre_conn' > 0.01)  local stars_pre_conn "**"
else if (`p_pre_conn' < 0.10 & `p_pre_conn' > 0.05)  local stars_pre_conn "*"

reghdfe `outcome' i.pos_conn##ib2011.year c.`conn'##ib2011.year if `s_trim', ///
	absorb(`absorb') vce(cluster identificad)
testparm 1.pos_conn#i(2009 2010).year
local pre_ftest_pos = r(p)
testparm c.`conn'#i(2009 2010).year
local pre_ftest_conn = r(p)

tempname fh
file open `fh' using "$tables/conn_margins/results_conn_margins_trim_ex3.csv", write append
file write `fh' `""`spec'";"ex3";"`outcome'";"main_pos";"'    %9.4f (`b_post_pos')   `"`stars_post_pos'""'  _n
file write `fh' `""`spec'";"ex3";"`outcome'";"main_pos_se";"' %9.4f (`se_post_pos')  `"""'                  _n
file write `fh' `""`spec'";"ex3";"`outcome'";"main_conn";"'   %9.4f (`b_post_conn')  `"`stars_post_conn'""' _n
file write `fh' `""`spec'";"ex3";"`outcome'";"main_conn_se";"' %9.4f (`se_post_conn') `"""'                 _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pos";"'     %9.4f (`b_pre_pos')    `"`stars_pre_pos'""'   _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pos_se";"'  %9.4f (`se_pre_pos')   `"""'                  _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_conn";"'    %9.4f (`b_pre_conn')   `"`stars_pre_conn'""'  _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_conn_se";"' %9.4f (`se_pre_conn')  `"""'                  _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pval_pos";"'  %9.4f (`pre_ftest_pos')  `"""'              _n
file write `fh' `""`spec'";"ex3";"`outcome'";"pre_pval_conn";"' %9.4f (`pre_ftest_conn') `"""'              _n
file write `fh' `""`spec'";"ex3";"`outcome'";"n_obs";"'        %12.0fc (`n_obs')   `"""'                    _n
file write `fh' `""`spec'";"ex3";"`outcome'";"n_estab";"'      %12.0fc (`n_estab') `"""'                    _n
file close `fh'

di as result "Ex3 done."
di as result "All trimmed exercises complete."

* ── Auto-run Python table ─────────────────────────────────────────────────────
if "`c(username)'" == "lgg3230" {
	shell ~/.conda/envs/venv_python312/bin/python "$programs/conn_margins/conn_margins_trim_table.py"
}
else {
	shell python3 "$programs/conn_margins/conn_margins_trim_table.py"
}
