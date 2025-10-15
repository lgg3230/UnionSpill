*************   ************************************************************************************************************************
*Project: Union Spillovers ) 
*Program: checking if municipio codes have 6 digits in all rais databases
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

global rais_emp_merge "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_emp_merge"

foreach i in 2009 2010 2011 2012 2013 2014 2015 2016 2017{
	use "$rais_emp_merge/rais_assoc_`i'.dta"
	tostring municipio, replace
	gen munlen = strlen(municipio)
	tab munlen 
	tab municipio if munlen==1
	clear all
	set more off
}
