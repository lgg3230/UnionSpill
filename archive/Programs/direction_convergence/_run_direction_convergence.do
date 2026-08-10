* Wrapper: direction-of-convergence test (untreated → treated benchmark)
*
* Steps:
*   1. direction_convergence_prep.py   → direction_convergence_untreated.dta
*   2. direction_convergence_static.do → static_results.csv
*   3. direction_convergence_eventstudy.do → eventstudy_results.csv
*   4. generate_direction_convergence_latex.py → static-results LaTeX table
*   5. generate_direction_convergence_eventstudy_plots.py → 4 event-study PDFs

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

global rais_firm    "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux     "$main/UnionSpill/Data/RAIS_aux"
global dirconv_data "$main/UnionSpill/Data/direction_convergence"
global tables       "$main/UnionSpill/Tables"
global graphs       "$main/UnionSpill/Graphs"
global logs         "$main/UnionSpill/Logs"
global programs     "$main/UnionSpill/Programs"

* Step 1: prep — untreated focal
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/direction_convergence/direction_convergence_prep.py"

* Step 2: prep — treated focal (mirror)
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/direction_convergence/direction_convergence_treated_prep.py"

* Step 3: untreated-side static + event study
do "$programs/direction_convergence/direction_convergence_static.do"
do "$programs/direction_convergence/direction_convergence_eventstudy.do"

* Step 4: treated-side static + event study (mirror)
do "$programs/direction_convergence/direction_convergence_treated_static.do"
do "$programs/direction_convergence/direction_convergence_treated_eventstudy.do"

* Step 5: combined LaTeX (both sides side-by-side)
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/direction_convergence/generate_direction_convergence_latex.py"

* Step 6: combined event-study plots (both sides overlaid)
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/direction_convergence/generate_direction_convergence_eventstudy_plots.py"

di _newline "direction-of-convergence pipeline complete."
