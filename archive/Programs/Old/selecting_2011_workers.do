********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM:Selects the workers present in 2011
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: WORKER-LEVEL ANALYSIS
********************************************************************************


use "$rais_firm/lagos_sample_workers.dta", clear

keep if year==2011

keep if lagos_sample_avg==1

keep PIS

save "$rais_aux/workers_2011.dta", replace
