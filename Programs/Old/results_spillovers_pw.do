********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: SPILLOVER EFFECTS ESTIMATES ON WAGES/EMPLOYMENT, WITH CONNECTIVITY MEASURED AS FLOW COUNTS (ROUGH MEASURE)
* INPUT: MERGED CBA RAIS, WITH CONNECTIVITY MEASURES
* OUTPUT:TWFE ESTIMATES FOR ROUGHT SPILLOVER EFFECTS 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016.dta",clear 

// keep high_treat lr_remdezr lr_remmedr l_firm_emp year microregion industry1 mode_union identificad mode_base_month high_t_top10 in_balanced_panel top10_linklagos


// SAMPLE DEFINITIONS

//  NOT IN LAGOS SAMPLE, BALANCED PANEL AND NO DIRECLTY TREAT

// we generate first and then replace latter because if we wanna change the definition of the variable, we just hit replace. And doing this way ensures that when we run the code for the first time the variables are correctly labelled.

// samples without treated and direct effects sample

gen sample_00 =0
gen sample_001_tpf =0
gen sample_000_tpf =0
gen sample_001_tpw =0
gen sample_000_tpw =0


replace sample_00      = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0,1,0)

replace sample_001_tpf = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 & totaltreat_pf> 0,1,0)

replace sample_000_tpf = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 & totaltreat_pf==0,1,0)

replace sample_001_tpw = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 & totaltreat_pw> 0,1,0)

replace sample_000_tpw = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 & totaltreat_pw==0,1,0)


// samples without treated, but with direct effects sample

gen sample_01=0
gen sample_011_tpf =0
gen sample_010_tpf =0
gen sample_011_tpw =0
gen sample_010_tpw =0


replace sample_01      = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==1,1,0)

replace sample_011_tpf = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pf> 0,1,0)

replace sample_010_tpf = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pf==0,1,0)

replace sample_011_tpw = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pw> 0,1,0)

replace sample_010_tpw = cond(treat_ultra==0 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pw==0,1,0)


// samples with treated, and direct effects sample

gen sample_11=0
gen sample_111_tpf =0
gen sample_110_tpf =0
gen sample_111_tpw =0
gen sample_110_tpw =0


replace sample_11      = cond(treat_ultra==1 & in_balanced_panel==1 & lagos_sample==1,1,0)

replace sample_111_tpf = cond(treat_ultra==1 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pf> 0,1,0)

replace sample_110_tpf = cond(treat_ultra==1 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pf==0,1,0)

replace sample_111_tpw = cond(treat_ultra==1 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pw> 0,1,0)

replace sample_110_tpw = cond(treat_ultra==1 & in_balanced_panel==1 & lagos_sample==1 & totaltreat_pw==0,1,0)


////////////////////////////////////////////////////////////////////////////////
**# Bookmark #1
// connectiivity measure: flows to treat as a percentage of total flows 
// EXCLUDES THOSE BELONGING TO LAGOS SAMPLE
// EXCLUDES THOSE DIRECTLY AFFECTED BY ULTRACTIVITY CLAUSE


// I. Tables estimates:

// I.a December wages
eststo: qui reghdfe lr_remdezr c.totaltreat_pf##b(2011).year  if   ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remdezr
    
// I.b Average wages    
eststo: qui reghdfe lr_remmedr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remmedr

// I.c log Employment
eststo: qui reghdfe l_firm_emp c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_emp
    
