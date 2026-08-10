
* ===============================
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: worker level regressions and study on new hires and incumbents
* INPUT:   worker level dataset, with measures of new hires ant incumbest
* OUTPUT:  Regression tables with incumbents vs new hires specs
********************************************************************************

// use "$rais_firm/labor_analysis_sample_aug6.dta", clear

// keep if year>=2009

use "$rais_firm/worker_year_pre_new_vs_nonnew.dta", clear

* Generate indicators for presence in each required year
forvalues y = 2009/2016 {
    gen has_year_`y' = 0
    bysort identificad_w: replace has_year_`y' = 1 if inlist(`y', year)
    bysort identificad_w: egen present_in_`y' = max(has_year_`y')
}

* Generate the balanced panel indicator - a unit is in the balanced panel 
* only if it appears in EVERY year from 2009-2016
gen in_balanced_panel = cond(present_in_2009 == 1 & present_in_2010 == 1 & ///
                         present_in_2011 == 1 & present_in_2012 == 1 & ///
                         present_in_2013 == 1 & present_in_2014 == 1 & ///
                         present_in_2015 == 1 & present_in_2016 == 1,1,0)
						 
* Clean up temporary variables
drop has_year_* present_in_*

// keep if 

gen placebo_year = cond(year<2011, 1,0)


bys identificad_w: egen firm_emp_pre_o = mean(firm_emp) if year<=2011 & year>=2009
bys identificad_w: egen firm_emp_pre =  min(firm_emp_pre_o)

capture drop firm_emp_pre_2009_a 
	capture drop firm_emp_pre_2009
	cap drop firm_emp_pre_2009_5_a
	cap drop firm_emp_pre_2009_5 // -> checks if var already there to allow for easy change of definition
	gen firm_emp_pre_2009_a = firm_emp_pre if year==2009 // -> auxiliary var to get 2009 value
	bys identificad_w: egen  firm_emp_pre_2009 = max(firm_emp_pre_2009_a) // -> expand 2009 to all years
	drop firm_emp_pre_2009_a // -> drops auxiliary var
	egen firm_emp_pre_2009_5_a = cut(firm_emp_pre_2009) if year==2009 & treat_ultra==0,group(5) // generates quintiles for the variables
	bys identificad_w: egen firm_emp_pre_2009_5 = min(firm_emp_pre_2009_5_a)
	drop firm_emp_pre_2009_5_a

cap drop avg_emp
bys identificad_w (year):  gen avg_emp = (firm_emp+firm_emp[_n-1])/2 if year>=2010

gen pos_conn_pw = cond(totaltreat_pw_n>0,1,0)

cap drop totaltreat_pw_n_med
sum totaltreat_pw_n if year==2009 &  treat_ultra==0 , detail
gen totaltreat_pw_n_med = r(p50)

gen large_conn_pw = cond(totaltreat_pw_n>=totaltreat_pw_n_med, 1,0)

destring industry1, replace force


// gen turnover_c = separations /avg_emp if year>=2010
// replace turnover_c =2* separations / (firm_emp+firm_emp_2008) if year==2009

cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
bys identificad_w: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if year<=2011
bys identificad_w: egen lr_remdezr_w_pre = min(lr_remdezr_w_pre_o)

* ===============================
* Quintiles of firm_emp_pre by sample
* ===============================

* Define samples (matching your specs)
cap macro drop s_direct
local s_direct "( treat_ultra==0 & totaltreat_pw_n<0.01 |  & treat_ultra==1) "

cap macro drop s_spill
local s_spill "  treat_ultra==0"

* ====================*===========
* Sample definitions
* ===============================
cap macro drop s_direct
local s_direct "( treat_ultra==0 & totaltreat_pw_n<0.01 |  treat_ultra==1)"

cap macro drop s_spill
local s_spill  "  treat_ultra==0 "

cap label define q5 1 "Q1 (smallest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (largest)"

* ===============================
* DIRECT sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_direct_a
cap drop q_firm_emp_pre_direct

egen q_firm_emp_pre_direct_a = cut(firm_emp_pre) if year==2009 & `s_direct', group(5)
bys identificad_w: egen q_firm_emp_pre_direct = min(q_firm_emp_pre_direct_a)
drop q_firm_emp_pre_direct_a

label var q_firm_emp_pre_direct "Quintile of firm_emp_pre (direct sample, from 2009 dist.)"
label values q_firm_emp_pre_direct q5

* Optional sanity check: constant within firm where defined
bys identificad_w: assert q_firm_emp_pre_direct == q_firm_emp_pre_direct[1] if !missing(q_firm_emp_pre_direct)

* ===============================
* SPILLOVER sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_spill_a
cap drop q_firm_emp_pre_spill

egen q_firm_emp_pre_spill_a = cut(firm_emp_pre) if year==2009 & `s_spill', group(5)
bys identificad_w: egen q_firm_emp_pre_spill = min(q_firm_emp_pre_spill_a)
drop q_firm_emp_pre_spill_a

