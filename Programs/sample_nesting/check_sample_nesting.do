********************************************************************************
* check_sample_nesting.do
* Empirical nesting check for Table 3 estimation samples.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main     "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

shell mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/sample_nesting
shell mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Tables/sample_nesting
shell mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Logs/sample_nesting

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/sample_nesting/check_sample_nesting_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLES
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* Connectivity
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* Pre-treatment means & 4-bin controls
cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
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

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
	cap drop `outcome'_pre4_o
	cap drop `outcome'_pre4
	quietly {
		egen `outcome'_pre4_o = cut(`outcome'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
		drop `outcome'_pre4_o
	}
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
}

di as result "All variables created."

********************************************************************************
* SECTION 3: ESTIMATION SAMPLES
********************************************************************************

local conn        "totaltreat_pw_norm"
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

tempname counts_fh
tempfile counts_file
postfile `counts_fh' str20 outcome int col double obs_est long estab_est double obs_target long estab_target str10 match using `counts_file', replace

local i = 1
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	di as result "--- Main spillover sample: `outcome' ---"
	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	gen byte insamp_`outcome' = e(sample)
	local n_obs = e(N)
	local n_estab = e(N_clust)
	if "`outcome'" == "lr_remdezr_w" {
		local target_obs = 32495
		local target_estab = 4084
	}
	if "`outcome'" == "lr_remdezr_h_w" {
		local target_obs = 32495
		local target_estab = 4084
	}
	if "`outcome'" == "l_firm_emp" {
		local target_obs = 32704
		local target_estab = 4088
	}
	local matchflag "MATCH"
	if (`n_obs' != `target_obs') local matchflag "MISMATCH"
	if (`n_estab' != `target_estab') local matchflag "MISMATCH"
	di as result "REPRODUCED outcome=`outcome' col=`i' obs=`n_obs' target_obs=`target_obs' estabs=`n_estab' target_estabs=`target_estab' `matchflag'"
	post `counts_fh' ("`outcome'") (`i') (`n_obs') (`n_estab') (`target_obs') (`target_estab') ("`matchflag'")
	local ++i
}

di as result "--- Main spillover sample: numb_clauses ---"
reghdfe numb_clauses c.`conn'##post_treat_cba ///
	if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
gen byte insamp_numb_clauses = e(sample)
local n_obs = e(N)
local n_estab = e(N_clust)
local target_obs = 19693
local target_estab = 4142
local matchflag "MATCH"
if (`n_obs' != `target_obs') local matchflag "MISMATCH"
if (`n_estab' != `target_estab') local matchflag "MISMATCH"
di as result "REPRODUCED outcome=numb_clauses col=4 obs=`n_obs' target_obs=`target_obs' estabs=`n_estab' target_estabs=`target_estab' `matchflag'"
post `counts_fh' ("numb_clauses") (4) (`n_obs') (`n_estab') (`target_obs') (`target_estab') ("`matchflag'")
postclose `counts_fh'

********************************************************************************
* SECTION 4: PRE-SINGLETON ELIGIBILITY FLAGS FOR CHANNEL CHECKS
********************************************************************************

gen byte elig_lr_remdezr_w_outcome = (`s_spill' & !missing(lr_remdezr_w))
gen byte elig_lr_remdezr_w_pre4 = (elig_lr_remdezr_w_outcome & !missing(lr_remdezr_w_pre4))
gen byte elig_lr_remdezr_w_full = (elig_lr_remdezr_w_pre4 & !missing(totaltreat_pw_norm) & !missing(treat_year) & !missing(identificad) & !missing(industry1) & !missing(year) & !missing(mode_base_month) & !missing(microregion) & !missing(l_firm_emp_pre4) & !missing(totalflows_pw_pre_07_114))

gen byte elig_numb_clauses_outcome = (`s_spill' & !missing(cba_period) & !missing(numb_clauses))
gen byte elig_numb_clauses_pre4 = (elig_numb_clauses_outcome & !missing(numb_clauses_pre4))
gen byte elig_numb_clauses_full = (elig_numb_clauses_pre4 & !missing(totaltreat_pw_norm) & !missing(post_treat_cba) & !missing(identificad) & !missing(industry1) & !missing(cba_period) & !missing(mode_base_month) & !missing(microregion) & !missing(l_firm_emp_pre4) & !missing(totalflows_pw_pre_07_114))

********************************************************************************
* SECTION 5: SET COMPARISON EXPORTS
********************************************************************************

preserve
	keep identificad insamp_lr_remdezr_w insamp_lr_remdezr_h_w insamp_l_firm_emp insamp_numb_clauses ///
		elig_lr_remdezr_w_outcome elig_lr_remdezr_w_pre4 elig_lr_remdezr_w_full ///
		elig_numb_clauses_outcome elig_numb_clauses_pre4 elig_numb_clauses_full
	collapse (max) insamp_lr_remdezr_w insamp_lr_remdezr_h_w insamp_l_firm_emp insamp_numb_clauses ///
		elig_lr_remdezr_w_outcome elig_lr_remdezr_w_pre4 elig_lr_remdezr_w_full ///
		elig_numb_clauses_outcome elig_numb_clauses_pre4 elig_numb_clauses_full, by(identificad)

	tempname estab_fh
	tempfile estab_overlap
	postfile `estab_fh' str20 A str20 B long N_A long N_B long N_intersect long N_A_minus_B long N_B_minus_A str5 A_subset_B using `estab_overlap', replace
	local names "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"
	foreach A in `names' {
		foreach B in `names' {
			count if insamp_`A' == 1
			local nA = r(N)
			count if insamp_`B' == 1
			local nB = r(N)
			count if insamp_`A' == 1 & insamp_`B' == 1
			local nI = r(N)
			count if insamp_`A' == 1 & insamp_`B' != 1
			local nAmb = r(N)
			count if insamp_`B' == 1 & insamp_`A' != 1
			local nBma = r(N)
			local subset "false"
			if (`nAmb' == 0) local subset "true"
			post `estab_fh' ("`A'") ("`B'") (`nA') (`nB') (`nI') (`nAmb') (`nBma') ("`subset'")
		}
	}
	postclose `estab_fh'

	use `estab_overlap', clear
	export delimited using "$tables/sample_nesting/estab_set_overlap.csv", replace
