************************************************************************************************************************************
*Project: Union Spillovers )
*Program: arraging matched cba-rais datasets. 
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


* find out who is employed in each firm by the end of each year. 
gen dtadmissao_stata = date(dtadmissao, "YMD")
format dtadmissao_stata %td 
