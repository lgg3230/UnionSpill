clear all
set more off
version 17.0
local R "/gpfs/kellogg/proj/lgg3230/UnionSpill"
use "`R'/archive/Data/baseline_2026-09-06/legacy_cba/cba_firm_exploded.dta",clear
sort pair_id contract_id codigo_municipio clean_asso_cnpj identificad_8 start_year file_year
tempfile historical
save `historical'
use "`R'/Data/CBA/cba_firm_exploded.dta",clear
sort pair_id contract_id codigo_municipio clean_asso_cnpj identificad_8 start_year file_year
cf _all using `historical',all
display "FULL HISTORICAL CBA INPUT EQUIVALENCE COMPLETE"
