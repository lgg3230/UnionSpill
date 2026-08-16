* Wrapper: set globals then run 4012_pct_tfpw.do (cluster,
* CURRENT CONNECTIVITY).
*
* Identical to _run_pct_tfpw_07_11_cluster.do except that rais_firm points at
* the current-connectivity overlay panel instead of the frozen one. The Lagos
* firm panel ships a frozen totaltreat_pw_n; the overlay directory carries the
* recomputable measure. 4012_pct_tfpw.do rebuilds
* totaltreat_pw_norm from totaltreat_pw_n's 2009 p90 itself (lines 140-146), so
* swapping the input directory is sufficient - the regressor is renormalized on
* the current measure rather than left on the legacy p90.
*
* Tables, graphs, and logs are written to dedicated pct_tfpw_cc/ subfolders so
* this run cannot overwrite the frozen-connectivity outputs already tracked.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/pct_tfpw_cc"
global graphs    "$main/UnionSpill/Graphs/pct_tfpw_cc"
global logs      "$main/UnionSpill/Logs/pct_tfpw_cc"
global programs  "$main/UnionSpill/Programs"

do "$programs/4012_pct_tfpw.do"
