* Wrapper: set globals then run Main_Results_turnover.do
set more off
set varabbrev off
clear all
macro drop _all
version 17.0

global klc  "/kellogg/proj/lgg3230"
global main "$klc"

global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global programs  "$main/UnionSpill/Programs"
global logs      "$main/UnionSpill/Logs"

do "$programs/Main_Results_turnover.do"
