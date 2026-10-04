clear all
set more off
version 17.0
global rais_aux "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/rais_aux"
global rais_firm "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/rais_firm"
global cba_dir "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016/CBA"
global ibge "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/IBGE"
do "/gpfs/kellogg/proj/lgg3230/UnionSpill/quality_reports/sample_gap_investigation/1020_suffix.do"
do "/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/sample_construction/1030_merge_cba_rais.do"
keep if lagos_sample_avg==1 & in_balanced_panel==1 & inrange(year,2009,2016)
keep identificad year municipio firm_emp union_id avg_file_date min_file_date max_file_date start_date_stata end_date_stata cba2009_avg cba_pre2012_avg cba_post2012_avg lagos_sample_avg in_balanced_panel treat_ultra
isid identificad year
save "$rais_firm/eligible_panel.dta",replace
display "FULL WIDE CANDIDATE COMPLETE"
