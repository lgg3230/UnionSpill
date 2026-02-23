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

* Baseline Means:



// Overall sample - Wages

local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1)"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_norm
local outcomes "lr_remdezr_p10 lr_remdezr_p50 lr_remdezr_p90  p90p10_ratio_dec p50p10_ratio_dec"
local tvfe_pre " identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year "
local tvfe_pos "identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year "


* Baseline Means:


foreach outcome in  `outcomes'{
	sum `outcome' if year==2011 & `s_direct'
	sum `outcome' if year==2011 & `s_spill'
}

// Direct Effects - -

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


 esttab using "$tables/Wages_dist_spill.csv", replace ///
                    keep( ///
                        1.treat_ultra#1.treat_year  1.treat_ultra#1.placebo_year ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn') se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3) 
						
						
// Making a test to see if the tvfe are affecting the pre period estimates:


local outcome p50p10_h_ratio_dec
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01| lagos_sample_avg==1 & treat_ultra==1)"
local tvfe_pre " identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year "
local tvfe_pos "identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year "


reghdfe `outcome' i.treat_ultra##i.treat_year if `s_direct' & year>=2009, ///
        absorb(`tvfe_pos') ///
        vce(cluster identificad)

// placebo coefficient
reghdfe `outcome' i.treat_ultra##i.placebo_year if `s_direct' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre') ///
        vce(cluster identificad)
		
		
// test for spillover effects:


local outcome p90p10_ratio_dec
local s_direct "(lagos_sample_avg==1 & treat_ultra==0| lagos_sample_avg==1 & treat_ultra==1)"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local tvfe_pre " identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year "
local tvfe_pos "identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year "
local conn totaltreat_pw_norm


reghdfe `outcome' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
        absorb(`tvfe_pos') ///
        vce(cluster identificad)
		
				// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.4f")
local post_se  = string(_se[1.treat_year#c.`conn'], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.4f")


// placebo coefficient
reghdfe `outcome' c.`conn'##i.placebo_year  if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`tvfe_pre') ///
        vce(cluster identificad)		
		
// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.4f")

reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year totalflows_n#year) ///
        vce(cluster identificad)
estimates store es_spill_remdezr	


local conn totaltreat_pw_norm
coefplot es_spill_remdezr, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
	note("P-value for pre-trend test = `pre_pval' ") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
	text(2 5 "`post_coef' (`post_se')", color(blue))
   
graph export "$graphs/es_remdezr_h_p10_spill_overall_draft.png", as(png) replace                   
				   
				   
				   