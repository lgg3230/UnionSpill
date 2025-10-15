********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MERGE LAGOS SAMPLE TO RAIS WORKER FILES TO CREATE WORKER LEVEL PANEL
* INPUT: WORKER LEVEL RAIS FILES (2003-2018) AND LAGOS SAMPLE
* OUTPUT: WORKER LEVEL PANEL WITH LAGOS VARIABLES
********************************************************************************

use "$rais_firm/lagos_sample_sep24.dta", clear

keep if in_balanced_panel==1

keep lagos_sample_avg industry1 mode_base_month microregion year ///
    avg_file_date earliest2009_avg second_cba_avg ///
    identificad firm_emp separations ///
    intreat_n outtreat_n totalflows_n ///
    in_balanced_panel treat_ultra treat_year ///
    lr_remdezr lr_remmedr l_firm_emp ///
    natjuridica mode_union ///
    outtreat_pw_n intreat_pw_n ///
    totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n ///
    retention n_negs_union_year cl_*

tostring year, generate(year_str)

gen cnpj_year = identificad + year_str

merge 1:m cnpj_year using "$rais_aux/worker_estab_all_years.dta"

keep if _merge==3

compress
save "$rais_firm/lagos_sample_workers.dta", replace
