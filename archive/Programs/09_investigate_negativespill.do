********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: VERIFY NEGATIVE SPILLVERS FOR LESS CBA'S
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: FIRM LEVEL RAIS FILES WITH ANALYSIS OUTCOMES
********************************************************************************


use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta",clear

keep if year>=2009
keep if !missing(mode_base_month)

gen treat_not_lagos = treat_ultra*(1-lagos_sample_avg)*in_balanced_panel

save "$rais_firm/cba_rais_firm_2009_2016_flows_1cba.dta",replace


