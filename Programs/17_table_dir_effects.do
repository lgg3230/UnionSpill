********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Recap of recent results 
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

// use "$rais_firm/labor_analysis_sample_aug6.dta", clear
use "$rais_firm/lagos_sample_sep24_pct.dta", clear

keep if year>=2009

keep if lagos_sample_avg==1

gen placebo_year = cond(year<2011, 1,0)


bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre =  min(firm_emp_pre_o)


cap drop avg_emp
bys identificad (year):  gen avg_emp = (firm_emp+firm_emp[_n-1])/2 if year>=2010


// gen turnover_c = separations /avg_emp if year>=2010
// replace turnover_c =2* separations / (firm_emp+firm_emp_2008) if year==2009

cap drop lr_remdezr_pre_o
cap drop lr_remdezr_pre
bys identificad: egen lr_remdezr_pre_o = mean(lr_remdezr) if year<=2011
bys identificad: egen lr_remdezr_pre = min(lr_remdezr_pre_o)

* ===============================
* Quintiles of firm_emp_pre by sample
* ===============================

* Define samples (matching your specs)
cap macro drop s_direct
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pf_n<0.01 | lagos_sample_avg==1 & treat_ultra==1) "

cap macro drop s_spill
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

* ===============================
* Sample definitions
* ===============================
cap macro drop s_direct
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"

cap macro drop s_spill
local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

cap label define q5 1 "Q1 (smallest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (largest)"

* ===============================
* DIRECT sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_direct_a
cap drop q_firm_emp_pre_direct

egen q_firm_emp_pre_direct_a = cut(firm_emp_pre) if year==2009 & `s_direct', group(5)
bys identificad: egen q_firm_emp_pre_direct = min(q_firm_emp_pre_direct_a)
drop q_firm_emp_pre_direct_a

label var q_firm_emp_pre_direct "Quintile of firm_emp_pre (direct sample, from 2009 dist.)"
label values q_firm_emp_pre_direct q5

* Optional sanity check: constant within firm where defined
bys identificad: assert q_firm_emp_pre_direct == q_firm_emp_pre_direct[1] if !missing(q_firm_emp_pre_direct)

* ===============================
* SPILLOVER sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_spill_a
cap drop q_firm_emp_pre_spill

egen q_firm_emp_pre_spill_a = cut(firm_emp_pre) if year==2009 & `s_spill', group(5)
bys identificad: egen q_firm_emp_pre_spill = min(q_firm_emp_pre_spill_a)
drop q_firm_emp_pre_spill_a

label var q_firm_emp_pre_spill "Quintile of firm_emp_pre (spillover sample, from 2009 dist.)"
label values q_firm_emp_pre_spill q5

* Optional sanity check
bys identificad: assert q_firm_emp_pre_spill == q_firm_emp_pre_spill[1] if !missing(q_firm_emp_pre_spill)


* generqating ratios
gen p90p10_ratio_dec = lr_remdezr_p90-lr_remdezr_p10
label var p90p10_ratio_dec "90 10 log wage ratio , december wages"

gen p50p10_ratio_dec  = lr_remdezr_p50 - lr_remdezr_p10
label var p90p10_ratio_dec "50 10 log wage ratio , december wages"


gen p90p10_h_ratio_dec = lr_remdezr_h_p90-lr_remdezr_h_p10
label var p90p10_h_ratio_dec "90 10 log hourly wage ratio , december wages"

gen p50p10_h_ratio_dec  = lr_remdezr_h_p50 - lr_remdezr_h_p10
label var p90p10_h_ratio_dec "50 10 log hourly wage ratio , december wages"

* Placebo-year dummy for non-clauses PRE
cap drop placebo_year
gen byte placebo_year = (year<2011)

// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "


cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) 



* Mark CBA periods (as in your script)
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date==earliest2009_avg-1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date==second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==.
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==.
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==.
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==.

cap drop pre_treat_cba post_treat_cba
gen pre_treat_cba  = cba_period<2 if !missing(cba_period)
gen post_treat_cba = cba_period>2 if !missing(cba_period)



* Run regression loop:
eststo clear
local outcomes "lr_remdezr_h l_firm_emp numb_clauses p90p10_h_ratio_dec p50p10_h_ratio_dec lr_remdezr_h_p10 lr_remdezr_h_p90"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"
local WIN_PRE "(inrange(year,2009,2011))"
local WIN_POST "(inrange(year,2009,2016))"
local FEYPRE        "identificad treat_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year"
local FEYPOST       "identificad placebo_year industry1#year mode_base_month#year microregion#year"
local FEPOSTCBA  "identificad post_treat_cba industry1#cba_period mode_base_month#cba_period microregion#cba_period"
local FEPRECBA   "identificad pre_treat_cba  industry1#cba_period  mode_base_month#cba_period  microregion#cba_period"

local estnum =1

