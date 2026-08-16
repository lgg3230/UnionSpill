********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MASTER DO FILE
*
* Single control surface for the whole replication chain, raw RAIS -> the
* exhibits in UnionSpill-paper/Draft.tex. Stages are grouped into six tiers and
* every stage is off by default; set its flag to 1 to run it.
*
*   TIER A  raw RAIS -> firm panel + connectivity          (Stata + MATLAB)
*   TIER B  firm panel -> analysis panel                    (Stata)
*   TIER D  analysis panel -> estimates                     (13 estimators)
*   TIER E  estimates -> tables and figures                (Python + Stata)
*   TIER F  exhibits -> UnionSpill-paper/Replication/Figures
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
* TIER C IS RETIRED
*   3010/3020 built a current-connectivity overlay onto the frozen panel,
*   because that panel shipped a stale totaltreat_pw_n. A panel rebuilt from
*   1050 carries the current measure natively -- verified 0 differing rows of
*   140,773 against the overlay -- so there is nothing left to overlay. Both
*   scripts are in archive/Programs/main_results/, and the pre-existing frozen
*   panel and overlay directory are preserved under archive/Data/ as comparison
*   baselines.
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

// Added for the full chain:

global paper             "$main/UnionSpill/UnionSpill-paper"
global paperfig          "$paper/Replication/Figures"
global stata_exe         "/software/Stata/stata17/stata-mp"
global matlab_exe        "/software/matlab/R2020b/bin/matlab"
global python_exe        "/home/lgg3230/.conda/envs/venv_python312/bin/python"

// CONTROL WHICH PROGRAMS RUN

* --- TIER A: raw RAIS -> firm panel + connectivity ---------------------------
local a_rais_to_firm     = 0
local a_clean_emp_assoc  = 0
local a_clean_cba        = 0
local a_merge_cba_rais   = 0
local a_flows            = 0      // 1050_yearly_employers.do, shells MATLAB
local a_worker_panel     = 0      // 1060_rais_worker_panel.do -> worker_estab_*

* --- TIER B: firm panel -> analysis panel ------------------------------------
local b_lagos_workers    = 0      // 2010_merge_lagos_worker.do
local b_wage_pctiles     = 0      // 2020_get_wage_pctiles.do  (set stop_after_pct)
local b_pct_unionexp     = 0      // 2040_build_pct_unionexp.do
local b_worker_panel_w   = 0      // 2050_build_worker_panel_w.do
local b_analysis_panel   = 0      // 2030_get_wage_pctiles_df2.do

* --- TIER D: analysis panel -> estimates (one fresh Stata process each) -------------
local d_pct_tfpw         = 0
local d_direct_coef_test = 0
local d_clause_types     = 0
local d_cba_value        = 0
local d_robustness       = 0
local d_micro_ind_q      = 0
local d_union_controls   = 0
local d_turnover         = 0
local d_composition      = 0
local d_descriptives     = 0
local d_mincer           = 0
local d_within_firm      = 0
local d_within_firm_hw   = 0

* --- TIER E: estimates -> tables and figures ---------------------------------
local e_tables           = 0      // the 9 table generators
local e_inline_repl      = 0      // 5100_inline_into_replication.py
local e_fig_bilateral    = 0
local e_fig_distros      = 0
local e_fig_binscatter   = 0
local e_fig_conn_hist    = 0
local e_fig_recentered   = 0      // both outcomes

* --- TIER F: exhibits -> paper ------------------------------------------------
local f_copy_figures     = 0
local f_copy_apply       = 0      // 0 = dry run (report diffs only), 1 = write

// RUN PROGRAMS

********************************************************************************
* TIER A -- raw RAIS to firm panel and connectivity
********************************************************************************

// Clean rais dataset, merge with employer association and collapse to firm level:

