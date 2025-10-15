********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MERGE CBA AND RAIS DATASET TO GENERATE ANALYSIS SAMPLE (FOR SECTORAL CBA'S) 
* INPUT: COLLAPSED CBA FIRM (ESTABLISHEMNT LEVEL, FIRM LEVEL CBA)
* OUTPUT: APPENDED PANEL OF FIRMS WITH CBA INFORMATION, FROM 2009 TO 2017
********************************************************************************

forvalues y = 2007/2016 {
    // RAIS is master (one row per firm-year)
    use "$rais_firm/rais_firm_`y'.dta", clear
    capture confirm variable year
    if _rc gen year = `y'

    // Slice CBA to the same year (empty for 2007–2008, which is fine)
    tempfile cba`y'
    preserve
        use "$cba_dir/collapsed_cba_firm_updated.dta", clear
        keep if inrange(active_year, 2009, 2016) & active_year == `y'
        // ensure unique by identificad (drop duplicates if any slipped through)
        sort identificad
        by identificad: keep if _n == 1
        save `cba`y''
    restore

    // Merge: keep RAIS-only (1) and matched (3); drop using-only (2)
    merge 1:1 identificad using `cba`y''
    keep if _merge != 2
    drop _merge

    // Save per-year merged file
    save "$rais_firm/cba_rais_firm_`y'_1.dta", replace
}

use "$rais_firm/cba_rais_firm_2007_1.dta", clear
forvalues i=2008/2016{
	append using "$rais_firm/cba_rais_firm_`i'_1.dta"
	erase "$rais_firm/cba_rais_firm_`i'_1.dta"
}

// Joining Microregion information (microregion codes only share state code with municipality codes!!!)

merge m:1 municipio using "$ibge/mun_microregion_ibge.dta"
drop _merge

** GENERATING INDICATOR FOR lagos'S SAMPLE

* Create firm-year indicators of positive employment
gen temp_2009 = (year==2009)*(firm_emp > 0)*!missing(firm_emp)
gen temp_2010 = (year==2010)*(firm_emp > 0)*!missing(firm_emp)
gen temp_2011 = (year==2011)*(firm_emp > 0)*!missing(firm_emp)
gen temp_2012 = (year==2012)*(firm_emp > 0)*!missing(firm_emp)
gen temp_2013 = (year==2013)*(firm_emp > 0)*!missing(firm_emp)
gen temp_2014 = (year==2014)*(firm_emp > 0)*!missing(firm_emp)

* Propagate these indicators to all observations of the same firm
bysort identificad: egen pos_emp_2009 = max(temp_2009)
bysort identificad: egen pos_emp_2010 = max(temp_2010)
bysort identificad: egen pos_emp_2011 = max(temp_2011)
bysort identificad: egen pos_emp_2012 = max(temp_2012)
bysort identificad: egen pos_emp_2013 = max(temp_2013)
bysort identificad: egen pos_emp_2014 = max(temp_2014)

* Create indicator for positive employment in all years
gen pos_emp = pos_emp_2009*pos_emp_2010*pos_emp_2011*pos_emp_2012*pos_emp_2013*pos_emp_2014

* Clean up temporary variables
drop temp_*



// versions of lagos sample using different file date specifications:

/// Generate Lagos Sample with different file date definitions (min, avg, max)
// Loop over the three file date definitions
foreach filedate in min avg max {
    
    // 1a. Indicator for having a CBA in 2009 using current file_date definition
    bysort identificad: egen cba2009_`filedate' = max(inrange(`filedate'_file_date, mdy(1,1,2009), mdy(12,31,2009)))

    // 1b. Count the number of CBAs negotiated before 2012 using current file_date definition
    // mark cba's negotiated in 2009:
    bys identificad: gen filled2009_`filedate' = inrange(`filedate'_file_date, mdy(1,1,2009), mdy(12,31,2009))

    // get the earliest file date within those filed in 2009:
    bys identificad: egen first_2009_cba_`filedate' = min(`filedate'_file_date) if filled2009_`filedate'==1
    format first_2009_cba_`filedate' %td

    // just expand to all years of the same establishment to compare each row's filing date individually
    bys identificad: egen earliest2009_`filedate' = min(first_2009_cba_`filedate')
    // add 1 to avoid counting earliest 2009 cba again
    replace earliest2009_`filedate' = earliest2009_`filedate'+1
    format earliest2009_`filedate' %td
    drop first_2009_cba_`filedate'

    // marks rows where the file date is post the earliest 2009 cba filing date, but before 2012
    bys identificad: gen tag_post2009_pre2012_`filedate' = inrange(`filedate'_file_date,earliest2009_`filedate',mdy(1,1,2012))
    // counts how many filing dates after the first 2009 and before 2012 there are
    bys identificad: egen count_2009_2012_`filedate' = total(tag_post2009_pre2012_`filedate')

    // retrieves the filing dates of the cba's after the earliest 2009
    gen file_2009_2012_`filedate'=.
    replace file_2009_2012_`filedate'=`filedate'_file_date if tag_post2009_pre2012_`filedate'==1
    format file_2009_2012_`filedate' %td 

    // gets the second earliest cba negotiated within a establishment on the sample years.
    bys identificad: egen second_cba_`filedate' = min(file_2009_2012_`filedate')
    format second_cba_`filedate' %td 

    // Condition 1: Firm must have at least one CBA in 2009 AND at least another different one before 2012
    gen cba_pre2012_`filedate' = (cba2009_`filedate' == 1 & count_2009_2012_`filedate' >= 1)

    // 1c. Indicator for having a CBA in 2012 or later using current file_date definition
    bysort identificad: egen cba_post2012_`filedate' = max(`filedate'_file_date >= mdy(1,1,2012) & end_date_stata>= mdy(12,31,2012) & !missing(`filedate'_file_date))

    // Generate Lagos sample for this file date definition:
    gen lagos_sample_`filedate' = (cba_pre2012_`filedate' == 1 & cba_post2012_`filedate' == 1 & pos_emp == 1)
}



// Generate Luis Sample with different file date definitions (min, avg, max)
// Loop over the three file date definitions
foreach filedate in min avg max {
    
    // among those with no cba filed in 2009, get the earliest cba using current file_date definition
    bys identificad: egen earliest_cba_`filedate' = min(`filedate'_file_date) if cba2009_`filedate'==0 & `filedate'_file_date<mdy(1,1,2012)
    format earliest_cba_`filedate' %td

    gen first_pre2012_cba_`filedate' = (earliest_cba_`filedate'==`filedate'_file_date) & !missing(`filedate'_file_date)

    // tag estabs that have an earliest cba between 2010 and 2012
    bys identificad: egen has_non2009_cba1_`filedate' = max(first_pre2012_cba_`filedate')

    // find second cba after the first for the estabs with no 2009 cba:
    gen earliest_cba1_`filedate' = earliest_cba_`filedate'+1
    format earliest_cba1_`filedate' %td

    bys identificad: egen earliest_cba1_all_`filedate' = max(earliest_cba1_`filedate')
    format earliest_cba1_all_`filedate' %td

    bys identificad: egen tag_post10_pre12_`filedate' = max(inrange(`filedate'_file_date, earliest_cba1_all_`filedate',mdy(1,1,2012)))

    bys identificad: gen tag_cba_post10_pre12_`filedate' = inrange(`filedate'_file_date, earliest_cba1_all_`filedate',mdy(1,1,2012))

    bys identificad: gen file_cba_10_12_`filedate' = `filedate'_file_date if tag_cba_post10_pre12_`filedate'==1
    format file_cba_10_12_`filedate' %td

    bys identificad: egen second_cba_lg_`filedate' = min(file_cba_10_12_`filedate')
    format second_cba_lg_`filedate' %td 
    
    // Generate luis sample for this file date definition:
    gen luis_sample_`filedate' = (cba2009_`filedate'==0 & tag_post10_pre12_`filedate'==1 & has_non2009_cba1_`filedate'==1 & cba_post2012_`filedate'==1 & pos_emp==1)
}



