/*==============================================================================

File: collapse firm

Goal: Collapse worker level data into firm level data

Written in Stata 18 on Windows by Catarina Gaspar
-------------------------------------------------------------------------------
Last update: 15 mar by Francisco W
==============================================================================*/

/*==============================================================================
Preliminaries & Stata Settings			
==============================================================================*/

{
cls
set more off, perm
set varabbrev on, perm
clear *
timer clear
}

/*==============================================================================
Globals & directories
==============================================================================*/

macro drop _all

* Paths for Windowns server

global os "D:"

* Paths for CentOS server
*global os "/mnt/vmJoanaShare/"

{
cd "${os}/Project_SaraMoreira_JS_ML"
pwd

global root "${os}/Project_SaraMoreira_JS_ML/After_SED"
global final_data "${root}/02_Data"
global temp "${root}/temp"
global dofiles "${root}/01_Codes/011_firm x year data"
} 

/*==============================================================================
	00: Compute firm level variables from worker level data		
==============================================================================*/


forvalues year=1995(1)2020 {	
		
		use "${temp}/rais_clean_`year'.dta", clear
		
		drop layer?
		
		forvalues i = 1/6 {
			gen layer_`i'_rob = (layer_cbo == `i')
		}
		
		gen layer_1 = layer_1_rob + layer_2_rob
		
		forvalues i = 3/6 {
			local j = `i' - 1
			gen layer_`j' = (layer_cbo == `i')
		}
		
		// Need firm measures for adjusted layers
		
		
	if `year' != 1995 {
		
		local previous_year = `year' - 1
		rename * *_this
		rename cpf_this cpf
	
		merge 1:1 cpf using "${temp}/rais_clean_`previous_year'.dta"
		
		drop layer?
		
		forvalues i = 1/6 {
			gen layer_`i'_rob = (layer_cbo == `i')
		}
		
		gen layer_1 = layer_1_rob + layer_2_rob
		
		forvalues i = 3/6 {
			local j = `i' - 1
			gen layer_`j' = (layer_cbo == `i')
		}
		
		drop if _merge == 2
		
		forvalues i = 1/5 {
			// Same layer, different firm
			gen layer_`i'_hi = (layer_`i' == 1 & layer_`i'_this == 1 & firm_id != firm_id_this & _merge == 3)
			// Same layer, different firm
			gen layer_`i'_hu = (layer_`i'_this == 1 & _merge == 1)
			// Different layer, different firm
			gen layer_`i'_ho = (layer_`i' == 0  & layer_`i'_this == 1 & firm_id != firm_id_this & _merge == 3)
			// Same layer, same firm
			gen layer_`i'_ci = (layer_`i' == 1 & layer_`i'_this == 1 & firm_id == firm_id_this)
			// Different layer, same firm
			gen layer_`i'_co = (layer_`i' == 0 & layer_`i'_this == 1 & firm_id == firm_id_this)
		}
		

		// gen ensino_sec=(education>6)
		gen ensino_sup=(grau_instr_this>8)
		
		forvalues i = 1/5 {
			// Hired, educated
			gen layer_`i'_h_educ = ((firm_id != firm_id_this | firm_id == .) & ensino_sup == 1 & layer_`i'_this == 1)
			// Continuing, educated
			gen layer_`i'_c_educ = ((firm_id != firm_id_this | firm_id == .) & ensino_sup == 1 & layer_`i'_this == 1)
		}
		
		forvalues i = 1/5 {
			// Hired (new in market), educated and old
			gen layer_`i'_h_educ_a30 = ((firm_id != firm_id_this | firm_id == .) & ensino_sup == 1 & idade_trab_this >= 30 & layer_`i'_this == 1)
			// Hired (new in market), educated and young
			gen layer_`i'_h_educ_l30 = ((firm_id != firm_id_this | firm_id == .) & ensino_sup == 1 & idade_trab_this < 30 & layer_`i'_this == 1)
		}

		keep layer_?_h? layer_?_c? layer_?_?_educ layer_?_h_educ* cpf

		merge 1:1 cpf using "${temp}/rais_clean_`year'.dta"
		
		drop layer?
		
		forvalues i = 1/6 {
			gen layer_`i'_rob = (layer_cbo == `i')
		}
		
		gen layer_1 = layer_1_rob + layer_2_rob
		
		forvalues i = 3/6 {
			local j = `i' - 1
			gen layer_`j' = (layer_cbo == `i')
		}
		
	}

	if `year' < 2003 {

	// Get number of distinct occupations - using 1994 CBO
		bys firm_id cbo_1994: gen nvals = _n == 1
		bys firm_id : egen nvals_aux = total(nvals)
		bys firm_id : replace nvals = nvals_aux
		drop nvals_aux
		
	// Now excluding managers and directors
		bys firm_id cbo_1994: gen nvals_2 = ( _n == 1 & layer_1 == 0)
		by firm_id : egen nvals_2_aux = total(nvals_2)
		by firm_id : replace nvals_2 = nvals_2_aux
		drop nvals_2_aux
		
	}
	
	if `year' >= 2003 {
	
	cap rename cbo2002 cbo_2002
	
	// Get number of distinct occupations - using 2002 CBO
		bys firm_id cbo_2002: gen nvals = _n == 1
		bys firm_id : egen nvals_aux = total(nvals)
		bys firm_id : replace nvals = nvals_aux
		drop nvals_aux
		
	// Now excluding managers and directors
		bys firm_id cbo_2002: gen nvals_2 = ( _n == 1 & layer_1 == 0)
		by firm_id : egen nvals_2_aux = total(nvals_2)
		by firm_id : replace nvals_2 = nvals_2_aux
		drop nvals_2_aux
		
	}

	// Get number of establishments
		bys firm_id estabid: gen n_estabs = _n == 1
		bys firm_id: egen n_estabs_aux = total(n_estabs)
		bys firm_id: replace n_estabs = n_estabs_aux
		drop n_estabs_aux

	foreach var of varlist municipality concla cnae10class {

		bys firm_id `var': egen total_size = count(cpf)
		bys firm_id (total_size): gen `var'_aux = `var' if _n == _N
		bys firm_id: egen `var'_main = min(`var'_aux)

		drop `var'_aux total_size

	}
	
	cap drop year_rais
	gen year_rais = `year'
	
	/*========================================================
				Full time employment
	=========================================================*/
	
	keep if contracthours > 30
	cap drop n
	gen n = 1
	bys firm_id: egen size_no_dups_ft = total(n)
	drop n
	
	/*========================================================
				
	=========================================================*/

	if `year' != 1995 {
		
		collapse (sum) layer_1 layer_2 layer_3 layer_4 layer_5 (mean) year_rais ///
		(sum) layer_?_?*  ///
		(mean) mean_wage = real_wage (median) median_wage = real_wage ///
		(p10) p10_wage = real_wage (p90) p90_wage = real_wage (max) max_wage = real_wage ///
		(min) min_wage = real_wage (sd) sd_wage = real_wage (min) n_distinct2 = nvals ///
		n_distinct = nvals_2 n_estabs ///
		(mean) *_main (max) tempo_emprego  ///
		(min) size_fte size_no_dups size_no_dups_ft ///
		, by(firm_id)

	}
	
	if `year' == 1995 {
		
		collapse (sum) layer_1 layer_2 layer_3 layer_4 layer_5 (mean) year_rais ///
		(mean) mean_wage = real_wage (median) median_wage = real_wage ///
		(p10) p10_wage = real_wage (p90) p90_wage = real_wage (max) max_wage = real_wage ///
		(min) min_wage = real_wage (sd) sd_wage = real_wage (min) n_distinct2 = nvals ///
		n_distinct = nvals_2 n_estabs ///
		(mean) *_main (max) tempo_emprego  ///
		(min) size_fte size_no_dups size_no_dups_ft ///
		, by(firm_id)
		
	}
		
		save "${temp}/rais_firm_`year'.dta", replace
	
}

/*==============================================================================
	01: Append firm level data to create panel	
==============================================================================*/

clear

forvalues year=1995(1)2020 {

append using "${temp}/rais_firm_`year'.dta"

}

preserve 
	use "${final_data}/other/correspondance_cnae_subsec", clear 
	tempfile corres
	ren cnae10class cnae10class_main
	ren ibgesubsec subsector
	save `corres'
restore 

merge m:1 cnae10class_main using `corres' 
drop _merge

/*==============================================================================
	01: Drop concla != 2
==============================================================================*/

compress

saveold "${temp}/panel_firms_1995_2020_v0.dta", replace

gen concla_2 = floor(concla_main/1000)
keep if concla_2 == 2
drop concla_2

compress

saveold "${temp}/panel_firms_1995_2020_v1.dta", replace

forvalues year=1995(3)2020 {
	
	preserve
	
	local end = `year' + 2
	
	if `end' > 2020 {
		local end = 2020
	}
	
	keep if year_rais >= `year' & year_rais <= `end'
	
	export delimited using "${temp}/panel_firms_`year'_`end'_v1.csv", replace
	
	restore 
	
}

/*==============================================================================

						 // End of do-file

==============================================================================*/
