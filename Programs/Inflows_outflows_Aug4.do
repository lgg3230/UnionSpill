********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Disentangle effects of outflows from inflows 
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear

keep if lagos_sample_avg==1

gen placebo_year = cond(year<2011, 1,0)
