********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN CBA DATASET FROM LAGOS, WITH COVERAGE INFORMATION, COLLAPSE TO ONE CBA PER FIRM (NOT ESTABLISHMENT) PER YEAR 
* INPUT: CONTRACTS CNES WITH COVERAGE INFORMATION
* OUTPUT: COLLAPSE FIRM, MUNICIPAL, STATE AND NATIONAL LEVEL CBAS
********************************************************************************

use "$cba_dir/cnes_contracts_coverage.dta", clear

// remove non number characters from establishment id (identificad) 
gen identificad_cba = regexr(employer_id, "[^0-9]", "")
 
while regexm(identificad_cba, "[^0-9]"){
 	replace identificad_cba = regexr(identificad_cba,"[^0-9]", "" )
 }
 
 replace codigo_municipio = "000000" if mode_state == "nacional" & missing(codigo_municipio)
 
 replace codigo_municipio = ustrtrim(codigo_municipio)
 
 drop if missing(codigo_municipio)
 
rename identificad_cba clean_asso_cnpj
 
 

 // generate firm id:

gen identificad_8  = substr(clean_asso_cnpj, 1,8)

*** APPLYING SOME OF LAGOS' RULES:

* step 0 : keep only cba's with start, file and end dates
drop if missing(start_mdy)|missing(end_mdy)|missing(file_mdy)

* Step 1: Convert Date Variables from String to Stata Date Format
gen start_date_stata = date(start_mdy, "YMD")  // Convert start_mdy to Stata date
gen end_date_stata = date(end_mdy, "YMD")      // Convert end_mdy to Stata date
gen file_date_stata = date(file_mdy, "YMD")    // Convert file_mdy to Stata date

* Apply a readable date format
format start_date_stata end_date_stata file_date_stata %td

* generate negotiation_months

gen negotiation_days = file_date_stata-start_date_stata
gen negotiation_months = negotiation_days/30.44

* Step 3: Generate All Active Years
gen start_year = year(start_date_stata)
gen file_year = year(file_date_stata)
gen end_year = year(end_date_stata)

// * Expand dataset to include all active years
// gen active_year = .
// expand end_year - file_year + 1
// gen row_id = _n  // Create a row-level identifier
// bysort row_id (file_year): replace active_year = file_year + (_n - 1)
// drop row_id  // Drop the temporary identifier

duplicates drop

drop if end_year<2009
drop if start_year>2017

save "$cba_dir/cba_coverage_clean.dta", replace


preserve
keep if act==1

keep pair_id contract_id clean_asso_cnpj identificad_8 start_year codigo_municipio 

save "$cba_dir/cba_coverage_clean_firm.dta", replace

restore



keep if act==0

keep pair_id contract_id clean_asso_cnpj identificad_8 start_year codigo_municipio


save "$cba_dir/cba_coverage_clean_sector.dta", replace

capture noisily shell "python3" "$programs/explode_cba_coverage_firm.py"

capture noisily shell "python3" "$programs/explode_cba_coverage_sector.py"


 use "$cba_dir/cba_firm_exploded.dta", clear
 
 replace codigo_municipio = ustrtrim(codigo_municipio)
 
 drop if missing(codigo_municipio)
 
 generate municipio = substr(codigo_municipio,1,6)
 generate state = substr(codigo_municipio,1,2)
 duplicates drop
 
 preserve
 keep if municipio!="000000" & strlen(municipio)==6
 save "$cba_dir/cba_firm_exploded_mun.dta", replace
 restore
 
 preserve
 keep if strlen(municipio)==2
 save "$cba_dir/cba_firm_exploded_sta.dta", replace
 restore
 
 preserve
 keep if municipio=="000000"
 save "$cba_dir/cba_firm_exploded_nat.dta", replace
 restore
 
 
 forvalues i=2009/2017{
 use "$cba_dir/cba_firm_exploded_mun.dta",clear
 keep if start_year==`i'
 merge m:m identificad_8 municipio  using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_firm_mun_`i'.dta",replace
 
 use "$cba_dir/cba_firm_exploded_sta.dta",clear
 keep if start_year==`i'
 merge m:m identificad_8 state  using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_firm_sta_`i'.dta",replace
 
 use "$cba_dir/cba_firm_exploded_nat.dta",clear
 keep if start_year==`i'
 merge m:m identificad_8 using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_firm_nat_`i'.dta",replace
 
 use "$cba_dir/cba_estab_firm_mun_`i'.dta", clear
 append using "$cba_dir/cba_estab_firm_sta_`i'.dta"
 append using "$cba_dir/cba_estab_firm_nat_`i'.dta"
 
 gen firm_cba=1
 gen sector_cba=0
 save "$cba_dir/cba_estab_firm_`i'.dta", replace
 
 erase "$cba_dir/cba_estab_firm_mun_`i'.dta"
 erase "$cba_dir/cba_estab_firm_sta_`i'.dta"
 erase "$cba_dir/cba_estab_firm_nat_`i'.dta"
 }
 
 
