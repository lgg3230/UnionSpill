************************************************************************************************************************************
* Project: Union Spillovers
* Program: Collecting current and year‐ahead employers to define worker flows.
* Author: Luis Gustavo Gomes
* Date: Nov 30, 2024
* 
* Objective: Arrange a dataset at the firm level that defines treated and control units,
*            for both direct and indirect effects.
************************************************************************************************************************************

** SET ENVIRONMENT
************************************************************************************************************************************

clear all                // Clear all variables from memory
clear matrix             // Clear any matrices stored in memory
set maxvar 20000         // Increase the maximum number of variables allowed
set more off             // Turn off --more-- prompts (output scrolling)

* Define global directories for your datasets (adjust these as necessary)
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

*-------------------------------------------------------------------------------------------------------------
* PART 1: Process yearly datasets to determine each worker's main employer for that year.
*         For each year (2009, 2010, 2011, 2012):
*         - Load the dataset.
*         - Convert the hiring date (dtadmissao) to Stata date format.
*         - Compute the month of admission and then the number of months worked.
*         - Create a modified employer ID variable (identificad_`i') by prefixing a "1" for consistency.
*         - Generate a random number for tie-breaking.
*         - (For 2012 only) Drop job spells with hiring date on/after August 31, 2012.
*         - Rank the job spells per worker and keep only the main job (rank 1).
*         - Save the resulting dataset.
*-------------------------------------------------------------------------------------------------------------
foreach i in 2009 2010 2011 2012 2013 2014 2015 2016 2017{
    
    use "$cba_rais_tot/cba_rais_total_`i'.dta"
    
    * Convert the hiring date from string to Stata date format (DMY) and format it
    gen dtadmissao_stata = date(dtadmissao, "DMY")
    format dtadmissao_stata %td 
    
    * Keep only the relevant variables needed for processing
    keep PIS dtadmissao_stata causadesli mesdesli identificad
    
    * Extract the month of admission from the hiring date
    gen month_admissao = month(dtadmissao_stata)
    
    * Compute months worked:
    *   - If a termination reason exists (causadesli != 0), compute months as: mesdesli - month_admissao + 1
    *   - If still employed (causadesli == 0), assume employment lasted until December (month 12)
    gen months_worked = .
    replace months_worked = mesdesli - month_admissao + 1 if causadesli != 0
    replace months_worked = 12 - month_admissao + 1 if causadesli == 0  // Assumes job lasted until December if no exit
    
    * Create a new employer ID variable for the current year by prefixing "1" to 'identificad'
    gen identificad1 = "1" + identificad
    
    rename identificad cnpj
    rename identificad1 identificad
    
    merge m:1 identificad using "$rais_aux/lorenzo_sample.dta"
	
	gen identificad_`i' = identificad
    
    * Drop the original identificad variable to avoid duplicate naming
    drop identificad
    
    * Generate a random number for tie-breaking when ranking job spells
    set seed 12345  // Ensure reproducibility
    gen rand = runiform()
    
    * Ensure numeric variables are stored as double precision for consistency
    destring PIS, replace force
    gen double PIS_new = PIS
    gen double months_worked_new = months_worked
    gen double month_admissao_new = month_admissao
    gen double rand_new = rand
    
    drop PIS months_worked month_admissao rand
    rename PIS_new PIS
    rename months_worked_new months_worked
    rename month_admissao_new month_admissao
    rename rand_new rand
    
    * For 2012, drop job spells with hiring date on or after August 31, 2012 (special case)
    *if `i' == 2012 {
        drop if dtadmissao_stata >= mdy(8,31,2012)
    *}
    
    * Rank job spells for each worker using lexicographic ordering:
    *   - Primary sort: descending by months_worked (more months = higher priority)
    *   - Secondary sort: ascending by month_admissao (earlier start = higher priority)
    *   - Tertiary sort: random tie-breaker (rand)
    bysort PIS (months_worked -month_admissao rand): gen rank = _n  
    
    * Keep only the top-ranked job spell (main employer) for each worker
    keep if rank == 1
    
    
    * Keep only the worker ID (PIS) and the new employer ID variable for the current year
    preserve
    keep PIS identificad_`i'
    
    * Save the processed dataset for the current year to the auxiliary folder
    save "$rais_aux/main_employer_full_`i'.dta", replace
    restore
    
	
	keep if lorenzo_sample==1
	keep PIS identificad_`i'
	                                                   
	export delimited "$rais_aux/cba_rais_total_`i'_main_employer_lsample.csv ", replace
	import delimited "$rais_aux/cba_rais_total_`i'_main_employer_lsample.csv ", clear
	save "$rais_aux/cba_rais_total_`i'_main_employer_lsample.dta", replace
}

