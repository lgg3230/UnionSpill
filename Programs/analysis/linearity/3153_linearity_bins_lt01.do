* Wrapper: set globals then run 3152_linearity_bins.do with the baseline group
* set to establishments with raw connectivity totaltreat_pw_n < 0.01 (the
* "<= 1% connectivity" control cut used in 3012 Panel B, here strict). The
* connectivity groups (median, terciles, quartiles) split the establishments
* at or above 0.01. Outputs carry the suffix _lt01.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/linearity"
global graphs    "$main/UnionSpill/Graphs/linearity"
global logs      "$main/UnionSpill/Logs/linearity"
global programs  "$main/UnionSpill/Programs"

global base_lt    "0.01"
global out_suffix "_lt01"

do "$programs/analysis/linearity/3152_linearity_bins.do"
