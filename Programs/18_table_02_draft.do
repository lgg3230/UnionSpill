 *******************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: GEnerating Regression Tables for distribution Effects
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

// use "$rais_firm/labor_analysis_sample_aug6.dta", clear

// keep if year>=2009

use "$rais_firm/lagos_sample_sep24_pct.dta", clear

keep if lagos_sample_avg==1 & year>=2009

gen placebo_year = cond(year<2011, 1,0)

gen p90p10_ratio_dec = lr_remdezr_p90-lr_remdezr_p10
label var p90p10_ratio_dec "90 10 log wage ratio , december wages"

gen p50p10_ratio_dec  = lr_remdezr_p50 - lr_remdezr_p10
label var p90p10_ratio_dec "50 10 log wage ratio , december wages"


gen p90p10_h_ratio_dec = lr_remdezr_h_p90-lr_remdezr_h_p10
label var p90p10_h_ratio_dec "90 10 log hourly wage ratio , december wages"

gen p50p10_h_ratio_dec  = lr_remdezr_h_p50 - lr_remdezr_h_p10
label var p90p10_h_ratio_dec "50 10 log hourly wage ratio , december wages"



local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "


cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) 

cap drop intreat_pw_n_p90
cap drop intreat_pw_norm
sum intreat_pw_n if `s_spill' & year==2009, detail
gen intreat_pw_n_p90 = r(p90)
gen intreat_pw_norm = (intreat_pw_n / intreat_pw_n_p90) 

cap drop outtreat_pw_n_p90
cap drop outtreat_pw_norm
sum outtreat_pw_n if `s_spill' & year==2009, detail
gen outtreat_pw_n_p90 = r(p90)
gen outtreat_pw_norm = (outtreat_pw_n / outtreat_pw_n_p90) 


// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
cap drop totaltreat_pw_norm
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) 

* Mark the CBA periods
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date==earliest2009_avg-1 & !missing(avg_file_date) /* First 2009 CBA */
replace cba_period = 2 if avg_file_date==second_cba_avg & !missing(avg_file_date) /* First renewal */
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==. /* 2013 CBA */
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==. /* 2014 CBA */
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==. /* 2015 CBA */
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==. /* 2016 CBA */



cap drop pre_treat_cba
gen pre_treat_cba = cond(cba_period<2,1,0)


cap drop post_treat_cba
gen post_treat_cba = cond(cba_period>2,1,0) if !missing(cba_period)





// Overall sample - Wages

local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1)"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_norm
local outcomes "lr_remdezr_h l_firm_emp p90p10_ratio_dec p50p10_ratio_dec"
local tvfe_pre " identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year "
local tvfe_pos "identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year "


// Spillover Effects -- 
						
eststo clear

local estnum =1

foreach outcome in `outcomes' {
	



// Spillover Effects - -

// post treat coefficient
eststo est`estnum': reghdfe `outcome' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
        absorb(`tvfe_pos') ///
        vce(cluster identificad)
local ++estnum


// placebo coefficient
eststo est`estnum': reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre') ///
        vce(cluster identificad)
local ++estnum
}


 esttab using "$tables/table_spill_draft.csv", replace ///
                    keep( ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn') se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3) 
						

// Direct Effects						
						
eststo clear

local estnum =1

foreach outcome in `outcomes' {
	

// post treat coefficient
**# Bookmark #1
eststo est`estnum': reghdfe `outcome' i.treat_ultra##i.treat_year if `s_direct' & year>=2009, ///
        absorb(`tvfe_pos') ///
        vce(cluster identificad)
local ++estnum
**# Bookmark #2

// placebo coefficient
eststo est`estnum': reghdfe `outcome' i.treat_ultra##i.placebo_year treat_ultra##placebo_year if `s_direct' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre') ///
        vce(cluster identificad)
local ++estnum


}


esttab using "$tables/table_dir_draft.csv", replace ///
                    keep( ///
                        1.treat_ultra#1.treat_year  1.treat_ultra#1.placebo_year ) se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3) 
						
//  Number of clauses 

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local tvfe_pre_cba " identificad pre_treat_cba industry1#pre_treat_cba mode_base_month#pre_treat_cba microregion#pre_treat_cba  "
local tvfe_pos_cba "identificad post_treat_cba industry1#post_treat_cba mode_base_month#post_treat_cba microregion#post_treat_cba totalflows_n#post_treat_cba "
local conn totaltreat_pw_norm
	
	
eststo clear

local estnum =1

// Direct Effects -- Number of Clauses

// post treat coefficient
eststo est`estnum': reghdfe numb_clauses treat_ultra##i.post_treat_cba if `s_spill' & year>=2009, ///
        absorb(`tvfe_pos_cba') ///
        vce(cluster identificad)
local ++estnum


// placebo coefficient
eststo est`estnum': reghdfe numb_clauses treat_ultra##i.pre_treat_cba if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre_cba') ///
        vce(cluster identificad)
local ++estnum


// Spillover Effects - - Number of Clauses 

// post treat coefficient
eststo est`estnum': reghdfe numb_clauses c.`conn'##i.post_treat_cba if `s_spill' & year>=2009, ///
        absorb(`tvfe_pos_cba') ///
        vce(cluster identificad)
local ++estnum


// placebo coefficient
eststo est`estnum': reghdfe numb_clauses c.`conn'##i.pre_treat_cba if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre_cba') ///
        vce(cluster identificad)
local ++estnum


 esttab using "$tables/table_draft_numb_clauses.csv", replace ///
                    keep( ///
                        1.treat_ultra#1.post_treat_cba  1.treat_ultra#1.pre_treat_cba ///
                        1.post_treat_cba#c.`conn'       1.pre_treat_cba#c.`conn') se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3) 
						
						
						

