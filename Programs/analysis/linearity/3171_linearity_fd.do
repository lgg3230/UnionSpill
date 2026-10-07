* Wrapper: set globals then run 3172_linearity_fd.do (first-difference
* linearity test with the same bins as the TWFE test 3142, both run side by
* side).
*
* PANEL: the July 2026 current-connectivity overlay, the vintage behind the
* published spillover table (Draft.tex: 0.0050 / 0.0065 / 0.0009 / 0.0227), not
* the Sep-14 panel rebuilt from raw RAIS. 3162 rebuilds totaltreat_pw_norm from
* this panel's own p90, avoiding the overlay's stale legacy-divisor column.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/archive/Data/CBA_RAIS_firm_level_currentconn_overlay"
global tables    "$main/UnionSpill/Tables/linearity"
global logs      "$main/UnionSpill/Logs/linearity"
global programs  "$main/UnionSpill/Programs"

do "$programs/analysis/linearity/3172_linearity_fd.do"
