********************************************************************************
* MAIN DATA PIPELINE WRAPPER
*
* This is the organized reconstruction runner for the main analysis dataset.
* All stages are off by default. Turn stages on deliberately below.
*
* The protected reference dataset is not overwritten by this runner.
********************************************************************************

version 17.0
set more off
set varabbrev off
clear all
macro drop _all

********************************************************************************
* Paths
********************************************************************************

global klc "/kellogg/proj/lgg3230"
global project "$klc/UnionSpill"
global data "$project/Data"
global programs "$project/Programs"
global pipeline "$programs/main_data_pipeline"

global rais_raw_dir "$klc/RAIS/output/data/full"
global emp_assoc "$data/stata_emp_assoc"
global cba_dir "$data/CBA"
global cba_rais_fir "$data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "$data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "$data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "$data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "$data/CBA_RAIS/cba_rais_total"
global rais_aux "$data/RAIS_aux"
global rais_firm "$data/CBA_RAIS_firm_level"
global ibge "$data/IBGE"
global tables "$project/Tables"
global graphs "$project/Graphs"
global logs "$project/Logs"

global protected_main_data "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"

********************************************************************************
* Stage Toggles
********************************************************************************

local run_rais_firm        = 0
local run_emp_assoc        = 0
local run_cba_clean        = 0
local run_merge_cba_rais   = 0
local run_connectivity     = 0

di as text "Main data reconstruction runner"
di as text "All stages are off by default."
capture confirm file "$protected_main_data"
if !_rc di as result "Protected reference exists; this runner does not overwrite it."

********************************************************************************
* Stages
********************************************************************************

if `run_rais_firm' == 1 {
    di as result "Stage 1: RAIS firm-year construction"
    do "$pipeline/10_011_rais_to_firm.do"
}

if `run_emp_assoc' == 1 {
    di as result "Stage 2: Employer association cleaning"
    do "$pipeline/20_02_clean_emp_assoc.do"
}

if `run_cba_clean' == 1 {
    di as result "Stage 3: CBA cleaning and establishment matching"
    do "$pipeline/30_031_clean_cba.do"
}

if `run_merge_cba_rais' == 1 {
    di as result "Stage 4: Merge RAIS and CBA, define samples"
    do "$pipeline/40_041_merge_cba_rais.do"
}

if `run_connectivity' == 1 {
    di as result "Stage 5: Worker-flow and connectivity construction"
    di as text "Warning: not yet confirmed to reproduce the protected connectivity measure exactly."
    do "$pipeline/50_05_yearly_employers.do"
}

di as result "Main data reconstruction runner finished."
