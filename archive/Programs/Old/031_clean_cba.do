********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN CBA DATASET FROM LAGOS, WITH COVERAGE INFORMATION, COLLAPSE TO ONE CBA PER FIRM (NOT ESTABLISHMENT) PER YEAR 
* INPUT: CONTRACTS CNES WITH COVERAGE INFORMATION
* OUTPUT: COLLAPSE FIRM, MUNICIPAL, STATE AND NATIONAL LEVEL CBAS
********************************************************************************

use "$cba_dir/cnes_contracts_coverage.dta", clear // load dataset with coverage info per contract. Not clean.

// remove non number characters from establishment id (identificad) 
gen identificad_cba = regexr(employer_id, "[^0-9]", "")
 
while regexm(identificad_cba, "[^0-9]"){ // regexm(identificad_cba, "[^0-9]") searches identificad_cba for non-number characters
 	replace identificad_cba = regexr(identificad_cba,"[^0-9]", "" ) // replaces the first occurence of a non-number character with empty string
 } // loop keeps going until there are no more non-number characters in idenitficad_cba
 
 
 // recoding coverage (codigo_municipio) information:
 
 // inserting a standard code to tag national agreements (if more granular info is unavailable)
 replace codigo_municipio = "000000" if mode_state == "nacional" & missing(codigo_municipio)
 
 // removing all blank spaces left in the coverage information
 replace codigo_municipio = ustrtrim(codigo_municipio)
 
 // drop all observations whose coverage information is missing
 drop if missing(codigo_municipio) // previously there were 6,045 rows with missing municipality. Now there are only 6,029. 
 
 // rename firm id to match variable name of the matching key for sector wide cba (convencoes coletivas de trabalho)
rename identificad_cba clean_asso_cnpj
 
 

 // generate firm id:

 // disntangles firm id (first 8 digits of cnpj (firm id) ) from estab id (full cnpj)
gen identificad_8  = substr(clean_asso_cnpj, 1,8)

*** APPLYING SOME OF LAGOS' RULES:

// keeping only legally valid cba's:
 keep if valid==1

* step 0 : keep only cba's with start, file and end dates
drop if missing(start_mdy)|missing(end_mdy)|missing(file_mdy) // excludes 236k observations because of the filing date.

* Step 1: Convert Date Variables from String to Stata Date Format
gen start_date_stata = date(start_mdy, "YMD")  // Convert start_mdy to Stata date
gen end_date_stata = date(end_mdy, "YMD")      // Convert end_mdy to Stata date
gen file_date_stata = date(file_mdy, "YMD")    // Convert file_mdy to Stata date

* Apply a readable date format
format start_date_stata end_date_stata file_date_stata %td

drop if start_date_stata>file_date_stata // 25k
drop if file_date_stata>end_date_stata // 20.6k

* generate negotiation_months

gen negotiation_days = file_date_stata-start_date_stata  // file date is the date where the cba comes to effect. start date, most of the times marks the beginning of the new cba negotiations
gen negotiation_months = negotiation_days/30.44 // divide by average number of days in a month

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

duplicates drop // drop duplicated lines: didn't drop anything

drop if end_year<2009 // drop if cba ends before 2009: 2.4k dropped
drop if start_year>2017 // drop if cba starts negotiations after 2017: none dropped

save "$cba_dir/cba_coverage_clean.dta", replace 

// save firm level cba dataset (acordos coletivo de trabalho)
preserve
keep if act==1

keep pair_id contract_id clean_asso_cnpj identificad_8 start_year file_year codigo_municipio 

save "$cba_dir/cba_coverage_clean_firm.dta", replace

restore


// save sectoral level cba's (convencao coletiva de trabalho)
keep if act==0

keep pair_id contract_id clean_asso_cnpj identificad_8 start_year file_year codigo_municipio


save "$cba_dir/cba_coverage_clean_sector.dta", replace

********************************************************************************
// python code to attribute coverage. 
// this python code takes the coverage string of each cba and repeats each row 
// so that each row is now each municipality of coverage of the cba_count
// this is done separately for sectoral and firm level cba's
********************************************************************************

capture noisily shell "python3" "$programs/explode_cba_coverage_firm.py"

// capture noisily shell "python3" "$programs/explode_cba_coverage_sector.py"

