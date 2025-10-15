********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS, GENERATE OUTCOMES, COLLAPSE TO FIRM LEVEL
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE), cba rais 2009 2016
* OUTPUT: cba rais 2009 2016 flows FILES WITH corrected retention measures
********************************************************************************
forvalues i = 2009/2016 {
    use "$rais_raw_dir/RAIS_`i'.dta", clear
    
    keep PIS identificad empem3112 dtadmissao mesdesli tempempr horascontr remdezr
    gen year = `i'
    tostring year, gen(year_s)
	gen remdezr_h = remdezr/(horascontr*4.348)
gen l_remdezr_h = ln(remdezr_h)
    // Parse admission date
    gen dtadmissao_stata = date(dtadmissao, "DMY")
    format dtadmissao_stata %td

    // Active in December (Lagos convention) at the spell level
    gen byte empdec_lagos = empem3112 * (tempempr > 1)

    // ---- JANUARY MAIN-EMPLOYMENT SELECTION (mirror of your December logic) ----
    // Define "active in January": hired before Jan 1 and not separated in Jan
    gen byte emp_jan = (dtadmissao_stata < mdy(1,1,`i') & mesdesli != 1)

    // Step 1: among Jan-active spells, pick max contracted hours
    bysort identificad PIS: egen double max_hours_j = max(horascontr * emp_jan)
    gen byte rank1_j = (horascontr == max_hours_j & emp_jan==1)
**# Bookmark #2

    // Step 2: among those, pick max hourly wage (use lr_remdezr_h as your dec-hourly tiebreaker)
    // If lr_remdezr_h is missing, the max() below will ignore it; see fallback note after code.
    bysort identificad PIS: egen double max_wage_j = max(l_remdezr_h * rank1_j)
    gen byte rank2_j = (l_remdezr_h == max_wage_j & rank1_j==1)

    // Step 3: break remaining ties at random (reproducible)
    set seed 12345
    gen double random_j = runiform() if rank2_j==1
    bysort identificad PIS: egen double max_random_j = max(random_j * rank2_j)

    // Final January "main employment" flag (exactly one per PIS×firm if emp_jan==1)
    gen byte final_rank_j = (random_j == max_random_j & rank2_j==1)

    // ---- COUNT DISTINCT WORKERS (not spells) USING THAT MAIN-JAN SELECTION ----
    // Denominator: # of workers whose main employment (per your rules) is at this firm in January
    bysort identificad: egen long tot_emp_jan_main = total(final_rank_j==1)

    // Numerator: among those, how many are still active at this firm in December?
    // (i.e., the main-January spell at this firm is active in December)
    bysort identificad: egen long firm_emp_jan_main_retained = total(final_rank_j==1 & empdec_lagos==1)

    // Retention ratio
    gen double retention_c = cond(tot_emp_jan_main>0, firm_emp_jan_main_retained / tot_emp_jan_main, .)

    // Establishment-year key
    capture confirm string variable identificad
    if _rc==0 {
        gen strL identificad_y = identificad + year_s
    }
    else {
        tostring identificad, gen(identificad_s) format(%18.0g)
        gen strL identificad_y = identificad_s + year_s
    }

    // Keep one row per establishment
    collapse (firstnm) tot_emp_jan_main firm_emp_jan_main_retained retention_c identificad_y, by(identificad)

**# Bookmark #1
    save "$rais_aux/retention_corrected_`i'.dta", replace
}

use "$rais_aux/retention_corrected_2009.dta", clear
forvalues i = 2010/2016 {
    append using "$rais_aux/retention_corrected_`i'.dta"
}
save "$rais_aux/retention_corrected.dta", replace

merge 1:1 identificad_y using "$rais_firm/labor_analysis_sample_aug6.dta"
