* Test: do *flows_pw rates survive adding ib0.totalflows_pw_pre_07_114#i.year
* to the absorb (same extra_year used in main loglevel spec)?

set more off
set varabbrev off

global main     "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* Merge flow outcomes panel
preserve
	import delimited "$rais_aux/totalflows_panel_2009_2016.csv", clear
	tostring identificad, replace format(%014.0f) force
	keep identificad year totalflows_pw outflows_pw inflows_pw
	tempfile fp
	save `fp'
restore
cap drop totalflows_pw
cap drop outflows_pw
cap drop inflows_pw
merge 1:1 identificad year using `fp', keep(master match) nogen

* Merge totalflows_wide_2007_2011 for pre_07_11 average
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile fw
	save `fw'
restore
merge m:1 identificad using `fw', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
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

* Treatment indicators
cap drop treat_year
cap drop placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year < 2011)

* Connectivity scaling
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90

* l_firm_emp_pre4
cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

* totalflows_pw_pre_07_114 (quartiles of 2007-2011 wide pre-treatment average)
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

local base_fe  "identificad i.year i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local conn     "totaltreat_pw_norm"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

foreach outcome in totalflows_pw outflows_pw inflows_pw {

	* Pre-treatment 4-bin control for this outcome (2009-2011 panel average)
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
		egen `outcome'_pre4_o = cut(`outcome'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4  = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
		replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)
	}

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	di as result _newline "=== `outcome' — with extra_year (totalflows_pw_pre_07_114#year) ==="
	capture reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	if _rc != 0 {
		di as error "  reghdfe failed: rc=" _rc
	}
	else {
		di "  b_post = " _b[1.treat_year#c.`conn'] ///
		   "  se = "     _se[1.treat_year#c.`conn'] ///
		   "  R2 = "     e(r2)
		di "  N = " e(N) "  N_clust = " e(N_clust)
	}
}

di as result _newline "Done."