********************************************************************************
********************************************************************************



 use "$cba_dir/cba_firm_exploded.dta", clear
 
 replace codigo_municipio = ustrtrim(codigo_municipio) // again, remove unnecessary preceeding or following spaces in the coverage info
 
 drop if missing(codigo_municipio) // drop if coverage info is missing
 
 
 
 
 generate municipio = substr(codigo_municipio,1,6) // current ibge code has 7 digits, this is more than what RAIS shows. 6 digits identify municipality already
 generate state = substr(codigo_municipio,1,2) // generate state code, 
 duplicates drop // remove duplicate lines . !!!!2.6 M obs dropped!!!!
 
 // next lines split the dataset according to their coverage information
 
 preserve
 keep if municipio!="000000" & strlen(municipio)==6 // keeps if coverage is not national (1st if) and also not state level (state level only display state code in coverge)
 save "$cba_dir/cba_firm_exploded_mun.dta", replace
 restore
 
 preserve
 keep if strlen(municipio)==2 // keeps only cba's whose coverage is the state
 save "$cba_dir/cba_firm_exploded_sta.dta", replace
 restore
 
 preserve
 keep if municipio=="000000" // keeps only cba's whose coverage is national
 save "$cba_dir/cba_firm_exploded_nat.dta", replace
 restore
 
 
 // This part merges the cba data with a dataset containing the cnpj of 
 // individual firms in each year in RAIS. the merge is done based on the 
 // the first 8 digits of the cnpj and in the coverage municipality of the cba
 // because it could be the case that the headquarters negotiates on behalf of their subsidiaries (Lagos and Sharma, 20??)
 // It needs to be firm id and municipality on the cba side because sometimes the headquarters is not in the area of coverage.
 
 forvalues i=2009/2016{
 use "$cba_dir/cba_firm_exploded_mun.dta",clear
 keep if start_year==`i' // The use of start year is justified in Lagos (2024) "The resultin panel contains estab-year obs for years when a cba was negotiated" (Appendinx C1)
 joinby identificad_8 municipio  using "$rais_aux/unique_firms_`i'.dta" // joinby performs all the interactions between datasets that have the same municipality and firm id
 save "$cba_dir/cba_estab_firm_mun_`i'.dta",replace // joinby also drops everyone who was not matched,
 
 use "$cba_dir/cba_firm_exploded_sta.dta",clear
 keep if start_year==`i'
 joinby identificad_8 state  using "$rais_aux/unique_firms_`i'.dta"
 save "$cba_dir/cba_estab_firm_sta_`i'.dta",replace
 
 use "$cba_dir/cba_firm_exploded_nat.dta",clear
 keep if start_year==`i'
 joinby identificad_8 using "$rais_aux/unique_firms_`i'.dta"
 save "$cba_dir/cba_estab_firm_nat_`i'.dta",replace
 
 use "$cba_dir/cba_estab_firm_mun_`i'.dta", clear
 append using "$cba_dir/cba_estab_firm_sta_`i'.dta"
 append using "$cba_dir/cba_estab_firm_nat_`i'.dta"
 
 gen firm_cba=1 // generates dummies to marke wheter this is a firm level cba
 gen sector_cba=0
 save "$cba_dir/cba_estab_firm_`i'.dta", replace
 
 erase "$cba_dir/cba_estab_firm_mun_`i'.dta" // erases unnecessary data for hd space conservation.
 erase "$cba_dir/cba_estab_firm_sta_`i'.dta"
 erase "$cba_dir/cba_estab_firm_nat_`i'.dta"
 }
 
 
// find establishments under sectoral level cba's . Essentially do the same for sector level cba
 
