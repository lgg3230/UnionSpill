											**********************,**************************************************************************************************************
				*Project: Union Spillovers )
				*Program: Homogenizing RAIS variables for appending
				*Author: Luis Gustavo Gomes
				*Date: Nov 27, 2024

				*Objective: Restrict each of the relevant RAIS datasets to the variables that are common among all so that the appending goes smoothly  

				************************************************************************************************************************************
				**SET ENVIRONMENT
				************************************************************************************************************************************

				clear all
				clear matrix
				set maxvar 20000
				set more off

global rais_raw_dir "/kellogg/proj/lgg3230/RAIS/output/data/full"
				global rais_aux "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux"

				************************************************************************************************************************************
				**RAW DATA
				************************************************************************************************************************************

				use "$rais_raw_dir/RAIS_2009.dta", clear 

				count
				di _N

				count if missing(municipio)

 
//  forvalues i=2009/2017{
//  	use "$rais_raw_dir/RAIS_`i'.dta",clear
// 	set seed 12345
// 	sample 1
// 	save "$rais_aux/RAIS_`i'_sample1.dta"
//  }
