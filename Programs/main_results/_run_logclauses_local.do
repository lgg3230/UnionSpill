* Local Mac wrapper: set globals to the on-disk layout, then run main_logclauses.do
local repo "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "`repo'/Data/CBA_RAIS_firm_level"
global rais_aux  "`repo'/Data/RAIS_aux"
global programs  "`repo'/Programs"
global tables    "`repo'/Tables"
global graphs    "`repo'/Graphs"
global logs      "`repo'/Logs"
do "`repo'/Programs/main_results/main_logclauses.do"