foreach y in `outcomes'{
	
	if `y' != numb_clauses {
		eststo est`estnum': reghdfe `y' i.treat_ultra##i.treat_year ///
    if (`s_direct') & `WIN_POST', absorb(`FEYPOST' totalflows_n#treat_year) vce(cluster identificad)
local ++estnum

eststo est`estnum': reghdfe `y' i.treat_ultra##i.placebo_year ///
    if (`s_direct') & `WIN_PRE', absorb(`FEYPRE' totalflows_n#placebo_year) vce(cluster identificad)
local ++estnum
	}
	else {
		//             * ---------- DIRECT ----------
            eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.post_treat_cba ///
                if (`s_direct') & !missing(cba_period) & `WIN_POST', ///
                absorb(`FEPOSTCBA' ) vce(cluster identificad)
            local ++estnum

            eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.pre_treat_cba ///
                if (`s_direct') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
                absorb(`FEPRECBA' ) vce(cluster identificad)
            local ++estnum
	}
}

esttab using "$tables/direct_effects_conncons_year_level.csv", replace ///
                     keep(1.treat_ultra#1.treat_year 1.treat_ultra#1.placebo_year ///
         1.treat_ultra#1.post_treat_cba 1.treat_ultra#1.pre_treat_cba) ///
    se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3)
	
	

	
	* --- SPILLOVER EFFECTS --- *
	
	* Run regression loop:
eststo clear
local outcomes "lr_remdezr_h l_firm_emp numb_clauses p90p10_h_ratio_dec p50p10_h_ratio_dec lr_remdezr_h_p10 lr_remdezr_h_p90"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"
local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
local conn totaltreat_pw_norm
local WIN_PRE "(inrange(year,2009,2011))"
local WIN_POST "(inrange(year,2009,2016))"
local FEYPRE        "identificad treat_year industry1#year mode_base_month#year microregion#year"
local FEYPOST       "identificad placebo_year industry1#year mode_base_month#year microregion#year"
local FEPOSTCBA  "identificad post_treat_cba industry1#cba_period mode_base_month#cba_period microregion#cba_period"
local FEPRECBA   "identificad pre_treat_cba  industry1#cba_period  mode_base_month#cba_period  microregion#cba_period"

local estnum =1

foreach y in `outcomes'{
	
	if `y' != numb_clauses {
		eststo est`estnum': reghdfe `y' c.`conn'##i.treat_year ///
    if (`s_spill') & `WIN_POST', absorb(`FEYPOST' totalflows_n#year) vce(cluster identificad)
local ++estnum

eststo est`estnum': reghdfe `y' c.`conn'##i.placebo_year ///
    if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' totalflows_n#year) vce(cluster identificad)
local ++estnum
	}
	else {
		//             * ---------- DIRECT ----------
            eststo est`estnum': reghdfe numb_clauses c.`conn'#i.post_treat_cba ///
                if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
                absorb(`FEPOSTCBA' totalflows_n#cba_period) vce(cluster identificad)
            local ++estnum

            eststo est`estnum': reghdfe numb_clauses c.`conn'##i.pre_treat_cba ///
                if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
                absorb(`FEPRECBA' totalflows_n#cba_period) vce(cluster identificad)
            local ++estnum
	}
}

esttab using "$tables/spillover_effects_conncons_year.csv", replace ///
                     keep(1.treat_year#c.`conn'       1.placebo_year#c.`conn' ///
         1.post_treat_cba#c.`conn'      1.pre_treat_cba#c.`conn'   ) ///
    se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3)
	
	
	
	
	* Run regression loop:
eststo clear
local outcomes "p90p10_ratio_dec"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"
local WIN_PRE "(inrange(year,2009,2011))"
local WIN_POST "(inrange(year,2009,2016))"
local FEYPRE        "identificad treat_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year"
local FEYPOST       "identificad placebo_year industry1#year mode_base_month#year microregion#year"
local FEPOSTCBA  "identificad post_treat_cba industry1#cba_period mode_base_month#cba_period microregion#cba_period"
local FEPRECBA   "identificad pre_treat_cba  industry1#cba_period  mode_base_month#cba_period  microregion#cba_period"

local estnum =1

foreach y in `outcomes'{
	
	if `y' != numb_clauses {
		eststo est`estnum': reghdfe `y' i.treat_ultra##i.treat_year ///
    if (`s_direct') & `WIN_POST', absorb(`FEYPOST' totalflows_n#treat_year) vce(cluster identificad)
local ++estnum

eststo est`estnum': reghdfe `y' i.treat_ultra##i.placebo_year ///
    if (`s_direct') & `WIN_PRE', absorb(`FEYPRE' totalflows_n#placebo_year) vce(cluster identificad)
local ++estnum
	}
	else {
		//             * ---------- DIRECT ----------
            eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.post_treat_cba ///
                if (`s_direct') & !missing(cba_period) & `WIN_POST', ///
                absorb(`FEPOSTCBA' ) vce(cluster identificad)
            local ++estnum

            eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.pre_treat_cba ///
                if (`s_direct') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
                absorb(`FEPRECBA' ) vce(cluster identificad)
            local ++estnum
	}
}

