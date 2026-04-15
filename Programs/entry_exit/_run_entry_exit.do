********************************************************************************
* PROJECT: UNION SPILLOVERS — ENTRY/EXIT PIPELINE WRAPPER
* AUTHOR: LUIS GOMES
*
* Runs the full entry/exit pipeline in sequence.
* Set flags to 1 to run each stage.
*
* STAGE 1 — 041_merge_cba_rais_unbal.do
*   Merges CBA + RAIS without pos_emp restriction.
*   Exports entry_exit_treat.csv for MATLAB.
*
* STAGE 2 — connectivity_treat_unbal.m  (MATLAB — run separately or via shell)
*   Reads entry_exit_treat.csv + employers_yyyy_yyyy.csv.
*   Outputs connectivity_treat_unbal_2007_2011.csv.
*
* STAGE 3 — 05_employers_unbal.do
*   Aggregates connectivity, merges to unbalanced firm panel.
*   Outputs cba_rais_firm_unbal_flows.dta.
*
* STAGE 4 — prep_entry_exit_data.do
*   Merges CBA vars from main dataset onto unbalanced panel.
*   Resolves microregion/industry1 for exiting firms not in balanced sample.
*   Creates presence indicators, expands to all firm×year cells.
*   Outputs Data/entry_exit/entry_exit_panel.dta.
*
* STAGE 5 — results_entry_exit.do
*   Runs direct and spillover effects for two samples:
*     (1) Full unbalanced panel
*     (2) Firms present in all pretreatment years (2009-2011)
*   Outputs CSVs to Tables/entry_exit/; event-study PDFs to Graphs/entry_exit/.
********************************************************************************

// DIRECTORIES — must match 00_master.do globals
// (source this file from master, or set globals here before running standalone)

global main    "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global programs  "$main/UnionSpill/Programs"
global tables  "$main/UnionSpill/Tables/entry_exit"
global graphs  "$main/UnionSpill/Graphs/entry_exit"
global logs    "$main/UnionSpill/Logs/entry_exit"

local d : display %tdCYND date("`c(current_date)'","DMY")

// ── Stage flags ───────────────────────────────────────────────────────────────

local run_041    = 0   // set to 1 to re-run CBA+RAIS merge
local run_matlab = 0   // set to 1 to re-run MATLAB connectivity
local run_05     = 0   // set to 1 to re-run connectivity aggregation
local run_prep   = 0   // prep_entry_exit_data.do (panel already built)
local run_results = 1  // results_entry_exit.do

// ── Stage 1: Merge CBA + RAIS (unbalanced) ───────────────────────────────────

if `run_041' {
    log using "$logs/041_merge_unbal_`d'.log", replace text
    do "$programs/entry_exit/041_merge_cba_rais_unbal.do"
    log close
}

// ── Stage 2: MATLAB connectivity ─────────────────────────────────────────────

if `run_matlab' {
    shell "/software/matlab/R2020b/bin/matlab" -nojvm ///
        < "/kellogg/proj/lgg3230/UnionSpill/Programs/entry_exit/connectivity_treat_unbal.m"
}

// ── Stage 3: Aggregate connectivity + build analysis dataset ─────────────────

if `run_05' {
    log using "$logs/05_employers_unbal_`d'.log", replace text
    do "$programs/entry_exit/05_employers_unbal.do"
    log close
}

// ── Stage 4: Prep analysis dataset ───────────────────────────────────────────

if `run_prep' {
    log using "$logs/prep_entry_exit_`d'.log", replace text
    do "$programs/entry_exit/prep_entry_exit_data.do"
    log close
}

// ── Stage 5: Regressions ─────────────────────────────────────────────────────

if `run_results' {
    do "$programs/entry_exit/results_entry_exit.do"
}

// ── Stage 6: LaTeX tables ─────────────────────────────────────────────────────

if `run_results' {
    shell ~/.conda/envs/venv_python312/bin/python ///
        "$programs/entry_exit/generate_entry_exit_latex.py"
}

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Entry/exit pipeline done" "Stages 4-6 completed for `d'"
