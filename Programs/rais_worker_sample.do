********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: select lagos sample from pure RAIS
* INPUT: COLLAPSED CBA FIRM (ESTABLISHEMNT LEVEL, FIRM LEVEL CBA)
* OUTPUT: APPENDED PANEL OF FIRMS WITH CBA INFORMATION, FROM 2009 TO 2017
********************************************************************************

use "$rais_aux/lagos_sample.dta", clear

keep if lagos_sample_avg==1

cap drop emp_id
gen emp_id = substr(identificad, 2, 14)

drop identificad
rename emp_id identificad

save "$rais_aux/lagos_sample_merge_worker.dta", replace



forvalues i=2008/2016{
	use "$rais_raw_dir/RAIS_`i'.dta", clear
	merge m:1 identificad using "$rais_aux/lagos_sample_merge_worker.dta"
	keep if _merge==3
	save "$rais_aux/rais_lagos_`i'.dta", replace
}
