************************************************************************************************************************************
* Project: Union Spillovers
* Program: Creating 
* Author: Luis Gustavo Gomes
* Date: Nov 30, 2024
* 
* Objective: Arrange a dataset at the firm level that defines treated and control units,
*           / for both direct and indirect effects.
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
global cba_rais_firm "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level"
global tables "/kellogg/proj/lgg3230/UnionSpill/Tables"


*-------------------------------------------------------------------------------
* Part 1: defining firm level outcome and control variables
*-------------------------------------------------------------------------------



forvalues i=2009/2017{
	
	use "$cba_rais_tot/cba_rais_conn_`i'.dta", clear

    * Convert the date of admission from string to a Stata date and format it
    gen dtadmissao_stata = date(dtadmissao, "DMY")
    format dtadmissao_stata %td 

    * Create a dummy that equals 1 if the hiring date is on or before December 1 of year `i'
    gen hired_ndec = (dtadmissao_stata <= mdy(12,1,`i'))

    * Create a dummy that equals 1 if the employee is active in December of year `i'
    * (active means the hiring date is on or before December 1 of `i' and mesdesli equals 0)
    gen emp_in_dec = (dtadmissao_stata <= mdy(12,1,`i') & mesdesli == 0)

    * *********************
    * Wage outcomes
    * *********************

    ** Log-contracted-wages
    gen salcontr_m = .
    replace salcontr_m = salcontr if inlist(tiposal, 1, 6, 7)
    replace salcontr_m = 2 * salcontr if tiposal == 2
    replace salcontr_m = 4.345 * salcontr if tiposal == 3
    replace salcontr_m = 30.436875 * salcontr if tiposal == 4
    replace salcontr_m = 4.345 * horascontr * salcontr if tiposal == 5

    * Convert salcontr_m to 2015 values using Brazil's CPI (IPCA)
    gen lr_salcontr_m = . 

    /* Wage adjustment according to year:
       Uncomment only the condition for year 2011, leave the others commented out.
    */
     replace lr_salcontr_m = log(salcontr_m/.671594887351247) if `i'==2009
     replace lr_salcontr_m = log(salcontr_m/.711277338716318) if `i'==2010
    replace lr_salcontr_m = log(salcontr_m/.757534213038901) if `i'==2011
     replace lr_salcontr_m = log(salcontr_m/.80176356558955) if `i'==2012
     replace lr_salcontr_m = log(salcontr_m/.849153270408197) if `i'==2013
     replace lr_salcontr_m = log(salcontr_m/.903562518222102) if `i'==2014
     replace lr_salcontr_m = log(salcontr_m) if `i'==2015
     replace lr_salcontr_m = log(salcontr_m/1.06287988213221) if `i'==2016
     replace lr_salcontr_m = log(salcontr_m/1.09420743038879) if `i'==2017
     
     * Deflated contracted wages
     gen r_salcontr_m=.
     replace r_salcontr_m = salcontr_m/.671594887351247 if `i'==2009
     replace r_salcontr_m = salcontr_m/.711277338716318 if `i'==2010
     replace r_salcontr_m = salcontr_m/.757534213038901 if `i'==2011
     replace r_salcontr_m = salcontr_m/.80176356558955 if `i'==2012
     replace r_salcontr_m = salcontr_m/.849153270408197 if `i'==2013
     replace r_salcontr_m = salcontr_m/.903562518222102 if `i'==2014
     replace r_salcontr_m = salcontr_m if `i'==2015
     replace r_salcontr_m = salcontr_m/1.06287988213221 if `i'==2016
     replace r_salcontr_m = salcontr_m/1.09420743038879 if `i'==2017

    ** 90-10 and 50-10 wage ratio
    egen salcontr_p90 = pctile(lr_salcontr_m) if emp_in_dec == 1, by(identificad_8) p(90)
    egen salcontr_p50 = pctile(lr_salcontr_m) if emp_in_dec == 1, by(identificad_8) p(50)
    egen salcontr_p10 = pctile(lr_salcontr_m) if emp_in_dec == 1, by(identificad_8) p(10)

    gen lr_salcontr_90_10 = salcontr_p90 - salcontr_p10
    gen lr_salcontr_50_10 = salcontr_p50 - salcontr_p10

    ** Log average wages
    gen lr_remmedr = .
     replace lr_remmedr = log(remmedr/.671594887351247) if `i'==2009
     replace lr_remmedr = log(remmedr/.711277338716318) if `i'==2010
    replace lr_remmedr = log(remmedr/.757534213038901) if `i'==2011
     replace lr_remmedr = log(remmedr/.80176356558955) if `i'==2012
     replace lr_remmedr = log(remmedr/.849153270408197) if `i'==2013
     replace lr_remmedr = log(remmedr/.903562518222102) if `i'==2014
     replace lr_remmedr = log(remmedr) if `i'==2015
     replace lr_remmedr = log(remmedr/1.06287988213221) if `i'==2016
     replace lr_remmedr = log(remmedr/1.09420743038879) if `i'==2017
     
     
     ** Average deflated wages
     gen r_remmedr=.
     replace r_remmedr = remmedr/.671594887351247 if `i'==2009
     replace r_remmedr = remmedr/.711277338716318 if `i'==2010
     replace r_remmedr = remmedr/.757534213038901 if `i'==2011
     replace r_remmedr = remmedr/.80176356558955  if `i'==2012
     replace r_remmedr = remmedr/.849153270408197 if `i'==2013
     replace r_remmedr = remmedr/.903562518222102 if `i'==2014
     replace r_remmedr = remmedr                  if `i'==2015
     replace r_remmedr = remmedr/1.06287988213221 if `i'==2016
     replace r_remmedr = remmedr/1.09420743038879 if `i'==2017
     

    ** Log December earnings
    gen lr_remdezr = .
     replace lr_remdezr = log(remdezr/.671594887351247) if `i'==2009
     replace lr_remdezr = log(remdezr/.711277338716318) if `i'==2010
     replace lr_remdezr = log(remdezr/.757534213038901) if `i'==2011
     replace lr_remdezr = log(remdezr/.80176356558955) if `i'==2012
     replace lr_remdezr = log(remdezr/.849153270408197) if `i'==2013
     replace lr_remdezr = log(remdezr/.903562518222102) if `i'==2014
     replace lr_remdezr = log(remdezr) if `i'==2015
     replace lr_remdezr = log(remdezr/1.06287988213221) if `i'==2016
     replace lr_remdezr = log(remdezr/1.09420743038879) if `i'==2017
     
     ** Deflated December earnings
     gen r_remdezr = .
     replace r_remdezr = remdezr/.671594887351247 if `i'==2009
     replace r_remdezr = remdezr/.711277338716318 if `i'==2010
     replace r_remdezr = remdezr/.757534213038901 if `i'==2011
     replace r_remdezr = remdezr/.80176356558955 if `i'==2012
     replace r_remdezr = remdezr/.849153270408197 if `i'==2013
     replace r_remdezr = remdezr/.903562518222102 if `i'==2014
     replace r_remdezr = remdezr if `i'==2015
     replace r_remdezr = remdezr/1.06287988213221 if `i'==2016
     replace r_remdezr = remdezr/1.09420743038879 if `i'==2017
     
     

    ****************************
    * Employment Outcomes
    ****************************

    ** Log employment: count each unique employee (PIS) with emp_in_dec==1
    bysort identificad PIS: gen tag = cond(emp_in_dec==1 & _n==1, 1, 0)
    bysort identificad: egen firm_emp = total(tag)
    drop tag

    gen l_firm_emp = ln(firm_emp)
    gen open_firm = cond(firm_emp>0,1,0)

    ** Hiring rate: count workers with hiring date in year `i'
    gen new_hire = (year(dtadmissao_stata)==`i')
    bysort identificad: egen hired_count = total(new_hire)
    gen hiring = hired_count / firm_emp

    ** Retention rate
    gen emp_in_jan = (dtadmissao_stata < mdy(1,1,`i') & mesdesli != 1)
    gen emp_jan_dec = emp_in_jan * emp_in_dec
    bysort identificad PIS: gen tag = cond(emp_jan_dec==1, 1, 0)
    bysort identificad: egen firm_emp_jan = total(tag)
    drop tag
    gen retention = firm_emp_jan / firm_emp

    ** Turnover rate
    bysort identificad PIS: gen tag = cond(causadesli != 0, 1, 0)
    bysort identificad: egen separations = total(tag)
    drop tag
    gen turnover = separations / firm_emp

    *** Layoffs
    bysort identificad PIS: gen tag = cond(causadesli==10 | causadesli==11, 1, 0)
    bysort identificad: egen lay_count = total(tag)
    drop tag
    gen layoffs = lay_count / firm_emp

    *** Quits
    bysort identificad PIS: gen tag = cond(causadesli==20 | causadesli==21, 1, 0)
    bysort identificad: egen qui_count = total(tag)
    drop tag
    gen quits = qui_count / firm_emp

    ** Fixed contract 
    gen fixed_c = cond(tpvinculo==60 | tpvinculo==65 | tpvinculo==70 | tpvinculo==75, 1, 0)
    bysort identificad PIS: gen tag_fixed = cond(fixed_c==1, 1, 0)
    bysort identificad: egen fixed_count = total(tag_fixed)
    gen fixed_prop = fixed_count / firm_emp

    ** Safety events
    gen safety_d = cond(causadesli==62 | causadesli==73 | causadesli==74 | causafast1==10 | causafast1==30 | causafast2==10 | causafast2==30 | causafast3==10 | causafast1==30, 1, 0)
    bysort identificad PIS: gen tag_safe = cond(safety_d==1, 1, 0)
    bysort identificad: egen safety_c = total(tag_safe)
    drop tag_safe
    gen safety = safety_c / firm_emp

    ** Taking leave
    bysort identificad PIS: gen tag_leave = cond(causafast1 != -1, 1, 0)
    bysort identificad: egen leave_c = total(tag_leave)
    drop tag_leave
    gen leaves = leave_c / firm_emp

    ** Education groups
    gen no_hs_c = cond(inlist(grinstrucao, 1, 2, 3, 4, 5, 6), 1, 0)
    gen hs_c = cond(inlist(grinstrucao, 7, 8), 1, 0)
    gen sup_c = cond(inlist(grinstrucao, 8, 9, 10, 11), 1, 0)

    bysort identificad PIS: gen tag_nhs = cond(_n==1 & no_hs_c==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen no_high_school = total(tag_nhs)
    drop tag_nhs
    gen prop_nhs = no_high_school / firm_emp

    bysort identificad PIS: gen tag_hs = cond(_n==1 & hs_c==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen high_school = total(tag_hs)
    drop tag_hs
    gen prop_hs = high_school / firm_emp

    bysort identificad PIS: gen tag_sup = cond(_n==1 & sup_c==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen superior = total(tag_sup)
    drop tag_sup
    gen prop_sup = superior / firm_emp

    ** Occupation groups (left for later or further clarification)

    ** Age calculation

    * First, ensure that dtnascimento is a string.
    capture confirm string variable dtnascimento
    if _rc {
        tostring dtnascimento, replace force
    }

    gen dtnascimento_stata = date(dtnascimento, "DMY")
    format dtnascimento_stata %td

    quietly summarize dtnascimento_stata
    if missing(r(mean)) {
        di "dtnascimento_stata is missing; using existing idade variable to generate age groups."
        gen d_below_30 = cond(idade <= 30, 1, 0)
        gen betw_30_40 = cond(idade > 30 & idade <= 40, 1, 0)
        gen above_40 = cond(idade > 40, 1, 0)
    }
    else {
        di "dtnascimento_stata is available; computing age from dtnascimento_stata."
        gen ref_date = mdy(12,31,`i')
        gen computed_age = (ref_date - dtnascimento_stata) / 365.25
        replace computed_age = floor(computed_age)
        gen d_below_30 = cond(computed_age <= 30, 1, 0)
        gen betw_30_40 = cond(computed_age > 30 & computed_age <= 40, 1, 0)
        gen above_40 = cond(computed_age > 40, 1, 0)
        drop ref_date computed_age
    }

    bysort identificad PIS: gen tag_below_30 = cond(_n == 1 & d_below_30==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen total_below_30 = total(tag_below_30)
    gen prop_below_30 = total_below_30 / firm_emp
    drop d_below_30 tag_below_30

    * Alternatively, if computed_age is not available because dtnascimento_stata is missing,
    * the earlier generated betw_30_40 from idade might be used.
    bysort identificad PIS: gen tag_30_40 = cond(_n==1 & betw_30_40==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen total_30_40 = total(tag_30_40)
    gen prop_30_40 = total_30_40 / firm_emp
    drop betw_30_40 tag_30_40

    bysort identificad PIS: gen tag_above_40 = cond(_n==1 & above_40==1 & emp_in_dec==1, 1, 0)
    bysort identificad: egen total_above_40 = total(tag_above_40)
    gen prop_above_40 = total_above_40 / firm_emp
    drop above_40 tag_above_40

    ** Tenure
    gen ref_date = mdy(12,31,`i')
    gen tenure_stata = (ref_date - dtadmissao_stata) / 365.25
    gen tenure = floor(tenure_stata)
    drop ref_date tenure_stata
    bysort identificad: egen avg_tenure = mean(tenure) if emp_in_dec == 1

    ** Gender - proportion of males
    bysort identificad: egen male_prop = mean(genero) if emp_in_dec == 1

    ** Race - proportion of whites (assuming raca_cor==2 indicates white)
    gen white = cond(raca_cor==2, 1, 0)
    bysort identificad: egen white_prop = mean(white) if emp_in_dec == 1

    ** Public firms
    generate pub_firm = inlist(natjuridica, 1015,1023,1031,1040,1058,1066,1074,1082,1104,1112,1120,1139,1147,1155,1163,1171,1180,1198,1201,1210)





*--------------------------------------------------------------------------------
*Part 2: Collapsing the dataset to the firm level
*--------------------------------------------------------------------------------

collapse ///
(first) white_prop male_prop avg_tenure prop_abov~40 prop_30_40 prop_belo~30 prop_sup prop_hs prop_nhs ///
 leaves leave_c safety fixed_prop fixed_count quits qui_count layoffs lay_count turnover separations retention ///
 firm_emp_jan hiring hired_count l_firm_emp firm_emp lr_sal~50_10 lr_sal~90_10 salcontr_p10 salcontr_p50 salcontr_p90 ///
 firm_cba stacode2 assoc_count clean_asso~j natjuridica clascnae20 municipio numb_clauses file_date_~a ultra cl_* /// 
 negotiatio~s start_date~a end_date_s~a text_tokens active_year year codigo_mun~o union_id identifica~8 treat_ultra ///
 con_2009_2010 outt_2009_2010 int_2009_2010 outtotreat_p_2009_2010 infromtreat_p_2009_2010 con_2010_2011 outt_2010_2011 int_2010_2011 outtotreat_p_2010_2011 infromtreat_p_2010_2011 con_2011_2012 outt_2011_2012 int_2011_2012 outtotreat_p_2011_2012 infromtreat_p_2011_2012 con_2012_2013 outt_2012_2013 int_2012_2013 infromtreat_p_2012_2013 outtotreat_p_2012_2013 con_2013_2014 outt_2013_2014 int_2013_2014 outtotreat_p_2013_2014 infromtreat_p_2013_2014 con_2014_2015 outt_2014_2015 int_2014_2015 outtotreat_p_2014_2015 infromtreat_p_2014_2015 con_2015_2016 outt_2015_2016 int_2015_2016 outtotreat_p_2015_2016 infromtreat_p_2015_2016 con_2016_2017 outt_2016_2017 int_2016_2017 outtotreat_p_2016_2017 infromtreat_p_2016_2017 infromsample_p_2009_2010 con_sample_2010_2011 outs_2010_2011 ins_2010_2011 outtosample_p_2010_2011 infromsample_p_2010_2011 con_sample_2011_2012 outs_2011_2012 ins_2011_2012 outtosample_p_2011_2012 infromsample_p_2011_2012 con_sample_2012_2013 outs_2012_2013 ins_2012_2013 outtosample_p_2012_2013 infromsample_p_2012_2013 con_sample_2013_2014 outs_2013_2014 ins_2013_2014 outtosample_p_2013_2014 infromsample_p_2013_2014 con_sample_2014_2015 outs_2014_2015 ins_2014_2015 outtosample_p_2014_2015 infromsample_p_2014_2015 con_sample_2015_2016 outs_2015_2016 ins_2015_2016 outtosample_p_2015_2016 infromsample_p_2015_2016 con_sample_2016_2017 outs_2016_2017 ins_2016_2017 outtosample_p_2016_2017 infromsample_p_2016_2017 con_r_2009_2010 outt_r_2009_2010 int_r_2009_2010 outtotreat_r_p_2009_2010 infromtreat_r_p_2009_2010 con_r_2010_2011 outt_r_2010_2011 int_r_2010_2011 outtotreat_r_p_2010_2011 infromtreat_r_p_2010_2011 con_r_2011_2012 outt_r_2011_2012 int_r_2011_2012 outtotreat_r_p_2011_2012 infromtreat_r_p_2011_2012 con_r_2012_2013 outt_r_2012_2013 int_r_2012_2013 outtotreat_r_p_2012_2013 infromtreat_r_p_2012_2013 con_r_2013_2014 outt_r_2013_2014 int_r_2013_2014 outtotreat_r_p_2013_2014 infromtreat_r_p_2013_2014 con_r_2014_2015 outt_r_2014_2015 int_r_2014_2015 outtotreat_r_p_2014_2015 infromtreat_r_p_2014_2015 con_r_2015_2016 outt_r_2015_2016 int_r_2015_2016 outtotreat_r_p_2015_2016 infromtreat_r_p_2015_2016 con_r_2016_2017 outt_r_2016_2017 int_r_2016_2017 outtotreat_r_p_2016_2017 infromtreat_r_p_2016_2017 con_sample_2009_2010 outs_2009_2010 ins_2009_2010 outtosample_p_2009_2010 pub_firm mode_base_month ///
(mean) lr_remdezr lr_remmedr lr_salcont~m r_salcontr_m r_remmedr r_remdezr ///
, by(identificad)

save "$cba_rais_firm/cba_rais_firm_`i'.dta", replace
}

use "$cba_rais_firm/cba_rais_firm_2009.dta", clear
append using "$cba_rais_firm/cba_rais_firm_2010.dta"
append using "$cba_rais_firm/cba_rais_firm_2011.dta"
append using "$cba_rais_firm/cba_rais_firm_2012.dta"
append using "$cba_rais_firm/cba_rais_firm_2013.dta"
append using "$cba_rais_firm/cba_rais_firm_2014.dta"
append using "$cba_rais_firm/cba_rais_firm_2015.dta"
append using "$cba_rais_firm/cba_rais_firm_2016.dta"
append using "$cba_rais_firm/cba_rais_firm_2017.dta"


** GENERATING INDICATOR FOR LORENZO'S SAMPLE

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

gen lorenzo_sample = (cba_pre2012 == 1 & cba_post2012 == 1 & pos_emp == 1)
gen lorenzo_treat = (lorenzo_sample==1 & treat_ultra==1)
gen lorenzo_control = (lorenzo_sample==1 & treat_ultra==0)

save "$cba_rais_firm/cba_rais_firm_2009_2017_0.dta", replace

preserve
collapse (first) lorenzo_sample,by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lorenzo_sample.dta", replace


export delimited "$rais_aux/lorenzo_sample.csv", replace
restore

preserve
collapse (first) lorenzo_control, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lorenzo_control.dta", replace


export delimited "$rais_aux/lorenzo_control.csv", replace
restore

preserve
collapse (first) lorenzo_treat, by(identificad)
gen identificad1 = "1"+identificad
drop identificad 
rename identificad1 identificad

save "$rais_aux/lorenzo_treat.dta", replace


export delimited "$rais_aux/lorenzo_treat.csv", replace
restore

/*
*-------------------------------------------------------------------------------------------------------------
* PART 4: Compute connectivity measures using MATLAB
*         Call MATLAB from Stata (using shell) to run the connectivity.m script.
*         (The MATLAB script will use the prepared flow datasets to compute connectivity measures.)
*-------------------------------------------------------------------------------------------------------------
shell "/software/matlab/R2018a/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_lcontrol.m"
shell "/software/matlab/R2018a/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_ltreat.m"

*-------------------------------------------------------------------------------------------------------------
* PART 5: Post-process the connectivity measures in Stata
*         - Import the final connectivity dataset from MATLAB (CSV file).
*         - Convert employer ID to string format and adjust it to remove the prefixed "1".
*-------------------------------------------------------------------------------------------------------------
import delimited "$rais_aux/connectivity_lcontrol_2009_2012.csv", clear
 
* Convert identificad to string; generate a new variable identificad_ with format %18.0f
tostring identificad, gen(identificad_) format(%18.0f)
drop identificad
rename identificad_ identificad
 
* Remove the prefixed "1" from identificad by extracting characters from position 2 for a length of 14
gen identificad1 = substr(identificad,2,14)

drop identificad lorenzo_control
rename  identificad1 identificad

save "$rais_aux/connectivity_lcontrol_2009_2012.dta", replace

import delimited "$rais_aux/connectivity_ltreat_2009_2012.csv", clear
 
* Convert identificad to string; generate a new variable identificad_ with format %18.0f
tostring identificad, gen(identificad_) format(%18.0f)
drop identificad
rename identificad_ identificad
 
* Remove the prefixed "1" from identificad by extracting characters from position 2 for a length of 14
gen identificad1 = substr(identificad,2,14)

drop identificad lorenzo_treat
rename  identificad1 identificad

save "$rais_aux/connectivity_ltreat_2009_2012.dta", replace

*-------------------------------------------------------------------------------------------------------------
* PART 7: merge connectivity measures to main dataset 
*-------------------------------------------------------------------------------------------------------------

use "$rais_aux/connectivity_lcontrol_2009_2012.dta", clear
merge 1:m identificad using "$cba_rais_firm/cba_rais_firm_2009_2017_0.dta"
drop _merge
save "$cba_rais_firm/cba_rais_firm_2009_2017_1.dta",replace
erase "$cba_rais_firm/cba_rais_firm_2009_2017_0.dta"

use "$rais_aux/connectivity_ltreat_2009_2012.dta", clear
merge 1:m identificad using "$cba_rais_firm/cba_rais_firm_2009_2017_1.dta"
drop _merge
save "$cba_rais_firm/cba_rais_firm_2009_2017.dta",replace
erase "$cba_rais_firm/cba_rais_firm_2009_2017_1.dta"
*/


gen industry =  substr(clascnae20,1,3)

gen microrregiao =  substr(municipio,1,5)

save "$cba_rais_firm/cba_rais_firm_2009_2017_0.dta", replace






