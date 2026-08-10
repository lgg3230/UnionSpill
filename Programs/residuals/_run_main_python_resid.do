* Run 4112_mincer.do using PYTHON residuals
* Python residuals: mincer_residuals_firm_year_python.csv
set more off
set varabbrev off

global klc      "/kellogg/proj/lgg3230"
global main     "$klc"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

* Point to Python residuals and tag output files with "_python" suffix
global resid_csv_name "mincer_residuals_firm_year_python.csv"
global results_suffix "_python"

do "$programs/residuals/4112_mincer.do"