* Suggestion: Instead of multiple "clear all" commands, you might use preserve/restore 
* to avoid reloading data repeatedly if memory permits.
clear all 



*-----------------------------------------------------------
* PART 2 (Modified): Arrange datasets for flow matrix for ANY two years t and t' (t < t')
* For each pair of years (e.g., 2009 & 2010, 2009 & 2011, 2009 & 2012, 2010 & 2011, etc.)
* we merge the main employer datasets by worker ID (PIS)
*-----------------------------------------------------------

** for full datasets
forvalues i = 2009/2016 {        // Outer loop: starting year t (last t is 2011 because t' must be > t)
   local j = `=`i'+1'  
        use "$rais_aux/cba_rais_total_`i'_main_employer_full.dta", clear
        
        merge 1:1 PIS using "$rais_aux/cba_rais_total_`j'_main_employer_full.dta"
        
        * Keep only workers who are present in both years
        keep if _merge == 3
        drop _merge
        
        * Order variables: PIS, then the employer IDs from year t and year t'
        order PIS identificad_`i' identificad_`j'
        
        * Save the merged dataset for this year pair (both .dta and .csv)
        save "$rais_aux/employers_full_`i'_`j'.dta", replace
        export delimited "$rais_aux/employers_full_`i'_`j'.csv", replace
        
        di "Processed full rais flow dataset for years `i' and `j'."
    
}

** for datasets restricted to Lorenzo's sample:

forvalues i = 2009/2016 {        // Outer loop: starting year t (last t is 2011 because t' must be > t)
   local j = `=`i'+1'
        use "$rais_aux/cba_rais_total_`i'_main_employer_lsample.dta", clear
        
        merge 1:1 pis using "$rais_aux/cba_rais_total_`j'_main_employer_lsample.dta"
        
        * Keep only workers who are present in both years
        keep if _merge == 3
        drop _merge
        
        * Order variables: PIS, then the employer IDs from year t and year t'
        order pis identificad_`i' identificad_`j'
        
        * Save the merged dataset for this year pair (both .dta and .csv)
        save "$rais_aux/employers_lsample_`i'_`j'.dta", replace
        export delimited "$rais_aux/employers_lsample_`i'_`j'.csv", replace
        
        di "Processed flow lorenzo sample dataset for years `i' and `j'."
    
}

*-------------------------------------------------------------------------------------------------------------
* PART 3: Prepare the treatment dataset (treatment status)
*         Using the 2012 dataset, derive a treatment dummy for each employer.
*         - Keep relevant variables.
*         - Create a dummy (treat_ultra) equal to 1 if the employer meets treatment criteria.
*         - Collapse to one observation per employer.
*         - Process the employer ID so that it matches those in other datasets.
*         - Export the treatment dataset as both CSV and Stata .dta.
*-------------------------------------------------------------------------------------------------------------
use "$cba_rais_tot/cba_rais_total_2012.dta", clear

keep identificad ultra start_date_stata end_date_stata file_date_stata

* Initialize treatment dummy to 0; set to 1 for employers meeting criteria:
*   - file_date_stata <= August 31, 2012 
*   - end_date_stata >= October 1, 2012
gen treat_ultra = 0
replace treat_ultra = 1 if file_date_stata <= mdy(8,31,2012) & end_date_stata >= mdy(10,1,2012)