//  use "$cba_dir/cba_sector_exploded.dta", clear // almost 60M obs
// 
//  replace codigo_municipio = ustrtrim(codigo_municipio)
// 
//  drop if missing(codigo_municipio) // drops 309k obs
// 
//  generate municipio = substr(codigo_municipio,1,6)
//  generate state = substr(codigo_municipio,1,2)
//  duplicates drop
// 
//  preserve
//  keep if municipio!="000000" & strlen(municipio)==6
//  save "$cba_dir/cba_sector_exploded_mun.dta", replace
//  restore
// 
//  preserve
//  keep if strlen(municipio)==2
//  save "$cba_dir/cba_sector_exploded_sta.dta", replace
//  restore
// 
//  preserve
//  keep if municipio=="000000"
//  save "$cba_dir/cba_sector_exploded_nat.dta", replace
//  restore
// 
//  // This part merges the cba data with a dataset containing the cnpj of 
//  // individual firms in each year in RAIS. the merge is done based on the 
//  // the establishment's employer association and in the coverage municipality 
//  // of the cba
// 
//  forvalues i=2009/2016{
//  use "$cba_dir/cba_sector_exploded_mun.dta",clear
//  keep if start_year==`i'
//  joinby clean_asso_cnpj municipio  using "$rais_aux/unique_firms_`i'.dta"
//  save "$cba_dir/cba_estab_sector_mun_`i'.dta",replace
// 
//  use "$cba_dir/cba_sector_exploded_sta.dta",clear
//  keep if start_year==`i'
//  joinby clean_asso_cnpj state  using "$rais_aux/unique_firms_`i'.dta"
//  save "$cba_dir/cba_estab_sector_sta_`i'.dta",replace
// 
//  use "$cba_dir/cba_sector_exploded_nat.dta",clear
//  keep if start_year==`i'
//  joinby clean_asso_cnpj using "$rais_aux/unique_firms_`i'.dta"
//  save "$cba_dir/cba_estab_sector_nat_`i'.dta",replace
// 
//  use "$cba_dir/cba_estab_sector_mun_`i'.dta", clear
//  append using "$cba_dir/cba_estab_sector_sta_`i'.dta"
//  append using "$cba_dir/cba_estab_sector_nat_`i'.dta"
// 
//  gen sector_cba=1
//  gen firm_cba=0
//  save "$cba_dir/cba_estab_sector_`i'.dta", replace
// 
//  erase "$cba_dir/cba_estab_sector_mun_`i'.dta"
//  erase "$cba_dir/cba_estab_sector_sta_`i'.dta"
//  erase "$cba_dir/cba_estab_sector_nat_`i'.dta"
//  }
 
 
 // Now we append all firm level cba datasets across all years and retrieve cba variables
 
 use "$cba_dir/cba_estab_firm_2009.dta",clear
 forvalues i=2010/2016 {
 	append using "$cba_dir/cba_estab_firm_`i'.dta"
 }
 //
  
 merge m:1 pair_id contract_id using "$cba_dir/cba_coverage_clean.dta" // retrieve cba variables
 
 drop if _merge!=3
 drop _merge
 keep if act==1 // no difference:  we are only dropping observations from sector level cba's
 
 save "$cba_dir/cba_estab_firm.dta", replace
 
 forvalues i=2009/2016{
 	erase "$cba_dir/cba_estab_firm_`i'.dta"
 }
 
 // Now we will do the same thing for sectoral cba's:
 
//  use "$cba_dir/cba_estab_sector_2009.dta",clear
//  forvalues i=2010/2016{
//  	append using "$cba_dir/cba_estab_sector_`i'.dta"
//  }
// 
//  merge m:1 pair_id contract_id using "$cba_dir/cba_coverage_clean.dta"
// 
//  drop if _merge!=3
//  drop _merge
//  keep if act==0 // no diff
// 
//  save "$cba_dir/cba_estab_sector.dta", replace
// 
//  forvalues i=2009/2016{
//  	erase "$cba_dir/cba_estab_sector_`i'.dta"
//  }
 
 
// This part performs the aggregation of the cba's for each establishment. 
// the goal is to have a single cba per establishment per year. 
// this does not exclude establishments with zero employment. 
 
use "$cba_dir/cba_estab_firm.dta",clear // 3.5m observations 
 
drop codigo_municipio // since data is already at estab elvel, we dont need coverage info anymore

//// DROP WEIRD CASES WHERE FILE DATE IS NOT BETWEEN START AND END
//  drop if file_date_stata>end_date_stata //112K
//  drop if file_date_stata<start_date_stata // 121.8k

// some cba-estab appear repeated because they are also being matched at the state level.
// this happens because the joinby at state level does not exclude those who were already matched at the municipality level.
// fix: exclude duplicates that have two digits in municipio
duplicates tag pair_id contract_id identificad, gen(dup) 
drop if  dup==1 & strlen(municipio)==2 // no duplicates anymore

// !!! We found out that there are some incredibly high cba_counts, max is 2750 (across all years). 
// !!! This could be due to the way Lagos organized his database, where all interactions of the employers and unions for each cba are 
// !!! reported in each row.
// !!! This could be due to the joinby procedure, especially in the scenario where each establishment affected by the cba is displayed in the cba
// !!! (and where these estabs negotiate with many unions in the same cba), and where there are many estabs of the same firm in the same municipality
// !!! The joinby procedure will create all interactions of these cases (bc it only uses municipality and firm_id to perform the match)
// !!! Using maximum makes sense in this setting
// !!! We still dont't if this is all that is behind this pattern or even how to test the hypothesis above.

