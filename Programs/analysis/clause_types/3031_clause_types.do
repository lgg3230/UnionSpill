* Wrapper: clause types, CURRENT-CONNECTIVITY panel.
*
* Created 2026-08-01. Tables/currentconn_full/clause_types/ already held this
* script's output, but the committed wrapper (_run_clause_types.do) points at
* the frozen panel and the legacy Tables/ root.
set more off
set varabbrev off

global main "/kellogg/proj/lgg3230"
global klc  "$main"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/currentconn_full"
global graphs    "$main/UnionSpill/Graphs/currentconn_full"
global logs      "$main/UnionSpill/Logs/currentconn_full"
global programs  "$main/UnionSpill/Programs"

do "$programs/analysis/clause_types/3032_clause_types.do"
