********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MERGE CBA AND RAIS DATASET TO GENERATE ANALYSIS SAMPLE (FOR SECTORAL CBA'S) 
* INPUT: COLLAPSED CBA FIRM (ESTABLISHEMNT LEVEL, FIRM LEVEL CBA)
* OUTPUT: APPENDED PANEL OF FIRMS WITH CBA INFORMATION, FROM 2009 TO 2017
********************************************************************************

forvalues i=2009/2016{
	use "$cba_dir/collapsed_cba_firm_1.dta",clear
	keep if active_year==`i'
	merge 1:1 identificad using "$rais_firm/rais_firm_`i'.dta"
	drop _merge
	save "$rais_firm/cba_rais_firm_`i'_1.dta", replace
}

use "$rais_firm/cba_rais_firm_2009_1.dta", clear
forvalues i=2010/2016{
	append using "$rais_firm/cba_rais_firm_`i'_1.dta"
	erase "$rais_firm/cba_rais_firm_`i'_1.dta"
}

// Joining Microregion information (microregion codes only share state code with municipality codes!!!)

merge m:1 municipio using "$ibge/mun_microregion_ibge.dta"
drop _merge

** GENERATING INDICATOR FOR lagos'S SAMPLE

//just to check with dataset:

// restrict to those that had some cba activity:
// bys identificad: egen mean_fd = mean(file_date_stata)
// bys identificad: gen some_cba = cond(mean_fd!=.,1,0)
//
//
// drop cba2009 count_pre2012_after2009 cba_pre2012t cba_post2012 

* 1a. Indicator for having a CBA in 2009
// see if a particular row has a cba whose file_date is during 2009 (includes the boundaries). if so, that particular is marked as having at least one cba negotiated during 2009
bysort identificad: egen cba2009 = max(inrange(file_date_stata, mdy(1,1,2009), mdy(12,31,2009)))

* 1b. Count the number of CBAs negotiated before 2012.
// counts number of cba's negotiated prior to 1 jan 2012 for each estab

// OLD AND WRONG, BUT LARGELY INCONSEQUENTIAL (BC ONLY BREAKS DOWN IF NO FILE DATE ON 2009)
// sort identificad file_date_stata
// by identificad: gen seq_num = _n
// by identificad: gen earliest_2009 = file_date_stata if cba2009==1 & seq_num==1
// format earliest_2009 %td 
// by identificad: egen first_cba_2009_date = min(earliest_2009)
// format first_cba_2009_date %td 
//
// bys identificad: egen count_pre2012_after2009 = total(file_date_stata > first_cba_2009_date & ///
// 						     file_date_stata < mdy(1,1,2012) & ///
// 						     !missing(file_date_stata))



// Identify the first cba filed(negotiated in 2009)

// mark cba's negotiated in 2009:
bys identificad:gen filled2009 = inrange(file_date_stata, mdy(1,1,2009), mdy(12,31,2009))

// get the earliest file date within those filed in 2009:
bys identificad: egen first_2009_cba = min(file_date_stata) if filled2009==1
format first_2009_cba %td

// just expand to all years of the same establishment to compare each row's filing date individually (min here is just to get the same value across).
bys identificad: egen earliest2009 = min(first_2009_cba)
// add 1 to avoid counting earliest 2009 cba again
replace earliest2009 = earliest2009+1
format earliest2009 %td
drop first_2009_cba

// marks rows where the file date is post the earliest 2009 cba filing date, but before 2012
bys identificad: gen tag_post2009_pre2012 = inrange(file_date_stata,earliest2009,mdy(1,1,2012))
// counts how many filing dates after the first 2009 and before 2012 there are
bys identificad: egen count_2009_2012 = total(tag_post2009_pre2012)

// retrieves the filing dates of the cba's after the earliest 2009
gen file_2009_2012=.
replace file_2009_2012=file_date_stata if tag_post2009_pre2012==1
format file_2009_2012 %td 

// gets the second earliest cba negotiated within a establishment on the sample years.
bys identificad: egen second_cba = min(file_2009_2012)
format second_cba %td 

// old solution (this is really wrong, but broke down paralell trends):

bysort identificad: egen count_pre2012_old = total(file_date_stata < mdy(1,1,2012))

bysort identificad: egen cba_post2012_old = max(file_date_stata >= mdy(1,1,2012))



* Condition 1: Firm must have at least one CBA in 2009 AND at least another different one before 2012

gen cba_pre2012 = (cba2009 == 1 & count_2009_2012 >= 1)



* 1c. Indicator for having a CBA in 2012 or later.
bysort identificad: egen cba_post2012 = max(file_date_stata >= mdy(1,1,2012) & end_date_stata>= mdy(12,31,2012) & !missing(file_date_stata))



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

gen lagos_sample = (cba_pre2012 == 1 & cba_post2012 == 1 & pos_emp == 1)
gen lagos_sample_old = (cba2009==1 & count_pre2012_old>=2 & cba_post2012_old==1 & pos_emp==1)

rename treat_ultra treat_cba
bys identificad: egen treat_ultra = max(treat_cba) // extends treat_ultra to all years: marks treated firms for all years they appear

replace treat_ultra=0 if treat_ultra==.


// Generate Luis Sample: two cba's before 2012, at least one after 2012, no cba negotiated in 2009

// among those with no cba filed in 2009, get the earliest cba
bys identificad: egen earliest_cba = min(file_date_stata) if cba2009==0 & file_date_stata<mdy(1,1,2012)
format earliest_cba %td

gen first_pre2012_cba = (earliest_cba==file_date_stata) & !missing(file_date_stata)

// tag estabs that have an earliest cba between 2010 and 2012
bys identificad: egen has_non2009_cba1 = max(first_pre2012_cba)


// find second cba after the first for the estabs with no 2009 cba:
gen earliest_cba1 = earliest_cba+1
format earliest_cba1 %td

bys identificad: egen earliest_cba1_all = max(earliest_cba1)
format earliest_cba1_all %td

bys identificad: egen tag_post10_pre12 = max( inrange(file_date_stata, earliest_cba1_all,mdy(1,1,2012)))

bys identificad: gen tag_cba_post10_pre12 = inrange(file_date_stata, earliest_cba1_all,mdy(1,1,2012))

bys identificad: gen file_cba_10_12 = file_date_stata if tag_cba_post10_pre12==1
format file_cba_10_12 %td

bys identificad: egen second_cba_lg = min(file_cba_10_12)
format second_cba_lg %td 
// Generate my sample:

gen luis_sample = (cba2009==0 & tag_post10_pre12==1 & has_non2009_cba1==1 & cba_post2012==1 & pos_emp==1)

// Expand treatment definition to all observations (so that treat ultra marks the cross section of treated and untreated firms)




// gen lagos_control = cond(lagos_sample==1 & treat_ultra==0,1,0)
// gen lagos_treat = cond(lagos_sample==1 & treat_ultra==1,1,0)

// Generates Samples for connectivity measures
//
// preserve
// collapse (first) lagos_sample,by(identificad)
// gen identificad1 = "1"+identificad
// drop identificad 
// rename identificad1 identificad
//
// save "$rais_aux/lagos_sample.dta", replace
//
//
// export delimited "$rais_aux/lagos_sample.csv", replace
// restore
//
// preserve
// collapse (first) lagos_control, by(identificad)
// gen identificad1 = "1"+identificad
// drop identificad 
// rename identificad1 identificad
//
// save "$rais_aux/lagos_control.dta", replace
//
//
// export delimited "$rais_aux/lagos_control.csv", replace
// restore
//
// preserve
// collapse (first) lagos_treat, by(identificad)
// gen identificad1 = "1"+identificad
// drop identificad 
// rename identificad1 identificad
//
// save "$rais_aux/lagos_treat.dta", replace
//
//
// export delimited "$rais_aux/lagos_treat.csv", replace
// restore
//
//



capture confirm variable industry
if _rc{
	gen industry = substr(clascnae20,1,3)
}

gen industry1 = "1" + industry // This is going to be a different code than the actual industry code, but it represents the same group
destring industry1, replace




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

gen big_region = substr(municipio,1,1)
destring big_region, replace force

destring microregion, replace

bys identificad: egen mode_union = mode(union_id), minmode
replace mode_union = ustrregexra(mode_union,"[\.\/\-]","")
destring mode_union, replace


save "$rais_firm/cba_rais_firm_2009_2016.dta", replace
