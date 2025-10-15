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
	
	gen year = `i' // generates year variable for whole dataset, used later to mactch with cba data
	gen identificad_8 = substr(identificad,1,8) // firm identifier, only 1st 8 digits of cnpj
	
	* Generate age variable for databases that do not have it
	// if dataset does not have the idade variable (used for age outcomes later):
	
	
	cap confirm var idade // test if idade exits in the dataset
	if _rc{ // if it does not exist
		gen dob_date = date(dtnascimento,"DMY") // generate date of birth (dob) in the stata date format
		format dob_date %td // format to look ok
		gen anonasc = year(dob_date) // get the year of the dob
		gen idade = year - anonasc // generate idade as current year minus year of birth
		drop anonasc dob_date
	*gen idade=.
	}
	
	* checkif variable dtnascimento exist. if not, create it
	
	cap confirm var dtnascimento
	if _rc{
		gen dtnascimento=. // since I dont have the birth day and month, I cannot reconstruct the actual date of birth, so I jsut leave it there so the variables are the same across the datasets.
	}
	
	// homogenizing variables across years.
	keep year PIS CPF numectps nome identificad identificad_8 municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	order year PIS CPF numectps nome identificad identificad_8 municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	
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
    
    

    ** Log-contracted-wages // salcontr is non missing only for 10% of the spells in some years. 
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

    * Convert salcontr_m to 2015 values using Brazil's CPI (IPCA)
    gen lr_salcontr_m = . 

    /* Wage adjustment according to year:
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
     label var lr_salcontr_m "Log Salario contratual , a precos do ano de 2015"
     
     // hourly contracted wages:
     gen lr_salcontr_h=.
     replace lr_salcontr_h = log(salcontr_h/.671594887351247) if `i'==2009
     replace lr_salcontr_h = log(salcontr_h/.711277338716318) if `i'==2010
    replace lr_salcontr_h = log(salcontr_h/.757534213038901) if `i'==2011
     replace lr_salcontr_h = log(salcontr_h/.80176356558955) if `i'==2012
     replace lr_salcontr_h = log(salcontr_h/.849153270408197) if `i'==2013
     replace lr_salcontr_h = log(salcontr_h/.903562518222102) if `i'==2014
     replace lr_salcontr_h = log(salcontr_h) if `i'==2015
     replace lr_salcontr_h = log(salcontr_h/1.06287988213221) if `i'==2016
     replace lr_salcontr_h = log(salcontr_h/1.09420743038879) if `i'==2017
     label var lr_salcontr_m "Log Salario contratual por hora , a precos do ano de 2015"
     
     
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
     label var r_salcontr_m "Salario contratual, a precos de 2015"
     
     gen r_salcontr_h=.
     replace r_salcontr_h = salcontr_h/.671594887351247 if `i'==2009
     replace r_salcontr_h = salcontr_h/.711277338716318 if `i'==2010
     replace r_salcontr_h = salcontr_h/.757534213038901 if `i'==2011
     replace r_salcontr_h = salcontr_h/.80176356558955 if `i'==2012
     replace r_salcontr_h = salcontr_h/.849153270408197 if `i'==2013
     replace r_salcontr_h = salcontr_h/.903562518222102 if `i'==2014
     replace r_salcontr_h = salcontr_h if `i'==2015
     replace r_salcontr_h = salcontr_h/1.06287988213221 if `i'==2016
     replace r_salcontr_h = salcontr_h/1.09420743038879 if `i'==2017
     label var r_salcontr_h "Salario contratual por hora, a precos de 2015"

    ** 90-10 and 50-10 wage ratio
    egen salcontr_p90 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(90)
    egen salcontr_p50 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(50)
    egen salcontr_p10 = pctile(lr_salcontr_m) if empdec_lagos == 1, by(identificad) p(10)

    gen lr_salcontr_90_10 = salcontr_p90 - salcontr_p10
    gen lr_salcontr_50_10 = salcontr_p50 - salcontr_p10
    
    

    ** Log average wages
    
    ** using wage type, convert average earnings to monthly measure
        
    // I will not do any adjustment to average earnings because this makes the dist look very weird. I did not understand Lagos' (2024) hourly adjustment.
    // Lagos (2024) "hourly adjustment": When this outcome is reported as "hourly," I divide the average earnings by monthly contracted hours before taking logs and calculating the mean
    // I am interpreting "outcome being reported as hourly" = tiposal==5. These outcomes have similar dist to other wage measures, if I do this, I get very low number for this wage type. 
    // though he might have switched "multiply"  for "divide" wrongly, but multiplying yields even wilder results. 
    
    // computing average hourly earnings:
    gen remmedr_h = remmedr/(horascontr*4.348) // contractual salary divided by the amount of contracted hours in the month
    label var remmedr_h "remuneracao media anual dividido pelo total de horas contratadas"
    
    // adjuting monthly average earnings for inflation and taking logs (2015 0prices) (december ipca index)
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
     
     
     
     //making the same for hourly average earnings:
     ** deflated hourly Average wages
     gen r_remmedr_h=.
     replace r_remmedr_h = remmedr_h/.671594887351247 if `i'==2009
     replace r_remmedr_h = remmedr_h/.711277338716318 if `i'==2010
     replace r_remmedr_h = remmedr_h/.757534213038901 if `i'==2011
     replace r_remmedr_h = remmedr_h/.80176356558955  if `i'==2012
     replace r_remmedr_h = remmedr_h/.849153270408197 if `i'==2013
     replace r_remmedr_h = remmedr_h/.903562518222102 if `i'==2014
     replace r_remmedr_h = remmedr_h                  if `i'==2015
     replace r_remmedr_h = remmedr_h/1.06287988213221 if `i'==2016
     replace r_remmedr_h = remmedr_h/1.09420743038879 if `i'==2017
     
     // adjuting hourly average earnings for inflation and taking logs (2015 0prices)
    gen lr_remmedr_h = .
     replace lr_remmedr_h = log(remmedr_h/.671594887351247) if `i'==2009
     replace lr_remmedr_h = log(remmedr_h/.711277338716318) if `i'==2010
     replace lr_remmedr_h = log(remmedr_h/.757534213038901) if `i'==2011
     replace lr_remmedr_h = log(remmedr_h/.80176356558955) if `i'==2012
     replace lr_remmedr_h = log(remmedr_h/.849153270408197) if `i'==2013
     replace lr_remmedr_h = log(remmedr_h/.903562518222102) if `i'==2014
     replace lr_remmedr_h = log(remmedr_h) if `i'==2015
     replace lr_remmedr_h = log(remmedr_h/1.06287988213221) if `i'==2016
     replace lr_remmedr_h = log(remmedr_h/1.09420743038879) if `i'==2017
     
     
    

    ** Log December earnings
    
    // Compute hourly december wages:
    
    gen remdezr_h = remdezr/(horascontr*4.348) // contractual salary divided by the amount of contracted hours in the month
    label var remdezr_h "remuneracao de dezembro dividido pelo total de horas contratadas"
    
    // adjust hourly dec earnings to logs and at december 2015 prices
    
       
    gen lr_remdezr_h = .
     replace lr_remdezr_h = log(remdezr_h/.671594887351247) if `i'==2009
     replace lr_remdezr_h = log(remdezr_h/.711277338716318) if `i'==2010
     replace lr_remdezr_h = log(remdezr_h/.757534213038901) if `i'==2011
     replace lr_remdezr_h = log(remdezr_h/.80176356558955) if `i'==2012
     replace lr_remdezr_h = log(remdezr_h/.849153270408197) if `i'==2013
     replace lr_remdezr_h = log(remdezr_h/.903562518222102) if `i'==2014
     replace lr_remdezr_h = log(remdezr_h) if `i'==2015
     replace lr_remdezr_h = log(remdezr_h/1.06287988213221) if `i'==2016
     replace lr_remdezr_h = log(remdezr_h/1.09420743038879) if `i'==2017
     
     ** Deflated December hourly earnings
     gen r_remdezr_h = .
     replace r_remdezr_h = remdezr_h/.671594887351247 if `i'==2009
     replace r_remdezr_h = remdezr_h/.711277338716318 if `i'==2010
     replace r_remdezr_h = remdezr_h/.757534213038901 if `i'==2011
     replace r_remdezr_h = remdezr_h/.80176356558955 if `i'==2012
     replace r_remdezr_h = remdezr_h/.849153270408197 if `i'==2013
     replace r_remdezr_h = remdezr_h/.903562518222102 if `i'==2014
     replace r_remdezr_h = remdezr_h if `i'==2015
     replace r_remdezr_h = remdezr_h/1.06287988213221 if `i'==2016
     replace r_remdezr_h = remdezr_h/1.09420743038879 if `i'==2017
     
    
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
bysort identificad PIS: egen max_hours = max(horascontr * empdec_lagos) // orders by estab_id and then PIS, within each estab-PIS group, takes the max of the contract hours, given that this spell is active in dec
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
bysort identificad: egen firm_emp = total(final_rank==1) // w/in estab counts spells that fulfill conditions of final_rank. 


gen l_firm_emp = ln(firm_emp) // generate log firm employment
gen open_firm = cond(firm_emp>0,1,0) // generate dummy to mark firms that are open throughout december

* Clean up temporary variables
drop  max_hours rank1 max_wage rank2 random max_random 

 // since the remaining variables are not being used as replication benchmarks, then we will leave them as they are right now
 
 ** Hiring rate: count workers with hiring date in year `i'. This is counting the number of SPELLS, not workers.
    gen new_hire = (year(dtadmissao_stata)==`i') // indicates if a spell was started during the current year
    bysort identificad: egen hired_count = total(new_hire) // counts the number of new spells per estab
    gen hiring = hired_count / firm_emp // computes the ratio of new spells to firm employment in december

    ** Retention rate
    gen emp_in_jan = (dtadmissao_stata < mdy(1,1,`i') & mesdesli != 1) //indicates spells that were active before the beginning of the year, but were not terminated in Jan
    gen emp_jan_dec = emp_in_jan * empdec_lagos // indicates which spells among those still active in dec were active throughout jan (bc it is multiplying by empdec_lagos, this actually counts employees)
    bysort identificad: egen firm_emp_jan = total(emp_jan_dec) // sums by each firmn the number of employees that were active in Jan that remained active in dec
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
    else { //  if mean is not missing, use dtnascimento
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
keep identificad municipio clascnae20 firm_emp
save "$rais_aux/worker_estab_`i'.dta", replace
restore
	
collapse ///
(firstnm) identificad_8 white_prop male_prop avg_tenure prop_abov~40 prop_30_40 prop_belo~30 prop_sup prop_hs prop_nhs year ///
 leaves leave_c safety fixed_prop fixed_count quits qui_count layoffs lay_count turnover separations retention pub_firm ///
 firm_emp_jan hiring hired_count l_firm_emp firm_emp lr_sal~50_10 lr_sal~90_10 salcontr_p10 salcontr_p50 salcontr_p90 ///
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

forvalues i=2010/2016 {
	append using "$rais_aux/worker_estab_`i'.dta"
	erase "$rais_aux/worker_estab_`i'.dta" // erases year level dataset, so that it does not occupy a lot of hd space
}


// get the mode of industry category, if there are two modes, choose the smallest of the two
bys identificad: egen modeind = mode(clascnae20), minmode

// get the mode of municipality category, if there are two modes, choose the smallest of the two
bys identificad: egen modemun = mode(municipio), minmode




collapse (firstnm) modemun modeind, by(identificad) // collapse to the estab level, to serve as a dictionary for 

tostring modemun, replace

save "$rais_aux/rais_mode_mun_ind.dta", replace

//incoporate the modal municipality and industry values into the collapsed firm level full datasets

forvalues i=2009/2016{
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
	
	gen microrregiao =  substr(municipio,1,5) // generates microrregiao groups using ibge's definition (i think this is not right, there are too many microregions using this, latter on i switch to only 4 digits and then i get a more sensible number)
	
	save "$rais_firm/rais_firm_`i'.dta", replace
	
	// this code generates the unique establishments id databese to perform the merge with the cba dataset. I cannot merge the whole rais because the database would get too big, i add the other variables later (041 do file)
keep identificad identificad_8 municipio firm_emp 
gen state = substr(municipio,1,2) // generates state identifier used for matching with the cba dataset

// keep if firm_emp>0 // restrict to firms with postive employment in december

save "$rais_aux/unique_estab_`i'.dta", replace

}


