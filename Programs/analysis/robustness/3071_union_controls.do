* Wrapper: union-controls robustness, LOG HOURLY WAGES, CURRENT-CONNECTIVITY
* panel. Hourly counterpart of _run_union_controls_cc.do.
*
* Created 2026-08-01. The _hw CSV it writes already existed at
* Tables/currentconn_full/robustness/, but no committed script could produce it
* -- the do-file hardcoded lr_remdezr_w. 3072_union_controls.do now
* reads $OUTVAR / $OUTSUF, following the 3061_micro_ind_q.do pattern.

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

global OUTVAR "lr_remdezr_h_w"
global OUTSUF "_hw"

do "$programs/analysis/robustness/3072_union_controls.do"
