********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS, GENERATE OUTCOMES, COLLAPSE TO FIRM LEVEL
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: FIRM LEVEL RAIS FILES WITH ANALYSIS OUTCOMES
********************************************************************************




local years "2007 2008 2009 2010 2011 2012 2013 2014 2015 2016"
local ipca  " 0.607949398754109 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"


forvalues i=2009/2016{
	
// 	local i=2007
	use "$rais_raw_dir/RAIS_`i'.dta",clear
	
	
	
	
	* Generate year variables
	
	gen year = `i' // generates year variable for whole dataset, used later to mactch with cba data
	gen identificad_8 = substr(identificad,1,8) // firm identifier, only 1st 8 digits of cnpj
	
	* Step 1: Check what age-related variables exist and create missing ones
cap confirm var idade
if _rc {
    gen idade = .
    di "idade variable created as missing"
}

cap confirm var dtnascimento  
if _rc {
    gen dtnascimento = ""
    di "dtnascimento variable created as missing"
}

* Step 2: Ensure dtnascimento is string format for consistent processing
capture confirm string variable dtnascimento
if _rc {
    tostring dtnascimento, replace force
}

* Step 3: Create a unified age variable that works across all years
gen idade_unified = .

* Case 1: If we have idade (age) but no dtnascimento, use idade directly
count if !missing(idade) & (missing(dtnascimento) | dtnascimento == "")
if r(N) > 0 {
    replace idade_unified = idade if !missing(idade) & (missing(dtnascimento) | dtnascimento == "")
    di "Using idade for " r(N) " observations"
}

* Case 2: If we have dtnascimento but no idade, calculate age from birthday
count if (missing(idade) | idade == .) & !missing(dtnascimento) & dtnascimento != ""
if r(N) > 0 {
    * Convert birthday to Stata date format
    gen dob_date = date(dtnascimento, "DMY")
    format dob_date %td
    
    * Calculate age as of December 31st of current year
    gen ref_date = mdy(12, 31, `i')
    gen calculated_age = (ref_date - dob_date) / 365.25
    replace calculated_age = floor(calculated_age)
    
    * Use calculated age where idade is missing
    replace idade_unified = calculated_age if (missing(idade) | idade == .) & !missing(calculated_age)
    
    di "Calculated age from dtnascimento for " r(N) " observations"
    
    * Clean up temporary variables
    drop dob_date ref_date calculated_age
}

