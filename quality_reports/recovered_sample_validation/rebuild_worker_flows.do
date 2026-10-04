clear all
set more off
version 17.0
global rais_aux "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/aux"
********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: SELECT SPELLS TO BE CONSIDERED IN THE TRANSITION MATRICES
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: FIRM LEVEL RAIS FILES WITH ANALYSIS OUTCOMES
********************************************************************************


forvalues  i=2007/2011{

// PARALLEL PIPELINE: read the worker panel that 1010p already produced instead of
// opening raw RAIS a third time (REDUNDANCY_AUDIT R1, R4). worker_estab_{i} is
// already restricted to one spell per worker-firm by exactly this rule -- same
// empdec_lagos definition, same three-step rank, same seed -- so the block that
// used to re-derive it here is gone. The ranking wage differed only by the
// deflator, a within-year constant, which cannot change a max.
use PIS identificad tempempr horascontr remdezr using "$rais_aux/worker_estab_`i'.dta", clear

gen identificad8 = substr(identificad, 1,8)

// wage variable retained for the worker-level (stage 2) ranking below
gen remdezr_h = remdezr/(horascontr*4.348)
gen l_remdezr_h = ln(remdezr_h)

// firm employment: count of selected spells per establishment
bysort identificad: egen firm_emp = total(1)

// Now, among selected spells, select only one per worker, according to the longest tenure

recast float tempempr, force

* ---- DETERMINISM: canonical row order, stage 2 (one firm per worker) ---------
* Stage 2 groups by PIS alone, so stage 1's `identificad PIS ...` order is not a
* valid prefix here and a fresh sort is required. Stage 1 leaves exactly one row
* per (identificad, PIS), so appending identificad makes this key unique and the
* seeded draw below fully determined by the data.
sort PIS tempempr l_remdezr_h identificad

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



forvalues i=2007/2010{
	local j = `i'+1
use "$rais_aux/yearly_employers_`i'.dta", clear

merge 1:1 PIS using "$rais_aux/yearly_employers_`j'.dta"
keep if _merge==3 // only get those who transitioned between two estabs, not those who left or entered the job market

replace identificad_`i' = "1"+identificad_`i'
replace identificad_`j' = "1"+identificad_`j'

replace identificad8_`i' = "1"+identificad8_`i'
replace identificad8_`j' = "1"+identificad8_`j' 
save "$rais_aux/employers_`i'_`j'.dta", replace 
export delimited "$rais_aux/employers_`i'_`j'.csv", replace	
}


// use "$rais_aux/employers_2007_2008.dta", clear
// sample 500, count
// export delimited "$rais_aux/employers_2007_2008_500.csv", replace

////////////////////////////////////////////////////////////////////////////////

display "RECOVERED SAMPLE WORKER FLOWS COMPLETE"
