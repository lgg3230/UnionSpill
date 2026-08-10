* Test: do *flows_pw rates produce non-zero coefs under the loglevel spec
* (no extra_year, outcome_pre4#year + l_firm_emp_pre4#year only)?

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

local base_fe "identificad i.year i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local conn    "totaltreat_pw_norm"

foreach outcome in totalflows_pw outflows_pw inflows_pw {

	* Pre-treatment 4-bin control for this outcome
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

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year"

	di as result _newline "=== `outcome' — no extra_year ==="
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
