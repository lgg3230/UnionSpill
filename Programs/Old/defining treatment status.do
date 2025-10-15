************************************************************************************************************************************
*Project: Union Spillovers )
*Program: defining treatment status in each firm in the RAIS dataset 
*Author: Luis Gustavo Gomes
*Date: Nov 30, 2024

*Objective: arrange a dataset that is at the firm level, defines treated and control  units,both for direct and indirect effects. 
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
global rais_aux "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux"

* 


use "$cba_rais_tot/cba_rais_total_2012.dta"

keep identificad ultra start_date_stata end_date_stata file_date_stata


gen treat_ultra =0
replace treat_ultra=1 if file_date_stata<= mdy(8,31,2012) & end_date_stata>=mdy(10,1,2012)


collapse (first)  treat_ultra, by(identificad)
drop if missing(identificad)

gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad


export delimited "$rais_aux/treat_cnpj.csv", replace

gen identificad2 = substr(identificad,2,14)
drop identificad 
rename identificad2 identificad

save "$rais_aux/treat_cnpj.dta",replace

clear all

forvalues i = 2009(1)2017{

use "$cba_rais_tot/cba_rais_total_`i'.dta"

merge m:1 identificad using "$rais_aux/treat_cnpj.dta"
drop _merge


save "$cba_rais_tot/cba_rais_total_`i'.dta", replace
}


