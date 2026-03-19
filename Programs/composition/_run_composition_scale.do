* Wrapper: set globals then run Main_Results_composition_scale.do
set more off
set varabbrev off

global main "/kellogg/proj/lgg3230"
global klc  "$main"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

do "$programs/composition/Main_Results_composition_scale.do"
