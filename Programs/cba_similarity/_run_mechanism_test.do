* Wrapper: run mechanism gap prep then mechanism_test.do
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

* Step 1: compute gap and surplus per treated firm × clause type
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/cba_similarity/mechanism_gap_prep.py"

* Step 2: reshape + regress
do "$programs/cba_similarity/mechanism_test.do"
