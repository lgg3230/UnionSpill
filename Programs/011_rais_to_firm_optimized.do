********************************************************************************
* PROJECT: UNION SPILLOVERS - OPTIMIZED VERSION
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS, GENERATE OUTCOMES, COLLAPSE TO FIRM LEVEL
* OPTIMIZATIONS: Reduced bysort operations, faster egen alternatives, 
*                streamlined ranking, memory optimization
********************************************************************************

local years "2008 2009 2010 2011 2012 2013 2014 2015 2016"
local ipca  " 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"

// Set memory and performance options
set maxvar 32767
set matsize 11000
set more off

forvalues i=2008/2016{
	
	di "Processing year `i'..."
	use "$rais_raw_dir/RAIS_`i'.dta",clear
	
	* Generate year variables
	gen year = `i'
	gen identificad_8 = substr(identificad,1,8)
	
	* OPTIMIZED: Streamlined age processing
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

	* OPTIMIZED: Single-pass age calculation
	gen idade_unified = idade
	gen temp_dob = date(dtnascimento, "DMY") if dtnascimento != ""
	format temp_dob %td
	
	* Calculate age only where needed
	replace idade_unified = floor((mdy(12, 31, `i') - temp_dob) / 365.25) ///
		if missing(idade_unified) & !missing(temp_dob)
	
	drop temp_dob
	replace idade = idade_unified if !missing(idade_unified)
	drop idade_unified

	// homogenizing variables across years - OPTIMIZED: reduced variable list
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

	// converting identifiers to double
	destring PIS, gen(PIS_d)
	destring identificad, gen(identificad_d)

	* Convert the date of admission from string to a Stata date and format it
	gen dtadmissao_stata = date(dtadmissao, "DMY")
	format dtadmissao_stata %td 

	gen hired_ndec = (dtadmissao_stata <= mdy(11,30,`i'))
	
	// OPTIMIZED: Generate employment dummy directly
	gen empdec_lagos = empem3112*(tempempr>1)

	* *********************
	* Wage outcomes - OPTIMIZED
	* *********************
	
	// Adjust 2016 contracted wages according to Lagos (2024)'s footnote 76
	if `i'==2016{
		replace salcontr = 100*salcontr if salcontr<880
	}

	* OPTIMIZED: Vectorized wage adjustments
	gen salcontr_m = salcontr
	replace salcontr_m = 2 * salcontr if tiposal == 2
	replace salcontr_m = 4.348 * salcontr if tiposal == 3
	replace salcontr_m = 30.436875 * salcontr if tiposal == 4
	replace salcontr_m = 4.348 * horascontr * salcontr if tiposal == 5
	label var salcontr_m "Salario contratual, ajustado para valor mensal"

	gen salcontr_h = salcontr_m/(horascontr*4.348)
	label var salcontr_h "Salario contratual por hora"

	gen remmedr_h = remmedr/(horascontr*4.348)
	label var remmedr_h "remuneracao media anual por hora"

	gen remdezr_h = remdezr/(horascontr*4.348)
	label var remdezr_h "remuneracao de dezembro por hora"

	* OPTIMIZED: Single-pass inflation adjustment
	local pos = `i'- 2006
	local deflator : word `pos' of `ipca'
	
	* Generate all deflated and log variables in one pass
	gen lr_salcontr_m = log(salcontr_m/`deflator')
	gen lr_salcontr_h = log(salcontr_h/`deflator')
	gen r_salcontr_m = salcontr_m/`deflator'
	gen r_salcontr_h = salcontr_h/`deflator'
	gen lr_remmedr = log(remmedr/`deflator')
	gen r_remmedr = remmedr/`deflator'
	gen r_remmedr_h = remmedr_h/`deflator'
	gen lr_remmedr_h = log(remmedr_h/`deflator')
	gen lr_remdezr_h = log(remdezr_h/`deflator')
	gen r_remdezr_h = remdezr_h/`deflator'
	gen lr_remdezr = log(remdezr/`deflator')
	gen r_remdezr = remdezr/`deflator'
	* OPTIMIZED: More efficient percentile calculation
	tempfile temp_data
	save `temp_data'
	
	preserve
	keep if empdec_lagos == 1
	collapse (p90) salcontr_p90=lr_salcontr_m (p50) salcontr_p50=lr_salcontr_m (p10) salcontr_p10=lr_salcontr_m, by(identificad)
	tempfile percentiles
	save `percentiles'
	restore
	
	merge m:1 identificad using `percentiles', nogenerate
	gen lr_salcontr_90_10 = salcontr_p90 - salcontr_p10
	gen lr_salcontr_50_10 = salcontr_p50 - salcontr_p10

	****************************
	* Employment Outcomes - OPTIMIZED
	****************************

	* OPTIMIZED: Simplified ranking system using single sort
	* Create composite ranking variable
	gen rank_composite = horascontr + lr_remdezr_h/1000
	set seed 12345
	gen random = runiform()
	gen rank_final = rank_composite + random/1000000
	
	* Single sort and selection
	sort identificad PIS rank_final
	by identificad PIS: gen final_rank = (_n == _N & empdec_lagos == 1)
	
	* OPTIMIZED: Single collapse for employment counts
	preserve
	keep if empdec_lagos == 1
	collapse (sum) firm_emp=final_rank, by(identificad)
	tempfile employment
	save `employment'
	restore
	
	merge m:1 identificad using `employment'
	* Handle cases where firms have no employees in December
	replace firm_emp = 0 if _merge == 1
	drop _merge
	
	gen l_firm_emp = ln(firm_emp + 1)  // Add 1 to avoid ln(0)
	gen open_firm = (firm_emp > 0)

	* OPTIMIZED: Batch hiring calculations
	gen new_hire = (year(dtadmissao_stata) == `i')
	gen new_hire_u = new_hire
	
	preserve
	collapse (sum) hired_count=new_hire hired_count_u=new_hire_u, by(identificad)
	* Handle division by zero for firms with no employment
	gen hiring = hired_count / (firm_emp + (firm_emp == 0))
	gen hiring_u = hired_count_u / (firm_emp + (firm_emp == 0))
	tempfile hiring_data
	save `hiring_data'
	restore
	
	merge m:1 identificad using `hiring_data'
	* Handle cases where firms have no hiring data
	replace hired_count = 0 if _merge == 1
	replace hiring = 0 if _merge == 1
	replace hiring_u = 0 if _merge == 1
	drop _merge

	* OPTIMIZED: Batch employment flow calculations
	gen emp_in_jan = (dtadmissao_stata < mdy(1,1,`i') & mesdesli != 1)
	gen emp_jan_dec = emp_in_jan * final_rank
	
	preserve
	collapse (sum) firm_emp_jan=emp_jan_dec separations=mesdesli ///
		lay_count=(causadesli==10 | causadesli==11) ///
		qui_count=(causadesli==20 | causadesli==21), by(identificad)
	
	* Handle division by zero for firms with no employment
	gen retention = firm_emp_jan / (firm_emp + (firm_emp == 0))
	gen turnover = separations / (firm_emp + (firm_emp == 0))
	gen layoffs = lay_count / (firm_emp + (firm_emp == 0))
	gen quits = qui_count / (firm_emp + (firm_emp == 0))
	
	tempfile flows
	save `flows'
	restore
	
	merge m:1 identificad using `flows'
	* Handle cases where firms have no flow data
	replace firm_emp_jan = 0 if _merge == 1
	replace separations = 0 if _merge == 1
	replace lay_count = 0 if _merge == 1
	replace qui_count = 0 if _merge == 1
	replace retention = 0 if _merge == 1
	replace turnover = 0 if _merge == 1
	replace layoffs = 0 if _merge == 1
	replace quits = 0 if _merge == 1
	drop _merge

	* OPTIMIZED: Batch other calculations
	gen fixed_c = inlist(tpvinculo, 60, 65, 70, 75, 95, 96, 97, 90)
	gen safety_d = inlist(causadesli, 62, 73, 74) | inlist(causafast1, 10, 30) | ///
		inlist(causafast2, 10, 30) | inlist(causafast3, 10, 30)
	
	preserve
	collapse (sum) fixed_count=fixed_c safety_c=safety_d ///
		leave_c=(causafast1 != -1), by(identificad)
	
	* Handle division by zero for firms with no employment
	gen fixed_prop = fixed_count / (firm_emp + (firm_emp == 0))
	gen safety = safety_c / (firm_emp + (firm_emp == 0))
	gen leaves = leave_c / (firm_emp + (firm_emp == 0))
	
	tempfile other_vars
	save `other_vars'
	restore
	
	merge m:1 identificad using `other_vars'
	* Handle cases where firms have no other variables data
	replace fixed_count = 0 if _merge == 1
	replace safety_c = 0 if _merge == 1
	replace leave_c = 0 if _merge == 1
	replace fixed_prop = 0 if _merge == 1
	replace safety = 0 if _merge == 1
	replace leaves = 0 if _merge == 1
	drop _merge

	* OPTIMIZED: Batch education and demographics
	gen no_hs_c = inlist(grinstrucao, 1, 2, 3, 4, 5, 6)
	gen hs_c = inlist(grinstrucao, 7, 8)
	gen sup_c = inlist(grinstrucao, 9, 10, 11)
	gen white = (raca_cor == 2)
	
	* Age groups - OPTIMIZED
	gen d_below_30 = (idade <= 30)
	gen betw_30_40 = (idade > 30 & idade <= 40)
	gen above_40 = (idade > 40)
	
	preserve
	keep if final_rank == 1
	collapse (mean) male_prop=genero white_prop=white avg_tenure=tempempr ///
		(sum) no_high_school=no_hs_c high_school=hs_c superior=sup_c ///
		total_below_30=d_below_30 total_30_40=betw_30_40 total_above_40=above_40, ///
		by(identificad)
	
	* Handle division by zero for firms with no employment
	gen prop_nhs = no_high_school / (firm_emp + (firm_emp == 0))
	gen prop_hs = high_school / (firm_emp + (firm_emp == 0))
	gen prop_sup = superior / (firm_emp + (firm_emp == 0))
	gen prop_below_30 = total_below_30 / (firm_emp + (firm_emp == 0))
	gen prop_30_40 = total_30_40 / (firm_emp + (firm_emp == 0))
	gen prop_above_40 = total_above_40 / (firm_emp + (firm_emp == 0))
	
	tempfile demographics
	save `demographics'
	restore
	
	merge m:1 identificad using `demographics'
	* Handle cases where firms have no demographics data
	replace male_prop = 0 if _merge == 1
	replace white_prop = 0 if _merge == 1
	replace avg_tenure = 0 if _merge == 1
	replace no_high_school = 0 if _merge == 1
	replace high_school = 0 if _merge == 1
	replace superior = 0 if _merge == 1
	replace total_below_30 = 0 if _merge == 1
	replace total_30_40 = 0 if _merge == 1
	replace total_above_40 = 0 if _merge == 1
	replace prop_nhs = 0 if _merge == 1
	replace prop_hs = 0 if _merge == 1
	replace prop_sup = 0 if _merge == 1
	replace prop_below_30 = 0 if _merge == 1
	replace prop_30_40 = 0 if _merge == 1
	replace prop_above_40 = 0 if _merge == 1
	drop _merge

	* Public firms
	generate pub_firm = inlist(natjuridica, 1015,1023,1031,1040,1058,1066,1074,1082,1104,1112,1120,1139,1147,1155,1163,1171,1180,1198,1201,1210)

	*--------------------------------------------------------------------------------
	*Part 2: Collapsing the dataset to the firm level - OPTIMIZED
	*--------------------------------------------------------------------------------

	keep if final_rank == 1

	// save an employee level dataset to homogenize municipality and industry
	preserve
	keep identificad municipio clascnae20 firm_emp
	save "$rais_aux/worker_estab_`i'.dta", replace
	restore
	
	* OPTIMIZED: Single collapse with all variables
	collapse ///
	(firstnm) identificad_8 year white_prop male_prop avg_tenure ///
		no_hs_c prop_nhs hs_c prop_hs sup_c prop_sup ///
		total_below_30 prop_below_30 total_30_40 prop_30_40 total_above_40 prop_above_40 ///
		leave_c leaves safety_c safety fixed_count fixed_prop ///
		qui_count quits lay_count layoffs separations turnover firm_emp_jan retention pub_firm ///
		hired_count hiring l_firm_emp firm_emp lr_salcontr_90_10 lr_salcontr_50_10 ///
		salcontr_p10 salcontr_p50 salcontr_p90 ///
		municipio clascnae20 natjuridica ///
	(mean) lr_remdezr lr_remmedr lr_salcontr_m r_salcontr_m r_remmedr r_remdezr ///
		lr_remdezr_h lr_remmedr_h lr_salcontr_h r_remdezr_h r_remmedr_h r_salcontr_h ///
		remdezr_h remmedr_h salcontr_h /// 
	, by(identificad)

	** microrregion groups
	tostring municipio, replace force

	save "$rais_firm/rais_firm_`i'.dta", replace
	
	* Clean up temporary files
	cap erase `percentiles'
	cap erase `employment'
	cap erase `hiring_data'
	cap erase `flows'
	cap erase `other_vars'
	cap erase `demographics'
	
	di "Completed year `i'"
}

// Homogenizing municipality and industry - OPTIMIZED
use "$rais_aux/worker_estab_2008.dta", clear

forvalues i=2009/2016 {
	append using "$rais_aux/worker_estab_`i'.dta"
	erase "$rais_aux/worker_estab_`i'.dta"
}

* OPTIMIZED: Single mode calculation
bys identificad: egen modeind = mode(clascnae20), minmode
bys identificad: egen modemun = mode(municipio), minmode

replace municipio = modemun
replace clascnae20 = modeind

gen cnpj_year = identificad + year/100

save "$rais_aux/worker_estab_all_years.dta", replace

collapse (firstnm) modemun modeind, by(identificad)
tostring modemun, replace

save "$rais_aux/rais_mode_mun_ind.dta", replace

// incorporate the modal municipality and industry values
forvalues i=2008/2016{
	use "$rais_aux/rais_mode_mun_ind.dta", clear
	merge 1:1 identificad using "$rais_firm/rais_firm_`i'.dta"
	keep if _merge==3
	drop _merge
	replace municipio = modemun
	drop modemun
	replace clascnae20 = modeind
	drop modeind
	
	** industry groups
	gen industry = substr(clascnae20,1,3)
	
	save "$rais_firm/rais_firm_`i'.dta", replace
	
	// generate unique establishments id database
	keep identificad identificad_8 municipio firm_emp 
	gen state = substr(municipio,1,2)
	save "$rais_aux/unique_estab_`i'.dta", replace
}
