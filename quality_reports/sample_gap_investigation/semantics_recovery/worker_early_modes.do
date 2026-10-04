clear all
set more off
version 17.0
forvalues y=2007/2008 {
 use identificad municipio using "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/worker_estab_`y'.dta",clear
 gen long workers=1
 collapse (sum) workers,by(identificad municipio)
 bys identificad: egen maxcount=max(workers)
 gen byte is_mode=(workers==maxcount & !missing(municipio))
 bys identificad: egen n_modes=total(is_mode)
 bys identificad: egen selected_mode=min(cond(is_mode,municipio,.))
 save "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/semantics_recovery/worker_municipality_counts_`y'.dta",replace
 keep identificad selected_mode n_modes
 duplicates drop
 save "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/semantics_recovery/worker_municipality_modes_`y'.dta",replace
}
display "EARLY MODES COMPLETE"
