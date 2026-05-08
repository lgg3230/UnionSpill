/*==============================================================================

File: Clean RAIS

Goal: Clean worker level data

Written in Stata 18 on Windows by Catarina Gaspar
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
global raw_data "${os}/1-RAIS/worker"
} 

program drop _all

timer clear 1
timer on 1

/*==============================================================================
				0. Programs to construct layers
==============================================================================*/

/*==============================================================================
				0.1. Define Layers (from cbo 02)
==============================================================================*/

program define_layers

		cap rename cbo_2002 cbo2002
		cap drop if cbo2002 == "0000-1"
		cap destring cbo2002, replace

		// Generate the first digit of occupation
		gen cbo2002_s = cbo2002
		cap tostring cbo2002_s , replace
		gen cbo02_1d=substr(cbo2002_s,1,1) if cbo2002>=100000
		replace cbo02_1d="0" if cbo2002<100000
		destring cbo02_1d, replace
		
		// Generate firs two digits of occupation (for distinguishing managers and directors)
		gen cbo02_2d=substr(cbo2002_s,1,2) if cbo2002>=100000
		replace cbo02_2d="0" if cbo2002<100000
		destring cbo02_2d, replace

		/*********************************/
		// 			LAYERS
		
		gen layer = 1 		if (cbo02_2d == 11 | cbo02_2d == 12 | cbo02_2d == 13)
		replace layer = 2 	if cbo02_2d == 14
		replace layer = 3 	if cbo02_1d == 2
		replace layer = 4   if (substr(cbo2002_s,3,1) == "0") & cbo2002>=100000 & cbo02_1d >= 4 & cbo02_1d <= 9
		replace layer = 5 	if cbo02_1d == 3
		replace layer = 6	if cbo02_1d >= 4 & cbo02_1d <= 9 & layer == .
		
		/*********************************/
		
		drop cbo2002_s cbo02_1d cbo02_2d
	
end

/*==============================================================================
				0.2. Construct crosswalk from 94 to 2002
==============================================================================*/

program crosswalk_wide

	use "${final_data}/other/cbo94-cbo2002.dta", clear

	// For consistency
	rename cbo94 cbo_1994
	tostring cbo_1994, replace
	
	// Drop armed forces
	drop if cbo2002 <= 100000
	
	// LAYERS
	define_layers
	
	// See all possible correspondences for each cbo1994
	bys cbo_1994 layer: keep if _n == 1
	bys cbo_1994: gen k = _n

	save "${temp}/temp_1d.dta", replace

	// Now let's get the mode of change

	// We keep only the cbo1994 that are problematic
	duplicates tag cbo_1994, gen(dup94)
	drop if dup94==0
	keep if k == 1 

	tostring cbo_1994, replace
	keep cbo_1994

	tempfile dup
	save `dup'

	// now we have only one observation per duplicate

	use cpf cbo_1994 cbo_2002 po_3112 cnpj_cei sal_med using "D:/1-RAIS/worker/Rais_trabalhador_2002", clear
		
		rename po_3112 employed
		rename cnpj_cei estabid
		merge m:1 cbo_1994 using `dup'
		keep if _merge==3
		drop _merge
		
		keep if employed == 1
		bys cpf (sal_med) : keep if _n == _N

		tempfile 2002
		save `2002'

	// we kept every worker that has a classification that will become ambiguous and
	// works in december (just to eliminate many duplicates)

	use cpf cbo_1994 cbo_2002 po_3112 cnpj_cei sal_med using "D:/1-RAIS/worker/Rais_trabalhador_2003", clear
		
		rename cnpj_cei estabid
		rename po_3112 employed 
		keep if employed == 1
		
		bys cpf (sal_med) : keep if _n == _N

		merge 1:1 cpf using `2002'
		keep if _merge==3

		gen n=1
	
	// LAYERS
	define_layers

	collapse (sum) n, by(cbo_1994 layer)

	save "${temp}/counts_per_correspondence.dta", replace

	use "${temp}/temp_1d.dta", clear 

	merge 1:1 cbo_1994 layer using "${temp}/counts_per_correspondence.dta"

	drop if _merge == 2 // The ones that appear in data but not on the official crosswalk
	replace n = 0 if n == .

	gsort cbo_1994 -n
	by cbo_1994: replace k = _n

	// Now we have them ordered by the real occurance in data

	keep cbo_1994 layer k
	reshape wide layer, i(cbo_1994) j(k)

	save "${temp}/crosswalk_1d.dta", replace

	erase "${temp}/temp_1d.dta"
	erase "${temp}/counts_per_correspondence.dta"

