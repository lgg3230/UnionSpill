* Wrapper: demo controls, CURRENT-CONNECTIVITY panel.
*
* Created 2026-08-01. Tables/currentconn_full/robustness/ already held this
* script's output, but the only committed wrapper (_run_demo_controls.do) points
* at the frozen panel and the legacy Tables/ root. That wrapper is left alone;
* it feeds the main draft.
set more off
set varabbrev off

global main "/kellogg/proj/lgg3230"
global klc  "$main"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables/currentconn_full"
global graphs    "$main/UnionSpill/Graphs/currentconn_full"
global logs      "$main/UnionSpill/Logs/currentconn_full"
global programs  "$main/UnionSpill/Programs"

do "$programs/robustness/Main_Results_demo_controls.do"
