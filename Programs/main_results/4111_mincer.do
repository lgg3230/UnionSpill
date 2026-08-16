* Run 4112_mincer.do with CURRENT connectivity and NATIONAL
* age-ONLY full-RAIS Mincer residuals (tenure removed from the residualization).
*
* Companion to _run_currentconn_mincer_ten_fullrais.do, which uses the
* age+tenure residuals. Firm tenure is plausibly an outcome of the reform, so
* this variant drops it from the Mincer projection and keeps only the quartic
* age polynomial within race x education x gender x year cells.
set more off
set varabbrev off

global klc      "/kellogg/proj/lgg3230"
global main     "$klc"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/currentconn_full"
global graphs    "$main/UnionSpill/Graphs/currentconn_full"
global logs      "$main/UnionSpill/Logs/currentconn_full"
global programs  "$main/UnionSpill/Programs"

cap mkdir "$tables/residuals"
cap mkdir "$graphs/residuals"
cap mkdir "$logs/residuals"

* NOTE on the "_rb" file. The pre-existing mincer_residuals_firm_year_age_fullrais.csv
* is NOT used here. It does not reproduce from Programs/residuals/fullrais/, and the
* deviation is numerical (median ~1e-6, 11 firm-years above 1e-3, max 3.0e-2 in 2011)
* rather than a specification difference. Reusing it would mean the age and age+tenure
* arms were computed by different code paths, confounding the very comparison this
* run exists to make. "_rb" is the rebuilt file from the reconstructed pipeline; the
* historical file is left untouched because other tables were produced from it.
global resid_csv_name "mincer_residuals_firm_year_age_fullrais_rb.csv"
global results_suffix "_currentconn_age_fullrais_rb"

do "$programs/residuals/4112_mincer.do"
