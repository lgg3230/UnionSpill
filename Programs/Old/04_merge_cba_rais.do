********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MERGE CBA AND RAIS DATASET TO GENERATE ANALYSIS SAMPLE 
* INPUT: COLLAPSED CBA FIRM (ESTABLISHEMNT LEVEL, FIRM LEVEL CBA)
* OUTPUT: APPENDED PANEL OF FIRMS WITH CBA INFORMATION, FROM 2009 TO 2017
********************************************************************************

forvalues i=2009/2017{
	use "$cba_dir/collapsed_cba_firm.dta",clear
	keep if active_year==`i'
	merge 1:1 identificad using "$rais_firm/rais_firm_`i'.dta"
	drop _merge
	save "$rais_firm/cba_rais_firm_`i'.dta", replace
}

use "$rais_firm/cba_rais_firm_2009", clear
forvalues i=2010/2017{
	append using "$rais_firm/cba_rais_firm_`i'.dta"
}

** GENERATING INDICATOR FOR lagos'S SAMPLE

* 1a. Indicator for having a CBA in 2009.
bysort identificad: egen cba2009 = max(inrange(file_date_stata, mdy(1,1,2009), mdy(12,31,2009)))

* 1b. Count the number of CBAs negotiated before 2012.
bysort identificad: egen count_pre2012 = total(file_date_stata < mdy(1,1,2012))

* Condition 1: Firm must have at least one CBA in 2009 AND at least two CBAs in total before 2012
gen cba_pre2012 = (cba2009 == 1 & count_pre2012 >= 2)

* 1c. Indicator for having a CBA in 2012 or later.
bysort identificad: egen cba_post2012 = max(file_date_stata >= mdy(1,1,2012))



* Create firm-year indicators of positive employment
gen temp_2009 = (year==2009)*(firm_emp > 0)
gen temp_2010 = (year==2010)*(firm_emp > 0)
gen temp_2011 = (year==2011)*(firm_emp > 0)
gen temp_2012 = (year==2012)*(firm_emp > 0)
gen temp_2013 = (year==2013)*(firm_emp > 0)
gen temp_2014 = (year==2014)*(firm_emp > 0)

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
gen lagos_treat = (lagos_sample==1 & treat_ultra==1)
gen lagos_control = (lagos_sample==1 & treat_ultra==0)



preserve
collapse (first) lagos_sample,by(identificad)
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


capture confirm variable microrregiao
if _rc {
	gen microrregiao =  substr(municipio,1,5)
	destring microrregiao, replace force
}


capture confirm variable industry
if _rc{
	gen industry = substr(clascnae20,1,3)
	destring industry, replace force
}


save "$rais_firm/cba_rais_firm_2009_2017_rep.dta", replace

