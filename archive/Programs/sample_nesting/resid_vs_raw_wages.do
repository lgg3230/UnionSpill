********************************************************************************
* resid_vs_raw_wages.do
*
* The residualized-wage regressions carry slightly LARGER samples than the raw
* wage regressions, even though the outcomes are nearly the same variable:
*   spillover  raw 32,495 / 4,084   resid 32,498 / 4,085
*   direct     raw 112,695 / 14,136 resid 112,702 / 14,138
*
* Two questions:
*   (1) Are the samples nested?
*   (2) Why do they diverge at all?
*
* Prime suspect, from 4112_mincer.do lines 178-197: the raw wage bins
* are NOT zero-filled, so an establishment with a missing pre-treatment raw wage
* loses lr_remdezr_w_pre4 and drops out; the Mincer residual bins ARE zero-filled
* (`replace `v'_pre4 = 0 if missing(`v'_pre4)`), so the same establishment keeps
* a bin and stays in. That channel runs the observed direction. Working against
* it, the residual is merged in and can be missing where the raw wage is present.
* This script measures both.
*
* Prep copied from 4112_mincer.do.
* Output: Tables/sample_nesting/resid_vs_raw_overlap.csv
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/sample_nesting/resid_vs_raw_wages_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD, MERGE RESIDUALS AND FLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/mincer_residuals_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile mincer
	save `mincer'
restore
merge 1:1 identificad year using `mincer', keep(master match) nogen

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

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop placebo_year
gen byte placebo_year = (year < 2011)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* Pre-treatment means
foreach v in lr_remdezr_w lr_remdezr_resid {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

* Raw wage bin: NO zero-fill (as in the source script)
cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
quietly {
	egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
	drop lr_remdezr_w_pre4_o
}

* Residual bin: WITH zero-fill (as in the source script)
cap drop lr_remdezr_resid_pre4_o
cap drop lr_remdezr_resid_pre4
quietly {
	egen lr_remdezr_resid_pre4_o = cut(lr_remdezr_resid_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_resid_pre4 = min(lr_remdezr_resid_pre4_o)
	drop lr_remdezr_resid_pre4_o
	replace lr_remdezr_resid_pre4 = 0 if missing(lr_remdezr_resid_pre4)
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
* SECTION 3: THE TWO SPILLOVER REGRESSIONS
********************************************************************************

local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

foreach outcome in lr_remdezr_w lr_remdezr_resid {

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	di as result "=== spillover: `outcome' ==="
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	cap drop insamp_`outcome'
	gen byte insamp_`outcome' = e(sample)
	di as result "  obs = " e(N) "   estabs = " e(N_clust)
}

di as result "Targets: raw 32,495 / 4,084   resid 32,498 / 4,085"

********************************************************************************
* SECTION 4: NESTING
********************************************************************************

cap drop any_raw
cap drop any_res
bysort identificad: egen byte any_raw = max(insamp_lr_remdezr_w)
bysort identificad: egen byte any_res = max(insamp_lr_remdezr_resid)

di _newline(1)
di as result "=== OBSERVATION-LEVEL overlap ==="
tab insamp_lr_remdezr_w insamp_lr_remdezr_resid, missing

preserve
	bysort identificad: keep if _n == 1

	di _newline(1)
	di as result "=== ESTABLISHMENT-LEVEL overlap ==="
	count if any_raw == 1
	local n_raw = r(N)
	count if any_res == 1
	local n_res = r(N)
	count if any_raw == 1 & any_res == 1
	local n_both = r(N)
	count if any_raw == 1 & any_res == 0
	local raw_not_res = r(N)
	count if any_res == 1 & any_raw == 0
	local res_not_raw = r(N)

	di as result "  raw only sample:        `n_raw'"
	di as result "  resid only sample:      `n_res'"
	di as result "  in both:                `n_both'"
	di as result "  raw but NOT resid:      `raw_not_res'"
	di as result "  resid but NOT raw:      `res_not_raw'"
	di as result "  raw subset of resid?    " cond(`raw_not_res'==0, "YES", "NO")
	di as result "  resid subset of raw?    " cond(`res_not_raw'==0, "YES", "NO")
restore

********************************************************************************
* SECTION 5: WHY — channel decomposition
********************************************************************************

* Rows eligible for each spec before singleton dropping
cap drop elig_raw
gen byte elig_raw = (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1) ///
	& !missing(lr_remdezr_w) & !missing(totaltreat_pw_norm) ///
	& !missing(industry1) & !missing(mode_base_month) & !missing(microregion) ///
	& !missing(lr_remdezr_w_pre4) & !missing(l_firm_emp_pre4) & !missing(totalflows_pw_pre_07_114)

cap drop elig_res
gen byte elig_res = (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1) ///
	& !missing(lr_remdezr_resid) & !missing(totaltreat_pw_norm) ///
	& !missing(industry1) & !missing(mode_base_month) & !missing(microregion) ///
	& !missing(lr_remdezr_resid_pre4) & !missing(l_firm_emp_pre4) & !missing(totalflows_pw_pre_07_114)

di _newline(1)
di as result "=== Row-level eligibility cross-tab ==="
tab elig_raw elig_res, missing

di as result "=== Outcome missingness, spillover sample rows ==="
count if `s_spill' & missing(lr_remdezr_w) & !missing(lr_remdezr_resid)
di as result "  raw missing, resid present: " r(N)
count if `s_spill' & !missing(lr_remdezr_w) & missing(lr_remdezr_resid)
di as result "  resid missing, raw present: " r(N)

di as result "=== Pre-treatment bin missingness (the zero-fill asymmetry) ==="
preserve
	bysort identificad: keep if _n == 1
	count if missing(lr_remdezr_w_pre4)
	di as result "  estabs with MISSING raw wage bin (dropped from raw spec):   " r(N)
	count if missing(lr_remdezr_resid_pre4)
	di as result "  estabs with MISSING resid bin (zero-filled, so none):       " r(N)
	count if missing(lr_remdezr_w_pre4) & !missing(lr_remdezr_resid_pre)
	di as result "  of those, resid pre-mean IS present:                        " r(N)
restore

* Establishments in resid but not raw: why
cap drop only_res
gen byte only_res = (any_res == 1 & any_raw == 0)
preserve
	bysort identificad: keep if _n == 1
	count if only_res == 1
	di as result "=== Establishments in resid but not raw: " r(N)
	count if only_res == 1 & missing(lr_remdezr_w_pre4)
	di as result "    missing raw wage bin:        " r(N)
	count if only_res == 1 & !missing(lr_remdezr_w_pre4)
	di as result "    raw bin present (singleton): " r(N)
restore

* Export establishment-level flags
preserve
	bysort identificad: keep if _n == 1
	keep identificad any_raw any_res only_res lr_remdezr_w_pre4 lr_remdezr_resid_pre4
	export delimited using "$tables/sample_nesting/resid_vs_raw_overlap.csv", replace
restore

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Resid vs raw wages done" "nesting + channel decomposition"
