* Wrapper: set globals then run Main_Results_union_controls.do (CURRENT
* CONNECTIVITY).
*
* Identical to _run_union_controls.do except that rais_firm points at the
* current-connectivity overlay panel instead of the frozen one, and tables go to
* the currentconn_full tree. This is the run that feeds the Replication
* document's ten-column union tables; the legacy wrapper feeds the six-column
* tab:spill_union_controls in the main draft and is left alone.
*
* Created 2026-08-01. The currentconn CSVs it writes already existed at
* Tables/currentconn_full/robustness/, but no committed wrapper produced them.

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

do "$programs/robustness/Main_Results_union_controls.do"