restore

preserve
	keep identificad year insamp_lr_remdezr_w insamp_lr_remdezr_h_w insamp_l_firm_emp insamp_numb_clauses
	collapse (max) insamp_lr_remdezr_w insamp_lr_remdezr_h_w insamp_l_firm_emp insamp_numb_clauses, by(identificad year)

	tempname obs_fh
	tempfile obs_overlap
	postfile `obs_fh' str20 A str20 B long N_A long N_B long N_intersect long N_A_minus_B long N_B_minus_A str5 A_subset_B using `obs_overlap', replace
	local names "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"
	foreach A in `names' {
		foreach B in `names' {
			count if insamp_`A' == 1
			local nA = r(N)
			count if insamp_`B' == 1
			local nB = r(N)
			count if insamp_`A' == 1 & insamp_`B' == 1
			local nI = r(N)
			count if insamp_`A' == 1 & insamp_`B' != 1
			local nAmb = r(N)
			count if insamp_`B' == 1 & insamp_`A' != 1
			local nBma = r(N)
			local subset "false"
			if (`nAmb' == 0) local subset "true"
			post `obs_fh' ("`A'") ("`B'") (`nA') (`nB') (`nI') (`nAmb') (`nBma') ("`subset'")
		}
	}
	postclose `obs_fh'

	use `obs_overlap', clear
	export delimited using "$tables/sample_nesting/obs_set_overlap.csv", replace
restore

********************************************************************************
* SECTION 6: CHANNEL DECOMPOSITION, WAGE VS CLAUSES
********************************************************************************

preserve
	keep identificad insamp_lr_remdezr_w insamp_numb_clauses ///
		elig_lr_remdezr_w_outcome elig_lr_remdezr_w_pre4 elig_lr_remdezr_w_full ///
		elig_numb_clauses_outcome elig_numb_clauses_pre4 elig_numb_clauses_full
	collapse (max) insamp_lr_remdezr_w insamp_numb_clauses ///
		elig_lr_remdezr_w_outcome elig_lr_remdezr_w_pre4 elig_lr_remdezr_w_full ///
		elig_numb_clauses_outcome elig_numb_clauses_pre4 elig_numb_clauses_full, by(identificad)

	count if insamp_lr_remdezr_w == 1 & insamp_numb_clauses != 1
	local wage_not_clause = r(N)
	count if insamp_numb_clauses == 1 & insamp_lr_remdezr_w != 1
	local clause_not_wage = r(N)

	count if insamp_lr_remdezr_w == 1 & insamp_numb_clauses != 1 & elig_numb_clauses_outcome != 1
	local wnc_outcome = r(N)
	count if insamp_lr_remdezr_w == 1 & insamp_numb_clauses != 1 & elig_numb_clauses_outcome == 1 & elig_numb_clauses_pre4 != 1
	local wnc_pre4 = r(N)
	count if insamp_lr_remdezr_w == 1 & insamp_numb_clauses != 1 & elig_numb_clauses_pre4 == 1 & elig_numb_clauses_full == 1
	local wnc_singleton = r(N)
	count if insamp_lr_remdezr_w == 1 & insamp_numb_clauses != 1 & elig_numb_clauses_outcome == 1 & elig_numb_clauses_pre4 == 1 & elig_numb_clauses_full != 1
	local wnc_other = r(N)

	count if insamp_numb_clauses == 1 & insamp_lr_remdezr_w != 1 & elig_lr_remdezr_w_outcome != 1
	local cnw_outcome = r(N)
	count if insamp_numb_clauses == 1 & insamp_lr_remdezr_w != 1 & elig_lr_remdezr_w_outcome == 1 & elig_lr_remdezr_w_pre4 != 1
	local cnw_pre4 = r(N)
	count if insamp_numb_clauses == 1 & insamp_lr_remdezr_w != 1 & elig_lr_remdezr_w_pre4 == 1 & elig_lr_remdezr_w_full == 1
	local cnw_singleton = r(N)
	count if insamp_numb_clauses == 1 & insamp_lr_remdezr_w != 1 & elig_lr_remdezr_w_outcome == 1 & elig_lr_remdezr_w_pre4 == 1 & elig_lr_remdezr_w_full != 1
	local cnw_other = r(N)

	di as result "NESTING wage_inside_clauses=" cond(`wage_not_clause' == 0, "true", "false") " wage_not_clause=`wage_not_clause' clause_not_wage=`clause_not_wage'"
	di as result "CHANNEL wage_not_clause target=clauses total=`wage_not_clause' outcome_missing=`wnc_outcome' pre4_missing=`wnc_pre4' singleton_drop=`wnc_singleton' other_complete_var_missing=`wnc_other'"
	di as result "CHANNEL clause_not_wage target=wages total=`clause_not_wage' outcome_missing=`cnw_outcome' pre4_missing=`cnw_pre4' singleton_drop=`cnw_singleton' other_complete_var_missing=`cnw_other'"
restore

********************************************************************************
* SECTION 7: LOG THE REPRODUCED COUNTS TABLE
********************************************************************************

preserve
	use `counts_file', clear
	list, noobs abbrev(24)
restore

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Sample nesting done" "4-column e(sample) overlap"

di "Finished: `c(current_date)' `c(current_time)'"
log close
