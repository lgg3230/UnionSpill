clear all
set more off
version 17.0
use "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/semantics_recovery/raw_spells_2009.dta",clear
gen long raw_order=_n
gen empdec_lagos=empem3112*(tempempr>1)
gen remdezr_h=remdezr/(horascontr*4.348)
gen lr_remdezr_h=.
replace lr_remdezr_h=log(remdezr_h/0.671594887351247)
bys identificad PIS: egen max_hours=max(horascontr)
gen rank1=(horascontr==max_hours & empdec_lagos==1)
bys identificad PIS: egen max_wage=max(lr_remdezr_h*rank1)
gen rank2=(lr_remdezr_h==max_wage & rank1==1)
bys identificad PIS: egen minmun=min(cond(rank2==1,municipio,.))
bys identificad PIS: egen maxmun=max(cond(rank2==1,municipio,.))
bys identificad PIS: egen nm=max(rank2==1 & missing(municipio))
gen byte ambiguous=minmun!=maxmun | (nm==1 & !missing(minmun))
gen byte missing_tenure_included=empdec_lagos==1 & missing(tempempr)
gen byte missing_wage_rank2=rank2==1 & missing(lr_remdezr_h)
gen byte missing_hours_rank2=rank2==1 & missing(horascontr)
bys identificad PIS: egen has_active=max(empdec_lagos==1)
bys identificad PIS: egen has_rank1=max(rank1)
bys identificad PIS: egen has_rank2=max(rank2)
egen tag=tag(identificad PIS)
gen byte active_but_no_rank1=tag==1 & has_active==1 & has_rank1==0
gen byte rank1_but_no_rank2=tag==1 & has_rank1==1 & has_rank2==0
count if missing_tenure_included
count if missing_wage_rank2
count if missing_hours_rank2
count if active_but_no_rank1
count if rank1_but_no_rank2
count if ambiguous==1 & tag==1
preserve
collapse (sum) missing_tenure_included missing_wage_rank2 missing_hours_rank2 active_but_no_rank1 rank1_but_no_rank2 (max) ambiguous,by(identificad)
export delimited using "actual_2009_semantic_flags_by_establishment.csv",replace
restore
sort identificad PIS municipio raw_order
set seed 12345
gen random=runiform() if rank2==1
bys identificad PIS: egen maxrandom=max(random*rank2)
gen byte selected1=random==maxrandom & rank2==1
preserve
keep if selected1==1
keep identificad PIS municipio
rename municipio municipality_order1
tempfile selected
save `selected'
restore
drop random maxrandom
gsort identificad PIS -municipio raw_order
set seed 12345
gen random=runiform() if rank2==1
bys identificad PIS: egen maxrandom=max(random*rank2)
keep if random==maxrandom & rank2==1
keep identificad PIS municipio
merge 1:1 identificad PIS using `selected'
assert _merge==3
count if municipio!=municipality_order1
keep if municipio!=municipality_order1
export delimited using "actual_2009_sort_sensitive_municipalities.csv",replace
display "ACTUAL SPELL PROFILES COMPLETE"
