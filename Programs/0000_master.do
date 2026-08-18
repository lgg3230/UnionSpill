********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MASTER DO FILE
*
* Single control surface for the whole replication chain, raw RAIS -> the
* exhibits in UnionSpill-paper/Draft.tex. Stages are grouped into six tiers and
* every stage is off by default; set its flag to 1 to run it.
*
*   TIER A  1010-1050  raw RAIS -> firm panel + connectivity  (Stata + MATLAB)
*   TIER B  2010-2050  firm panel -> analysis panel          (Stata)
*   TIER C  3011-3132  analysis panel -> estimates           (13 estimators)
*   TIER D  4010-4220  estimates -> tables and figures       (Python + Stata)
*   TIER E  5010       exhibits -> UnionSpill-paper/Replication/Figures
*
* NUMBERING IS DEPENDENCY ORDER. No script reads a file written by a
* higher-numbered script. Scripts with no dependency between them are ordered for
* readability. The old tier C (currentconn overlay) is retired, so what were tiers
* D, E and F are now C, D and E; see Docs/pipeline/RENUMBERING_2026-08-16.md for
* the full old -> new map.
*
* WHY TIER D SHELLS OUT INSTEAD OF USING `do`
*   reghdfe carries session state: running two exercises in one Stata process
*   shifts coefficients in the sixth digit, and `clear all` does not reset it.
*   Each estimator therefore gets a fresh stata-mp process via `shell`. Do not
*   "simplify" these into plain `do` calls.
*
* TIER B IS NO LONGER FENCED
*   It used to be: 2030 needed two datasets absent from disk and written by no
*   script (sample_provenance.md H2). Both turned out to be derivable rather
*   than lost -- lagos_sample_sep24_pct_unionexp.dta is the percentile panel
*   2020 writes itself joined to union_treat_exp_sep24.dta on mode_union (2040),
*   and worker_year_pre_new_vs_nonnew_dec26.dta is a _w rename of the panel 2010
*   builds (2050). The analysis panel is now built from 1050/1060 output.
*
* TIER A IS NOW ONE PASS OVER RAW RAIS
*   1010 replaces the old 1010 + 1060: it cleans, selects one spell per
*   worker-firm and then branches, writing both the firm panel and the worker
*   panel. 1040 reads that worker panel instead of opening the raw files a third
*   time. Raw RAIS is therefore read once rather than three times.
********************************************************************************

// PRELIMINAIRES

set more off
set varabbrev off
clear all
macro drop _all
version 17.0

// DIRECTORIES

// Main:

global klc "/kellogg/proj/lgg3230"
global luis "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"

if "`c(username)'"=="luisg"{
	global main "$luis"
}

if "`c(username)'"=="lgg3230"{
	global main "$klc"
}

// Subfolders:


global rais_raw_dir "$main/RAIS/output/data/full"
global emp_assoc "$main/UnionSpill/Data/stata_emp_assoc"
global rais_emp_merge "$main/UnionSpill/Data/RAIS_emp_merge"
global cba_dir "$main/UnionSpill/Data/CBA"
global cba_rais_fir "$main/UnionSpill/Data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "$main/UnionSpill/Data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "$main/UnionSpill/Data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "$main/UnionSpill/Data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "$main/UnionSpill/Data/CBA_RAIS/cba_rais_total"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global ibge "$main/UnionSpill/Data/IBGE"

global programs "$main/UnionSpill/Programs"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"
global logs "$main/UnionSpill/Logs"

* Batch logs. `stata-mp -b do X.do` writes X.log into the CURRENT directory, not
* next to the do-file, so every shelled call below runs from $logs. Programs/ is
* code only and must never accumulate logs. Enforced belt-and-braces by the
* Programs/**/*.log rule in .gitignore.

// Added for the full chain:

global paper             "$main/UnionSpill/UnionSpill-paper"
global paperfig          "$paper/Replication/Figures"
global stata_exe         "/software/Stata/stata17/stata-mp"
global matlab_exe        "/software/matlab/R2020b/bin/matlab"
global python_exe        "/home/lgg3230/.conda/envs/venv_python312/bin/python"

// CONTROL WHICH PROGRAMS RUN

* --- TIER A: raw RAIS -> firm panel + connectivity ---------------------------
local a_rais_clean       = 0      // 1010_rais_clean.do   -> rais_firm_*, worker_estab_*
local a_clean_cba        = 0      // 1020_clean_cba.do    (+1021/1022 exploders)
local a_merge_cba_rais   = 0      // 1030_merge_cba_rais.do
local a_flows            = 0      // 1040_yearly_employers.do, shells 1041-1045
local a_corr_turnover    = 0      // 1050_corrected_turnover.py

* --- TIER A SIDE-BRANCHES: inputs for specific tier-C estimators ---------------
* Restored from archive/ 2026-08-16. Each builds a Data/ artifact that a tier-C
* estimator consumes; without them the package is not replicable from raw data.
* Each is a sub-pipeline with its own internal order -- see its README.
local a_layers           = 0      // sample_construction/layers/ 2060-2078       -> Data/layer_connectivity/
local a_mincer_resid     = 0      // sample_construction/mincer_residuals/ 2080-2086 -> mincer_residuals_*.csv
local a_rand_inference   = 0      // sample_construction/rand_inference/ 2090-2106  -> permutation inputs