* Case 3: If we have both, prefer dtnascimento (more precise) but use idade as fallback
count if !missing(idade) & !missing(dtnascimento) & dtnascimento != ""
if r(N) > 0 {
    * First try to calculate from dtnascimento
    gen dob_date = date(dtnascimento, "DMY")
    format dob_date %td
    gen ref_date = mdy(12, 31, `i')
    gen calculated_age = (ref_date - dob_date) / 365.25
    replace calculated_age = floor(calculated_age)
    
    * Use calculated age where it's valid, otherwise use idade
    replace idade_unified = calculated_age if !missing(calculated_age) & calculated_age >= 0 & calculated_age <= 100
    replace idade_unified = idade if missing(idade_unified) & !missing(idade) & idade >= 0 & idade <= 100
    
    di "Used dtnascimento for " r(N) " observations with both variables available"
    
    * Clean up temporary variables
    drop dob_date ref_date calculated_age
}

* Step 4: Create standardized age and birthday variables for consistency
* Standardize idade to use the unified version
replace idade = idade_unified if !missing(idade_unified)

* Create a standardized dtnascimento variable
gen dtnascimento_std = dtnascimento
replace dtnascimento_std = "" if missing(dtnascimento_std)

	
	// homogenizing variables across years.
	* Core variables available 2007-2016
    keep year PIS CPF numectps nome identificad identificad_8 municipio ///
     tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ///
     ocup2002 grinstrucao genero dtnascimento idade nacionalidad ///
     portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr ///
     tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 ///
     tamestab natjuridica tipoestbl indceivinc ceivinc indalvara ///
     indpat indsimples causafast1 causafast2 causafast3 ///
     diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 ///
     mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3

	order year PIS CPF numectps nome identificad identificad_8 municipio ///
     tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ///
      ocup2002 grinstrucao genero dtnascimento idade nacionalidad /// 
      portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr /// 
      tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 /// 
      tamestab natjuridica tipoestbl indceivinc ceivinc indalvara /// 
      indpat indsimples  causafast1 causafast2 causafast3 /// 
      diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 /// 
      mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	
	di "keep successfull"
	
	// converting identifiers to double in order to apply Lagos(2021) selection rules
	destring PIS, gen(PIS_d)
	destring identificad, gen(identificad_d)
	
	// remove invalid identifiers or remuneration (drop if x==1)
	// from Lagos (2021), PIS_d removes very few obs, identificad_d removes no obs, remdezr<=0 removes part of people not employed through dec.
// 	gen x= (PIS_d<1000) | (identificad_d<=0) | (remdezr<=0)
// 	tab x // nobody, in 2009 at least 
//  	drop if x==1
// 	drop x 
 
    * Convert the date of admission from string to a Stata date and format it
    gen dtadmissao_stata = date(dtadmissao, "DMY")
    format dtadmissao_stata %td 
//


//     * Create a dummy that equals 1 if the hiring date is on or before December 1 of year `i'
     gen hired_ndec = (dtadmissao_stata <= mdy(11,30,`i'))
//
//     * Create a dummy that equals 1 if the employee is active in December of year `i'
//     * (active means the hiring date is on or before December 1 of `i' and mesdesli equals 0)
//     gen emp_in_dec = (dtadmissao_stata <= mdy(11,30,`i') & mesdesli == 0) // 
    
    // generate dummy of employment in december according to Lagos(2021) -- let's use this one instead of ours
    gen empdec_lagos = empem3112*(tempempr>1)

    * *********************
    * Wage outcomes
    * *********************
    
// Adjust wage variables: 

** Log-contracted-wages 

// Adjust 2016 contracted wages according to Lagos (2024)'s footnote 76: multiply by 100 any contracted wage below minimum wage.

if `i'==2016{
	replace salcontr = 100*salcontr if salcontr<880
}
 


// salcontr is non missing only for 10% of the spells in some years. 
// adjusting wage measure for each contract type. This does not changes the dist too much



    gen salcontr_m = .
    replace salcontr_m = salcontr if inlist(tiposal, 1, 6, 7) // keep the same if salaray is monthly, other or per task (dont know how to deal with per task)
    replace salcontr_m = 2 * salcontr if tiposal == 2 // multiply by two if it is biweekly
    replace salcontr_m = 4.348 * salcontr if tiposal == 3 // multiply by avg number of weeks if weekly
    replace salcontr_m = 30.436875 * salcontr if tiposal == 4 // multiply by avg number of days if daily
    replace salcontr_m = 4.348 * horascontr * salcontr if tiposal == 5 // multiply by monthly hours if hourly
    label var salcontr_m "Salario contratual, ajustado para valor mensal de acordo com o tipo de salario"
    
    gen salcontr_h = salcontr_m/(horascontr*4.348) // contractual salary divided by the amount of contracted hours in the month
    label var salcontr_h "Salario contratual dividido pelo total de horas trabalhadas no mes"

	
** Log average wages
    
    ** using wage type, convert average earnings to monthly measure
        
    // I will not do any adjustment to average earnings because this makes the dist look very weird. I did not understand Lagos' (2024) hourly adjustment.
    // Lagos (2024) "hourly adjustment": When this outcome is reported as "hourly," I divide the average earnings by monthly contracted hours before taking logs and calculating the mean
    // I am interpreting "outcome being reported as hourly" = tiposal==5. These outcomes have similar dist to other wage measures, if I do this, I get very low number for this wage type. 
    // though he might have switched "multiply"  for "divide" wrongly, but multiplying yields even wilder results. 
    
    // computing average hourly earnings:
    gen remmedr_h = remmedr/(horascontr*4.348) // contractual salary divided by the amount of contracted hours in the month
    label var remmedr_h "remuneracao media anual dividido pelo total de horas contratadas"
	

	
** Log December earnings
    
    // Compute hourly december wages:
    
    gen remdezr_h = remdezr/(horascontr*4.348) // contractual salary divided by the amount of contracted hours in the month
    label var remdezr_h "remuneracao de dezembro dividido pelo total de horas contratadas"	
	
	
	
	
// Generate variables in logs and deflated




// just for test
//
// local years "2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016"
// local ipca  "0.582005577354073 0.607949398754109 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"
// local i=2016

local pos = `i'- 2006
local deflator : word `pos' of `ipca'
    
    * Convert salcontr_m to 2015 values using Brazil's CPI (IPCA)
    gen lr_salcontr_m = . 

    /* Wage adjustment according to year:
    */
	replace lr_salcontr_m = log(salcontr_m/`deflator') 
	 label var lr_salcontr_m "Log Salario contratual , a precos do ano de 2015"

	 
	
	
     // hourly contracted wages:
     gen lr_salcontr_h=.
	 replace lr_salcontr_h = log(salcontr_h/`deflator')
	 label var lr_salcontr_m "Log Salario contratual por hora , a precos do ano de 2015"

     
     * Deflated contracted wages
     
     
     gen r_salcontr_m=.
	 replace r_salcontr_m = salcontr_m/`deflator'
	 label var r_salcontr_m "Salario contratual, a precos de 2015"
     

     
     gen r_salcontr_h=.
	 replace r_salcontr_h = salcontr_h/`deflator'
	 label var r_salcontr_h "Salario contratual por hora, a precos de 2015"

   
    // adjuting monthly average earnings for inflation and taking logs (2015 0prices) (december ipca index)
    gen lr_remmedr = .
	replace lr_remmedr = log(remmedr/`deflator')

     
      ** Average deflated wages
     gen r_remmedr=.
	 replace r_remmedr = remmedr/`deflator'
	 

     
     //making the same for hourly average earnings:
     ** deflated hourly Average wages
     gen r_remmedr_h=.
	 replace r_remmedr_h = remmedr_h/`deflator'

     
     // adjuting hourly average earnings for inflation and taking logs (2015 0prices)
    gen lr_remmedr_h = .
	replace lr_remmedr_h = log(remmedr_h/`deflator')

    
    
    // adjust hourly dec earnings to logs and at december 2015 prices
    
       
    gen lr_remdezr_h = .
	replace lr_remdezr_h = log(remdezr_h/`deflator')

     ** Deflated December hourly earnings
     gen r_remdezr_h = .
	 replace r_remdezr_h = log(remdezr_h/`deflator')

    
    // adjust wages to logs and at december 2015 prices
    
    
    
    gen lr_remdezr = .
	replace lr_remdezr = log(remdezr/`deflator')

     ** Deflated December earnings
     gen r_remdezr = .
	 replace r_remdezr = remdezr/`deflator'

	 ** 90-10 and 50-10 wage ratio
    egen salcontr_p90 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(90)
    egen salcontr_p50 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(50)
    egen salcontr_p10 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(10)

    gen lr_salcontr_90_10 = salcontr_p90 - salcontr_p10
    gen lr_salcontr_50_10 = salcontr_p50 - salcontr_p10
    
    
     
     

    ****************************
    * Employment Outcomes
    ****************************

    ** Log employment: count each unique employee (PIS) with empdec_lagos==1
    // we need to select a single spell per worker per estab (we are counting the employee twice if they are also an employee in another estab)
    // but this makes sense, because from the establishment pov it counts as its employment.
    
//     set seed 12345 // we will randomly pick among spells active throughout december within each estab
//     gen random=runiform()
//    
//     sort identificad PIS random // This ensures a random order among spells for the same worker-establishment pair
//     bys identificad PIS: gen count_worker = (empdec_lagos==1 & _n==1) // _n==1 is random now
//    
//     bys identificad: egen firm_emp = sum(count_worker) // within estab, count unique workers
//     drop random 
//     sum firm_emp, detail
//
//     gen l_firm_emp = ln(firm_emp)
//     gen open_firm = cond(firm_emp>0,1,0)
//    
    
    // alternative approach: let's see if it delivers the same employment measurements:
    
    * For each worker-establishment pair, create rankings according to your criteria
* Step 1: Rank by contracted hours (higher = better)
bysort identificad PIS: egen max_hours = max(horascontr ) // orders by estab_id and then PIS, within each estab-PIS group, takes the max of the contract hours, given that this spell is active in dec
gen rank1 = (horascontr == max_hours & empdec_lagos==1) // generates an indicator for the spells active throughout dec and whose contracted hours match the max 

* Step 2: Among those with max hours, rank by hourly wage (higher = better)
bysort identificad PIS: egen max_wage = max(lr_remdezr_h * rank1) // orderd by estab id and PIS, within each group computes the max of the log hourly dec wages within the max contracted hours that are active in dec
gen rank2 = (lr_remdezr_h == max_wage & rank1==1) // marks spells w/in estab-pis active in dec that have max hourly log dec wages among those that have max contracted hours

* Step 3: For any remaining ties, assign a random number
set seed 12345
gen random = runiform() if rank2==1 // gen random number w/in spells that fulfill conditions of rank2

* Create a final rank combining all criteria
bysort identificad PIS: egen max_random = max(random * rank2) // w/in estab-PIS-max hourly log dec wage-max contracted hours computes the maximum random number
gen final_rank = (random == max_random & rank2==1) // marks spells that fulfill rank2 and have max random number

* count the number of selected spells within each establishment:
bysort identificad: egen firm_emp = total(final_rank==1 ) // w/in estab counts spells that fulfill conditions of final_rank. 


gen l_firm_emp = ln(firm_emp) // generate log firm employment
gen open_firm = cond(firm_emp>0,1,0) // generate dummy to mark firms that are open throughout december

* Clean up temporary variables
drop  max_hours rank1 max_wage rank2 random max_random 

 // since the remaining variables are not being used as replication benchmarks, then we will leave them as they are right now
//  local i=2016
 ** Hiring rate: count workers with hiring date in year `i'. This is counting the number of SPELLS, not workers.

//  local i=2009
 
    gen new_hire = (year(dtadmissao_stata)==`i') // indicates if a spell was started during the current year
    bysort identificad: egen hired_count = total(new_hire) // counts the number of new spells per estab
	gen hiring = hired_count / firm_emp // computes the ratio of new spells to firm employment in december
	
	** attempt at correcting hiring:
	
// 	local i = 2009

* 1) Flag spells that START in year i (do NOT filter to Dec-employed)
gen byte new_hire_u = year(dtadmissao_stata) == `i'

* 2) Tag each worker once per establishment among those new_hire==1
*    (avoids double-counting workers with multiple hires/spells in the year)
egen byte hire_tag = tag(identificad PIS) if new_hire_u

* 3) Count unique hires per establishment and compute hiring rate
bysort identificad: egen hired_count_u = total(hire_tag)
gen hiring_u = hired_count_u / firm_emp
label var hiring_u "Hiring rate (unique workers hired in year i / Dec emp)"

* (Optional) clean-up
drop hire_tag

    ** Retention rate
    gen emp_in_jan = (dtadmissao_stata < mdy(1,1,`i') & mesdesli != 1) //indicates spells that were active before the beginning of the year, but were not terminated in Jan
    egen byte emp_in_jan_tag = tag(identificad PIS) if emp_in_jan==1
	gen emp_jan_dec = emp_in_jan_tag * final_rank // indicates which spells among those still active in dec were active throughout jan (bc it is multiplying by empdec_lagos, this actually counts employees)
// 	set seed 12345
// 	gen random = runiform() if emp_jan_dec==1
// 	bys identificad PIS: egen max_random=max(random)
//	
// 	gen rank = (random==max_random & emp_jan_dec==1)
	
	
    bysort identificad: egen firm_emp_jan = total(emp_jan_dec) // sums by each firmn the number of employees that were active in Jan that remained active in dec
// 	drop rank
//     bysort identificad: egen firm_emp_jan = total(emp_jan_dec) // sums by each firmn the number of employees that were active in Jan that remained active in dec
    gen retention = firm_emp_jan / firm_emp // make it as a ratio of estab employment

    ** Turnover rate
    bysort identificad: egen separations = total(cond(causadesli != 0, 1, 0)) // w/in each estab, tag spells that were terminated for any reason during the whole year
    gen turnover = separations / firm_emp 

    *** Layoffs
    bysort identificad: egen lay_count = total(cond(causadesli==10 | causadesli==11, 1, 0)) // w/in each estab, tag spells that fired by the employer during the whole year
    gen layoffs = lay_count / firm_emp

    *** Quits
    bysort identificad: egen qui_count = total(cond(causadesli==20 | causadesli==21, 1, 0)) // w/in each estab, tag spells that were terminated by the employee during the whole year
    gen quits = qui_count / firm_emp

    ** Fixed contract 
    gen fixed_c = cond(tpvinculo==60 | tpvinculo==65 | tpvinculo==70 | tpvinculo==75 | tpvinculo==95 | tpvinculo==96 |tpvinculo==97 | tpvinculo==90, 1, 0) // mark spells w/ fixed duration contracts: CLT U/PJ DET (60), CLT U/PF DET (65), CLT R/PJ DET (70), CLT R/PF DET (75), CONT PRZ DET (90), CONT TMP DET(95), CONT LEI EST(96), CONT LEI MUN (97)
    bysort identificad: egen fixed_count = total(fixed_c) // count marked spells within each estab whose contract type is fixed duration
    gen fixed_prop = fixed_count / firm_emp

    ** Safety events
    gen safety_d = cond(causadesli==62 | causadesli==73 | causadesli==74 | causafast1==10 | causafast1==30 | causafast2==10 | causafast2==30 | causafast3==10 | causafast1==30, 1, 0) // mark spells that were affected by a safety incident : death from work accident (62), retiring from work accident (73), retiring from work acquired disease (74),  leave due to work accident (10), leave due to work disease (30)
    bysort identificad: egen safety_c = total(safety_d) // count safety events per estab
    gen safety = safety_c / firm_emp

    ** Taking leave
    bysort identificad PIS: egen leave_c = total(cond(causafast1 != -1, 1, 0)) // mark spells that took a leave sometime in the year, count per estab
    gen leaves = leave_c / firm_emp

    ** Education groups
    gen no_hs_c = cond(inlist(grinstrucao, 1, 2, 3, 4, 5, 6), 1, 0) // mark spells with no high school (illiterate (1) + incomplete elementary (2-5) + incomplete high schools(6))
    gen hs_c = cond(inlist(grinstrucao, 7, 8), 1, 0) // mark spells with complete high school (7) and incomplete college (8) 
    gen sup_c = cond(inlist(grinstrucao, 9, 10, 11), 1, 0) // mark spells with complete college (9), masters (10) and doctoral degree (11)

    bysort identificad PIS: gen tag_nhs = cond(no_hs_c==1 & final_rank==1, 1, 0) // marks relevant (final_rank==1) spell w/in estab-PIS pair that is employed throughout dec that has incomplete hs
    bysort identificad: egen no_high_school = total(tag_nhs) // count this number of employees per estab
    drop tag_nhs
    gen prop_nhs = no_high_school / firm_emp

    bysort identificad PIS: gen tag_hs = cond(hs_c==1 & final_rank==1, 1, 0) // marks  relevant (final_rank==1) w/in estab-PIS pair that is employed throughout dec that has complete hs
    bysort identificad: egen high_school = total(tag_hs)
    drop tag_hs
    gen prop_hs = high_school / firm_emp

    bysort identificad PIS: gen tag_sup = cond(sup_c==1 & final_rank==1, 1, 0) // marks relevant (final_rank==1) spell w/in estab-PIS pair that is employed throughout dec that has complete college
    bysort identificad: egen superior = total(tag_sup)
    drop tag_sup
    gen prop_sup = superior / firm_emp

    ** Occupation groups (left for later or further clarification)

    ** Age calculation

    * First, ensure that dtnascimento is a string.
    capture confirm string variable dtnascimento // confirm dtnascimento is in string format
    if _rc { // in negative case, converts to string
        tostring dtnascimento, replace force
    }

    gen dtnascimento_stata = date(dtnascimento, "DMY") // converts string dtnascimento to stata date format
    format dtnascimento_stata %td

    quietly summarize dtnascimento_stata // computes means and other moments of dtnascimento
    if missing(r(mean)) { // if mean is missing, means that dtnascimento is missing, so we need to use idade to calculate worker ages
        di "dtnascimento_stata is missing; using existing idade variable to generate age groups."
        gen d_below_30 = cond(idade <= 30, 1, 0) // marks spells whose age is less than 30 yo
        gen betw_30_40 = cond(idade > 30 & idade <= 40, 1, 0) // marks age between 30 and 40
        gen above_40 = cond(idade > 40, 1, 0) // marks age more than 40 
    }
    else {  //  if mean is not missing, use dtnascimento
       di "dtnascimento_stata is available; computing age from dtnascimento_stata."
        gen ref_date = mdy(12,31,`i') // makes reference date, so that worker age is computed as end of year age
        gen computed_age = (ref_date - dtnascimento_stata) / 365.25 // computes age of employees, with decimal numbers
        replace computed_age = floor(computed_age) // exclude decimals to compute just the number of complete birthdays since birth
        gen d_below_30 = cond(computed_age <= 30, 1, 0) // marks age groups 
        gen betw_30_40 = cond(computed_age > 30 & computed_age <= 40, 1, 0)
        gen above_40 = cond(computed_age > 40, 1, 0)
        drop ref_date computed_age
    }

    bysort identificad PIS: gen tag_below_30 = cond(_n == 1 & d_below_30==1 & empdec_lagos==1, 1, 0) // marks first spell of an employee active through dec that is younger than 30yo
    bysort identificad: egen total_below_30 = total(tag_below_30) // counts these workers w/in estab
    gen prop_below_30 = total_below_30 / firm_emp
    drop d_below_30 tag_below_30

    * Alternatively, if computed_age is not available because dtnascimento_stata is missing,
    * the earlier generated betw_30_40 from idade might be used.
    bysort identificad PIS: gen tag_30_40 = cond(_n==1 & betw_30_40==1 & empdec_lagos==1, 1, 0)
    bysort identificad: egen total_30_40 = total(tag_30_40)
    gen prop_30_40 = total_30_40 / firm_emp
    drop betw_30_40 tag_30_40

    bysort identificad PIS: gen tag_above_40 = cond(_n==1 & above_40==1 & empdec_lagos==1, 1, 0)
    bysort identificad: egen total_above_40 = total(tag_above_40)
    gen prop_above_40 = total_above_40 / firm_emp
    drop above_40 tag_above_40

    ** Tenure
    bysort identificad: egen avg_tenure = mean(tempempr) if final_rank == 1 // take the mean w/in estabs among workers active throughout dec

    ** Gender - proportion of males
    bysort identificad: egen male_prop = mean(genero) if final_rank == 1 // genero equals 1 if male, computes proportion of spells of workers active through dec that were males

    ** Race - proportion of whites (raca_cor==2 indicates white)
    gen white = cond(raca_cor==2, 1, 0) // marks spells of white workers
    bysort identificad: egen white_prop = mean(white) if final_rank == 1 // within each estab, takes the avg of a dummy marking if the spell was of an employee active throughout dec and was white

    ** Public firms // marks estabs that are associtated to the public sector (admin and judicial system, all gov levels, exclude gov companies)
    generate pub_firm = inlist(natjuridica, 1015,1023,1031,1040,1058,1066,1074,1082,1104,1112,1120,1139,1147,1155,1163,1171,1180,1198,1201,1210)
	
	
	
*--------------------------------------------------------------------------------
*Part 2: Collapsing the dataset to the firm level
*--------------------------------------------------------------------------------

//drop if count_worker!=1 // only considering for average the unique PIS active in december

keep if final_rank==1	// considers only main spells of employees active throughout dec

// save an employee level dataset to homogenize municipality and industry for across year 
preserve
keep PIS identificad municipio clascnae20 year genero idade dtnascimento_stata dtadmissao_stata ocup2002 raca_cor causadesli mesdesli ///
    grinstrucao nacionalidad portdefic tpdefic tipoadm tempempr tiposal salcontr ultrem horascontr ///
    remdezembro remmedia remdezr remmedr dtnascimento idade nacionalidad ///
     tempempr tiposal salcontr ///
     lr_remdezr lr_remmedr r_remmedr r_remmedr_h r_remdezr r_remdezr_h ///
save "$rais_aux/worker_estab_`i'.dta", replace
restore
	
collapse ///
(firstnm) identificad_8 year white_prop male_prop avg_tenure no_hs_c prop_nhs hs_c prop_hs sup_c prop_sup total_below_30 prop_below_30 total_30_40 prop_30_40 total_above_40 prop_above_40 ///
 leave_c leaves safety_c safety fixed_count fixed_prop qui_count quits lay_count layoffs separations turnover firm_emp_jan retention pub_firm ///
 hired_count hiring l_firm_emp firm_emp lr_sal~50_10 lr_sal~90_10 salcontr_p10 salcontr_p50 salcontr_p90 ///
 municipio clascnae20 natjuridica /// // take the first non missing observation within estab for observations that are the same for the whole estab
(mean) lr_remdezr lr_remmedr lr_salcont~m r_salcontr_m r_remmedr r_remdezr lr_remdezr_h lr_remmedr_h lr_salcontr_h /// 
 r_remdezr_h r_remmedr_h r_salcontr_h remdezr_h remmedr_h salcontr_h /// // takes the mean of wage variables within estab
, by(identificad)

	
	** microrregion groups
	tostring municipio, replace force
	


save "$rais_firm/rais_firm_`i'.dta", replace



	
}


// Homogenizing municipality and induestry. Using same technique as Lagos (2021), which gets the mode at the worker x year level

// just appending year-level datasets
use "$rais_aux/worker_estab_2009.dta",clear

forvalues k=2010/2016 {
	append using "$rais_aux/worker_estab_`k'.dta"
	erase "$rais_aux/worker_estab_`k'.dta" // erases year level dataset, so that it does not occupy a lot of hd space
}


// get the mode of industry category, if there are two modes, choose the smallest of the two
bys identificad: egen modeind = mode(clascnae20), minmode

// get the mode of municipality category, if there are two modes, choose the smallest of the two
bys identificad: egen modemun = mode(municipio), minmode

replace municipio=modemun
replace clascnae20=modeind

tostring year, generate(year_str)

gen cnpj_year = identificad + year_str // generates a variable that is the identificad plus the year divided by 100, so that it is unique for each firm-year
// now collapsing to the firm level, taking the first non missing observation of each variable (all variables are the same for each estab, except wages, which we do not need here

compress
save "$rais_aux/worker_estab_all_years.dta", replace // saves the full dataset with all years, just in case


/* collapse (firstnm) modemun modeind, by(identificad) // collapse to the estab level, to serve as a dictionary for 

tostring modemun, replace

save "$rais_aux/rais_mode_mun_ind.dta", replace

//incoporate the modal municipality and industry values into the collapsed firm level full datasets

forvalues i=2007/2016{
	use "$rais_aux/rais_mode_mun_ind.dta",clear
	merge 1:1 identificad using "$rais_firm/rais_firm_`i'.dta" // merge with firm level collapsed full dataset 
	keep if _merge==3 // keep only observations that are matched. there should not be a decrease in the number of obs
	drop _merge
	replace municipio=modemun // replace municipio with mode municipality
	drop modemun // drop 
	replace clascnae20=modeind // replace industry id with mode industry id
	drop modeind
	
	** industry groups
	gen industry =  substr(clascnae20,1,3) // generates specific industry groups using the 1st three digits of the cnae classification
	
	
	save "$rais_firm/rais_firm_`i'.dta", replace
	
	// this code generates the unique establishments id databese to perform the merge with the cba dataset. I cannot merge the whole rais because the database would get too big, i add the other variables later (041 do file)
keep identificad identificad_8 municipio firm_emp 
gen state = substr(municipio,1,2) // generates state identifier used for matching with the cba dataset

// keep if firm_emp>0 // restrict to firms with postive employment in december

save "$rais_aux/unique_estab_`i'.dta", replace

} */


