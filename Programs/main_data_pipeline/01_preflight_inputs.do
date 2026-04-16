********************************************************************************
* MAIN DATA PIPELINE PREFLIGHT
*
* Non-destructive checks for files used by the main data pipeline. This is not a
* full dependency graph yet; it records the files currently known to matter.
********************************************************************************

version 17.0
set more off
clear all

global klc "/kellogg/proj/lgg3230"
global project "$klc/UnionSpill"
global data "$project/Data"
global programs "$project/Programs"
global rais_raw_dir "$klc/RAIS/output/data/full"
global rais_aux "$data/RAIS_aux"
global rais_firm "$data/CBA_RAIS_firm_level"
global cba_dir "$data/CBA"
global ibge "$data/IBGE"

global preflight_missing 0

program define check_file
    args path label
    capture confirm file "`path'"
    if _rc {
        di as error "MISSING: `label'"
        di as error "        `path'"
        global preflight_missing = $preflight_missing + 1
    }
    else {
        di as result "OK: `label'"
    }
end

di as text "Checking protected/current analysis files..."
check_file "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta" "protected main analysis dataset"
check_file "$rais_aux/totalflows_wide_2007_2011.csv" "totalflows wide controls"

di as text _newline "Checking known missing/upstream link..."
check_file "$rais_firm/lagos_sample_sep24_pct_unionexp.dta" "upstream union-exposure sample used by 121_get_wage_pctiles_df2.do"

di as text _newline "Checking core construction inputs..."
check_file "$cba_dir/cnes_contracts_coverage_updated.dta" "raw/current CBA coverage file"
check_file "$ibge/mun_microregion_ibge.dta" "IBGE municipality-to-microregion crosswalk"

di as text _newline "Checking core construction scripts..."
check_file "$programs/031_clean_cba.do" "CBA cleaning script"
check_file "$programs/041_merge_cba_rais.do" "RAIS-CBA merge script"
check_file "$programs/05_yearly_employers.do" "connectivity construction script"
check_file "$programs/union_treat_exp.do" "union exposure script"
check_file "$programs/121_get_wage_pctiles_df2.do" "wage percentile merge script"

di as text _newline "Checking RAIS firm-year outputs used downstream..."
forvalues y = 2007/2016 {
    check_file "$rais_firm/rais_firm_`y'.dta" "RAIS firm-year `y'"
}

di as text _newline "Checking raw RAIS yearly files..."
forvalues y = 2007/2016 {
    check_file "$rais_raw_dir/RAIS_`y'.dta" "raw RAIS `y'"
}

di as text _newline "Preflight complete. Missing count: $preflight_missing"
if $preflight_missing > 0 {
    exit 9
}
