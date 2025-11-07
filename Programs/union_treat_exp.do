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

keep year identificad treat_ultra mode_union firm_emp

order mode_union year identificad
sort mode_union year identificad


cap drop firm_emp_pre_o
cap drop firm_emp_pre

bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)

bys mode_union year: egen union_emp_pre = total(firm_emp_pre)

bys mode_union year: egen union_emp_pre_treat = total(firm_emp_pre) if treat_ultra==1
gen union_emp_exp_o = union_emp_pre_treat/union_emp_pre
bys mode_union:  egen union_emp_exp = min(union_emp_exp_o)


**# Bookmark #1
cap drop treat_union_exp_a
bys mode_union year: egen treat_union_exp_a = mean(treat_ultra) 
cap drop treat_union_exp_pre
bys mode_union: egen treat_union_exp_pre = mean(treat_union_exp_a) if year<=2011
cap drop treat_union_exp
bys mode_union: egen treat_union_exp = min(treat_union_exp_pre)

 
collapse (firstnm) treat_union_exp union_emp_exp, by(mode_union)
rename treat_union_exp treat_union_exp_all
label var treat_union_exp_all "Proportion of firms affected by ultra reform by union"
label var union_emp_exp "Proportion of a union's covered workers affected by reform'"

replace union_emp_exp = 0 if union_emp_exp==.

isid mode_union

corr treat_union_exp_all union_emp_exp

save "$rais_aux/union_treat_exp_sep24.dta", replace
