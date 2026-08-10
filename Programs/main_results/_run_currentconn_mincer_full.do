* Run 4112_mincer.do with CURRENT connectivity and the DEFAULT Mincer
* residuals (mincer_residuals_firm_year.csv), writing the _currentconn_full
* suffix.
*
* Created 2026-08-01. This is the arm that feeds the Replication document's
* "Effects on Residualized Wages" tables -- its spillover estimates (0.0050 raw,
* 0.0046 residualized) are the ones printed there. Companions
* 4111_mincer.do and _run_currentconn_mincer_ten_fullrais.do
* already existed; this one did not, even though its CSVs were in the tree.

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

global resid_csv_name "mincer_residuals_firm_year.csv"
global results_suffix "_currentconn_full"

do "$programs/residuals/4112_mincer.do"
