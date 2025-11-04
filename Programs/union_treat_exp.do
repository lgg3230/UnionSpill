********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Construct measure of mode union exposition to treatment
* INPUT:   MERGED CBA RAIS, from sep 24
* OUTPUT:  mode-union x year level dataset with exposition measures	 
********************************************************************************

use "$rais_firm/cba_rais_firm_2007_2016.dta", clear


keep if year >=2009

keep if !missing(mode_base_month)

keep year identificad treat_ultra mode_union

**# Bookmark #1
cap drop treat_union_exp_a
bys mode_union year: egen treat_union_exp_a = mean(treat_ultra) 
cap drop treat_union_exp_pre
bys mode_union: egen treat_union_exp_pre = mean(treat_union_exp_a) if year<=2011
cap drop treat_union_exp
bys mode_union: egen treat_union_exp = min(treat_union_exp_pre)

 
collapse (firstnm) treat_union_exp, by(mode_union)
rename treat_union_exp treat_union_exp_all
label var treat_union_exp_all "Proportion of firms affected by ultra reform by union"

isid mode_union

save "$rais_aux/union_treat_exp_sep24.dta", replace
