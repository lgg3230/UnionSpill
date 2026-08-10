* Standalone: rebuild entry_exit_panel.dta and re-run regressions.
* Run after swapping lr_remdezr_h_w source to rais_firm files.

version 17.0
set more off

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global programs  "$main/UnionSpill/Programs"
global tables    "$main/UnionSpill/Tables/entry_exit"
global graphs    "$main/UnionSpill/Graphs/entry_exit"
global logs      "$main/UnionSpill/Logs/entry_exit"

local d : display %tdCYND date("`c(current_date)'","DMY")

di "=== Stage 4: prep_entry_exit_data ==="
log using "$logs/prep_entry_exit_`d'.log", replace text
do "$programs/entry_exit/prep_entry_exit_data.do"
log close

di "=== Stage 5: results_entry_exit ==="
do "$programs/entry_exit/results_entry_exit.do"

di "=== Stage 5b: generate LaTeX tables ==="
shell ~/.conda/envs/venv_python312/bin/python "$programs/entry_exit/generate_entry_exit_latex.py"

shell curl -s -o /dev/null -H "Title: Entry/exit done" -d "prep + results finished for `d'" https://ntfy.sh/lgg3230-kellogg

di "=== _run_prep_and_results.do done: `c(current_date)' `c(current_time)' ==="
