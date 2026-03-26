********************************************************************************
* conn_margins_scatter.do
* Residualizes lr_remdezr_w on the full untreated sample (same FEs as Ex4),
* collapses to firm level, and exports pre/post average residuals vs.
* normalized connectivity for the binned scatter plot.
*
* Output: Tables/conn_margins/scatter_resid_wages.csv
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
global graphs    "$main/UnionSpill/Graphs"
global programs  "$main/UnionSpill/Programs"

cap mkdir "$tables/conn_margins"
cap mkdir "$graphs/conn_margins"

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

* ── Connectivity measure ──────────────────────────────────────────────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

sum totaltreat_pw_n if `s_spill' & year == 2009, detail
local p90_conn = r(p90)   // save before cap drop clears r()
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
gen double totaltreat_pw_n_p90 = `p90_conn'
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment means for 4-bin controls ────────────────────────────────────
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

* ── Residualize on full untreated sample (same spec as Ex4) ──────────────────
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_e   "`base_fe' ib0.lr_remdezr_w_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

cap drop e_lr_remdezr_w
di as result "Residualizing lr_remdezr_w on full untreated sample..."
reghdfe lr_remdezr_w if `s_spill', absorb(`absorb_e') residuals(e_lr_remdezr_w)

* ── Firm-level averages of residuals ─────────────────────────────────────────
* Connectivity is time-invariant: use value from any year
cap drop conn_firm
bys identificad: egen conn_firm = mean(totaltreat_pw_norm)

* Pre-treatment residual (avg 2009-2011)
cap drop e_pre_o
cap drop e_pre
quietly {
	bys identificad: egen e_pre_o = mean(e_lr_remdezr_w) ///
		if inrange(year, 2009, 2011) & `s_spill'
	bys identificad: egen e_pre = min(e_pre_o)
	drop e_pre_o
}

* Post-treatment residual (avg 2012-2016)
cap drop e_post_o
cap drop e_post
quietly {
	bys identificad: egen e_post_o = mean(e_lr_remdezr_w) ///
		if inrange(year, 2012, 2016) & `s_spill'
	bys identificad: egen e_post = min(e_post_o)
	drop e_post_o
}

* ── Firm-level averages of raw log wages ─────────────────────────────────────
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

* ── Collapse to one row per firm ──────────────────────────────────────────────
keep if `s_spill'
bys identificad (year): keep if _n == 1
keep identificad conn_firm e_pre e_post raw_pre raw_post

drop if missing(conn_firm) | missing(e_pre) | missing(e_post)

di as result "Firms in scatter data: " _N

export delimited "$tables/conn_margins/scatter_resid_wages.csv", replace
di as result "Exported → Tables/conn_margins/scatter_resid_wages.csv"

* ── Auto-run Python plots ─────────────────────────────────────────────────────
if "`c(username)'" == "lgg3230" {
	shell ~/.conda/envs/venv_python312/bin/python "$programs/conn_margins/conn_margins_scatter.py"
	shell ~/.conda/envs/venv_python312/bin/python "$programs/conn_margins/conn_margins_scatter_raw.py"
}
else {
	shell python3 "$programs/conn_margins/conn_margins_scatter.py"
	shell python3 "$programs/conn_margins/conn_margins_scatter_raw.py"
}
