********************************************************************************
* UNION SPILLOVERS - MAIN DATA PIPELINE RUNNER
*
* Purpose:
*   Organize the canonical data-construction stages for a replication-style
*   workflow. All stages are off by default. Turn stages on deliberately below.
*
* Important:
*   This runner treats lagos_sample_sep24_pct_unionexp_ext_df2.dta as a protected
*   reference file until its historical connectivity measure is exactly
*   reproducible. The wage-percentile stage will not overwrite it unless the
*   explicit override is set.
********************************************************************************

version 17.0
set more off
set varabbrev off
clear all
macro drop _all

********************************************************************************
* 0. Paths
********************************************************************************

global klc "/kellogg/proj/lgg3230"
global luis "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication_Mar 2"

if "`c(username)'" == "luisg" {
    global main "$luis"
}
else if "`c(username)'" == "lgg3230" {
    global main "$klc"
}
else {
    di as error "Unknown username: `c(username)'. Set global main manually."
    exit 198
}

global project    "$main/UnionSpill"
global programs   "$project/Programs"
global data       "$project/Data"
global rais_raw_dir "$main/RAIS/output/data/full"
global emp_assoc  "$data/stata_emp_assoc"
global cba_dir    "$data/CBA"
global cba_rais_tot "$data/CBA_RAIS/cba_rais_total"
global rais_aux   "$data/RAIS_aux"
global rais_firm  "$data/CBA_RAIS_firm_level"
global ibge       "$data/IBGE"
global tables     "$project/Tables"
global graphs     "$project/Graphs"
global logs       "$project/Logs"

global protected_main_data "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"

********************************************************************************
* 1. Stage Toggles
********************************************************************************

local run_rais_firm        = 0
local run_cba_clean        = 0
local run_merge_cba_rais   = 0
local run_connectivity     = 0
local run_union_exposure   = 0
local run_wage_percentiles = 0

* Keep this at 0 until the protected dataset can be reproduced exactly.
local allow_overwrite_protected = 0

********************************************************************************
* 2. Preflight
********************************************************************************

di as text "Main data pipeline runner"
di as text "Project: $project"
di as text "Protected reference path is set in global protected_main_data."

capture confirm file "$protected_main_data"
if !_rc {
    di as result "Protected reference exists and must not be overwritten accidentally."
}
else {
    di as error "Protected reference not found at expected path."
}

if `run_wage_percentiles' == 1 & `allow_overwrite_protected' == 0 {
    di as error "Refusing to run wage-percentile stage because it overwrites:"
    di as error "See global protected_main_data."
    di as error "Set local allow_overwrite_protected = 1 only after creating a backup or changing the output path."
    exit 459
}

********************************************************************************
* 3. Pipeline Stages
********************************************************************************

if `run_rais_firm' == 1 {
    di as result "Stage 1: RAIS firm-year construction"
    do "$programs/011_rais_to_firm.do"
}

if `run_cba_clean' == 1 {
    di as result "Stage 2: CBA cleaning and establishment matching"
    do "$programs/031_clean_cba.do"
}

if `run_merge_cba_rais' == 1 {
    di as result "Stage 3: Merge RAIS and CBA, define treatment samples"
    do "$programs/041_merge_cba_rais.do"
}

if `run_connectivity' == 1 {
    di as result "Stage 4: Worker-flow and connectivity construction"
    di as text "Warning: this stage is not yet confirmed to reproduce the protected connectivity measure exactly."
    do "$programs/05_yearly_employers.do"
}

if `run_union_exposure' == 1 {
    di as result "Stage 5: Union treatment exposure"
    do "$programs/union_treat_exp.do"
}

if `run_wage_percentiles' == 1 {
    di as result "Stage 6: Worker wage percentiles merged to firm-year data"
    do "$programs/121_get_wage_pctiles_df2.do"
}

di as result "Pipeline runner finished."
