********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: EXTEND YEARLY EMPLOYERS TO 2005-2006
* INPUT: DTA RAIS FILES (DAHIS' CLEANING PROCEDURE) FOR 2005-2006
* OUTPUT: yearly_employers_2005.dta, yearly_employers_2006.dta
*         employers_2005_2006.csv, employers_2006_2007.csv
*
* NOTE: Replicates logic from 1050_yearly_employers.do lines 10-112
*       for years 2005-2006. yearly_employers_2007.dta already exists.
********************************************************************************

version 17.0

global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"


timer clear
timer on 1

********************************************************************************
* PART 1: Create yearly_employers for 2005 and 2006
********************************************************************************

forvalues i=2005/2006{

use "$rais_raw_dir/RAIS_`i'.dta",clear

// first we will keep only the variables we need to make this lighter.

 keep PIS identificad empem3112 tempempr horascontr remdezr

// genreate firm identifier:

gen identificad8 = substr(identificad, 1,8)

// select only spells within each firm that are active throughtout december of each year

gen empdec_lagos = empem3112*(tempempr>1)
keep if empdec_lagos ==1

// generate necessary wage variable for ranking

gen remdezr_h = remdezr/(horascontr*4.348)
gen l_remdezr_h = ln(remdezr_h)

// now select only one spell per worker per firm:
// Step 1: Rank by contracted hours (higher = better)
bysort identificad PIS: egen max_hours = max(horascontr * empdec_lagos)
gen rank1 = (horascontr == max_hours & empdec_lagos==1)

* Step 2: Among those with max hours, rank by hourly wage (higher = better)
bysort identificad PIS: egen max_wage = max(l_remdezr_h * rank1)
gen rank2 = (l_remdezr_h == max_wage & rank1==1)

* Step 3: For any remaining ties, assign a random number
set seed 12345
gen random = runiform() if rank2==1

* Create a final rank combining all criteria
bysort identificad PIS: egen max_random = max(random * rank2)
gen final_rank = (random == max_random & rank2==1)

drop rank1 rank2 random max_random

* count the number of selected spells within each establishment:
bysort identificad: egen firm_emp = total(final_rank==1)


keep if final_rank==1

// Now, among selected spells, select only one per worker, according to the longest tenure

recast float tempempr, force

bys PIS: egen max_ten = max(tempempr)
gen rank1 = (tempempr==max_ten)

// among those with same tenure, choose  the one with the largest lgo hourly december earning

bys PIS: egen max_worker_wage = max(l_remdezr_h*rank1)
gen rank2 = (l_remdezr_h==max_worker_wage & rank1==1)

// among those with same tenure and december earnings, choose randomly

set seed 12345

gen random = runiform() if rank2==1

bys PIS: egen max_random = max(rank2*random)

gen rank_emp = (max_random==random & rank2==1)

keep if rank_emp==1



// keep only necessary variables to perform connectivity measures.

keep PIS identificad identificad8 firm_emp

// rename variables in order to keep them after the merge later:

rename (identificad identificad8 firm_emp ) (identificad_`i' identificad8_`i' firm_emp_`i')

save "$rais_aux/yearly_employers_`i'.dta", replace


}


********************************************************************************
* PART 2: Create employer transition files for 2005-2006 and 2006-2007
********************************************************************************

forvalues i=2005/2006{
	local j = `i'+1
use "$rais_aux/yearly_employers_`i'.dta", clear

merge 1:1 PIS using "$rais_aux/yearly_employers_`j'.dta"
keep if _merge==3

replace identificad_`i' = "1"+identificad_`i'
replace identificad_`j' = "1"+identificad_`j'

replace identificad8_`i' = "1"+identificad8_`i'
replace identificad8_`j' = "1"+identificad8_`j'
save "$rais_aux/employers_`i'_`j'.dta", replace
export delimited "$rais_aux/employers_`i'_`j'.csv", replace
}


timer off 1
timer list

display "Done: yearly_employers_2005.dta, yearly_employers_2006.dta"
display "Done: employers_2005_2006.csv, employers_2006_2007.csv"