* --- TIER B: firm panel -> analysis panel ------------------------------------
local b_lagos_workers    = 0      // 2010_merge_lagos_worker.do
local b_wage_pctiles     = 0      // 2020_get_wage_pctiles.do
local b_pct_unionexp     = 0      // 2030_build_pct_unionexp.do
local b_worker_panel_w   = 0      // 2040_build_worker_panel_w.do
local b_analysis_panel   = 0      // 2050_build_analysis_panel.do
local b_worker_pnl_lagos = 0      // 2051-2053 -> worker_panel_lagos.parquet

* --- TIER C: analysis panel -> estimates (one fresh Stata process each) ------
local c_pct_tfpw         = 0
local c_direct_coef_test = 0
local c_clause_types     = 0
local c_cba_value        = 0
local c_robustness       = 0
local c_micro_ind_q      = 0
local c_union_controls   = 0
local c_turnover         = 0
local c_composition      = 0
local c_descriptives     = 0
local c_mincer           = 0
local c_within_firm      = 0
local c_within_firm_hw   = 0

* --- TIER D: estimates -> tables and figures ---------------------------------
local d_tables           = 0      // the 9 table generators
local d_inline_repl      = 0      // 4100_inline_into_replication.py
local d_fig_bilateral    = 0
local d_fig_distros      = 0
local d_fig_binscatter   = 0
local d_fig_conn_hist    = 0
local d_fig_recentered   = 0      // both outcomes

* --- TIER E: exhibits -> paper ------------------------------------------------
local e_copy_figures     = 0
local e_copy_apply       = 0      // 0 = dry run (report diffs only), 1 = write

// RUN PROGRAMS

********************************************************************************
* TIER A -- raw RAIS to firm panel and connectivity
********************************************************************************

// Clean rais dataset, merge with employer association and collapse to firm level:

