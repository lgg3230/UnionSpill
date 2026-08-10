*************************************************************************************************************************************
*Project: Union Spillovers )
*Program: Collecting unique cnpj's
*Author: Luis Gustavo Gomes
*Date: Nov 27, 2024

*Objective: to merge with employer association data

************************************************************************************************************************************
**SET ENVIRONMENT
************************************************************************************************************************************

clear all
clear matrix
set maxvar 20000
set more off

global rais_hom_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_homog/"
global rais_aux_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/"

************************************************************************************************************************************
* Collect Unique Employer Identifiers (identificad) and Save Separate Files for Each Year
************************************************************************************************************************************



* Loop through each dataset by year
foreach i in 2009 2010 2011 2012 2013 2014 2015 2016 2017 {
    use "$rais_hom_dir/RAIS_`i'_hom.dta", clear
    
    // Extract unique employer identifiers
    keep year identificad
    duplicates drop identificad, force  // Keep only unique employer identifiers
    
    // Save the dataset with unique employer IDs for the current year
    save "$rais_aux_dir/unique_employers_`i'.dta", replace
    
    
}
