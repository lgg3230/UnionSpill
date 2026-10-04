clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local S "`R'/Data/sample_gap_investigation/semantics_recovery"
local W "`R'/Data/sample_gap_investigation/wide_2007_2016"
* Validate selected-worker totals independently, before aggregating geography.
forvalues y=2007/2016 {
 use identificad workers using "`S'/worker_municipality_counts_`y'.dta",clear
 collapse (sum) workers,by(identificad)
 merge 1:1 identificad using "`W'/rais_firm/rais_firm_`y'.dta",keepusing(firm_emp)
 count if _merge!=3 | workers!=firm_emp
 display "EMPLOYMENT DISAGREEMENTS `y': " r(N)
 preserve
 keep if _merge!=3 | workers!=firm_emp
 export delimited using "employment_disagreements_`y'.csv",replace
 restore
 assert _merge==3 & workers==firm_emp
}
use identificad municipio workers using "`S'/worker_municipality_counts_2007.dta",clear
forvalues y=2008/2016 {
 append using "`S'/worker_municipality_counts_`y'.dta"
}
replace ambiguous_workers=0 if missing(ambiguous_workers)
collapse (sum) workers ambiguous_workers,by(identificad municipio)
save "`S'/pooled_worker_municipality_counts_2007_2016.dta",replace
* Missing municipalities receive no votes, but all-missing establishments must
* remain in the dictionary (and can still match national coverage).
gen byte nonmissing_mun=!missing(municipio)
replace workers=0 if missing(municipio)
bys identificad: egen total_ambiguous=total(ambiguous_workers)
gen fixed_votes=workers-ambiguous_workers
gsort identificad -nonmissing_mun -workers municipio
by identificad: gen byte winner=_n==1
by identificad: gen runner_votes=workers[2]
replace runner_votes=0 if missing(runner_votes)
* Conservative bound: even allocating ALL ambiguous votes to the runner cannot
* displace the winner, accounting for numeric minmode on exact ties separately.
gen byte robust=(total_ambiguous==0 | fixed_votes>runner_votes+total_ambiguous)
keep if winner
rename municipio modemun_numeric
preserve
keep if !robust
export delimited using "wide_mode_uncertainty.csv",replace
restore
tab robust
save "`S'/wide_mode_audit.dta",replace
tostring modemun_numeric,gen(modemun) format(%06.0f)
keep identificad modemun
isid identificad
save "`W'/rais_aux/rais_mode_mun_ind.dta",replace
forvalues y=2009/2016 {
 use "`W'/rais_firm/rais_firm_`y'.dta",clear
 merge 1:1 identificad using "`W'/rais_aux/rais_mode_mun_ind.dta"
 keep if _merge==3
 replace municipio=modemun
 gen state=substr(municipio,1,2)
 keep identificad identificad_8 municipio firm_emp state
 save "`W'/rais_aux/unique_firms_`y'.dta",replace
}
display "WIDE DICTIONARY COMPLETE"
