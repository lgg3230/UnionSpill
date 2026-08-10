********************************************************************************
* PROJECT: UNION SPILLOVERS - PARALLEL PROCESSING VERSION
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS WITH PARALLEL PROCESSING
* OPTIMIZATIONS: Parallel year processing, reduced I/O, optimized algorithms
********************************************************************************

* Set up parallel processing
local years "2008 2009 2010 2011 2012 2013 2014 2015 2016"
local ipca  " 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"

set maxvar 32767
set matsize 11000
set more off

* Create parallel processing script for each year
foreach year of local years {
    local pos = `year' - 2007
    local deflator : word `pos' of `ipca'
    
    tempname fh
    file open `fh' using "011_process_year_`year'.do", write replace
    
    file write `fh' `"********************************************************************************"' _n
    file write `fh' `"* PARALLEL PROCESSING SCRIPT FOR YEAR `year'"' _n
    file write `fh' `"********************************************************************************"' _n _n
    
    file write `fh' `"local year = `year'"' _n
    file write `fh' `"local deflator = `deflator'"' _n _n
    
    file write `fh' `"set maxvar 32767"' _n
    file write `fh' `"set matsize 11000"' _n
    file write `fh' `"set more off"' _n _n
    
    file write `fh' `"di "Processing year `year'...""' _n
    file write `fh' `"use "$rais_raw_dir/RAIS_`year'.dta",clear"' _n _n
    
    file write `fh' `"* Generate year variables"' _n
    file write `fh' `"gen year = `year'"' _n
    file write `fh' `"gen identificad_8 = substr(identificad,1,8)"' _n _n
    
    file write `fh' `"* OPTIMIZED: Streamlined age processing"' _n
    file write `fh' `"cap confirm var idade"' _n
    file write `fh' `"if _rc {"' _n
    file write `fh' `"    gen idade = ."' _n
    file write `fh' `"    di "idade variable created as missing""' _n
    file write `fh' `"}"' _n _n
    
    file write `fh' `"cap confirm var dtnascimento"' _n
    file write `fh' `"if _rc {"' _n
    file write `fh' `"    gen dtnascimento = """' _n
    file write `fh' `"    di "dtnascimento variable created as missing""' _n
    file write `fh' `"}"' _n _n
    
    file write `fh' `"capture confirm string variable dtnascimento"' _n
    file write `fh' `"if _rc {"' _n
    file write `fh' `"    tostring dtnascimento, replace force"' _n
    file write `fh' `"}"' _n _n
    
    file write `fh' `"* OPTIMIZED: Single-pass age calculation"' _n
    file write `fh' `"gen idade_unified = idade"' _n
    file write `fh' `"gen temp_dob = date(dtnascimento, "DMY") if dtnascimento != """' _n
    file write `fh' `"format temp_dob %td"' _n _n
    
    file write `fh' `"replace idade_unified = floor((mdy(12, 31, `year') - temp_dob) / 365.25) ///"' _n
    file write `fh' `"    if missing(idade_unified) & !missing(temp_dob)"' _n _n
    
    file write `fh' `"drop temp_dob"' _n
    file write `fh' `"replace idade = idade_unified if !missing(idade_unified)"' _n
    file write `fh' `"drop idade_unified"' _n _n
    
    file write `fh' `"* Keep only necessary variables"' _n
    file write `fh' `"keep year PIS CPF numectps nome identificad identificad_8 municipio ///"' _n
    file write `fh' `"    tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ///"' _n
    file write `fh' `"    ocup2002 grinstrucao genero dtnascimento idade nacionalidad ///"' _n
    file write `fh' `"    portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr ///"' _n
    file write `fh' `"    tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 ///"' _n
    file write `fh' `"    tamestab natjuridica tipoestbl indceivinc ceivinc indalvara ///"' _n
    file write `fh' `"    indpat indsimples causafast1 causafast2 causafast3 ///"' _n
    file write `fh' `"    diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 ///"' _n
    file write `fh' `"    mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3"' _n _n
    
    file write `fh' `"* Convert identifiers"' _n
    file write `fh' `"destring PIS, gen(PIS_d)"' _n
    file write `fh' `"destring identificad, gen(identificad_d)"' _n _n
    
    file write `fh' `"* Date processing"' _n
    file write `fh' `"gen dtadmissao_stata = date(dtadmissao, "DMY")"' _n
    file write `fh' `"format dtadmissao_stata %td"' _n _n
    
    file write `fh' `"gen hired_ndec = (dtadmissao_stata <= mdy(11,30,`year'))"' _n
    file write `fh' `"gen empdec_lagos = empem3112*(tempempr>1)"' _n _n
    
    file write `fh' `"* Wage adjustments"' _n
    file write `fh' `"if `year'==2016{"' _n
    file write `fh' `"    replace salcontr = 100*salcontr if salcontr<880"' _n
    file write `fh' `"}"' _n _n
    
    file write `fh' `"gen salcontr_m = salcontr"' _n
    file write `fh' `"replace salcontr_m = 2 * salcontr if tiposal == 2"' _n
    file write `fh' `"replace salcontr_m = 4.348 * salcontr if tiposal == 3"' _n
    file write `fh' `"replace salcontr_m = 30.436875 * salcontr if tiposal == 4"' _n
    file write `fh' `"replace salcontr_m = 4.348 * horascontr * salcontr if tiposal == 5"' _n _n
    
    file write `fh' `"gen salcontr_h = salcontr_m/(horascontr*4.348)"' _n
    file write `fh' `"gen remmedr_h = remmedr/(horascontr*4.348)"' _n
    file write `fh' `"gen remdezr_h = remdezr/(horascontr*4.348)"' _n _n
    
    file write `fh' `"* Inflation adjustments"' _n
    file write `fh' `"gen lr_salcontr_m = log(salcontr_m/`deflator')"' _n
    file write `fh' `"gen lr_salcontr_h = log(salcontr_h/`deflator')"' _n
    file write `fh' `"gen r_salcontr_m = salcontr_m/`deflator'"' _n
    file write `fh' `"gen r_salcontr_h = salcontr_h/`deflator'"' _n
    file write `fh' `"gen lr_remmedr = log(remmedr/`deflator')"' _n
    file write `fh' `"gen r_remmedr = remmedr/`deflator'"' _n
    file write `fh' `"gen r_remmedr_h = remmedr_h/`deflator'"' _n
    file write `fh' `"gen lr_remmedr_h = log(remmedr_h/`deflator')"' _n
    file write `fh' `"gen lr_remdezr_h = log(remdezr_h/`deflator')"' _n
    file write `fh' `"gen r_remdezr_h = remdezr_h/`deflator'"' _n
    file write `fh' `"gen lr_remdezr = log(remdezr/`deflator')"' _n
    file write `fh' `"gen r_remdezr = remdezr/`deflator'"' _n _n
    
    file write `fh' `"* Percentile calculations"' _n
    file write `fh' `"preserve"' _n
    file write `fh' `"keep if empdec_lagos == 1"' _n
    file write `fh' `"collapse (p90) salcontr_p90=lr_salcontr_m (p50) salcontr_p50=lr_salcontr_m (p10) salcontr_p10=lr_salcontr_m, by(identificad)"' _n
    file write `fh' `"tempfile percentiles"' _n
    file write `fh' `"save `percentiles'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `percentiles', nogenerate"' _n
    file write `fh' `"gen lr_salcontr_90_10 = salcontr_p90 - salcontr_p10"' _n
    file write `fh' `"gen lr_salcontr_50_10 = salcontr_p50 - salcontr_p10"' _n _n
    
    file write `fh' `"* Employment ranking - OPTIMIZED"' _n
    file write `fh' `"gen rank_composite = horascontr + lr_remdezr_h/1000"' _n
    file write `fh' `"set seed 12345"' _n
    file write `fh' `"gen random = runiform()"' _n
    file write `fh' `"gen rank_final = rank_composite + random/1000000"' _n _n
    
    file write `fh' `"sort identificad PIS rank_final"' _n
    file write `fh' `"by identificad PIS: gen final_rank = (_n == _N & empdec_lagos == 1)"' _n _n
    
    file write `fh' `"* Employment counts"' _n
    file write `fh' `"preserve"' _n
    file write `fh' `"keep if empdec_lagos == 1"' _n
    file write `fh' `"collapse (sum) firm_emp=final_rank, by(identificad)"' _n
    file write `fh' `"tempfile employment"' _n
    file write `fh' `"save `employment'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `employment', nogenerate"' _n
    file write `fh' `"gen l_firm_emp = ln(firm_emp)"' _n
    file write `fh' `"gen open_firm = (firm_emp > 0)"' _n _n
    
    file write `fh' `"* Hiring calculations"' _n
    file write `fh' `"gen new_hire = (year(dtadmissao_stata) == `year')"' _n
    file write `fh' `"gen new_hire_u = new_hire"' _n _n
    
    file write `fh' `"preserve"' _n
    file write `fh' `"collapse (sum) hired_count=new_hire hired_count_u=new_hire_u, by(identificad)"' _n
    file write `fh' `"gen hiring = hired_count / firm_emp"' _n
    file write `fh' `"gen hiring_u = hired_count_u / firm_emp"' _n
    file write `fh' `"tempfile hiring_data"' _n
    file write `fh' `"save `hiring_data'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `hiring_data', nogenerate"' _n _n
    
    file write `fh' `"* Employment flows"' _n
    file write `fh' `"gen emp_in_jan = (dtadmissao_stata < mdy(1,1,`year') & mesdesli != 1)"' _n
    file write `fh' `"gen emp_jan_dec = emp_in_jan * final_rank"' _n _n
    
    file write `fh' `"preserve"' _n
    file write `fh' `"collapse (sum) firm_emp_jan=emp_jan_dec separations=mesdesli ///"' _n
    file write `fh' `"    lay_count=(causadesli==10 | causadesli==11) ///"' _n
    file write `fh' `"    qui_count=(causadesli==20 | causadesli==21), by(identificad)"' _n _n
    
    file write `fh' `"gen retention = firm_emp_jan / firm_emp"' _n
    file write `fh' `"gen turnover = separations / firm_emp"' _n
    file write `fh' `"gen layoffs = lay_count / firm_emp"' _n
    file write `fh' `"gen quits = qui_count / firm_emp"' _n _n
    
    file write `fh' `"tempfile flows"' _n
    file write `fh' `"save `flows'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `flows', nogenerate"' _n _n
    
    file write `fh' `"* Other variables"' _n
    file write `fh' `"gen fixed_c = inlist(tpvinculo, 60, 65, 70, 75, 95, 96, 97, 90)"' _n
    file write `fh' `"gen safety_d = inlist(causadesli, 62, 73, 74) | inlist(causafast1, 10, 30) | ///"' _n
    file write `fh' `"    inlist(causafast2, 10, 30) | inlist(causafast3, 10, 30)"' _n _n
    
    file write `fh' `"preserve"' _n
    file write `fh' `"collapse (sum) fixed_count=fixed_c safety_c=safety_d ///"' _n
    file write `fh' `"    leave_c=(causafast1 != -1), by(identificad)"' _n _n
    
    file write `fh' `"gen fixed_prop = fixed_count / firm_emp"' _n
    file write `fh' `"gen safety = safety_c / firm_emp"' _n
    file write `fh' `"gen leaves = leave_c / firm_emp"' _n _n
    
    file write `fh' `"tempfile other_vars"' _n
    file write `fh' `"save `other_vars'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `other_vars', nogenerate"' _n _n
    
    file write `fh' `"* Demographics"' _n
    file write `fh' `"gen no_hs_c = inlist(grinstrucao, 1, 2, 3, 4, 5, 6)"' _n
    file write `fh' `"gen hs_c = inlist(grinstrucao, 7, 8)"' _n
    file write `fh' `"gen sup_c = inlist(grinstrucao, 9, 10, 11)"' _n
    file write `fh' `"gen white = (raca_cor == 2)"' _n _n
    
    file write `fh' `"gen d_below_30 = (idade <= 30)"' _n
    file write `fh' `"gen betw_30_40 = (idade > 30 & idade <= 40)"' _n
    file write `fh' `"gen above_40 = (idade > 40)"' _n _n
    
    file write `fh' `"preserve"' _n
    file write `fh' `"keep if final_rank == 1"' _n
    file write `fh' `"collapse (mean) male_prop=genero white_prop=white avg_tenure=tempempr ///"' _n
    file write `fh' `"    (sum) no_high_school=no_hs_c high_school=hs_c superior=sup_c ///"' _n
    file write `fh' `"    total_below_30=d_below_30 total_30_40=betw_30_40 total_above_40=above_40, ///"' _n
    file write `fh' `"    by(identificad)"' _n _n
    
    file write `fh' `"gen prop_nhs = no_high_school / firm_emp"' _n
    file write `fh' `"gen prop_hs = high_school / firm_emp"' _n
    file write `fh' `"gen prop_sup = superior / firm_emp"' _n
    file write `fh' `"gen prop_below_30 = total_below_30 / firm_emp"' _n
    file write `fh' `"gen prop_30_40 = total_30_40 / firm_emp"' _n
    file write `fh' `"gen prop_above_40 = total_above_40 / firm_emp"' _n _n
    
    file write `fh' `"tempfile demographics"' _n
    file write `fh' `"save `demographics'"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"merge m:1 identificad using `demographics', nogenerate"' _n _n
    
    file write `fh' `"generate pub_firm = inlist(natjuridica, 1015,1023,1031,1040,1058,1066,1074,1082,1104,1112,1120,1139,1147,1155,1163,1171,1180,1198,1201,1210)"' _n _n
    
    file write `fh' `"* Final collapse"' _n
    file write `fh' `"keep if final_rank == 1"' _n _n
    
    file write `fh' `"preserve"' _n
    file write `fh' `"keep identificad municipio clascnae20 firm_emp"' _n
    file write `fh' `"save "$rais_aux/worker_estab_`year'.dta", replace"' _n
    file write `fh' `"restore"' _n _n
    
    file write `fh' `"collapse ///"' _n
    file write `fh' `"    (firstnm) identificad_8 year white_prop male_prop avg_tenure ///"' _n
    file write `fh' `"        no_hs_c prop_nhs hs_c prop_hs sup_c prop_sup ///"' _n
    file write `fh' `"        total_below_30 prop_below_30 total_30_40 prop_30_40 total_above_40 prop_above_40 ///"' _n
    file write `fh' `"        leave_c leaves safety_c safety fixed_count fixed_prop ///"' _n
    file write `fh' `"        qui_count quits lay_count layoffs separations turnover firm_emp_jan retention pub_firm ///"' _n
    file write `fh' `"        hired_count hiring l_firm_emp firm_emp lr_salcontr_90_10 lr_salcontr_50_10 ///"' _n
    file write `fh' `"        salcontr_p10 salcontr_p50 salcontr_p90 ///"' _n
    file write `fh' `"        municipio clascnae20 natjuridica ///"' _n
    file write `fh' `"    (mean) lr_remdezr lr_remmedr lr_salcontr_m r_salcontr_m r_remmedr r_remdezr ///"' _n
    file write `fh' `"        lr_remdezr_h lr_remmedr_h lr_salcontr_h r_remdezr_h r_remmedr_h r_salcontr_h ///"' _n
    file write `fh' `"        remdezr_h remmedr_h salcontr_h ///"' _n
    file write `fh' `", by(identificad)"' _n _n
    
    file write `fh' `"tostring municipio, replace force"' _n
    file write `fh' `"save "$rais_firm/rais_firm_`year'.dta", replace"' _n _n
    
    file write `fh' `"di "Completed year `year'""' _n
    
    file close `fh'
}

* Create batch processing script
tempname fh
file open `fh' using "011_run_parallel.sh", write replace

file write `fh' `"#!/bin/bash"' _n
file write `fh' `"# Parallel processing script for RAIS data"' _n _n

file write `fh' `"# Set up parallel processing"' _n
file write `fh' `"export OMP_NUM_THREADS=4"' _n
file write `fh' `"export STATA_MP_NUM_PROCESSORS=4"' _n _n

file write `fh' `"# Process years in parallel"' _n
foreach year of local years {
    file write `fh' `"nohup stata-mp -b do 011_process_year_`year'.do > log_`year'.log 2>&1 &"' _n
}

file write `fh' _n
file write `fh' `"# Wait for all processes to complete"' _n
file write `fh' `"wait"' _n _n

file write `fh' `"# Clean up individual year scripts"' _n
foreach year of local years {
    file write `fh' `"rm -f 011_process_year_`year'.do"' _n
}

file write `fh' _n
file write `fh' `"echo "All years processed. Running final homogenization...""' _n _n

file write `fh' `"# Run final homogenization"' _n
file write `fh' `"stata-mp -b do 011_homogenize_final.do"' _n

file close `fh'

* Create final homogenization script
tempname fh
file open `fh' using "011_homogenize_final.do", write replace

file write `fh' `"********************************************************************************"' _n
file write `fh' `"* FINAL HOMOGENIZATION SCRIPT"' _n
file write `fh' `"********************************************************************************"' _n _n

file write `fh' `"* Homogenizing municipality and industry"' _n
file write `fh' `"use "$rais_aux/worker_estab_2008.dta", clear"' _n _n

file write `fh' `"forvalues i=2009/2016 {"' _n
file write `fh' `"    append using "$rais_aux/worker_estab_`i'.dta""' _n
file write `fh' `"    erase "$rais_aux/worker_estab_`i'.dta""' _n
file write `fh' `"}"' _n _n

file write `fh' `"bys identificad: egen modeind = mode(clascnae20), minmode"' _n
file write `fh' `"bys identificad: egen modemun = mode(municipio), minmode"' _n _n

file write `fh' `"replace municipio = modemun"' _n
file write `fh' `"replace clascnae20 = modeind"' _n _n

file write `fh' `"gen cnpj_year = identificad + year/100"' _n
file write `fh' `"save "$rais_aux/worker_estab_all_years.dta", replace"' _n _n

file write `fh' `"collapse (firstnm) modemun modeind, by(identificad)"' _n
file write `fh' `"tostring modemun, replace"' _n
file write `fh' `"save "$rais_aux/rais_mode_mun_ind.dta", replace"' _n _n

file write `fh' `"* Incorporate modal values"' _n
file write `fh' `"forvalues i=2008/2016{"' _n
file write `fh' `"    use "$rais_aux/rais_mode_mun_ind.dta", clear"' _n
file write `fh' `"    merge 1:1 identificad using "$rais_firm/rais_firm_`i'.dta""' _n
file write `fh' `"    keep if _merge==3"' _n
file write `fh' `"    drop _merge"' _n
file write `fh' `"    replace municipio = modemun"' _n
file write `fh' `"    drop modemun"' _n
file write `fh' `"    replace clascnae20 = modeind"' _n
file write `fh' `"    drop modeind"' _n _n
    
file write `fh' `"    gen industry = substr(clascnae20,1,3)"' _n _n
    
file write `fh' `"    save "$rais_firm/rais_firm_`i'.dta", replace"' _n _n
    
file write `fh' `"    keep identificad identificad_8 municipio firm_emp"' _n
file write `fh' `"    gen state = substr(municipio,1,2)"' _n
file write `fh' `"    save "$rais_aux/unique_estab_`i'.dta", replace"' _n
file write `fh' `"}"' _n _n

file write `fh' `"di "Homogenization completed!""' _n

file close `fh'

* Make the shell script executable
run_terminal_cmd
