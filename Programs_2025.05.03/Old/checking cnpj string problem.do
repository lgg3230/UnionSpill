************************************************************************************************************************************
*Project: Union Spillovers )
*Program: cheking string issue with firm id's 
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

*load connectivity dataset

import delimited "$rais_aux/connectivity_2009_2012.csv"

tostring identificad, gen(identificad_str) format(%18.0f)


*test
clear all

use "$rais_aux/employers_2009_2010.dta"

gen cnpj_len_10= strlen(identificad_2010)
tab cnpj_len_10

use "$rais_aux/employers_2010_2011.dta", clear

gen cnpj_len_10= strlen(identificad_2010)
tab cnpj_len_10
gen cnpj_len_11= strlen(identificad_2011)
tab cnpj_len_11

use "$rais_aux/employers_2011_2012.dta", clear

gen cnpj_len_11= strlen(identificad_2011)
tab cnpj_len_11
gen cnpj_len_12= strlen(identificad_2012)
tab cnpj_len_12

import delimited "$rais_aux/employers_2011_2012.csv", clear

tostring identificad_2011, gen(identificad_2011_str) format(%18.0f)

gen cnpj_len_11= strlen(identificad_2011_str)
tab cnpj_len_11
gen cnpj_len_12= strlen(identificad_2012)
tab cnpj_len_12