label var q_firm_emp_pre_spill "Quintile of firm_emp_pre (spillover sample, from 2009 dist.)"
label values q_firm_emp_pre_spill q5

* Optional sanity check
bys identificad_w: assert q_firm_emp_pre_spill == q_firm_emp_pre_spill[1] if !missing(q_firm_emp_pre_spill)


* ===============================
* Quintiles of firm_emp_pre by sample
* ===============================

* Define samples (matching your specs)
cap macro drop s_direct
local s_direct "(treat_ultra==0 & totaltreat_pw_n<0.01 |  & treat_ultra==1) "

cap macro drop s_spill
local s_spill "  treat_ultra==0"

* ====================*===========
* Sample definitions
* ===============================
cap macro drop s_direct
local s_direct "( treat_ultra==0 & totaltreat_pw_n<0.01 |  treat_ultra==1)"

cap macro drop s_spill
local s_spill  "  treat_ultra==0 "

cap label define q5 1 "Q1 (smallest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (largest)"

* ===============================
* DIRECT sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_direct_a
cap drop q_firm_emp_pre_direct

egen q_firm_emp_pre_direct_a = cut(firm_emp_pre) if year==2009 & `s_direct', group(5)
bys identificad_w: egen q_firm_emp_pre_direct = min(q_firm_emp_pre_direct_a)
drop q_firm_emp_pre_direct_a

label var q_firm_emp_pre_direct "Quintile of firm_emp_pre (direct sample, from 2009 dist.)"
label values q_firm_emp_pre_direct q5

* Optional sanity check: constant within firm where defined
bys identificad_w: assert q_firm_emp_pre_direct == q_firm_emp_pre_direct[1] if !missing(q_firm_emp_pre_direct)

* ===============================
* SPILLOVER sample quintiles (2009)
* ===============================
cap drop q_firm_emp_pre_spill_a
cap drop q_firm_emp_pre_spill

egen q_firm_emp_pre_spill_a = cut(firm_emp_pre) if year==2009 & `s_spill', group(5)
bys identificad_w: egen q_firm_emp_pre_spill = min(q_firm_emp_pre_spill_a)
drop q_firm_emp_pre_spill_a

label var q_firm_emp_pre_spill "Quintile of firm_emp_pre (spillover sample, from 2009 dist.)"
label values q_firm_emp_pre_spill q5

* Optional sanity check
bys identificad_w: assert q_firm_emp_pre_spill == q_firm_emp_pre_spill[1] if !missing(q_firm_emp_pre_spill)




cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)

// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)


* ---------------------------------
* Cheking if worker level data is right:
* ---------------------------------

// Collapse to the firm level
//
// tostring year, generate(year_str)
//
// gen cnpj_y = identificad_w + year_str
//
// collapse (firstnm) year microregion mode_base_month industry1 totalflows_n totaltreat_pw_n identificad_w treat_ultra treat_year placebo_year firm_emp_pre totaltreat_pw_norm in_balanced_panel (mean) lr_remdezr_w lr_remmedr_w, by(cnpj_y)
//
// save "$rais_aux/worker_lagos_firm_test.dta", replace
//
// use "$rais_firm/lagos_sample_sep24.dta", clear
//
// tostring year, generate(year_str)
//
// gen cnpj_y = identificad + year_str
//
// merge 1:1 cnpj_y using "$rais_aux/worker_lagos_firm_test.dta"

// apparently the difference is due to in_balanced_panel -> in large part is, coefficients are suff. close

* ===============================
// Overall sample - WAges
* ===============================

gen new_hire = cond(year<=2011|new_hire_after2011==1,1,0)
gen incumbent = cond(year<=2011|new_hire_after2011==0,1,0)
gen new_hire_adj = new_hire
replace new_hire_adj = 0 if year<=2011


// Overall sample - Wages
local s_direct "( treat_ultra==0 & totaltreat_pw_n<0.01 & lagos_sample_avg==1|  treat_ultra==1 & lagos_sample_avg==1)"

local s_spill " treat_ultra==0 & in_balanced_panel==1"
local conn totaltreat_pw_norm
local outcome lr_remdezr_w
// gen weight_reg = 1/firm_emp