// Test for problem:
order employer_id employer_name clean_asso_cnpj pair_id contract_id 
bys identificad contract_id union_id: gen count_3 = _N
bys identificad-cl_91ren_res: gen count_5 =_N
gen y=(count_5==count_3)
tab y // y is 1 for all: this means that identificad contract_id union_id uniquely identify an actual contract between an establishment and an union, since all other variables just repeat themselves within each observation for a given triplet. A consequence is that we can just take any given one of these observations to attribute to a given triplet observation and hence have how many contracts were established between the two parties. One consequence is that attributing a random observation within the triplet makes the other variables on the employer_id (name etc.) used to attribute the CBA useless and confounding. Need to check if we dont use any such variables to do anything afterwards

// to test our hypothesis, all values of y should be 1!!!

// Collapse the dataset to the estab-contract_id-union_id level to get rid of unecessary repetitions due to the problem described above

gen group_3 = identificad+"_"+contract_id+"_"+union_id

// so far, we have 3.5 M obs

collapse (first) contract_id-end_year, by(group_3) // goes to 2.5M obs

// this seems to be generating another problem:  it is attributing cba's to estabs of the same firm not mentioned in the cba
// the thing is, how much of this is actually a problem? so far it seems that it is just that the headquarters is in the same municipality as the other estabs.


// DEFINING MODE BASE MONTH BEFORE RESTRICTING TO MAIN UNION (UNCLEAR IN TEXZT HOW THIS IS DONE)

//Generating mode base month variables: negotiation month (paper text) = base_month (lagos dataset) (definition from lagos' variables dictionary)

// Different method that should coincide with the above
destring base_month, replace // minmode with string variables is lexicographic: 12<2
bys identificad: egen mode_base_month=mode(base_month), minmode


/////////////////////////////////////////////////////////////////////////////////

// COMPUTING MAIN UNION

* 2) Identify main union for each firm-level

* 2a) count the number of cba's for each pair firm x union
bysort identificad union_id: gen cba_count = _N // there are pairs with too many cba's
bysort identificad union_id start_year: gen cba_count_year = _N


* 2b) Identify the modal union for each firm: for each estab, mark the union whose cba count is the highest

bysort identificad: egen mode_union = mode(union_id), minmode // across all years or year specific? document how this changes
gen is_main_union = (union_id==mode_union)


* 2c) Keep only CBAs negotiated by the main union: delete all cba's not made by the main union
drop if is_main_union == 0 // drops 1.6M obs (2/3 of all obs)

/////////////////////////////////////////////////////////////////////////////////


// DEFINING MODE BASE MONTH !!!AFTER!!! RESTRICTING TO MAIN UNION (UNCLEAR IN TEXZT HOW THIS IS DONE)

//Generating mode base month variables: negotiation month (paper text) = base_month (lagos dataset) (definition from lagos' variables dictionary)

// Different method that should coincide with the above
// destring base_month, replace // minmode with string variables is lexicographic: 12<2
// bys identificad: egen mode_base_month=mode(base_month), minmode



/////////////////////////////////////////////////////////////////////////////////

// Generate active year: this marks whether the estab had an active cba in december of each year

gen end_month = month(end_date_stata)
tab end_month

gen end_day = day(end_date_stata)
tab end_day
tab end_day if end_month==12 // all of the above was to see if it would make much differece to select end of year if active in dec 31 or anytime in dec.


/////////////////////////////////////////////////////////////////////////////////

//  IN ORDER TO FIGURE HOW TO IMPLEMENT THE TEMPORAL COVERAGE OF THE CBA, WE HAVE TO UNDERSTAND 
//  TRULY WHEN IT STARTS AND ENDS.
//  END: Seems preety clear that end date is the appropriate one.
//  START: Not clear if it is start date or file_date. Lagos leans towards file_date (footnote 75). 
// !!! REVISION:  IN FIG 1 OF LAGOS, IT SEEMS THAT HE DEFINES COVERAGE USING START AND END DATES. 


// There are some oddities with regard to file dates:
gen file_before_start = (file_date_stata<start_date_stata)
gen file_after_end = (file_date_stata>end_date_stata)

tab file_after_end // 3.7% of observation: By looking at some examples, it seems that the parts struck a cba preemptively. In this case, I find it more reasonable to assume that the true start of the cba is the maximum between the two dates. 
tab file_before_start // 3.2%: on the other hand, a slightly  higher proportion of the rows (1.8%) have filing dates AFTER the end date. I don't have any good hypothesis why this could be the case. i dont know if these are valid or not. 



