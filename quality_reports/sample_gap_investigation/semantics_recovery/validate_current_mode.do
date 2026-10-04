clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
local S "`R'/Data/sample_gap_investigation/semantics_recovery"
use identificad municipio workers using "`S'/worker_municipality_counts_2009.dta",clear
forvalues y=2010/2016 {
 append using "`S'/worker_municipality_counts_`y'.dta"
}
replace ambiguous_workers=0 if missing(ambiguous_workers)
collapse (sum) workers ambiguous_workers,by(identificad municipio)
gen byte nonmissing_mun=!missing(municipio)
replace workers=0 if missing(municipio)
bys identificad: egen total_ambiguous=total(ambiguous_workers)
gen fixed_votes=workers-ambiguous_workers
gsort identificad -nonmissing_mun -workers municipio
by identificad: gen runner_votes=workers[2]
replace runner_votes=0 if missing(runner_votes)
by identificad: keep if _n==1
gen byte robust=(total_ambiguous==0 | fixed_votes>runner_votes+total_ambiguous)
rename municipio reconstructed_mode
merge 1:1 identificad using "`R'/Data/RAIS_aux/rais_mode_mun_ind.dta",keepusing(modemun)
destring modemun,gen(observed_mode)
gen byte agrees=reconstructed_mode==observed_mode & _merge==3
tab agrees robust,missing
count if !agrees & robust
assert r(N)==0
preserve
keep if !agrees | !robust
export delimited using "current_mode_validation_exceptions.csv",replace
restore
display "CURRENT MODE VALIDATION COMPLETE"