end

/*==============================================================================
C: Mode of change 	
==============================================================================*/

program mode_of_change
	
		use cpf cbo_1994 cbo_2002 po_3112 cnpj_cei sal_med using "D:/1-RAIS/worker/Rais_trabalhador_2002", clear
		
		rename cnpj_cei estabid
		rename po_3112 employed 
		keep if employed == 1
		bys cpf (sal_med) : keep if _n == _N

		tempfile 2002
		save `2002'

		use cpf cbo_1994 cbo_2002 po_3112 cnpj_cei sal_med using "D:/1-RAIS/worker/Rais_trabalhador_2003", clear
		
		rename cnpj_cei estabid
		rename po_3112 employed 
		keep if employed == 1
		bys cpf (sal_med) : keep if _n == _N

		// We keep the ones who are in the same firm (less likely to change occupation)
		merge 1:1 cpf using `2002'
		keep if _merge==3

		gen n=1
		
		// LAYERS
		define_layers

		collapse (sum) n, by(cbo_1994 layer)
		
		gsort cbo_1994 -n
		by cbo_1994: keep if _n == 1
		
		rename layer last_resort
		drop n
		drop if cbo_1994==""

		save "${temp}/counts_per_correspondence_2.dta", replace

end

/*==============================================================================
D: Apply the crosswalk: Main	
==============================================================================*/

program main
	args year

	destring cpf, replace

	// LAYERS
	define_layers

	destring layer, replace

	merge m:1 cbo_1994 using "D:/Project_SaraMoreira_JS_ML/intermediate_datasets/crosswalk_1d.dta"
	drop if _merge == 2
	drop _merge
	
	if `year' >= 2003 {

		gen occ_group = layer  // the real ones
		
	}
	
	if `year' < 2003 {
		
		// Case 1: Your cbo94 corresponds to only one 1d group
		di "Case 1"
		gen occ_group = layer1 if layer2 == .

		// Case 2: Crosswalk is ambiguous -> We assume you get the mode
		di "Case 2"
		replace occ_group = layer1 if occ_group == .
		
		// Case 3: They do not appear in official crosswalk (very very few)
		merge m:1 cbo_1994 using "D:/Project_SaraMoreira_JS_ML/intermediate_datasets/counts_per_correspondence_2.dta"
		
		destring occ_group, replace
		di "Case 3"
		replace occ_group = last_resort if occ_group == . 
		drop _merge last_resort
		
	}
	
	#delimit ;
	label define layers_label
	1 "Director"
	2 "Manager"
	3 "Science Professional"
	4 "Supervisor"
	5 "Middle Technician"
	6 "Other";
	#delimit cr

	label values occ_group layers_label

end

/*==============================================================================
					1.	Clean each year
==============================================================================*/

crosswalk_wide

mode_of_change

