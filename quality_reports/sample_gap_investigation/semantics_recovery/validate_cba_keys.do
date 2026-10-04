clear all
set more off
version 17.0
use identificad_8 using "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/CBA/cba_firm_exploded.dta",clear
count if missing(identificad_8)
assert !missing(identificad_8)
display "FIRM CBA ROOTS ALL NONMISSING"