// find establishments under sectoral level cba's
 
 use "$cba_dir/cba_sector_exploded.dta", clear
 
 replace codigo_municipio = ustrtrim(codigo_municipio)
 
 drop if missing(codigo_municipio)
 
 generate municipio = substr(codigo_municipio,1,6)
 generate state = substr(codigo_municipio,1,2)
 duplicates drop
 
 preserve
 keep if municipio!="000000" & strlen(municipio)==6
 save "$cba_dir/cba_sector_exploded_mun.dta", replace
 restore
 
 preserve
 keep if strlen(municipio)==2
 save "$cba_dir/cba_sector_exploded_sta.dta", replace
 restore
 
 preserve
 keep if municipio=="000000"
 save "$cba_dir/cba_sector_exploded_nat.dta", replace
 restore
 
 
 forvalues i=2009/2017{
 use "$cba_dir/cba_sector_exploded_mun.dta",clear
 keep if start_year==`i'
 merge m:m clean_asso_cnpj municipio  using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_sector_mun_`i'.dta",replace
 
 use "$cba_dir/cba_sector_exploded_sta.dta",clear
 keep if start_year==`i'
 merge m:m clean_asso_cnpj state  using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_sector_sta_`i'.dta",replace
 
 use "$cba_dir/cba_sector_exploded_nat.dta",clear
 keep if start_year==`i'
 merge m:m clean_asso_cnpj using "$rais_aux/unique_firms_`i'.dta"
 keep if _merge==3
 drop _merge
 save "$cba_dir/cba_estab_sector_nat_`i'.dta",replace
 
 use "$cba_dir/cba_estab_sector_mun_`i'.dta", clear
 append using "$cba_dir/cba_estab_sector_sta_`i'.dta"
 append using "$cba_dir/cba_estab_sector_nat_`i'.dta"
 
 gen sector_cba=1
 gen firm_cba=0
 save "$cba_dir/cba_estab_sector_`i'.dta", replace
 
 erase "$cba_dir/cba_estab_sector_mun_`i'.dta"
 erase "$cba_dir/cba_estab_sector_sta_`i'.dta"
 erase "$cba_dir/cba_estab_sector_nat_`i'.dta"
 }
 
 
 use "$cba_dir/cba_estab_firm_2009.dta",clear
 forvalues i=2010/2017 {
 	append using "$cba_dir/cba_estab_firm_`i'.dta"
 }
 
  
 merge m:1 pair_id contract_id using "$cba_dir/cba_coverage_clean.dta"
 
 drop if _merge!=3
 drop _merge
 keep if act==1
 
 save "$cba_dir/cba_estab_firm.dta", replace
 
 forvalues i=2009/2017{
 	erase "$cba_dir/cba_estab_firm_`i'.dta"
 }
 
 use "$cba_dir/cba_estab_sector_2009.dta",clear
 forvalues i=2010/2017{
 	append using "$cba_dir/cba_estab_sector_`i'.dta"
 }
 
 merge m:1 pair_id contract_id using "$cba_dir/cba_coverage_clean.dta"
 
 drop if _merge!=3
 drop _merge
 keep if act==0
 
 save "$cba_dir/cba_estab_sector.dta", replace
 
 forvalues i=2009/2017{
 	erase "$cba_dir/cba_estab_sector_`i'.dta"
 }
 
 
use "$cba_dir/cba_estab_firm.dta",clear
 
drop codigo_municipio


* 2) Identify main union for each firm-level

* 2a) count the number of cba's for each firm
bysort identificad union_id: gen cba_count = _N
* 2b) Identify the modal union for each firm
bysort identificad (cba_count union_id): gen is_main_union = union_id[_n] == union_id[_N]
* 2c) Keep only CBAs negotiated by the main union
drop if is_main_union == 0

//Generating mode base month variables

* Step 1: Count occurrences of each base month by establishment
bysort identificad base_month: gen month_count = _N if !missing(base_month) & firm_cba == 1

* Step 2: Identify the maximum count for each establishment
bysort identificad: egen max_count = max(month_count)

* Step 3: Mark which month(s) have the maximum count
gen is_modal = (month_count == max_count) & !missing(month_count)

* Step 4: In case of ties, choose consistently based on alphabetical order
* (You can modify this to choose a different ordering if preferred)
sort identificad base_month

* Step 5: Tag the first observation with maximum count for each establishment
by identificad: gen keep_this = is_modal & _n == 1 if is_modal

* Step 6: Propagate the modal month to all observations of the same establishment
gen temp_mode = base_month if keep_this
bysort identificad: egen mode_base_month = mode(temp_mode), maxmode

* Step 7: Clean up temporary variables
drop month_count max_count is_modal keep_this temp_mode 

// Generate active year 
gen active_year=.
expand end_year-start_year+1
gen row_id = _n
bysort row_id (start_year): replace active_year= start_year+(_n-1)
drop row_id


* 4c) Create synthetic cba, trying our best to emulate Lagos' rules

