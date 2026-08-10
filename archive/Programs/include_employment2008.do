********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN RAIS DATASETS, GENERATE OUTCOMES, COLLAPSE TO FIRM LEVEL
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE), cba rais 2009 2016
* OUTPUT: cba rais 2009 2016 FILES WITH 2008 employment to adjust hiring measure
********************************************************************************


**# Bookmark #1


use "$rais_raw_dir/RAIS_2008.dta",clear

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
bysort identificad PIS: egen max_hours = max(horascontr * empdec_lagos) // orders by estab_id and then PIS, within each estab-PIS group, takes the max of the contract hours, given that this spell is active in dec
gen rank1 = (horascontr == max_hours & empdec_lagos==1) // generates an indicator for the spells active throughout dec and whose contracted hours match the max 

* Step 2: Among those with max hours, rank by hourly wage (higher = better)
bysort identificad PIS: egen max_wage = max(l_remdezr_h * rank1) // orderd by estab id and PIS, within each group computes the max of the log hourly dec wages within the max contracted hours that are active in dec
gen rank2 = (l_remdezr_h == max_wage & rank1==1) // marks spells w/in estab-pis active in dec that have max hourly log dec wages among those that have max contracted hours

* Step 3: For any remaining ties, assign a random number
set seed 12345
gen random = runiform() if rank2==1 // gen random number w/in spells that fulfill conditions of rank2

* Create a final rank combining all criteria
bysort identificad PIS: egen max_random = max(random * rank2) // w/in estab-PIS-max hourly log dec wage-max contracted hours computes the maximum random number
gen final_rank = (random == max_random & rank2==1) // marks spells that fulfill rank2 and have max random number

drop rank1 rank2 random max_random

* count the number of selected spells within each establishment:
bysort identificad: egen firm_emp_2008 = total(final_rank==1) // w/in estab counts spells that fulfill conditions of final_rank. 


// collapse to the firm level to get only the employement in 2008:

collapse (first) firm_emp_2008, by(identificad)

save "$rais_aux/firm_emp_2008.dta", replace


merge 1:m identificad using "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta"


// generate hiring with lagos definition:

bys identificad (year):  gen avg_emp = (firm_emp+firm_emp[_n-1])/2 if year>=2010

gen hiring_lagos=.


replace hiring_lagos= hired_count /((firm_emp+firm_emp_2008)/2) if year==2009

replace hiring_lagos= hired_count/avg_emp if year>=2010

