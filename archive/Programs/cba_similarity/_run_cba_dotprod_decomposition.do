* Wrapper: set globals then run cba_dotprod_decomposition.do
set more off
set varabbrev off

if "`c(username)'" == "lgg3230" {
	global main "/kellogg/proj/lgg3230"
}
else if "`c(username)'" == "luisg" {
	global main "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster"
}
else {
	di as error "Unknown username: `c(username)'. Set global main manually."
	exit 1
}

global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

do "$programs/cba_similarity/cba_dotprod_decomposition.do"