* Step 3: Group Data by Employer-Year
gen group_id_firm = identificad + "_" + string(active_year)

* Step 4: Apply Merge Rules to Variables

collapse ///
    (firstnm) pair_id employer_id identificad_8 identificad union_id active_year municipio act mode_base_month /// Variables to keep as is 
    (max) text_tokens end_date_stata /// Take maximum values
    (min) start_date_stata /// Take minimum value
    (mean) negotiation_months /// Compute average negotiation months
    (max) cl_* /// Sum clauses as requested
    (max) ultra /// Take maximum of binary variable ultra, ensuring it's 1 if any are 1
, by(group_id_firm)

gen negotiation_days = negotiation_months * 30.44
gen file_date_stata = start_date_stata+negotiation_days

format file_date_stata %td 

ds cl_* 
local clause_vars `r(varlist)'  // Store all variables starting with cl_

* Step 2: Generate a New Variable as the Sum of All cl_ Variables
gen numb_clauses = 0
foreach var of local clause_vars {
    replace numb_clauses = numb_clauses + `var'
}

keep pair_id employer_id identificad_8 identificad union_id text_tokens end_date_stata start_date_stata file_date_stata active_year negotiation_months mode_base_month ultra numb_clauses cl_* municipio

gen start_year = year(start_date_stata)
gen end_year = year(end_date_stata)

gen treat_ultra =0
replace treat_ultra=1 if file_date_stata<= mdy(8,31,2012) & end_date_stata>=mdy(10,1,2012)

* Save Final Dataset
save "$cba_dir/collapsed_cba_firm.dta", replace
erase "$cba_dir/cba_estab_firm.dta"


// FOR SECTORAL LEVEL CBA'S:

use "$cba_dir/cba_estab_sector.dta",clear
 
drop codigo_municipio


* 2) Identify main union for each firm-level

* 2a) count the number of cba's for each firm
bysort identificad union_id: gen cba_count = _N
* 2b) Identify the modal union for each firm
bysort identificad (cba_count union_id): gen is_main_union = union_id[_n] == union_id[_N]
* 2c) Keep only CBAs negotiated by the main union
drop if is_main_union == 0

//Generating mode base month variables

* Step 1: Count occurrences of each base month by establishment
bysort identificad base_month: gen month_count = _N if !missing(base_month) & firm_cba == 1

* Step 2: Identify the maximum count for each establishment
bysort identificad: egen max_count = max(month_count)

* Step 3: Mark which month(s) have the maximum count
gen is_modal = (month_count == max_count) & !missing(month_count)

* Step 4: In case of ties, choose consistently based on alphabetical order
* (You can modify this to choose a different ordering if preferred)
sort identificad base_month

* Step 5: Tag the first observation with maximum count for each establishment
by identificad: gen keep_this = is_modal & _n == 1 if is_modal

* Step 6: Propagate the modal month to all observations of the same establishment
gen temp_mode = base_month if keep_this
bysort identificad: egen mode_base_month = mode(temp_mode), maxmode

* Step 7: Clean up temporary variables
drop month_count max_count is_modal keep_this temp_mode

// Generate active year 
gen active_year=.
expand end_year-start_year+1
gen row_id = _n
bysort row_id (start_year): replace active_year= start_year+(_n-1)
drop row_id


* 4c) Create synthetic cba, trying our best to emulate Lagos' rules

* Step 3: Group Data by Employer-Year
gen group_id_firm = identificad + "_" + string(active_year)

* Step 4: Apply Merge Rules to Variables

collapse ///
    (firstnm) pair_id employer_id identificad_8 identificad union_id active_year municipio act mode_base_month /// Variables to keep as is 
    (max) text_tokens end_date_stata /// Take maximum values
    (min) start_date_stata /// Take minimum value
    (mean) negotiation_months /// Compute average negotiation months
    (max) cl_* /// Sum clauses as requested
    (max) ultra /// Take maximum of binary variable ultra, ensuring it's 1 if any are 1
, by(group_id_firm)

gen negotiation_days = negotiation_months * 30.44
gen file_date_stata = start_date_stata+negotiation_days

format file_date_stata %td 

ds cl_* 
local clause_vars `r(varlist)'  // Store all variables starting with cl_

* Step 2: Generate a New Variable as the Sum of All cl_ Variables
gen numb_clauses = 0
foreach var of local clause_vars {
    replace numb_clauses = numb_clauses + `var'
}

keep pair_id employer_id identificad_8 identificad union_id text_tokens end_date_stata start_date_stata file_date_stata active_year negotiation_months mode_base_month ultra numb_clauses cl_* municipio

gen start_year = year(start_date_stata)
gen end_year = year(end_date_stata)

gen treat_ultra =0
replace treat_ultra=1 if file_date_stata<= mdy(8,31,2012) & end_date_stata>=mdy(10,1,2012)

* Save Final Dataset
save "$cba_dir/collapsed_cba_sector.dta", replace
erase "$cba_dir/cba_estab_sector.dta"


								 
 
 