// post treat coefficient
reghdfe `outcome' ///
		c.`conn'##treat_year  /// 
		if `s_spill' & year>=2009  , ///
        absorb(identificad_w treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad_w)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

local s_spill " treat_ultra==0 & in_balanced_panel==1"
local conn totaltreat_pw_norm
local outcome lr_remdezr_w
// placebo coefficient
reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011 & year>=2009 , ///
        absorb(identificad_w placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year ) ///
        vce(cluster identificad_w)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")
 
 
//  preserve
//  keep if year>=2011
 
		
// 	local s_spill " &  treat_ultra==0 "
// reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
//         absorb(identificad_w year industry1#year mode_base_month#year microregion#year totalflows_n#year) ///
//         vce(cluster identificad_w)
// // 		gen emp_sample = e(sample)	
// estimates store es_spill_remdezr	
//
// coefplot es_spill_remdezr, ///
//     keep(*#*c.`conn') ///
//     msymbol(diamond) ///
//     coeflabels(2009.year#c.`conn' = "2009" ///
//                2010.year#c.`conn' = "2010" ///
//                2011.year#c.`conn' = "2011" ///
//                2012.year#c.`conn' = "2012" ///
//                2013.year#c.`conn' = "2013" ///
//                2014.year#c.`conn' = "2014" ///
//                2015.year#c.`conn' = "2015" ///
//                2016.year#c.`conn' = "2016") ///
//     vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
// 	ylabel(-.2(.1).5) ///
// 	ytitle("Dynamic DiD coefficients", size(small)) ///
//     title("Spillover Effect on Dec Earnings - Overall", size(medium large)) ///
//     note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
//     graphregion(color(white)) bgcolor(white) ///
//     text(-.1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
//     text(.25 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
//     ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
//    
// graph export "$graphs/es_remdezr_spill_overall.png", as(png) replace

* ===============================
// Overall sample - WAges - new hires after 2011
* ===============================

// Overall sample - Wages

// gen new_hire = cond(year<=2011|new_hire_after2011==1,1,0)
// gen incumbent = cond(year<=2011|new_hire_after2011==0,1,0)

// Overall sample - Wages
local s_direct "( treat_ultra==0 & totaltreat_pw_n<0.01 & lagos_sample_avg==1|  treat_ultra==1 & lagos_sample_avg==1)"

local s_spill " treat_ultra==0 & in_balanced_panel==1"
local conn totaltreat_pw_norm
local outcome lr_remdezr_w
// gen weight_reg = 1/firm_emp


// post treat coefficient
reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009 & incumbent==1 , ///
        absorb(identificad_w treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad_w)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011 & year>=2009 & incumbent==1, ///
        absorb(identificad_w placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year ) ///
        vce(cluster identificad_w)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

		
	local s_spill " treat_ultra==0 & in_balanced_panel==1"
reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & year>=2009 & incumbent==1, ///
        absorb(identificad_w year industry1#year mode_base_month#year microregion#year totalflows_n#year) ///
        vce(cluster identificad_w)
// 		gen emp_sample = e(sample)	
estimates store es_spill_remdezr	

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
	ylabel(-.2(.1).5) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Dec Earnings - New Hires", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.25 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
   
graph export "$graphs/es_remdezr_spill_newhire.png", as(png) replace


* ===============================
// Overall sample - WAges - incumbents
* ===============================

// Overall sample - Wages

local s_spill "  treat_ultra==0 "
local conn totaltreat_pw_norm
local outcome avg_lr_remdezr_w_pre_or_nonnew

// post treat coefficient
reghdfe `outcome' ///
		
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009, ///
        absorb(identificad_w treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad_w)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")


// placebo coefficient
reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011 & year>=2009, ///
        absorb(identificad_w placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year ) ///
        vce(cluster identificad_w)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

		
// 	local s_spill " &  treat_ultra==0 "
// reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
//         absorb(identificad_w year industry1#year mode_base_month#year microregion#year totalflows_n#year) ///
//         vce(cluster identificad_w)
// // 		gen emp_sample = e(sample)	
// estimates store es_spill_remdezr	
//
// coefplot es_spill_remdezr, ///
//     keep(*#*c.`conn') ///
//     msymbol(diamond) ///
//     coeflabels(2009.year#c.`conn' = "2009" ///
//                2010.year#c.`conn' = "2010" ///
//                2011.year#c.`conn' = "2011" ///
//                2012.year#c.`conn' = "2012" ///
//                2013.year#c.`conn' = "2013" ///
//                2014.year#c.`conn' = "2014" ///
//                2015.year#c.`conn' = "2015" ///
//                2016.year#c.`conn' = "2016") ///
//     vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
// 	ylabel(-.2(.1).5) ///
// 	ytitle("Dynamic DiD coefficients", size(small)) ///
//     title("Spillover Effect on Dec Earnings - Incumbents", size(medium large)) ///
//     note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
//     graphregion(color(white)) bgcolor(white) ///
//     text(-.1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
//     text(.25 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
//     ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
//    
// graph export "$graphs/es_remdezr_spill_incumbent.png", as(png) replace