// Expand treatment definition to all observations (so that treat ultra marks the cross section of treated and untreated firms)

rename treat_ultra treat_cba
bys identificad: egen treat_ultra = max(treat_cba) // extends treat_ultra to all years: marks treated firms for all years they appear

replace treat_ultra=0 if treat_ultra==.

// generate industry groups tags.

capture confirm variable industry
if _rc{
	gen industry = substr(clascnae20,1,3)
}

gen industry1 = "1" + industry // This is going to be a different code than the actual industry code, but it represents the same group
destring industry1, replace
bys identificad: egen industry1_mode = mode(industry1), minmode
replace industry1 = industry1_mode
drop industry1_mode


// processes mode_base_month and apply it to all observations with information of at least one base month. 

destring mode_base_month, replace force

rename mode_base_month mode_base_month_t
bys identificad: egen mode_base_month = max(mode_base_month_t)




* Generate indicators for presence in each required year
forvalues y = 2009/2016 {
    gen has_year_`y' = 0
    bysort identificad: replace has_year_`y' = 1 if inlist(`y', year)
    bysort identificad: egen present_in_`y' = max(has_year_`y')
}

* Generate the balanced panel indicator - a unit is in the balanced panel 
* only if it appears in EVERY year from 2009-2016
gen in_balanced_panel = cond(present_in_2009 == 1 & present_in_2010 == 1 & ///
                         present_in_2011 == 1 & present_in_2012 == 1 & ///
                         present_in_2013 == 1 & present_in_2014 == 1 & ///
                         present_in_2015 == 1 & present_in_2016 == 1,1,0)

