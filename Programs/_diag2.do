set more off
global rais_firm "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009

di "Non-missing lr_remdezr_w by treat_ultra:"
tab treat_ultra if !missing(lr_remdezr_w)

di "Non-missing lr_remdezr_w by in_balanced_panel:"
tab in_balanced_panel if !missing(lr_remdezr_w)

di "Non-missing lr_remdezr (no _w) in spill sample:"
count if !missing(lr_remdezr) & treat_ultra==0 & in_balanced_panel==1 & lagos_sample_avg==1

di "Non-missing lr_remdezr_w overall:"
count if !missing(lr_remdezr_w)
