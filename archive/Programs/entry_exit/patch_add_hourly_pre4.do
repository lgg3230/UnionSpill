********************************************************************************
* patch_add_hourly_pre4.do
* Adds lr_remdezr_h_w_pre and lr_remdezr_h_w_pre4 to entry_exit_panel.dta.
* Run once; safe to re-run (cap drop guards).
********************************************************************************

use "/kellogg/proj/lgg3230/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear

* Pre-treatment mean of log real hourly wage (2009-2011)
cap drop lr_remdezr_h_w_pre_o
cap drop lr_remdezr_h_w_pre
quietly {
    bys identificad: egen lr_remdezr_h_w_pre_o = mean(lr_remdezr_h_w) if inrange(year,2009,2011)
    bys identificad: egen lr_remdezr_h_w_pre   = min(lr_remdezr_h_w_pre_o)
    drop lr_remdezr_h_w_pre_o
}
label var lr_remdezr_h_w_pre "Pre-treatment mean log real hourly wage (avg 2009-2011)"

* Quartile bins (cut within 2009 obs, full unbalanced sample)
cap drop lr_remdezr_h_w_pre4_o
cap drop lr_remdezr_h_w_pre4
quietly {
    egen lr_remdezr_h_w_pre4_o = cut(lr_remdezr_h_w_pre) if year == 2009, group(4)
    bys identificad: egen lr_remdezr_h_w_pre4 = min(lr_remdezr_h_w_pre4_o)
    drop lr_remdezr_h_w_pre4_o
    replace lr_remdezr_h_w_pre4 = 0 if missing(lr_remdezr_h_w_pre4)
}
label var lr_remdezr_h_w_pre4 "Quartile bin of pre-treatment log real hourly wage (0=ref)"

* Fill forward into padded rows (same pattern as prep_entry_exit_data.do)
foreach v in lr_remdezr_h_w_pre lr_remdezr_h_w_pre4 {
    bys identificad (present_in_year `v'): ///
        replace `v' = `v'[1] if missing(`v') & !missing(`v'[1])
}

count if missing(lr_remdezr_h_w_pre4) & present_in_year == 1
di "Obs with present_in_year=1 still missing lr_remdezr_h_w_pre4: " r(N)

save "/kellogg/proj/lgg3230/UnionSpill/Data/entry_exit/entry_exit_panel.dta", replace

di "Patch complete."
