clear all
set more off
version 17.0
local O "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/semantics_recovery"
forvalues y=2009/2011 {
 use identificad municipio using "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/worker_estab_`y'.dta",clear
 gen long workers=1
 collapse (sum) workers,by(identificad municipio)
 save "`O'/worker_municipality_counts_`y'.dta",replace
}
* Deflators below were extracted from the 1010 local ipca list (year minus 2006).
forvalues y=2012/2016 {
 use identificad PIS municipio horascontr remdezr tempempr empem3112 using "/kellogg/proj/lgg3230/RAIS/output/data/full/RAIS_`y'.dta",clear
 if `y'==2012 local deflator=0.80176356558955
 if `y'==2013 local deflator=0.849153270408197
 if `y'==2014 local deflator=0.903562518222102
 if `y'==2015 local deflator=1
 if `y'==2016 local deflator=1.06287988213221
 gen empdec_lagos=empem3112*(tempempr>1)
 gen remdezr_h=remdezr/(horascontr*4.348)
 gen lr_remdezr_h=.
 replace lr_remdezr_h=log(remdezr_h/`deflator')
 bysort identificad PIS: egen max_hours=max(horascontr)
 gen rank1=(horascontr==max_hours & empdec_lagos==1)
 bysort identificad PIS: egen max_wage=max(lr_remdezr_h*rank1)
 gen rank2=(lr_remdezr_h==max_wage & rank1==1)
 * Count every ambiguous geographical tie BEFORE choosing any representative.
 bysort identificad PIS: egen minmun=min(cond(rank2==1,municipio,.))
 bysort identificad PIS: egen maxmun=max(cond(rank2==1,municipio,.))
 bysort identificad PIS: egen missingmun=max(rank2==1 & missing(municipio))
 gen byte ambiguous=(minmun!=maxmun | (missingmun==1 & !missing(minmun)))
 preserve
 keep if rank2==1 & ambiguous==1
 save "`O'/ambiguous_rank2_spells_`y'.dta",replace
 restore
 keep if rank2==1
 * When all candidate spells share municipality, this is exactly the same vote
 * under any random ordering. Ambiguous cases are retained separately for bounds.
 sort identificad PIS municipio
 by identificad PIS: keep if _n==1
 gen long workers=1
 gen long ambiguous_workers=ambiguous
 collapse (sum) workers ambiguous_workers,by(identificad municipio)
 save "`O'/worker_municipality_counts_`y'.dta",replace
 display "COUNTS YEAR COMPLETE `y'"
}
display "FULL WORKER COUNTS COMPLETE"
