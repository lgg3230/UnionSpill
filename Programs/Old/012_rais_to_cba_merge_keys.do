********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: GENERATE RAIS COLLAPSED TO ESTAB LEVEL FOR MERGE WITH CBA 
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: ESTAB LEVEL DATASET ONLY WITH RELEVANT MERGE KEYS FOR MERGING TO THE CBA DATASETS
********************************************************************************

// First, let's try the whole set of spells of all firms. We will see if this changes any municipality of the ones that are in unique firms currently.

// For loop with full rais:

forvalues i=2009/2016{
	use "$rais_raw_dir/RAIS_`i'.dta",clear 
	keep identificad municipio // for each rais dataset, keep only estab id and municipality
	gen identificad_8 = substr(identificad,1,8) // generate firm id (8 1st digits of cnpj)
	save "$rais_aux/rais_cba_keys_`i'.dta", replace
}

use "$rais_aux/rais_cba_keys_2009.dta", clear

forvalues i=2010/2016{ // append all years
	append using "$rais_aux/rais_cba_keys_`i'.dta"
	erase "$rais_aux/rais_cba_keys_`i'.dta"
}

erase "$rais_aux/rais_cba_keys_2009.dta"

// with final dataset, generate modal municipality

bys identificad: egen mode_mun=mode(municipio), minmode
replace municipio=mode_mun
drop mun_mode

collapse (first) identificad_8 municipio, by(identificad)

// now we compare with the one done in unique estab
// goal is to see if there any differences with the matched firms

merge 1:1 identificad using "$rais_aux/rais_"
