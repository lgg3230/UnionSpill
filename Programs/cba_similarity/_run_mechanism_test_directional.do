* Wrapper: directional mechanism test (treated + untreated + pooled)
*
* Assumes mechanism_gaps.dta already exists from _run_mechanism_test.do.
* If not, run _run_mechanism_test.do first.
*
* Steps:
*   1. mechanism_gap_prep_untreated.py  → mechanism_gaps_untreated.dta
*   2. mechanism_test_untreated.do      → results_untreated_all.csv
*   3. mechanism_test_pooled.do         → results_pooled_all.csv
*   4. generate_mechanism_test_directional_latex.py → 4 .tex tables

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

* Step 1: mirror prep
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/cba_similarity/mechanism_gap_prep_untreated.py"

* Step 2: untreated regression
do "$programs/cba_similarity/mechanism_test_untreated.do"

* Step 3: pooled regression with triple interaction
do "$programs/cba_similarity/mechanism_test_pooled.do"

* Step 4: comparison LaTeX
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/cba_similarity/generate_mechanism_test_directional_latex.py"

di _newline "Directional mechanism test pipeline complete."
