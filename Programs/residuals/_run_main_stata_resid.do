* Run 4112_mincer.do using STATA residuals
* Stata residuals: mincer_residuals_firm_year.csv (already in rais_firm)
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

* Stata residuals are already at the expected path:
* $rais_firm/mincer_residuals_firm_year.csv
global resid_csv_name "mincer_residuals_firm_year.csv"
global results_suffix ""

do "$programs/residuals/4112_mincer.do"
