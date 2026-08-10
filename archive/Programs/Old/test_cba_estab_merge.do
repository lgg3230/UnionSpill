//// Test to understand why the date selection matters 

/// get current sample of lagos_sample+inblanpanel (start_year):

use "$rais_firm/cba_rais_firm_2009_2017_rep_3.dta",clear 

keep if in_balanced_panel==1 // 11,210,608 obs

bys identificad: egen n_negs_s =nvals(file_date_stata)

keep identificad treat_ultra n_negs_s lagos_sample file_date_stata year cba2009
rename (treat_ultra lagos_sample file_date_stata year cba2009) (treat_ultra_s lagos_sample_s file_date_stata_s year_s cba2009_s)
keep if year_s==2012 // 1,401,326

save "$rais_aux/balpan_start.dta", replace

// 16.3k obs
// 4.5k (27.91%) estabs in the treatment
// 11.8 (72.09%) estabs in the control

// Get sample not being selected by any year in particualr:
// 


use "$rais_firm/cba_rais_firm_2009_2017_rep_2.dta",clear 

keep if in_balanced_panel==1 // 11,210,608 obs 

bys identificad: egen n_negs_n =nvals(file_date_stata)

keep identificad treat_ultra n_negs_n lagos_sample file_date_stata year cba2009
rename (treat_ultra lagos_sample file_date_stata year cba2009) (treat_ultra_n lagos_sample_n file_date_stata_n year_n cba2009_n)
keep if year_n==2012 // 1,401,326

save "$rais_aux/balpan_no.dta", replace
// 17.9 k obs
// 5k (28.28%) control
// 12.8k (71.72%) treat_ultra


// Get sample selected using file year:

use "$rais_firm/cba_rais_firm_2009_2017_rep_4.dta",clear 

keep if in_balanced_panel==1 // 11,210,608 obs 

bys identificad: egen n_negs_f =nvals(file_date_stata)

keep identificad treat_ultra n_negs_f lagos_sample file_date_stata year cba2009
rename (treat_ultra lagos_sample file_date_stata year cba2009) (treat_ultra_f lagos_sample_f file_date_stata_f year_f cba2009_f)
keep if year_f==2012 // 1,401,326

save "$rais_aux/balpan_file.dta", replace


// merge to see where each one is

merge 1:1 identificad using "$rais_aux/balpan_start.dta"

rename _merge merge_fs

merge 1:1 identificad using "$rais_aux/balpan_no.dta"

rename _merge merge_fsn


order identificad lagos_sample_* n_negs_* treat_ultra_* file_date_stata_* year_* 

gen all_ls = lagos_sample_f*lagos_sample_n*lagos_sample_s

keep if lagos_sample_f==1 | lagos_sample_n==1 | lagos_sample_s==1

keep if all_ls==0

gen equal_negs = (n_negs_f==n_negs_s)

order identificad equal_negs




