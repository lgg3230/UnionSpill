************************************************************************************************************************************
*Project: Union Spillovers )
*Program: Merging employer assciation data with each RAIS database
*Author: Luis Gustavo Gomes
*Date: Nov 30, 2024

*Objective: 
************************************************************************************************************************************
**SET ENVIRONMENT
************************************************************************************************************************************

clear all
clear matrix
set maxvar 20000
set more off

global rais_hom_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_homog"
global emp_assoc "/kellogg/proj/lgg3230/UnionSpill/Data/stata_emp_assoc"
global rais_emp_merge "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_emp_merge"
global cba_dir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA"
global cba_rais_fir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_total"


********************************************************************************
* Firm:  merge using 1st 8 digits of cnpj *******






 foreach i in 2009 2010 2011 2012 2013 2014 2015 2016 2017{
use "$cba_dir/collapsed_cba_firm.dta",clear
 keep if active_year==`i'


* merge firm level cba's
merge 1:m identificad_8 using "$rais_emp_merge/rais_assoc_`i'.dta"
capture drop firm_cba
gen firm_cba = (_merge==3)
preserve 
keep if _merge ==3
drop _merge
save "$cba_rais_fir/cba_rais_firm_`i'.dta", replace
restore

* get all that did not have a merge with firm
keep if _merge !=3
drop _merge pair_id start_date_stata  cl_*  numb_clauses employer_id   negotiation_months union_id codigo_municipio active_year text_tokens ultra end_date_stata   file_date_stata mode_base_month

save "$cba_rais_fir/rais_notfirm_`i'.dta", replace
clear

*merge remaining with municipality level sectoral cba's
use "$cba_dir/collapsed_cba_sectoral.dta"

keep if active_year==`i'
keep if municipio!="000000" & strlen(municipio)==6

merge 1:m clean_asso_cnpj municipio using "$cba_rais_fir/rais_notfirm_`i'.dta"
capture drop mun_cba
gen mun_cba = (_merge==3)
preserve 
keep if _merge==3
drop _merge
save "$cba_rais_mun/cba_rais_muni_`i'.dta", replace
restore

keep if _merge !=3
drop _merge pair_id start_date_stata  cl_* numb_clauses employer_id   negotiation_months union_id codigo_municipio active_year text_tokens ultra end_date_stata   file_date_stata mode_base_month

save "$cba_rais_mun/rais_notmuni_`i'.dta", replace
erase "$cba_rais_fir/rais_notfirm_`i'.dta"
clear

* merge remaining with state level cba's

use "$cba_dir/collapsed_cba_sectoral.dta"

keep if active_year==`i'
keep if strlen(municipio)==2


merge 1:m clean_asso_cnpj stacode2 using "$cba_rais_mun/rais_notmuni_`i'.dta"
capture drop state_cba
gen state_cba=(_merge==3)
preserve 
keep if _merge==3
drop _merge
save "$cba_rais_sta/cba_rais_stat_`i'.dta", replace
restore  

keep if _merge!=3 

drop _merge pair_id start_date_stata  cl_* stacode2 numb_clauses employer_id   negotiation_months union_id codigo_municipio active_year text_tokens ultra end_date_stata   file_date_stata mode_base_month

save "$cba_rais_sta/rais_notstat_`i'.dta", replace
erase "$cba_rais_mun/rais_notmuni_`i'.dta"
clear


* merge remaining with national level cba's
use "$cba_dir/collapsed_cba_sectoral.dta"

keep if active_year==`i'
keep if municipio=="000000"


merge 1:m clean_asso_cnpj using "$cba_rais_sta/rais_notstat_`i'.dta"
capture drop nac_cba
gen nac_cba=(_merge==3)
keep if _merge==3
drop _merge
save "$cba_rais_nac/cba_rais_nati_`i'.dta", replace
erase "$cba_rais_sta/rais_notstat_`i'.dta"
clear


********************************************************************************
* Harmonize all datasets before appending
********************************************************************************

* Load the first dataset to serve as reference
use "$cba_rais_fir/cba_rais_firm_`i'.dta", clear
ds
local varlist `r(varlist)'

* Ensure all datasets have the same variables
foreach dataset in "$cba_rais_mun/cba_rais_muni_`i'.dta" "$cba_rais_sta/cba_rais_stat_`i'.dta" "$cba_rais_nac/cba_rais_nati_`i'.dta" {
    use "`dataset'", clear
    foreach var in `varlist' {
        capture confirm variable `var'
        if _rc {
            gen `var' = .
        }
    }
    
    * Ensure all variables are present and in the correct order
    order `varlist'
    save "`dataset'", replace
}

********************************************************************************
* Append datasets together
********************************************************************************

use "$cba_rais_fir/cba_rais_firm_`i'.dta", clear
append using "$cba_rais_mun/cba_rais_muni_`i'.dta"
append using "$cba_rais_sta/cba_rais_stat_`i'.dta"
append using "$cba_rais_nac/cba_rais_nati_`i'.dta"

save "$cba_rais_tot/cba_rais_total_`i'.dta", replace

erase "$cba_rais_fir/cba_rais_firm_`i'.dta"
erase "$cba_rais_mun/cba_rais_muni_`i'.dta"
erase "$cba_rais_sta/cba_rais_stat_`i'.dta"
erase "$cba_rais_nac/cba_rais_nati_`i'.dta"
}



 
