set more off
global main     "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009
keep if lagos_sample_avg == 1

* Check lr_remdezr
di "Non-missing lr_remdezr in spillover sample (treat_ultra==0 & in_balanced_panel==1):"
count if !missing(lr_remdezr) & treat_ultra==0 & in_balanced_panel==1
di "Non-missing totaltreat_pw_n in spill sample:"
count if !missing(totaltreat_pw_n) & treat_ultra==0 & in_balanced_panel==1
di "Distinct years:"
tab year if treat_ultra==0 & in_balanced_panel==1 & !missing(lr_remdezr)
