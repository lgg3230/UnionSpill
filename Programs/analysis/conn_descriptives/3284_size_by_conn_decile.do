********************************************************************************
* UNION SPILLOVERS — ESTABLISHMENT SIZE BY CONNECTIVITY DECILE
* Purpose: Average pre-treatment size of the establishments in each connectivity
*          group of the decile exercise (3154 -> 3152, Panel B of
*          t_linearity_bins_dec.tex), and the average scaled connectivity of
*          the spillover sample.
* Sample:  spillover sample, one row per establishment (year == 2009):
*          lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1
* Groups:  group 0 = zero connectivity; 1-10 = deciles of totaltreat_pw_n among
*          establishments with positive connectivity (xtile, as in 3152).
* Size:    firm_emp_pre = mean employment 2009-2011 (as in 3012).
* Scaled connectivity: totaltreat_pw_norm = totaltreat_pw_n / its 2009 p90
*          among spillover establishments (the regressor of the main spillover
*          regressions).
* Output:  $tables/size_by_conn_decile.csv   one row per group, plus rows for
*                                            all exposed and the full sample
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/size_by_conn_decile_`d'_`t'.log", replace text

********************************************************************************
* SECTION 1: DATA (variable construction as in 3012_pct_tfpw.do / 3152)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if year >= 2009
keep if lagos_sample_avg == 1

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

********************************************************************************
* SECTION 2: CONNECTIVITY DECILES (firm level, as 3152 Section 3)
********************************************************************************

keep if `s_spill' & year == 2009
isid identificad

cap drop cg10
xtile cg10 = totaltreat_pw_n if totaltreat_pw_n > 0 & !missing(totaltreat_pw_n), nq(10)
replace cg10 = 0 if totaltreat_pw_n == 0

di _newline "Scaled connectivity, spillover sample (one row per establishment, 2009):"
sum totaltreat_pw_norm, detail
di _newline "Scaled connectivity, establishments with positive connectivity:"
sum totaltreat_pw_norm if cg10 >= 1 & !missing(cg10), detail

di _newline "Pre-treatment employment (mean 2009-2011) by connectivity group:"
tabstat firm_emp_pre totaltreat_pw_norm, by(cg10) ///
	statistics(n mean p50) format(%9.3f) nototal

********************************************************************************
* SECTION 3: TABLE
********************************************************************************

* Three stacked copies: by group, all exposed (-1), full sample (-2)
tempfile base
save `base'

keep if !missing(cg10)
gen int group = cg10
tempfile g
save `g'

use `base', clear
keep if cg10 >= 1 & !missing(cg10)
gen int group = -1
append using `g'
tempfile g2
save `g2'

use `base', clear
keep if !missing(totaltreat_pw_n)
gen int group = -2
append using `g2'

gen byte one = 1
collapse (sum) n_firms = one ///
	(mean) mean_emp = firm_emp_pre (p50) median_emp = firm_emp_pre ///
	(p25) p25_emp = firm_emp_pre (p75) p75_emp = firm_emp_pre ///
	(mean) mean_lemp = l_firm_emp_pre ///
	(mean) mean_conn = totaltreat_pw_norm (min) min_conn = totaltreat_pw_norm ///
	(max) max_conn = totaltreat_pw_norm, by(group)

gen str16 label = ""
replace label = "zero"        if group == 0
replace label = "decile " + string(group) if group >= 1
replace label = "all exposed" if group == -1
replace label = "all spill"   if group == -2
order group label
replace group = . if group < 0
sort group label

list, noobs abbreviate(12) sep(0)

export delimited using "$tables/size_by_conn_decile.csv", replace

di "Finished: `c(current_date)' `c(current_time)'"
capture log close
