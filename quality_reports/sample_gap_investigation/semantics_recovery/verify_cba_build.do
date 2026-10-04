clear all
set more off
version 17.0
global rais_aux "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/rais_aux"
global rais_firm "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/rais_firm"
global cba_dir "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/CBA_verified"
global ibge "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/IBGE"
do "/gpfs/kellogg/proj/lgg3230/UnionSpill/quality_reports/sample_gap_investigation/1020_suffix.do"

display "ISOLATED CBA VERIFICATION BUILD COMPLETE"
