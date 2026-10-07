* Wrapper: set globals then run 3142_linearity_twfe.do (linearity test of the
* spillover DiD on the TWFE equation, Cattaneo et al. binstest).
*
* Input panel is the same one 3011/3012 read. Outputs go to the linearity/
* subfolders; 4240_table_linearity_latex.py builds the table from them.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/linearity"
global logs      "$main/UnionSpill/Logs/linearity"
global programs  "$main/UnionSpill/Programs"

do "$programs/analysis/linearity/3142_linearity_twfe.do"
