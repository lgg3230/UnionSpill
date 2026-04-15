********************************************************************************
* _run_exit.do
* PURPOSE:  Cluster wrapper for the standalone firm survival (exit) pipeline.
*           Sets paths, runs results_exit.do, generates the LaTeX table,
*           and sends a push notification when done.
*
* To run on Mac instead: open Stata, cd to the project root, and run
*   do Programs/exit/results_exit.do
* No other file or global is needed.
********************************************************************************

version 17.0

* ── Cluster paths ─────────────────────────────────────────────────────────────
global tables  "/kellogg/proj/lgg3230/UnionSpill/Tables/exit"
global graphs  "/kellogg/proj/lgg3230/UnionSpill/Graphs/exit"
global logs    "/kellogg/proj/lgg3230/UnionSpill/Logs/exit"
global data_in "/kellogg/proj/lgg3230/UnionSpill/Data/entry_exit/entry_exit_panel.dta"

* ── Log ──────────────────────────────────────────────────────────────────────
local d : display %tdCYND date("`c(current_date)'","DMY")
local t : display %tCHH_MM_SS clock("`c(current_time)'","hms")

cap log close
log using "$logs/run_exit_`d'_`t'.log", replace text

* ── Run regressions ──────────────────────────────────────────────────────────
do "/kellogg/proj/lgg3230/UnionSpill/Programs/exit/results_exit.do"

* ── LaTeX table ──────────────────────────────────────────────────────────────
shell ~/.conda/envs/venv_python312/bin/python ///
    "/kellogg/proj/lgg3230/UnionSpill/Programs/exit/generate_exit_latex.py"

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "Exit pipeline done" "_run_exit.do completed for `d'"
