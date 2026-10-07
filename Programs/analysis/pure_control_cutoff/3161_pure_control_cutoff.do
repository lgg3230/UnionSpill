* Wrapper: set globals then run 3162_pure_control_cutoff.do.
*
* Direct effects (4 headline outcomes) re-estimated with the pure-control group
* widened from zero connectivity to totaltreat_pw_n <= c, for c at the
* terciles and quartiles of positive connectivity among untreated firms.
*
* INPUT PANEL. rais_firm points at the archived current-connectivity overlay,
* NOT the canonical Data/CBA_RAIS_firm_level. The overlay is the panel that
* reproduces the published direct-effects table (tab:direct_connectivity_robust)
* exactly; the rebuilt canonical panel currently differs from it (Panel A
* hourly N 112,667 vs published 112,695; see
* quality_reports/sample_gap_investigation/). 3162 checks the replication
* columns against the published CSVs and stops if they do not match.
* totalflows_wide_2007_2011.csv is byte-identical in Data/RAIS_aux and the
* 2026-09-06 baseline, so rais_aux stays canonical.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/archive/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables/pure_control_cutoff"
global graphs    "$main/UnionSpill/Graphs/pure_control_cutoff"
global logs      "$main/UnionSpill/Logs/pure_control_cutoff"
global programs  "$main/UnionSpill/Programs"
global python_exe "/home/lgg3230/.conda/envs/venv_python312/bin/python"

do "$programs/analysis/pure_control_cutoff/3162_pure_control_cutoff.do"
