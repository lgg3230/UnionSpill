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

// drop cba2009 count_pre2012 cba_pre2012 cba_post2012 pos_emp_2009 pos_emp_2010 pos_emp_2011 pos_emp_2012 pos_emp_2013 pos_emp_2014 pos_emp lagos_sample

* 1a. Indicator for having a CBA in 2009
// see if a particular row has a cba whose file_date is during 2009 (includes the boundaries). if so, that particular is marked as having at least one cba negotiated during 2009
bysort identificad: egen cba2009 = max(inrange(file_date_stata, mdy(1,1,2009), mdy(12,31,2009)))

* 1b. Count the number of CBAs negotiated before 2012.
// counts number of cba's negotiated prior to 1 jan 2012 for each estab
bysort identificad: egen count_pre2012 = total(file_date_stata < mdy(1,1,2012))

* Condition 1: Firm must have at least one CBA in 2009 AND at least two CBAs in total before 2012
// 1 if that row belongs to a firm whose 
gen cba_pre2012 = (cba2009 == 1 & count_pre2012 >= 2)

* 1c. Indicator for having a CBA in 2012 or later.
bysort identificad: egen cba_post2012 = max(file_date_stata >= mdy(1,1,2012))



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




capture confirm variable industry
if _rc{
	gen industry = substr(clascnae20,1,3)
}

gen industry1 = "1" + industry // This is going to be a different code than the actual industry code, but it represents the same group
destring industry1, replace

rename treat_ultra treat_cba
bys identificad: egen treat_ultra = max(treat_cba) // extends treat_ultra to all years: marks treated firms for all years they appear

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
gen in_balanced_panel = (present_in_2009 == 1 & present_in_2010 == 1 & ///
                         present_in_2011 == 1 & present_in_2012 == 1 & ///
                         present_in_2013 == 1 & present_in_2014 == 1 & ///
                         present_in_2015 == 1 & present_in_2016 == 1)

* Clean up temporary variables
drop has_year_* present_in_*





// GEnerate more aggregate region and industry measures for distribution graphs


gen big_industry = substr(industry,1,2)
destring big_industry, replace force

gen big_region = substr(municipio,1,1)
destring big_region, replace force


save "$rais_firm/cba_rais_firm_2009_2017_rep_3.dta", replace
