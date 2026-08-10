********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Recap of recent results 
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

use "$rais_firm/labor_analysis_sample_aug6.dta", clear

keep if lagos_sample_avg==1

gen placebo_year = cond(year<2011, 1,0)

bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre =  min(firm_emp_pre_o)
drop firm_emp_pre_o

bys identificad (year):  gen avg_emp = (firm_emp+firm_emp[_n-1])/2 if year>=2010

gen turnover_c = separations /avg_emp if year>=2010
replace turnover_c =2* separations / (firm_emp+firm_emp_2008) if year==2009


// Weak evidence of wage spillovers in Lagos's sample:>

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local interactions "am_tn_pre am_lfe am_tf_n"
local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

********************************************************************************
// 1. OVERALL SAMPLE - WEAK POSITIVE SPILLOVER EFFECTS
********************************************************************************

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n

// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// post treat coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)
	
	
// Overall sample - Employment

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment - Overall Sample", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: -0.03, p-v: 0.9 ", color(orange)) /// 
    text(.5 2 "C x Pre Coef: -0.13, p-v: 0.5" , color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_overall.png", as(png) replace	

// Overall sample - Wages
local conn totaltreat_pw_n

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remdezr c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year ) ///
        vce(cluster identificad)

// placebo coefficient
reghdfe lr_remdezr c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year ) ///
        vce(cluster identificad)

	local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
reghdfe lr_remdezr c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year ) ///
        vce(cluster identificad)
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
	ylabel(-.2(.05).35) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Dec Earnings - Overall", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.1 6 "C x Post Coef: 0.17, p-v: .03", color(blue)) ///
    text(.25 2 "C x Pre Coef: 0.06, p-v: .5", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_remdezr_spill_overall.png", as(png) replace

********************************************************************************
// 2. OVERALL SAMPLE WITH MODE_UNION CONTROLS
********************************************************************************

// Overall sample with mode_union - Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year ) ///
        vce(cluster identificad)

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year ) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") /// 
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Overall", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: -.2, p-v: .4", color(orange)) ///
    text(.5 2 "C x Pre Coef: -.3, p-v: .15", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_overall_mu.png", as(png) replace	

// Overall sample with mode_union - Wages
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad)

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n#placebo_year) ///
        vce(cluster identificad)

	local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year totalflows_n#placebo_year ) ///
        vce(cluster identificad)
estimates store es_spill_remdezr	


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
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
	ylabel(-.4(.1).5) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Overall", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.3 6 "C x Post Coef: .18, p-v: .05", color(blue)) ///
    text(.25 2 "C x Pre Coef: -.04, p-v: .66", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remdezr_spill_overall_mu.png", as(png) replace

********************************************************************************
// 3. BELOW MEDIAN FIRMS - POSITIVE SPILLOVER EFFECTS
********************************************************************************

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// Below median totalflows - Employment
local conn totaltreat_pw_n
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)
estimates store es_spill_emp_did_pos

local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

	
// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & totalflows_n<=26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)
estimates store es_spill_emp_did_pre

local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")
	
	
reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	


coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Below Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)	
	
graph export "$graphs/es_emp_spill_bm_tf.png", as(png) replace	

// Below median employment with mode_union - Wages
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Below Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.2 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_bm_emp_mu.png", as(png) replace

********************************************************************************
// 3. BELOW MEDIAN FIRMS - POSITIVE SPILLOVER EFFECTS (MISSING GRAPHS)
********************************************************************************

// Below median totalflows - Wages
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & totalflows_n<=26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Below Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_bm_tf.png", as(png) replace

// Below median employment - Employment
local conn totaltreat_pw_n
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Below Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_bm_emp.png", as(png) replace	

// Below median employment - Wages
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Below Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_bm_emp.png", as(png) replace

********************************************************************************
// 4. BELOW MEDIAN WITH MODE_UNION - RESULTS MAINTAINED (MISSING GRAPHS)
********************************************************************************

// Below median totalflows with mode_union - Employment
local conn totaltreat_pw_n
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & totalflows_n<=26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Below Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_bm_tf_mu.png", as(png) replace	

// Below median totalflows with mode_union - Wages
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & totalflows_n<=26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & totalflows_n<=26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Below Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_bm_tf_mu.png", as(png) replace

// Below median employment with mode_union - Employment
local conn totaltreat_pw_n
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Below Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.5 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_bm_emp_mu.png", as(png) replace

********************************************************************************
// 5. ABOVE MEDIAN - NEGATIVE EFFECTS ONLY WITH MODE_UNION
********************************************************************************

// Above median totalflows WITHOUT mode_union - Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & totalflows_n>26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & totalflows_n>26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & totalflows_n>26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.5)2) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Above Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-1.25 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(1.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_am_tf.png", as(png) replace	

// Above median totalflows WITHOUT mode_union - Wages
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & totalflows_n>26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & totalflows_n>26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & totalflows_n>26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Above Median TotalFlows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_am_tf.png", as(png) replace

// Above median employment WITHOUT mode_union - Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_emp	
	
