* Wrapper: set globals then run 3152_linearity_bins.do (binned-connectivity
* spillover DiD: connectivity groups x Post, zero connectivity as baseline).
*
* Input panel is the same one 3011/3012 read. Outputs go to the linearity/
* subfolders; 4250 (table) and 4260 (figure) build the exhibits.

set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/linearity"
global graphs    "$main/UnionSpill/Graphs/linearity"
global logs      "$main/UnionSpill/Logs/linearity"
global programs  "$main/UnionSpill/Programs"

* Zero-connectivity baseline: clear the baseline globals 3153 sets.
global base_lt    ""
global out_suffix ""

do "$programs/analysis/linearity/3152_linearity_bins.do"