* Clean up temporary variables
drop has_year_* present_in_*


preserve
collapse (first) in_balanced_panel, by (identificad)
save "$rais_aux/bal_pan.dta", replace
restore


// GEnerate more aggregate region and industry measures for distribution graphs

gen treat_year = cond(year>=2012,1,0)


gen big_industry = substr(industry,1,2)
destring big_industry, replace force
bys identificad: egen big_idustry_md = mode(big_industry), minmode
replace big_industry=big_idustry_md
drop big_idustry_md

gen big_region = substr(municipio,1,1)
destring big_region, replace force

destring microregion, replace

bys identificad: egen mode_union = mode(union_id), minmode
replace mode_union = ustrregexra(mode_union,"[\.\/\-]","")
destring mode_union, replace



// Generate indicators for treatment samples for connectivity measures:

// Lagos sample

gen lagos_control = cond(lagos_sample_avg==1 & treat_ultra==0,1,0)
gen lagos_treat = cond(lagos_sample_avg==1 & treat_ultra==1,1,0)

// At least one cba sample:

gen one_cba_treat = cond(!missing(mode_base_month) & treat_ultra==1 & in_balanced_panel==1,1,0)

// No restriction on cba numbers:

gen zero_cba_treat = cond(treat_ultra==1 & in_balanced_panel==1,1,0)

// Generates Samples for connectivity measures

preserve
collapse (first) lagos_sample_avg ,by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lagos_sample.dta", replace


export delimited "$rais_aux/lagos_sample.csv", replace
restore

preserve
collapse (first) lagos_control, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lagos_control.dta", replace


export delimited "$rais_aux/lagos_control.csv", replace
restore

preserve
collapse (first) lagos_treat, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lagos_treat.dta", replace


export delimited "$rais_aux/lagos_treat.csv", replace
restore


preserve
collapse (first) one_cba_treat, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/1_cba_treat.dta", replace


export delimited "$rais_aux/1_cba_treat.csv", replace
restore

preserve
collapse (first) zero_cba_treat, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/1_cba_treat.dta", replace


export delimited "$rais_aux/0_cba_treat.csv", replace
restore


save "$rais_firm/cba_rais_firm_2007_2016.dta", replace