// A lot of firm-level cba's end on December, concentrated either on the 15th or 31st 

// at this point, dataset is at the identificad-contract_id-union_id level.

gen last_active_year = end_year if end_month==12 // if month of end date is dec, then last active year is the year of the end date
replace last_active_year= end_year-1 if end_month!=12 // if month of end date is prior to dec, last active year is the year before
replace last_active_year= end_year if (last_active_year<start_year)

// Using the maximum of file and start date to define coverage: 


// On a previous attempt, I was using start_year and end_year to define coverage, but this was generating a lagos sample with 40k firms per year. this is clearly not right. So I decided to go back to using file_dates as the start of the coverage where appropriate (if start_date<file_date<end_date) and using start and end dates in the other cases where file date is in a wierd position.

gen true_start_year=.
replace true_start_year=start_year if file_year>end_year
replace true_start_year=max(file_year, start_year) if file_year<=end_year


gen x = (last_active_year-true_start_year<0) // means that cba was never active at the end of year. 
tab x // Oh wow, 226k (27%) with x==1!
replace last_active_year = true_start_year if x==1

// drop if x==1 // drop because then cba is not active when we actually measure firm level outcomes. 
drop x


gen true_start_date = max(file_date_stata, start_date_stata) if file_date_stata<=end_date_stata
replace true_start_date=start_date_stata if file_date_stata>end_date_stata
// gen true_start_year = max(file_year, start_year) 

// Now, we use start_year to define coverage and that is it.

gen active_year=. // now we repeat the cba rows to all years in which a cba was active any day during december
gen row_mult = last_active_year-start_year+1
expand last_active_year-start_year+1 // expands to 1.2M observations
bysort contract_id identificad union_id: replace active_year= start_year+(_n-1) // generate active year. The data was previously at the contract_id-union_id-estab level. So these are the right varibles to sort by in order to generate the active year variable.

order identificad contract_id union_id start_year file_year end_year true_start_year last_active_year active_year

* 4c) Create synthetic cba, trying our best to emulate Lagos' rules

* Step 3: Group Data by Employer-Year
gen group_id_firm = identificad + "_" + string(active_year) // we are going to collapse the dataset by estab id within each year where the estab has an active cba

gen treat_ultra =0 // generate treatment status variable
replace treat_ultra=1 if file_date_stata<=mdy(9,25,2012) & end_date_stata>=mdy(9,26,2012) // this only marks estabs with active cbas in 2012, does not mark the cross-section of firms that get treated at some point. "If an agreement was reached before Sep 2012"

// forvalues i=1/30 {
// gen treat_ultra_t = inrange(mdy(9,`i',2012), true_start_date, end_date_stata)
// di "Threshold:  Sep `i' 2012" 
//
// tab mode_base_month if active_year==2012 & treat_ultra_t==0
// drop treat_ultra_t
// }

* Step 4: Apply Merge Rules to Variables

collapse ///
    (firstnm) identificad_8 identificad union_id active_year act mode_base_month /// Variables to keep as is. choose the first that is non missing
    (max) text_tokens end_date_stata treat_ultra numb_clauses /// Take maximum values . within estab and active year, pick the maximum duration and whether any cba was ever under ultra activity
    (min) start_date_stata /// Take minimum value
    (mean) negotiation_months /// Compute average negotiation months
    (max) cl_* /// Sum clauses as requested
    (max) ultra /// Take maximum of binary variable ultra, ensuring it's 1 if any are 1 ( this variable is not very useful so far)
, by(group_id_firm) 
// reduced to 176k observations

rename numb_clauses numb_clauses_original // just not to confuse with the one I create from the individual clause variables

gen negotiation_days = negotiation_months * 30.44 // recalculate negotiation months because of the new start dates and avg neg months
gen file_date_stata = start_date_stata+negotiation_days // regenerate file date according to avg neg months.

format file_date_stata %td 

ds cl_* 
local clause_vars `r(varlist)'  // Store all variables starting with cl_

* Step 2: Generate a New Variable as the Sum of All cl_ Variables
gen numb_clauses = 0
foreach var of local clause_vars {
    replace numb_clauses = numb_clauses + `var'
}

keep identificad_8 identificad union_id text_tokens end_date_stata start_date_stata file_date_stata active_year negotiation_months mode_base_month ultra treat_ultra numb_clauses_original numb_clauses cl_*

