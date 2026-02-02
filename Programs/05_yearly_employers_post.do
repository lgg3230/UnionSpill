********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: EXTEND TRANSITION MATRICES TO POST-TREATMENT YEARS (2011-2016)
* INPUT: DTA RAIS FILES (DAHIS' CLEANING PROCEDURE)
* OUTPUT: YEARLY EMPLOYER FILES AND TRANSITION MATRICES FOR 2011-2016
********************************************************************************

* This script extends 05_yearly_employers.do to cover post-treatment years
* It uses the same selection algorithm as the pre-treatment period

********************************************************************************
* PART 1: CREATE YEARLY EMPLOYER FILES FOR 2012-2016
********************************************************************************

forvalues i=2012/2016 {

    use "$rais_raw_dir/RAIS_`i'.dta", clear

    // Keep only the variables needed for transition matrices
    keep PIS identificad empem3112 tempempr horascontr remdezr

    // Generate firm identifier (8-digit version)
    gen identificad8 = substr(identificad, 1, 8)

    // Select only spells active throughout December (Lagos criterion)
    gen empdec_lagos = empem3112 * (tempempr > 1)
    keep if empdec_lagos == 1

    // Generate necessary wage variable for ranking
    gen remdezr_h = remdezr / (horascontr * 4.348)
    gen l_remdezr_h = ln(remdezr_h)

    // Select one spell per worker per firm using the same algorithm as pre-period:
    // Step 1: Rank by contracted hours (highest = best)
    bysort identificad PIS: egen max_hours = max(horascontr * empdec_lagos)
    gen rank1 = (horascontr == max_hours & empdec_lagos == 1)

    // Step 2: Among those with max hours, rank by hourly wage (highest = best)
    bysort identificad PIS: egen max_wage = max(l_remdezr_h * rank1)
    gen rank2 = (l_remdezr_h == max_wage & rank1 == 1)

    // Step 3: Random tiebreaker (same seed as pre-period for consistency)
    set seed 12345
    gen random = runiform() if rank2 == 1

    // Create final rank combining all criteria
    bysort identificad PIS: egen max_random = max(random * rank2)
    gen final_rank = (random == max_random & rank2 == 1)

    drop rank1 rank2 random max_random

    // Count selected spells within each establishment
    bysort identificad: egen firm_emp = total(final_rank == 1)

    keep if final_rank == 1

    // Among selected spells, select one per worker by longest tenure
    recast float tempempr, force
    bys PIS: egen max_ten = max(tempempr)
    gen rank1 = (tempempr == max_ten)

    // Among those with same tenure, choose one with largest log hourly Dec earnings
    bys PIS: egen max_worker_wage = max(l_remdezr_h * rank1)
    gen rank2 = (l_remdezr_h == max_worker_wage & rank1 == 1)

    // Random tiebreaker for remaining ties
    set seed 12345
    gen random = runiform() if rank2 == 1
    bys PIS: egen max_random = max(rank2 * random)
    gen rank_emp = (max_random == random & rank2 == 1)

    keep if rank_emp == 1

    // Keep only variables needed for connectivity measures
    keep PIS identificad identificad8 firm_emp

    // Rename variables with year suffix
    rename (identificad identificad8 firm_emp) (identificad_`i' identificad8_`i' firm_emp_`i')

    save "$rais_aux/yearly_employers_`i'.dta", replace

    di "Processed yearly employers for `i'"
}

********************************************************************************
* PART 2: CREATE TRANSITION MATRICES FOR 2011-2016
********************************************************************************

forvalues i=2011/2015 {
    local j = `i' + 1

    use "$rais_aux/yearly_employers_`i'.dta", clear

    merge 1:1 PIS using "$rais_aux/yearly_employers_`j'.dta"

    // Keep only workers who transitioned between establishments
    keep if _merge == 3
    drop _merge

    // Add leading 1 to identifiers (same format as pre-period)
    replace identificad_`i' = "1" + identificad_`i'
    replace identificad_`j' = "1" + identificad_`j'

    replace identificad8_`i' = "1" + identificad8_`i'
    replace identificad8_`j' = "1" + identificad8_`j'

    save "$rais_aux/employers_`i'_`j'.dta", replace
    export delimited "$rais_aux/employers_`i'_`j'.csv", replace

    di "Created transition matrix for `i'-`j'"
}

di "Post-treatment employer files created successfully!"
