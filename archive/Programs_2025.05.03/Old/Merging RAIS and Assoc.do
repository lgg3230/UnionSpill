*************  ************************************************************************************************************************
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


foreach i in  2010 2011 2012 2013 2014 2015 2016 2017{
use "$rais_hom_dir/RAIS_`i'_hom.dta"

/* Merge RAIS data with emp_assoc_i.dta */
merge m:1 identificad using "$emp_assoc/emp_assoc_`i'.dta"
drop _merge

tostring municipio, replace
gen stacode2 = substr(municipio,1,2)
gen mergemun = clean_asso_cnpj + "_" + municipio
gen mergesta = clean_asso_cnpj + "_" + stacode2

cd $rais_emp_merge
save "rais_assoc_`i'.dta", replace
}

