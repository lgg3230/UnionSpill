* Run 4112_mincer.do with CURRENT connectivity and NATIONAL
* age+tenure full-RAIS Mincer residuals.
set more off
set varabbrev off

global klc      "/kellogg/proj/lgg3230"
global main     "$klc"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables/currentconn_full"
global graphs    "$main/UnionSpill/Graphs/currentconn_full"
global logs      "$main/UnionSpill/Logs/currentconn_full"
global programs  "$main/UnionSpill/Programs"

cap mkdir "$tables/residuals"
cap mkdir "$graphs/residuals"
cap mkdir "$logs/residuals"

global resid_csv_name "mincer_residuals_firm_year_ten_fullrais.csv"
global results_suffix "_currentconn_ten_fullrais"

do "$programs/residuals/4112_mincer.do"
