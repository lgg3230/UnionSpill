********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS, GENERATE OUTCOMES, COLLAPSE TO FIRM LEVEL
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: FIRM LEVEL RAIS FILES WITH ANALYSIS OUTCOMES
********************************************************************************






foreach i in 2009 2010 2011 2012 2013 2014 2015 2016{
	
// 	local i=2009
	use "$rais_raw_dir/RAIS_`i'.dta",clear
	
	
	
	
	* Generate year variables
	
	gen year = `i'
	gen identificad_8 = substr(identificad,1,8)
	
	* Generate age variable for databases that do not have it
	
	
	cap confirm var idade
	if _rc{
		gen dob_date = date(dtnascimento,"DMY")
		format dob_date %td
		gen anonasc = year(dob_date)
		gen idade = year - anonasc
		drop anonasc dob_date
	*gen idade=.
	}
	
	* checkif variable dtnascimento exist. if not, create it
	
	cap confirm var dtnascimento
	if _rc{
		gen dtnascimento=.
	}
	
	keep year PIS CPF numectps nome identificad identificad_8 municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	order year PIS CPF numectps nome identificad identificad_8 municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	

 
    * Convert the date of admission from string to a Stata date and format it
    gen dtadmissao_stata = date(dtadmissao, "DMY")
    format dtadmissao_stata %td 

    * Create a dummy that equals 1 if the hiring date is on or before December 1 of year `i'
    gen hired_ndec = (dtadmissao_stata <= mdy(11,30,`i'))

    * Create a dummy that equals 1 if the employee is active in December of year `i'
    * (active means the hiring date is on or before December 1 of `i' and mesdesli equals 0)
    gen emp_in_dec = (dtadmissao_stata <= mdy(11,30,`i') & mesdesli == 0)

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
    
    
    gen salcontr_h = salcontr
    

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
    
    ** using wage type, convert average earnings to monthly measure
        
    gen remmedr_m =remmedr
    replace remmedr_m = remmedr if inlist(tiposal, 1, 6, 7)
    replace remmedr_m = 2 * remmedr if tiposal == 2
    replace remmedr_m = 4.345 * remmedr if tiposal == 3
    replace remmedr_m = 30.436875 * remmedr if tiposal == 4
    replace remmedr_m = 4.345 * horascontr * remmedr if tiposal == 5
    
    gen lr_remmedr = .
     replace lr_remmedr = log(remmedr_m/.671594887351247) if `i'==2009
     replace lr_remmedr = log(remmedr_m/.711277338716318) if `i'==2010
    replace lr_remmedr = log(remmedr_m/.757534213038901) if `i'==2011
     replace lr_remmedr = log(remmedr_m/.80176356558955) if `i'==2012
     replace lr_remmedr = log(remmedr_m/.849153270408197) if `i'==2013
     replace lr_remmedr = log(remmedr_m/.903562518222102) if `i'==2014
     replace lr_remmedr = log(remmedr_m) if `i'==2015
     replace lr_remmedr = log(remmedr_m/1.06287988213221) if `i'==2016
     replace lr_remmedr = log(remmedr_m/1.09420743038879) if `i'==2017
     
     
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
    * adjust wages by hours worked:
    gen remdezr_m =.
    replace remdezr_m = remdezr if inlist(tiposal, 1, 6, 7) // if type of work is regular
    replace remdezr_m = 2 * remdezr if tiposal == 2 // if type of work is byweekly
    replace remdezr_m = 4.345 * remdezr if tiposal == 3 // if type of work is weeklykly
    replace remdezr_m = 30.436875 * remdezr if tiposal == 4 // if type of work is daily
    replace remdezr_m = 4.345 * horascontr * remdezr if tiposal == 5 // if type of work is by weekly hour
    
    // adjust wages to logs and at december 2015 prices
    
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
(firstnm) identificad_8 white_prop male_prop avg_tenure prop_abov~40 prop_30_40 prop_belo~30 prop_sup prop_hs prop_nhs year ///
 leaves leave_c safety fixed_prop fixed_count quits qui_count layoffs lay_count turnover separations retention pub_firm ///
 firm_emp_jan hiring hired_count l_firm_emp firm_emp lr_sal~50_10 lr_sal~90_10 salcontr_p10 salcontr_p50 salcontr_p90 ///
 municipio clascnae20 natjuridica ///
(mean) lr_remdezr lr_remmedr lr_salcont~m r_salcontr_m r_remmedr r_remdezr ///
, by(identificad)

	** industry groups
	gen industry =  substr(clascnae20,1,3)

	** microrregion groups
	tostring municipio, replace force
	gen microrregiao =  substr(municipio,1,5)


save "$rais_firm/rais_firm_`i'.dta", replace

keep identificad identificad_8 municipio firm_emp
gen state = substr(municipio,1,2)

keep if firm_emp>0

save "$rais_aux/unique_estab_`i'.dta", replace

	
}
