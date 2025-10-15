********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Permutation test for mode_union control 
*          into heterogeneity
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE'S Control
* OUTPUT:  P-value of mode union permutation test	 
********************************************************************************
use "$rais_firm/labor_analysis_sample_jul31.dta",clear

keep if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

keep lr_remmedr totaltreat_pw_n treat_year lagos_sample_avg in_balanced_panel treat_ultra totalflows_n identificad year industry1 mode_base_month microregion mode_union l_firm_emp_2009_5 

reghdfe lr_remmedr c.totaltreat_pw_n##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
		
// Create the base dataset for permutations
tempfile original_data
save `original_data'		

// Create the original identificad ordering (only 2009 establishments)
keep if year == 2009
keep identificad
gen og_order = _n
save "$rais_firm/permutation_og_sample.dta", replace


// Set up postfile for efficient coefficient storage
tempname results
postfile `results' permutation_id coefficient using "permutation_coefficients.dta", replace

// Loop through 10 permutations
forvalues i = 1/10000 {
    
    display "Running permutation `i' of 10"
    
    // Create permutation
    use `original_data', clear
    keep if year == 2009
    keep mode_union
    rename mode_union mu_id
    gen r_order = runiform()
    sort r_order
    gen og_order = _n
    merge 1:1 og_order using "$rais_firm/permutation_og_sample.dta", nogenerate

    // This gives you the new identificad-to-union mapping
    keep identificad mu_id
    rename mu_id mode_union

    // Now merge this back to the full dataset
    tempfile permutation_map
    save `permutation_map'

    use `original_data', clear
    drop mode_union
    merge m:1 identificad using `permutation_map', nogenerate

    // Run regression and capture coefficient
    capture reghdfe lr_remmedr c.totaltreat_pw_n##treat_year if totalflows_n>26 & !missing(totalflows_n), ///
            absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
            vce(cluster identificad)
    
    if _rc == 0 {
        local coef = _b[1.treat_year#c.totaltreat_pw_n]
        display "Permutation `i': coefficient = `coef'"
    }
    else {
        local coef = .
        display "Permutation `i': regression failed"
    }
    
    // Post result
    post `results' (`i') (`coef')
}

postclose `results'

// Display results
use "permutation_coefficients.dta", clear
list
summarize coefficient

// REference





// // Now create first permutation
// use `original_data', clear
// keep if year == 2009
// keep mode_union
// rename mode_union mu_id
// gen r_order = runiform()
// sort r_order
// gen og_order = _n
// merge 1:1 og_order using "$rais_firm/permutation_og_sample.dta", nogenerate
//
// // This gives you the new identificad-to-union mapping
// keep identificad mu_id
// rename mu_id mode_union
//
// // Now merge this back to the full dataset
// tempfile permutation_map
// save `permutation_map'
//
// use `original_data', clear
// drop mode_union
// merge m:1 identificad using `permutation_map', nogenerate
//
// // Run your regression
// reghdfe lr_remmedr c.totaltreat_pw_n##treat_year if totalflows_n>26 & !missing(totalflows_n), ///
//         absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
//         vce(cluster identificad)
//
//
//

// keep if year==2009
//
// keep mode_union
// rename mode_union mu_id
//
// gen r_order = runiform()
// sort r_order
//
// gen og_order = _n
//
// merge 1:1 og_order using "$rais_firm/permutation_og_sample.dta"
//
//
// reghdfe lr_remmedr c.totaltreat_pw_n##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n), ///
//                 absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
//                 vce(cluster identificad)
//		
// scalar coef_inter = _b[1.treat_year#c.totaltreat_pw_n]
//		
		
