********************************************************************************
* conn_margins_scatter_controls.do
* Exports raw firm-level DiD + control variables for the correct Cattaneo et al.
* (2024) covariate-adjusted binsreg (Problem 1 fix).
*
* Unlike conn_margins_scatter.do, this does NOT residualize x or y.
* Instead it exports the raw variables + controls so that binsreg can handle
* covariate adjustment internally via the semi-linear partially-linear estimator
* (equation 3 in Cattaneo et al. 2024).
*
* Output: Tables/conn_margins/scatter_raw_controls.csv
********************************************************************************

set more off
set varabbrev off

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

* ── Load and merge ────────────────────────────────────────────────────────────
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

keep if year >= 2009
keep if lagos_sample_avg == 1

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ── Per-worker flows (for quartile control) ───────────────────────────────────
gen double totalflows_pw_pre_07_11     = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

* ── Connectivity measure (normalized by p90 in 2009) ─────────────────────────
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
local p90_conn = r(p90)
cap drop totaltreat_pw_norm
gen double totaltreat_pw_norm = totaltreat_pw_n / `p90_conn'

* ── Pre-treatment baseline means for quartile controls ───────────────────────
cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
quietly {
	bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_w_pre   = min(lr_remdezr_w_pre_o)
	drop lr_remdezr_w_pre_o
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

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
	drop lr_remdezr_w_pre4_o

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

* ── Firm-level pre/post raw wage averages ─────────────────────────────────────
cap drop raw_pre_o
cap drop raw_pre
cap drop raw_post_o
cap drop raw_post
quietly {
	bys identificad: egen raw_pre_o = mean(lr_remdezr_w) ///
		if inrange(year, 2009, 2011) & `s_spill'
	bys identificad: egen raw_pre = min(raw_pre_o)
	drop raw_pre_o

	bys identificad: egen raw_post_o = mean(lr_remdezr_w) ///
		if inrange(year, 2012, 2016) & `s_spill'
	bys identificad: egen raw_post = min(raw_post_o)
	drop raw_post_o
}

* ── Firm-level connectivity (time-invariant) ─────────────────────────────────
cap drop conn_firm
bys identificad: egen conn_firm = mean(totaltreat_pw_norm)

* ── Firm-level control variables (take 2009 value) ───────────────────────────
* industry1, mode_base_month, microregion are time-invariant or nearly so.
* After DiD differencing, the ×year interactions collapse to group dummies.

* ── Collapse to one row per firm ──────────────────────────────────────────────
keep if `s_spill'
bys identificad (year): keep if _n == 1

keep identificad conn_firm raw_pre raw_post ///
     industry1 mode_base_month microregion ///
     lr_remdezr_w_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114

drop if missing(conn_firm) | missing(raw_pre) | missing(raw_post)

gen double raw_did = raw_post - raw_pre

di as result "Firms exported: " _N

export delimited "$tables/conn_margins/scatter_raw_controls.csv", replace
di as result "Exported → Tables/conn_margins/scatter_raw_controls.csv"
