++++++++++++++++++++

keep identificad year lr_remdezr firm_emp lagos_sample_avg

rename lr_remdezr lr_remdezr_2
rename firm_emp firm_emp_assert
keep if year>=2009 & lagos_sample_avg==1
drop lagos_sample_avg

save  "$rais_firm/lagos_sample_sep24_remdezr.dta", replace


tostring year, generate(year_str)

gen cnpj_year = identificad + year_str

keep cnpj_year identificad year_str

save "$rais_aux/lagos_sample_year.dta", replace
