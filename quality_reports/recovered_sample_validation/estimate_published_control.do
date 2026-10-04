clear all
set more off
set varabbrev off
version 17.0
global main "/gpfs/kellogg/proj/lgg3230"
global rais_aux "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/aux"
global rais_firm "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/panels/published_control"
global tables "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/tables/published_control"
global graphs "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/graphs/published_control"
global logs "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/logs/published_control"
global programs "/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs"
do "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/recovered_sample_validation/programs/3012_pct_tfpw.do"
display "PUBLISHED CONTROL ESTIMATION COMPLETE"
