* Wrapper: 4082_turnover.do on the CURRENT-CONNECTIVITY overlay panel.
set more off
set varabbrev off

global main "/kellogg/proj/lgg3230"
global klc  "$main"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables/currentconn_full"
global graphs    "$main/UnionSpill/Graphs/currentconn_full"
global logs      "$main/UnionSpill/Logs/currentconn_full"
global programs  "$main/UnionSpill/Programs"

do "$programs/turnover/4082_turnover.do"
