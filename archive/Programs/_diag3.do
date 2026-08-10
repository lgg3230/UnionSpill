set more off
global rais_firm "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level"
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009
keep if lagos_sample_avg == 1

describe industry1 mode_base_month microregion totaltreat_pw_n lr_remdezr

di "Spillover sample (treat_ultra==0 & in_balanced_panel==1):"
count if treat_ultra==0 & in_balanced_panel==1

* Try simplest possible reghdfe
reghdfe lr_remdezr totaltreat_pw_n if treat_ultra==0 & in_balanced_panel==1, ///
    absorb(identificad) vce(cluster identificad)
di "Simple reghdfe worked: " e(N)