* Collapse to one record per employer, taking the first value of treat_ultra
collapse (first) treat_ultra, by(identificad)
drop if missing(identificad)

* Modify employer ID by prefixing "1" for consistency with flow datasets
gen identificad1 = "1" + identificad
drop identificad 
rename identificad1 identificad

* Export treatment dataset as CSV
export delimited "$rais_aux/treat_cnpj.csv", replace

* Further process employer ID: remove the prefixed "1" by taking the substring from position 2
gen identificad2 = substr(identificad,2,14)
drop identificad 
rename identificad2 identificad

* Save treatment dataset as a Stata .dta file
save "$rais_aux/treat_cnpj.dta", replace

clear all

*-------------------------------------------------------------------------------------------------------------
* PART 4: Merge treatment status into all yearly RAIS datasets
*         For each year from 2009 to 2017, merge the treatment dataset onto the RAIS dataset using employer ID.
*         Drop the merge indicator and save the updated dataset.
*-------------------------------------------------------------------------------------------------------------
forvalues i = 2009(1)2017 {
    use "$cba_rais_tot/cba_rais_total_`i'.dta", clear
    
    merge m:1 identificad using "$rais_aux/treat_cnpj.dta"
    drop _merge
    
    save "$cba_rais_tot/cba_rais_treat_`i'.dta", replace
    erase "$cba_rais_tot/cba_rais_total_`i'.dta"
}

*-------------------------------------------------------------------------------------------------------------
* PART 5: Compute connectivity measures using MATLAB
*         Call MATLAB from Stata (using shell) to run the connectivity.m script.
*         (The MATLAB script will use the prepared flow datasets to compute connectivity measures.)
*-------------------------------------------------------------------------------------------------------------
shell "/software/matlab/R2018a/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_full.m"
shell "/software/matlab/R2018a/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_lsample.m"
shell "/software/matlab/R2018a/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_restricted_lsample.m"
 
*-------------------------------------------------------------------------------------------------------------
* PART 6: Post-process the connectivity measures in Stata
*         - Import the final connectivity dataset from MATLAB (CSV file).
*         - Convert employer ID to string format and adjust it to remove the prefixed "1".
*-------------------------------------------------------------------------------------------------------------

foreach dataset in "connectivity_2009_2017" "connectivity_lsample_2009_2017" "connectivity_restricted_2009_2017"{

import delimited "$rais_aux/`dataset'.csv", clear
 
* Convert identificad to string; generate a new variable identificad_ with format %18.0f
tostring identificad, gen(identificad_) format(%18.0f)
drop identificad
rename identificad_ identificad
 
* Remove the prefixed "1" from identificad by extracting characters from position 2 for a length of 14
gen identificad1 = substr(identificad,2,14)

drop identificad 
capture drop treat_ultra
capture drop lorenzo_sample
rename  identificad1 identificad

save "$rais_aux/`dataset'.dta", replace

}

use "$rais_aux/connectivity_2009_2017.dta", clear

merge 1:1 identificad using "$rais_aux/connectivity_lsample_2009_2017.dta"
drop _merge

merge 1:1 identificad using "$rais_aux/connectivity_restricted_2009_2017.dta"
drop _merge

save "$rais_aux/connectivity_2009_2017_full.dta", replace

*-------------------------------------------------------------------------------------------------------------
* PART 7: merge connectivity measures to main dataset 
*-------------------------------------------------------------------------------------------------------------


forvalues i=2009/2017{
	use "$rais_aux/connectivity_2009_2017_full.dta", clear
	merge 1:m identificad using "$cba_rais_tot/cba_rais_treat_`i'.dta"
	drop _merge
	save "$cba_rais_tot/cba_rais_conn_`i'.dta",replace
	erase "$cba_rais_tot/cba_rais_treat_`i'.dta"
}

