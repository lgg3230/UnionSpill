use "$rais_aux/worker_estab_all_years.dta", clear

keep if year>=2009
// keep cnpj_year PIS year
rename (*) (*_w)
rename cnpj_year_w cnpj_year

save "$rais_aux/worker_estab_all_years.dta", replace

use "$rais_firm/lagos_sample_sep24.dta", clear

tostring year, generate(year_str)
gen cnpj_year = identificad + year_str

mmerge cnpj_year using "$rais_aux/worker_estab_all_years.dta", type(1:n)

keep if _merge==3

compress
save "$rais_aux/worker_estab_lagos.dta", replace