gen start_year = year(start_date_stata)
gen end_year = year(end_date_stata)


gen treat_ultra_t = inrange(mdy(9,15,2012), file_date_stata, end_date_stata)



* Save Final Dataset
save "$cba_dir/collapsed_cba_firm_1.dta", replace


/// !!!! CHANGE THIS TO APPLY CORRECTIONS WE MADE ABOVE!!!!
// // FOR SECTORAL LEVEL CBA'S:
//
// use "$cba_dir/cba_estab_sector.dta",clear
// 
// drop codigo_municipio
//
//
// * 2) Identify main union for each firm-level
//
// * 2a) count the number of cba's for each firm
// bysort identificad union_id: gen cba_count = _N
// * 2b) Identify the modal union for each firm
// bysort identificad (cba_count union_id): gen is_main_union = union_id[_n] == union_id[_N]
// * 2c) Keep only CBAs negotiated by the main union
// drop if is_main_union == 0
//
// //Generating mode base month variables
//
// * Step 1: Count occurrences of each base month by establishment
// bysort identificad base_month: gen month_count = _N if !missing(base_month) & firm_cba == 1
//
// * Step 2: Identify the maximum count for each establishment
// bysort identificad: egen max_count = max(month_count)
//
// * Step 3: Mark which month(s) have the maximum count
// gen is_modal = (month_count == max_count) & !missing(month_count)
//
// * Step 4: In case of ties, choose consistently based on alphabetical order
// * (You can modify this to choose a different ordering if preferred)
// sort identificad base_month
//
// * Step 5: Tag the first observation with maximum count for each establishment
// by identificad: gen keep_this = is_modal & _n == 1 if is_modal
//
// * Step 6: Propagate the modal month to all observations of the same establishment
// gen temp_mode = base_month if keep_this
// bysort identificad: egen mode_base_month = mode(temp_mode), maxmode
//
// * Step 7: Clean up temporary variables
// drop month_count max_count is_modal keep_this temp_mode
//
// // Generate active year 
// gen end_month=month(end_date_stata)
// gen end_day = day(end_date_stata)
//
// gen last_active_year = end_year if end_month==12
// replace last_active_year = end_year-1 if end_month<12
//
// gen active_year=.
// expand last_active_year-start_year+1
// gen row_id = _n
// bysort row_id (start_year): replace active_year= start_year+(_n-1)
// drop row_id
//
//
// * 4c) Create synthetic cba, trying our best to emulate Lagos' rules
//
// * Step 3: Group Data by Employer-Year
// gen group_id_firm = identificad + "_" + string(active_year)
//
// gen treat_ultra =0
// replace treat_ultra=1 if file_date_stata<=mdy(9,14,2012) & end_date_stata>=mdy(9,15,2012)
//
// bys identificad: egen max_treat = max(treat_ultra)
// replace treat_ultra=max_treat
// drop max_treat
//
// * Step 4: Apply Merge Rules to Variables
//
// collapse ///
//     (firstnm) pair_id employer_id identificad_8 identificad union_id active_year municipio act mode_base_month /// Variables to keep as is 
//     (max) text_tokens end_date_stata treat_ultra /// Take maximum values
//     (min) start_date_stata /// Take minimum value
//     (mean) negotiation_months /// Compute average negotiation months
//     (max) cl_* /// Sum clauses as requested
//     (max) ultra /// Take maximum of binary variable ultra, ensuring it's 1 if any are 1
// , by(group_id_firm)
//
// gen negotiation_days = negotiation_months * 30.44
// gen file_date_stata = start_date_stata+negotiation_days
//
// format file_date_stata %td 
//
// ds cl_* 
// local clause_vars `r(varlist)'  // Store all variables starting with cl_
//
// * Step 2: Generate a New Variable as the Sum of All cl_ Variables
// gen numb_clauses = 0
// foreach var of local clause_vars {
//     replace numb_clauses = numb_clauses + `var'
// }
//
// keep pair_id employer_id identificad_8 identificad union_id text_tokens end_date_stata start_date_stata file_date_stata active_year negotiation_months mode_base_month ultra numb_clauses cl_* municipio
//
// gen start_year = year(start_date_stata)
// gen end_year = year(end_date_stata)
//
// // gen treat_ultra =0
// // replace treat_ultra=1 if file_date_stata<= mdy(8,31,2012) & end_date_stata>=mdy(10,1,2012)
//
//
//
// * Save Final Dataset
// save "$cba_dir/collapsed_cba_sector.dta", replace

