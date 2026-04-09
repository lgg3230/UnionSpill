********************************************************************************
* ENTRY/EXIT PIPELINE — BATCH RUNNER
* Sets globals and runs all three stages sequentially.
********************************************************************************

version 17.0
set more off
clear all

* --- Globals (mirror 00_master.do for cluster) ---
global klc       "/kellogg/proj/lgg3230"
global main      "$klc"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global cba_dir   "$main/UnionSpill/Data/CBA"
global ibge      "$main/UnionSpill/Data/IBGE"
global programs  "$main/UnionSpill/Programs"
global tables    "$main/UnionSpill/Tables/entry_exit"
global graphs    "$main/UnionSpill/Graphs/entry_exit"
global logs      "$main/UnionSpill/Logs/entry_exit"

* --- Stage 1: Merge CBA + RAIS (unbalanced) ---
do "$programs/entry_exit/041_merge_cba_rais_unbal.do"

* --- Stage 2: MATLAB connectivity ---
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/entry_exit/connectivity_treat_unbal.m"

* --- Stage 3: Aggregate connectivity + build analysis dataset ---
do "$programs/entry_exit/05_employers_unbal.do"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Pipeline done" "entry_exit pipeline completed"