if (`a_rais_to_firm'    ==1) do "$programs/1010_rais_to_firm.do"
if (`a_clean_emp_assoc' ==1) do "$programs/1020_clean_emp_assoc.do"
if (`a_clean_cba'       ==1) do "$programs/1030_clean_cba.do"
if (`a_merge_cba_rais'  ==1) do "$programs/1040_merge_cba_rais.do"
if (`a_flows'           ==1) do "$programs/1050_yearly_employers.do"
if (`a_worker_panel'    ==1) do "$programs/1060_rais_worker_panel.do"

********************************************************************************
* TIER B -- analysis panel
*
* Order matters and is not the numeric order. 2020 must stop after writing
* lagos_sample_sep24_pct.dta, because its tail needs pct_unionexp -- which 2040
* derives from that very file. Hence stop_after_pct, then 2040, then 2030.
********************************************************************************

if (`b_lagos_workers' ==1) do "$programs/2010_merge_lagos_worker.do"

if (`b_wage_pctiles' ==1) {
    global stop_after_pct "1"
    do "$programs/2020_get_wage_pctiles.do"
    global stop_after_pct ""
}

if (`b_pct_unionexp'   ==1) do "$programs/2040_build_pct_unionexp.do"
if (`b_worker_panel_w' ==1) do "$programs/2050_build_worker_panel_w.do"
if (`b_analysis_panel' ==1) do "$programs/2030_get_wage_pctiles_df2.do"

********************************************************************************
* TIER D -- estimators, one fresh Stata process each (see header note)
********************************************************************************

if (`d_pct_tfpw'         ==1) shell $stata_exe -b do "$programs/4011_pct_tfpw.do"
if (`d_direct_coef_test' ==1) shell $stata_exe -b do "$programs/conn_margins/4021_direct_sample_coef_test.do"
if (`d_clause_types'     ==1) shell $stata_exe -b do "$programs/clause_types/4031_clause_types.do"
if (`d_cba_value'        ==1) shell $stata_exe -b do "$programs/cba_value/4041_cba_value.do"
if (`d_robustness'       ==1) shell $stata_exe -b do "$programs/robustness/4051_robustness_bins.do"
if (`d_micro_ind_q'      ==1) shell $stata_exe -b do "$programs/robustness/4061_micro_ind_q.do"
if (`d_union_controls'   ==1) shell $stata_exe -b do "$programs/robustness/4071_union_controls.do"
if (`d_turnover'         ==1) shell $stata_exe -b do "$programs/turnover/4081_turnover.do"
if (`d_composition'      ==1) shell $stata_exe -b do "$programs/composition/4091_composition.do"
if (`d_descriptives'     ==1) shell $stata_exe -b do "$programs/descriptives/4101_sample_descriptives.do"
if (`d_mincer'           ==1) shell $stata_exe -b do "$programs/main_results/4111_mincer.do"
if (`d_within_firm'      ==1) shell $stata_exe -b do "$programs/layer_connectivity/07_within_firm/4121_within_firm.do"
if (`d_within_firm_hw'   ==1) shell $stata_exe -b do "$programs/layer_connectivity/07_within_firm/4131_within_firm_hourly.do"

********************************************************************************
* TIER E -- tables and figures
********************************************************************************

if (`e_tables' ==1) {
    shell $python_exe "$programs/main_results/5010_table_direct.py"
    shell $python_exe "$programs/main_results/5020_table_spill.py"
    shell $python_exe "$programs/main_results/5030_table_twopanel.py"
    shell $python_exe "$programs/clause_types/5040_table_clause.py"
    shell $python_exe "$programs/robustness/5050_table_union.py"
    shell $python_exe "$programs/robustness/5060_table_rob_logwages.py"
    shell $python_exe "$programs/residuals/5070_table_resid.py"
    shell $python_exe "$programs/conn_descriptives/5080_table_pairwise_appendix.py"
    shell $python_exe "$programs/layer_connectivity/07_within_firm/5090_table_within_firm.py"
}

if (`e_inline_repl' ==1) {
    shell $python_exe "$programs/layer_connectivity/07_within_firm/5100_inline_into_replication.py"
}

if (`e_fig_bilateral'  ==1) shell $python_exe "$programs/conn_descriptives/5110_figure_bilateral_coefplot.py"
if (`e_fig_distros'    ==1) shell $python_exe "$programs/descriptives/5120_figure_distributions.py"
if (`e_fig_binscatter' ==1) shell $python_exe "$programs/rand_inference/5130_figure_binscatter.py"
if (`e_fig_conn_hist'  ==1) shell $python_exe "$programs/conn_descriptives/5140_figure_conn_hist.py"

* Both outcomes. Draft.tex cites the HOURLY pair; before 2026-08 the export
* filenames in 5152_recentered_eventstudy.do were hardcoded to the monthly
* outcome, so the hourly figures could not be produced at all.
if (`e_fig_recentered' ==1) {
    shell $stata_exe -b do "$programs/rand_inference/5151_recentered_eventstudy.do" lr_remdezr_w
    shell $stata_exe -b do "$programs/rand_inference/5151_recentered_eventstudy.do" lr_remdezr_h_w
}

********************************************************************************
* TIER F -- copy exhibits into the paper
*
* Replaces the undocumented hand-copy that populated
* UnionSpill-paper/Replication/Figures/. Source -> published-name map comes
* from Docs/pipeline/INVENTORY.md section C.
********************************************************************************

* Dry run by default: reports every file it would replace, with both md5s, and
* writes nothing. Set f_copy_apply = 1 only after reading that report.
if (`f_copy_figures' ==1 & `f_copy_apply' != 1) {
    shell $python_exe "$programs/main_results/6010_copy_figures_to_paper.py"
}
if (`f_copy_figures' ==1 & `f_copy_apply' == 1) {
    shell $python_exe "$programs/main_results/6010_copy_figures_to_paper.py" --apply
}

di as result _newline "0000_master.do finished."