forvalues  year=1995(1)2020 {
	
	// For testing the code
	*use "${raw_data}/sample_to_run_faster/Rais_trabalhador_`year'-sample.dta", clear
	
	if `year' < 2020 {
		use "${raw_data}/Rais_trabalhador_`year'", clear
		*use "${raw_data}/sample_to_run_faster/Rais_trabalhador_`year'-sample.dta", clear
	}
	
	// Use the corrected version for 2020
		// In RAIS 2020, it seems there are no workers employed in december, po_3112==0
		// for everyone. What caused this is that this variable is computed from the 
		// variable mes_desligamento==0, which in the raw RAIS for 2020 is wrongly 
		// codified with "{ñ".

		// IMPORTANT: This does not correct for all issues, it only corrects for the 
		// variables we need for this specific project.

	if `year' == 2020 {
		use "D:/1-RAIS/worker/Rais_trabalhador_2020", clear
		
		replace mes_desligamento = 0 if mes_desligamento == .
		
		// It is weird because, even if the numbers are consistent over time, people
		// with mes_desligamento == . have motivo_desligamento not missing
		
		replace po_3112 = 1 if mes_desligamento == 0
	}
	
	rename po_3112 employed 

/*==============================================================================
					Wage cleaning
==============================================================================*/

	merge m:1 ano using "${final_data}/other/ipca_december.dta"
	drop ano
	
	keep if _merge == 3
	// Let's make 2010 our base year
	replace ipca = ipca / 3195.89 * 100
	gen real_wage = sal_med / ipca * 100
	drop _merge ipca
	
	rename cnpj_cei estabid
	rename municipio_estab municipality
	rename horas_semanais contracthours
	rename natureza_juridica concla
	rename cnae10 cnae10class
	
	gen hourly_wage = real_wage / contracthours

/*========================================================
=========================================================*/

	// Correcting the information for firmidcnpj based on establishment id
	*format estabid %16.0f
	gen estabid_text=estabid
	*format estabid_text %16.0f
	*tostring estabid_text, replace use
	gen lenght=length(estabid_text)

	// firm_id

	gen aux_text=substr(estabid_text,1,8) if lenght==14
	replace aux_text=substr(estabid_text,1,7) if lenght==13
	replace aux_text=substr(estabid_text,1,6) if lenght==12
	replace aux_text=substr(estabid_text,1,5) if lenght==11
	replace aux_text=substr(estabid_text,1,4) if lenght==10
	replace aux_text=substr(estabid_text,1,3) if lenght==9
	replace aux_text=substr(estabid_text,1,2) if lenght==8
	replace aux_text=substr(estabid_text,1,1) if lenght==7

	destring aux_text, replace
	gen double firm_id=aux_text
	drop aux_text lenght estabid_text

	// Dropping variables that we do not need
	cap drop day_rais

	destring cnae10class, replace
	replace concla="" if concla=="{ñ c"
	replace concla="" if concla=="00-1"
	destring concla, replace

/*==============================================================================
					2 Measures of employment
==============================================================================*/

	rename mes_desligamento sep_month // zero if never fired in the year
	rename mes_admissao hire_month // zero if hired before
	cap gen ano_admissao = year(data_admissao)
	rename ano_admissao hire_year
	
	* months employed in any job during current year
	
	gen byte months_emp = 0
	sort cpf
	forval m = 1/12 {
		
		gen byte month_`m'_emp = .
		
		replace month_`m'_emp = (hire_month == 0 & (`m' <= sep_month | sep_month == 0)) if sep_month < . 
		// person was hired before current year and separated after month `m' of current year
		
		replace month_`m'_emp = (hire_month <= `m' & (`m' <= sep_month | sep_month == 0)) if sep_month < . & inlist(month_`m'_emp, 0, .) 
		// person was hired before month `m' of current year and separated after month `m' of current year
		
		by cpf: egen byte month_`m'_emp_max = max(month_`m'_emp)
		
		drop month_`m'_emp
		replace months_emp = months_emp + month_`m'_emp_max
		drop month_`m'_emp_max
		
	}
	
	label var months_emp "Months employed in any job during current year"
	
	* actual work experience (= years recorded in RAIS) // done below!
	
	* hours worked during year in current job
	
	gen byte months_year = (sep_month == 0)*12 + (sep_month > 0)*sep_month - (hire_year == year)*max(hire_month, 1) - (hire_year < year)*1 + 1 
	// months worked during current year
	
	replace months_year = min(months_year, 12) if months_year < .
	gen int hours_year = .
	cap confirm var contracthours, exact
	if !_rc {
		replace contracthours = min(contracthours, 168) if hours < .
		replace hours_year = round(contracthours*365/7*months_year/12)
		replace hours_year = round(contracthours*365/7*12/12) if hours_year == .
	}
	replace hours_year = round(44*365/7*months_year/12) if hours_year == .
	replace hours_year = round(44*365/7*12/12) if hours_year == .
	replace hours_year = min(hours_year, 2294) if hours_year < .
	drop months_year
	label var hours_year "Hours worked during year in current job"
	
	/*========================================================
					Full time equivalent
	=========================================================*/
	bys firm_id: egen float size_fte = total(hours_year/(44*365/7)) 

	// size_fte = number of full-time full-year employees, winsorized from below at 1 FTE month
	replace size_fte = max(1/12, size_fte)
	
	label var size_fte "Establishment size (full-time equivalent workers)"
	
	/*========================================================
				Eliminate duplicates
	=========================================================*/

	// Note: I am considering all workers (full time and not full time)
	keep if employed == 1
	bys cpf (real_wage): keep if _n == _N
	gen n = 1
	bys firm_id: egen size_no_dups = total(n)
	drop n

/*========================================================
				3. Layers now
=========================================================*/
	
	main `year'

	rename occ_group layer_cbo
	drop if cpf == .

	saveold "${temp}/rais_clean_`year'.dta", replace

}

timer off 1
timer list

/*==============================================================================

						// END OF DO-FILE

===============================================================================*/









