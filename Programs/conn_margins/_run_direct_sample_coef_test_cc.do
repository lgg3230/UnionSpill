* Wrapper: direct-effect Panel A vs Panel C equality test, CURRENT-CONNECTIVITY.
*
* Created 2026-08-01. The Replication document's Direct Effects table prints a
* $p$-value row ([0.009] [0.013] [0.741] [0.386]) that no committed script
* reproduced: direct_sample_coef_test.do ran against the frozen panel and its
* saved CSV covered only 2 of the 4 outcomes. This wrapper runs the same script
* on the overlay for all four, writing a suffixed CSV so the legacy output is
* preserved for comparison.
set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level_currentconn_overlay"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"
global testsuf   "_currentconn"

do "$main/Programs/conn_margins/direct_sample_coef_test.do"