coefplot es_spill_emp, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(.5)2) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Employment - Above Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
    text(-1 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_am_emp.png", as(png) replace	

// Above median employment WITHOUT mode_union - Wages
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
	ylabel(-.4(.1).8) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Earnings - Above Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_am_emp.png", as(png) replace

// Above median totalflows WITH mode_union - Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & totalflows_n>26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & totalflows_n>26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & totalflows_n>26, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
        vce(cluster identificad)
estimates store es_spill_emp		

coefplot es_spill_emp, ///
   keep(*#*c.`conn') ///
   coeflabels(2009.year#c.`conn' = "2009" ///
              2010.year#c.`conn' = "2010" ///
              2011.year#c.`conn' = "2011" ///
              2012.year#c.`conn' = "2012" ///
              2013.year#c.`conn' = "2013" ///
              2014.year#c.`conn' = "2014" ///
              2015.year#c.`conn' = "2015" ///
              2016.year#c.`conn' = "2016") ///
   vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
   ylabel(-3.5(.5)3) ///
   ytitle("Dynamic DiD coefficients", size(small)) ///
   title("Spillover Effect on Employment - Above Median TotalFlows", size(medium large)) ///
   note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
   graphregion(color(white)) bgcolor(white) ///
   text(-2 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
   text(2 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
   ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
   
graph export "$graphs/es_emp_spill_am_tf_mu.png", as(png) replace	

// Above median totalflows WITH mode_union - Wages
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & totalflows_n>26, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & totalflows_n>26 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & totalflows_n>26, ///
       absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
       vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
   ylabel(-2(.25).75) ///
   ytitle("Dynamic DiD coefficients", size(small)) ///
   title("Spillover Effect on Earnings - Above Median TotalFlows", size(medium large)) ///
   note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
   graphregion(color(white)) bgcolor(white) ///
   text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
   text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
   ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_am_tf_mu.png", as(png) replace

// Above median employment WITH mode_union - Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe l_firm_emp c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe l_firm_emp c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe l_firm_emp c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
       absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
       vce(cluster identificad)
estimates store es_spill_emp	
   
coefplot es_spill_emp, ///
   keep(*#*c.`conn') ///
   coeflabels(2009.year#c.`conn' = "2009" ///
              2010.year#c.`conn' = "2010" ///
              2011.year#c.`conn' = "2011" ///
              2012.year#c.`conn' = "2012" ///
              2013.year#c.`conn' = "2013" ///
              2014.year#c.`conn' = "2014" ///
              2015.year#c.`conn' = "2015" ///
              2016.year#c.`conn' = "2016") ///
   vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
   ylabel(-1.5(.2)1) ///
   ytitle("Dynamic DiD coefficients", size(small)) ///
   title("Spillover Effect on Employment - Above Median Employment", size(medium large)) ///
   note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
   graphregion(color(white)) bgcolor(white) ///
   text(.5 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(orange)) ///
   text(.5 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(orange)) ///
   ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
   
graph export "$graphs/es_emp_spill_am_emp_mu.png", as(png) replace	

// Above median employment WITH mode_union - Wages
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
       absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
       vce(cluster identificad)
estimates store es_spill_remmedr	

coefplot es_spill_remmedr, ///
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
  ylabel(-.4(.1).8) ///
  ytitle("Dynamic DiD coefficients", size(small)) ///
  title("Spillover Effect on Earnings - Above Median Employment", size(medium large)) ///
  note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
  graphregion(color(white)) bgcolor(white) ///
  text(.6 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
  text(.6 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
  ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_remmedr_spill_am_emp_mu.png", as(png) replace
//



// Direct effects on hiring and retention

// Direct Effect on Hiring
// post treat coefficient
reghdfe hiring_lagos treat_ultra##treat_year if in_balanced_panel==1, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

// placebo coefficient
reghdfe hiring_lagos treat_ultra##placebo_year if in_balanced_panel==1 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

reghdfe hiring_lagos treat_ultra##b(2011).year if in_balanced_panel==1, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store ed_hiring

coefplot ed_hiring, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Hiring Rate", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.05 6 "Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.05 2 "Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/ed_hiring.png", as(png) replace

// Direct Effect on Retention
// post treat coefficient
reghdfe retention_c treat_ultra##treat_year if in_balanced_panel==1, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

// placebo coefficient
reghdfe retention_c treat_ultra##placebo_year if in_balanced_panel==1 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

reghdfe retention_c treat_ultra##b(2011).year if in_balanced_panel==1, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store ed_retention	

coefplot ed_retention, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.005).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Retention Rate", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.015 6 "Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.015 2 "Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/ed_retention.png", as(png) replace

// Spillover effects on hiring and retention

// Spillover Effect on Hiring
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n

// post treat coefficient
reghdfe hiring_lagos c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe hiring_lagos c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe hiring_lagos c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_hiring	

coefplot es_spill_hiring, ///
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
	ylabel(-2(.5)3) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Hiring Rate - Overall Sample", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(2 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(2 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_hiring_spill_overall.png", as(png) replace

// Spillover Effect on Retention
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n

// post treat coefficient
reghdfe retention_c c.`conn'##treat_year if `s_spill', ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_pre#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe retention_c c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_pre#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe retention_c c.`conn'##b(2011).year if `s_spill', ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year firm_emp_pre#year) ///
        vce(cluster identificad)
estimates store es_spill_retention

coefplot es_spill_retention, ///
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
	ylabel(-.5(.1).5) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Retention Rate - Overall Sample", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_retention_spill_overall.png", as(png) replace



// Spillover Effect on Hiring - Above Median Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
// post treat coefficient
reghdfe hiring_lagos c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe hiring_lagos c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe hiring_lagos c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
        vce(cluster identificad)
estimates store es_spill_hiring_am_emp	

coefplot es_spill_hiring_am_emp, ///
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
	ylabel(-4(1)10) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Hiring Rate - Above Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(2 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(2 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_hiring_spill_am_emp.png", as(png) replace

// Above median firms are the ones hiring less

// Spillover Effect on Retention - Above Median Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe retention_c c.`conn'##treat_year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_pre#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe retention_c c.`conn'##placebo_year if `s_spill' & firm_emp_pre>29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_pre#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe retention_c c.`conn'##b(2011).year if `s_spill' & firm_emp_pre>29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year firm_emp_pre#year) ///
        vce(cluster identificad)
estimates store es_spill_retention_am_emp

coefplot es_spill_retention_am_emp, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///s
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.5(.1).5) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Retention Rate - Above Median Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_retention_spill_am_emp.png", as(png) replace


// Extra Exercises: Bassier connectivity measures -- According to Bassier, the connectivity measure that should count is the proportion of your hiring that is made with the 
gen intreat_pft1 = intreat_n/(intreat_n + outtreat_n)
gen outtreat_pft1 = outtreat_n/(intreat_n + outtreat_n)

gen intreat_pf_n = intreat_n/totalflows_n
gen outtreat_pf_n = outtreat_n/totalflows_n




// Are the firms with more inflows the same with more outflows?
// If not: then there is some ordering between firms of the treatment and control
// actual ordering depends on whether the in(out)flows were voluntary or involuntary
// If yes: then there is no clear ordering of firms between treatment and control

reg intreat_pf_n outtreat_pf_n firm_emp_pre totalflows_n lr_remdezr i.big_industry i.microregion if year==2009 & treat_ultra==0

// actually what we are trying to disentangle is wheter the effects we are observing are responses from firms or from 


// Spillover Effect on Retention - Below  Median Employment - In vs Outflows
local conn intreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe lr_remdezr c.`conn'##treat_year if `s_spill' , ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year c.totaltreat_pw_n#treat_year ) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remdezr c.`conn'##placebo_year if `s_spill'  & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year c.totaltreat_pw_n#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

local conn outtreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
reghdfe lr_remdezr c.`conn'##b(2011).year if `s_spill' , ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year c.totaltreat_pw_n#year ) ///
        vce(cluster identificad)
estimates store es_spill_remmedr_am_emp

// local conn totaltreat_pw_n
coefplot es_spill_remmedr_am_emp, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///s
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.5(.1).5) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Avg Earning - Small, Inflows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_remmedr_inflw_bm_emp.png", as(png) replace


// Spillover Effect on Retention - Above Median Employment
local conn outtreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe lr_remmedr c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_pre#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe lr_remmedr c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_pre#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe lr_remmedr c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year firm_emp_pre#year) ///
        vce(cluster identificad)
estimates store es_spill_remmedr_am_emp

coefplot es_spill_remmedr_am_emp, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///s
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(.25)1.75) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Avg Earnings - Small, Outflows", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_remmedr_outflw_bm_emp.png", as(png) replace


// Spillover Effect on Retention and Hiring - Below  Median Employment 
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe hiring_lagos c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_pre#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe hiring_lagos c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_pre#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe hiring_lagos c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year firm_emp_pre#year) ///
        vce(cluster identificad)
estimates store es_spill_hiring_am_emp


coefplot es_spill_hiring_am_emp, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///s
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-6(1)7) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Hiring - Small Firms", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_hiring_spill_bm_emp.png", as(png) replace


// Spillover Effect on Retention - Below Median Employment
local conn totaltreat_pw_n
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

// post treat coefficient
reghdfe retention_c c.`conn'##treat_year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_pre#treat_year) ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")

// placebo coefficient
reghdfe retention_c c.`conn'##placebo_year if `s_spill' & firm_emp_pre<=29.83333 & year<=2011, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_pre#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

reghdfe retention_c c.`conn'##b(2011).year if `s_spill' & firm_emp_pre<=29.83333, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year firm_emp_pre#year) ///
        vce(cluster identificad)
estimates store es_spill_rentention_bm_emp

coefplot es_spill_retention_bm_emp, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///s
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(.25)1.75) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Retention - Small Firms", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(.3 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.3 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_retention_spill_bm_emp.png", as(png) replace