esttab,  replace keep(*.year#*c.totaltreat_pf) 



// II. Event Studies Graphs:

// II.a December wages:
reghdfe lr_remdezr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad industry1#year mode_base_month#year microregion#year ) vce(cluster identificad)
estimates store es_spillover_remdezr

// Create event study plot
coefplot es_spillover_remdezr, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_remdezr.png", as(png) replace

// II.b Average earnings

reghdfe lr_remmedr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_remmedr

// Create event study plot
coefplot es_spillover_remmedr, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Average Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_remmedr.png", as(png) replace


// II.c Log Employment

reghdfe l_firm_emp c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_emp

// Create event study plot
coefplot es_spillover_emp, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_employment.png", as(png) replace    


**# Bookmark #1
////////////////////////////////////////////////////////////////////////////////
// Using smae specification as above, but with flows to treat per worker (average)
// EXCLUDING THOSE IN LAGOS SAMPLE
// EXCLUDING THOSE DIRECTLY AFFECTED BY ULTRAACTIVITY


// B.I. Tables estimates:

eststo clear
// I.a December wages
eststo: qui reghdfe lr_remdezr c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remdezr
    
// I.b Average wages    
eststo: qui reghdfe lr_remmedr c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remmedr

// I.c log Employment
eststo: qui reghdfe l_firm_emp c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_emp
    
esttab,  replace keep(*.year#*c.totaltreat_pw) 



// B.II. Event Studies Graphs:

// II.a December wages:
qui reghdfe lr_remdezr c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad industry1#year mode_base_month#year microregion#year ) vce(cluster identificad)
estimates store es_spillover_remdezr

// Create event study plot
coefplot es_spillover_remdezr, ///
    keep(*.year#*c.totaltreat_pw) ///
    coeflabels(2009.year#c.totaltreat_pw = "2009" ///
              2010.year#c.totaltreat_pw = "2010" ///
              2011.year#c.totaltreat_pw = "2011" ///
              2012.year#c.totaltreat_pw = "2012" ///
              2013.year#c.totaltreat_pw = "2013" ///
              2014.year#c.totaltreat_pw = "2014" ///
              2015.year#c.totaltreat_pw = "2015" ///
              2016.year#c.totaltreat_pw = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(0.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pw_remdezr.png", as(png) replace

// II.b Average earnings

qui reghdfe lr_remmedr c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_remmedr

// Create event study plot
coefplot es_spillover_remmedr, ///
    keep(*.year#*c.totaltreat_pw) ///
    coeflabels(2009.year#c.totaltreat_pw = "2009" ///
              2010.year#c.totaltreat_pw = "2010" ///
              2011.year#c.totaltreat_pw = "2011" ///
              2012.year#c.totaltreat_pw = "2012" ///
              2013.year#c.totaltreat_pw = "2013" ///
              2014.year#c.totaltreat_pw = "2014" ///
              2015.year#c.totaltreat_pw = "2015" ///
              2016.year#c.totaltreat_pw = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1(0.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Average Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pw_remmedr.png", as(png) replace


// II.c Log Employment

qui reghdfe l_firm_emp c.totaltreat_pw##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_emp

// Create event study plot
coefplot es_spillover_emp, ///
    keep(*.year#*c.totaltreat_pw) ///
    coeflabels(2009.year#c.totaltreat_pw = "2009" ///
              2010.year#c.totaltreat_pw = "2010" ///
              2011.year#c.totaltreat_pw = "2011" ///
              2012.year#c.totaltreat_pw = "2012" ///
              2013.year#c.totaltreat_pw = "2013" ///
              2014.year#c.totaltreat_pw = "2014" ///
              2015.year#c.totaltreat_pw = "2015" ///
              2016.year#c.totaltreat_pw = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-1.5(0.2)1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pw_employment.png", as(png) replace  


////////////////////////////////////////////////////////////////////////////////
**# Bookmark #1
// connectiivity measure: flows to treat as a percentage of total flows 
// EXCLUDES THOSE BELONGING TO LAGOS SAMPLE
// EXCLUDES THOSE DIRECTLY AFFECTED BY ULTRACTIVITY CLAUSE

preserve
keep if totaltreat_pf>0
// I. Tables estimates:

// I.a December wages
eststo: qui reghdfe lr_remdezr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remdezr
    
// I.b Average wages    
eststo: qui reghdfe lr_remmedr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_remmedr

// I.c log Employment
eststo: qui reghdfe l_firm_emp c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
// estimates store es_s_pf_emp
    
esttab,  replace keep(*.year#*c.totaltreat_pf) 



// II. Event Studies Graphs:

// II.a December wages:
reghdfe lr_remdezr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad industry1#year mode_base_month#year microregion#year ) vce(cluster identificad)
estimates store es_spillover_remdezr_pospf

// Create event study plot
coefplot es_spillover_remdezr_pospf, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_remdezr_pospf.png", as(png) replace

// II.b Average earnings

reghdfe lr_remmedr c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_remmedr_pospf

// Create event study plot
coefplot es_spillover_remmedr_pospf, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Average Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_remmedr_pospf.png", as(png) replace


// II.c Log Employment

reghdfe l_firm_emp c.totaltreat_pf##b(2011).year  if  treat_ultra==0 & in_balanced_panel==1 & lagos_sample==0 ,  absorb(year identificad  industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_emp_pospf

// Create event study plot
coefplot es_spillover_emp_pospf, ///
    keep(*.year#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
              2010.year#c.totaltreat_pf = "2010" ///
              2011.year#c.totaltreat_pf = "2011" ///
              2012.year#c.totaltreat_pf = "2012" ///
              2013.year#c.totaltreat_pf = "2013" ///
              2014.year#c.totaltreat_pf = "2014" ///
              2015.year#c.totaltreat_pf = "2015" ///
              2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_spill_pf_employment_pospf.png", as(png) replace    

restore
