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
********************************************************************************

// DIRECTORIES — must match 00_master.do globals
// (source this file from master, or set globals here before running standalone)

global tables "$main/UnionSpill/Tables/entry_exit"
global graphs "$main/UnionSpill/Graphs/entry_exit"
global logs   "$main/UnionSpill/Logs/entry_exit"

local d : display %tdCYND date("`c(current_date)'","DMY")

// ── Stage flags ───────────────────────────────────────────────────────────────

local run_041   = 1
local run_matlab = 1   // set to 0 if MATLAB already run
local run_05    = 1

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

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Entry/exit pipeline done" "Stages completed for `d'"