if (`a_rais_clean'      ==1) do "$programs/sample_construction/1010_rais_clean.do"
if (`a_clean_cba'       ==1) do "$programs/sample_construction/1020_clean_cba.do"
if (`a_merge_cba_rais'  ==1) do "$programs/sample_construction/1030_merge_cba_rais.do"
if (`a_flows'           ==1) do "$programs/sample_construction/1040_yearly_employers.do"
if (`a_corr_turnover'   ==1) shell cd "$logs" && $python_exe "$programs/analysis/turnover/1050_corrected_turnover.py"

********************************************************************************
* TIER A SIDE-BRANCHES
*
* Each is a numbered sub-pipeline, not a single script, so the master reports what
* to run rather than guessing an order that its own README already states. Run the
* steps in numeric order from the directory named below.
********************************************************************************

if (`a_layers' ==1) {
    di as error "Run Programs/sample_construction/layers/ 2060-2078 in order (see README.md)."
    di as text  "  builds Data/layer_connectivity/, consumed by analysis/layer_connectivity/07_within_firm/3121,3131"
}
if (`a_mincer_resid' ==1) {
    di as error "Run Programs/sample_construction/mincer_residuals/ 2080-2086 (see README.md)."
    di as text  "  published path is 2085_residualize_fullrais.py -> mincer_residuals_firm_year_age_fullrais_rb.csv"
    di as text  "  2084 builds the fullrais panel; recovered from orphaned git objects 2026-08-16"
}
if (`a_rand_inference' ==1) {
    di as error "Run Programs/sample_construction/rand_inference/ 2090-2106 in order (see README.md)."
    di as text  "  builds the permutation inputs behind analysis/rand_inference/4130,4151,4152"
}

********************************************************************************
* TIER B -- analysis panel
*
* Numeric order IS execution order after the 2026-08-16 renumbering. 2020 runs
* with stop_after_pct: its tail would need pct_unionexp, which 2030 derives from
* 2020's own output, and that tail's product
* (lagos_sample_sep24_pct_unionexp_ext.dta) is read by nothing in Programs/.
* Stopping after the percentiles keeps the chain acyclic and loses no artifact.
********************************************************************************

if (`b_lagos_workers' ==1) do "$programs/sample_construction/2010_merge_lagos_worker.do"

if (`b_wage_pctiles' ==1) {
    global stop_after_pct "1"
    do "$programs/sample_construction/2020_get_wage_pctiles.do"
    global stop_after_pct ""
}

if (`b_pct_unionexp'   ==1) do "$programs/sample_construction/2030_build_pct_unionexp.do"
if (`b_worker_panel_w' ==1) do "$programs/sample_construction/2040_build_worker_panel_w.do"
if (`b_analysis_panel' ==1) do "$programs/sample_construction/2050_build_analysis_panel.do"

* worker_panel_lagos.parquet: read by 2061, 2080 and 2081. The builder existed all
* along as Programs/011c_worker_panel.py; it was archived by cd49461 and restored
* here on 2026-08-16. 2051 writes the panel, 2052 and 2053 add the bin columns in
* place. See Docs/pipeline/TIER_A_DEFECTS.md A10.
if (`b_worker_pnl_lagos' ==1) {
    shell cd "$logs" && $python_exe "$programs/sample_construction/2051_worker_panel_lagos.py"
    shell cd "$logs" && $python_exe "$programs/sample_construction/2052_worker_panel_bins.py"
    shell cd "$logs" && $python_exe "$programs/sample_construction/2053_worker_panel_bins2.py"
}

********************************************************************************
* TIER C -- estimators, one fresh Stata process each (see header note)
********************************************************************************

if (`c_pct_tfpw'         ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/main_results/3011_pct_tfpw.do"
if (`c_direct_coef_test' ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/conn_margins/3021_direct_sample_coef_test.do"
if (`c_clause_types'     ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/clause_types/3031_clause_types.do"
if (`c_cba_value'        ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/cba_value/3041_cba_value.do"
if (`c_robustness'       ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/robustness/3051_robustness_bins.do"
if (`c_micro_ind_q'      ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/robustness/3061_micro_ind_q.do"
if (`c_union_controls'   ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/robustness/3071_union_controls.do"
if (`c_turnover'         ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/turnover/3081_turnover.do"
if (`c_composition'      ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/composition/3091_composition.do"
if (`c_descriptives'     ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/descriptives/3101_sample_descriptives.do"
if (`c_mincer'           ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/main_results/3111_mincer.do"
if (`c_within_firm'      ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/layer_connectivity/07_within_firm/3121_within_firm.do"
if (`c_within_firm_hw'   ==1) shell cd "$logs" && $stata_exe -b do "$programs/analysis/layer_connectivity/07_within_firm/3131_within_firm_hourly.do"

********************************************************************************
* TIER D -- tables and figures
********************************************************************************

if (`d_tables' ==1) {
    shell cd "$logs" && $python_exe "$programs/analysis/main_results/4010_table_direct.py"
    shell cd "$logs" && $python_exe "$programs/analysis/main_results/4020_table_spill.py"
    shell cd "$logs" && $python_exe "$programs/analysis/main_results/4030_table_twopanel.py"
    shell cd "$logs" && $python_exe "$programs/analysis/clause_types/4040_table_clause.py"
    shell cd "$logs" && $python_exe "$programs/analysis/robustness/4050_table_union.py"
    shell cd "$logs" && $python_exe "$programs/analysis/robustness/4060_table_rob_logwages.py"
    shell cd "$logs" && $python_exe "$programs/analysis/residuals/4070_table_resid.py"
    shell cd "$logs" && $python_exe "$programs/analysis/conn_descriptives/4080_table_pairwise_appendix.py"
    shell cd "$logs" && $python_exe "$programs/analysis/layer_connectivity/07_within_firm/4090_table_within_firm.py"
}

if (`d_inline_repl' ==1) {
    shell cd "$logs" && $python_exe "$programs/analysis/layer_connectivity/07_within_firm/4100_inline_into_replication.py"
}

if (`d_fig_bilateral'  ==1) shell cd "$logs" && $python_exe "$programs/analysis/conn_descriptives/4110_figure_bilateral_coefplot.py"
if (`d_fig_distros'    ==1) shell cd "$logs" && $python_exe "$programs/analysis/descriptives/4120_figure_distributions.py"
if (`d_fig_binscatter' ==1) shell cd "$logs" && $python_exe "$programs/analysis/rand_inference/4130_figure_binscatter.py"
if (`d_fig_conn_hist'  ==1) shell cd "$logs" && $python_exe "$programs/analysis/conn_descriptives/4140_figure_conn_hist.py"

* Both outcomes. Draft.tex cites the HOURLY pair; before 2026-08 the export
* filenames in 4152_recentered_eventstudy.do were hardcoded to the monthly
* outcome, so the hourly figures could not be produced at all.
if (`d_fig_recentered' ==1) {
    shell cd "$logs" && $stata_exe -b do "$programs/analysis/rand_inference/4151_recentered_eventstudy.do" lr_remdezr_w
    shell cd "$logs" && $stata_exe -b do "$programs/analysis/rand_inference/4151_recentered_eventstudy.do" lr_remdezr_h_w
}

********************************************************************************
* TIER E -- copy exhibits into the paper
*
* Replaces the undocumented hand-copy that populated
* UnionSpill-paper/Replication/Figures/. Source -> published-name map comes
* from Docs/pipeline/INVENTORY.md section C.
********************************************************************************

* Dry run by default: reports every file it would replace, with both md5s, and
* writes nothing. Set f_copy_apply = 1 only after reading that report.
if (`e_copy_figures' ==1 & `e_copy_apply' != 1) {
    shell cd "$logs" && $python_exe "$programs/analysis/main_results/5010_copy_figures_to_paper.py"
}
if (`e_copy_figures' ==1 & `e_copy_apply' == 1) {
    shell cd "$logs" && $python_exe "$programs/analysis/main_results/5010_copy_figures_to_paper.py" --apply
}

di as result _newline "0000_master.do finished."
