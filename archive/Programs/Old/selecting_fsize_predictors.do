********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Selectiong variables that are more correlated to employment
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: WORKER-LEVEL ANALYSIS
********************************************************************************



use "$rais_firm/lagos_sample_sep24.dta", clear

keep if inrange(year, 2009, 2011)
keep if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

collapse (mean) white_prop male_prop avg_tenure  prop_nhs prop_hs prop_sup  prop_below_30  prop_30_40  prop_above_40  leaves safety fixed_prop quits layoffs  pub_firm hiring   n_negs_union_year industry1 treat_ultra turnover firm_emp lr_remdezr   outtreat_pw_n intreat_pw_n totaltreat_pf_n avg_ftreat_pf_n totaltreat_pw_n , by(identificad)



vl set
vl create myconts = vlcontinuous - (industry1 treat_ultra firm_emp)
vl create myfactors = (industry1 treat_ultra)
vl substitute myvarlist = i.myfactors myconts


lasso linear firm_emp  $myvarlist
lassocoef


// the variables selected by the lasso are here (all pre-treatement averages)
reghdfe white_prop prop_above_40 prop_nhs leaves n_negs_union_year lr_remdezr, absorb(industry1)
