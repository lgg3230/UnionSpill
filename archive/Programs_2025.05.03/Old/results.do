
************************************************************************************************************************************
************************************************************************************************************************************
* Project: Union Spillovers
* Program: Regression Analysis at the firm level
* Author: Luis Gustavo Gomes
* Date: Nov 30, 2024
* 
* Objective: run did regressions and balance checks,
*           / for both direct and indirect effects.
************************************************************************************************************************************

** SET ENVIRONMENT
************************************************************************************************************************************

clear all                // Clear all variables from memory
clear matrix             // Clear any matrices stored in memory
set maxvar 20000         // Increase the maximum number of variables allowed
set more off             // Turn off --more-- prompts (output scrolling)

* Define global directories for your datasets (adjust these as necessary)
global rais_hom_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_homog"
global emp_assoc "/kellogg/proj/lgg3230/UnionSpill/Data/stata_emp_assoc"
global rais_emp_merge "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_emp_merge"
global cba_dir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA"
global cba_rais_fir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_total"
global rais_aux "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux"
global cba_rais_firm "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level"
global tables "/kellogg/proj/lgg3230/UnionSpill/Tables"
global graphs "/kellogg/proj/lgg3230/UnionSpill/Graphs"


ssc install coefplot

use "$cba_rais_firm/cba_rais_firm_2009_2017_0.dta"

capture confirm variable microrregiao
if _rc {
	gen microrregiao =  substr(municipio,1,5)
	destring microrregiao, replace force
}


capture confirm variable industry
if _rc{
	gen industry = substr(clascnae20,1,3)
	destring industry, replace force
}

destring mode_base_month, replace force 

* First, create an event time variable relative to 2012.



gen pos_con_09_10 = (con_2009_2010>0)

gen rel_time = year-2012



* Generate indicators for presence in each required year
forvalues y = 2009/2016 {
    gen has_year_`y' = 0
    bysort identificad: replace has_year_`y' = 1 if inlist(`y', year)
    bysort identificad: egen present_in_`y' = max(has_year_`y')
}

* Generate the balanced panel indicator - a unit is in the balanced panel 
* only if it appears in EVERY year from 2009-2016
gen in_balanced_panel = (present_in_2009 == 1 & present_in_2010 == 1 & ///
                         present_in_2011 == 1 & present_in_2012 == 1 & ///
                         present_in_2013 == 1 & present_in_2014 == 1 & ///
                         present_in_2015 == 1 & present_in_2016 == 1)

* Clean up temporary variables
drop has_year_*




local outcomes " turnover retention layoffs hiring l_firm_emp lr_remdezr"

local exposures "con_2009_2010 con_2010_2011 con_2011_2012"


* Now, run the regression. Here we use reghdfe and include fixed effects for firm and year.

foreach outcome of local outcomes{
foreach exposure of local exposures{
 
 reghdfe `outcome' c.`exposure'##ib(2011).year if treat_ultra==0 & lorenzo_sample==1 & firm_cba==1, absorb(identificad microrregiao##year industry##year mode_base_month##year) vce(cluster identificad)
 
 estimates store es_indirect
 
 // Create event study plot
coefplot es_indirect, vertical ///
    keep(*.year#*c.`exposure') ///
    coeflabels(2009.year#c.`exposure' = "2009" ///
               2010.year#c.`exposure' = "2010" ///
               2012.year#c.`exposure' = "2012" ///
               2013.year#c.`exposure' = "2013" ///
               2014.year#c.`exposure' = "2014" ///
               2015.year#c.`exposure' = "2015" ///
               2016.year#c.`exposure' = "2016" ///
               2017.year#c.`exposure' = "2017") ///
    yline(0) xline(3, lpattern(dash)) ///
    xtitle("Years Relative to Union Bargaining Power Increase (2012)") ///
    title("Event Study: Spillover Effects of `exposure' on `outcome'") ///
    note("Reference year: 2011") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(navy*.6)) 
	
	graph export "$graphs/es_`outcome'_`exposure'.png", as(png) replace
}
}	
	

//microrregiao#year industry#year mode_base_month#year

* Now, run the regression. Here we use reghdfe and include fixed effects for firm and year.


// foreach outcome of local outcomes{
 reghdfe l_firm_emp i.treat_ultra##ib(2011).year if lorenzo_sample==1 & firm_cba==1 & pub_firm==0, absorb(identificad year microrregiao#year industry#year mode_base_month#year) vce(cluster identificad)
 
 estimates store es_direct
 
 // Create event study plot
// Create event study plot
coefplot es_direct, vertical ///
    keep(1.treat_ultra#*.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year= "2010" ///
              1.treat_ultra#2012.year= "2012" ///
              1.treat_ultra#2013.year= "2013" ///
              1.treat_ultra#2014.year= "2014" ///
              1.treat_ultra#2015.year= "2015" ///
              1.treat_ultra#2016.year= "2016") ///
//              0.treat_ultra#2017.year= "2017") ///
    yline(0) xline(3, lpattern(dash)) ///
//     xtitle("Years Relative to Union Bargaining Power Increase (2012)") ///
//     title("Event Study: Dir. Effects of Ultra on `outcome'") ///
    note("Reference year: 2011") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(navy*.6))
	
	graph export "$graphs/es_`outcome'_treat.png", as(png) replace
// }


