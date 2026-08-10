********************************************************************************
* PROJECT: UNION SPILLOVERS - AUTOMATED CLEANUP
* AUTHOR: LUIS GOMES
* PROGRAM: SAFELY DELETE INTERMEDIATE FILES TO FREE UP SPACE
********************************************************************************

di "Starting automated cleanup of intermediate files..."

* Function to safely delete file if it exists
program define safe_delete
    args filepath
    
    capture confirm file "`filepath'"
    if !_rc {
        erase "`filepath'"
        di "Deleted: `filepath'"
    }
    else {
        di "File not found (already deleted): `filepath'"
    }
end

* 1. Delete year-by-year worker-establishment files
di "Deleting worker-establishment year files..."
forvalues year = 2008/2016 {
    safe_delete "$rais_aux/worker_estab_`year'.dta"
}

* 2. Delete temporary connectivity files
di "Deleting connectivity intermediate files..."
forvalues year = 2007/2011 {
    safe_delete "$rais_aux/yearly_employers_`year'.dta"
}

* Delete year-pair employer files
forvalues i = 2007/2011 {
    forvalues j = 2008/2011 {
        if `i' < `j' {
            safe_delete "$rais_aux/employers_`i'_`j'.dta"
        }
    }
}

* 3. Delete CBA intermediate files
di "Deleting CBA intermediate files..."
safe_delete "$cba_dir/cba_coverage_clean.dta"
safe_delete "$cba_dir/cba_coverage_clean_firm.dta"
safe_delete "$cba_dir/cba_coverage_clean_sector.dta"

safe_delete "$cba_dir/cba_firm_exploded_mun.dta"
safe_delete "$cba_dir/cba_firm_exploded_sta.dta"
safe_delete "$cba_dir/cba_firm_exploded_nat.dta"

* Delete year-by-year CBA establishment files
forvalues year = 2007/2016 {
    safe_delete "$cba_dir/cba_estab_firm_mun_`year'.dta"
    safe_delete "$cba_dir/cba_estab_firm_sta_`year'.dta"
    safe_delete "$cba_dir/cba_estab_firm_nat_`year'.dta"
    safe_delete "$cba_dir/cba_estab_firm_`year'.dta"
}

* 4. Delete RAIS firm intermediate files
di "Deleting RAIS firm intermediate files..."
forvalues year = 2007/2016 {
    safe_delete "$rais_firm/cba_rais_firm_`year'_1.dta"
    safe_delete "$rais_aux/unique_estab_`year'.dta"
}

* 5. Delete temporary sample files
di "Deleting temporary sample files..."
safe_delete "$rais_aux/bal_pan.dta"
safe_delete "$rais_aux/lagos_sample.dta"
safe_delete "$rais_aux/lagos_control.dta"
safe_delete "$rais_aux/lagos_treat.dta"
safe_delete "$rais_aux/1_cba_treat.dta"

* 6. Delete worker-level temporary files
di "Deleting worker-level temporary files..."
safe_delete "$rais_aux/lagos_sample_merge_worker.dta"
forvalues year = 2008/2016 {
    safe_delete "$rais_aux/rais_lagos_`year'.dta"
}

* 7. Delete employer association year files
di "Deleting employer association files..."
forvalues year = 2009/2016 {
    safe_delete "$emp_assoc/emp_assoc_`year'.dta"
}

* 8. Delete temporary worker panel files
di "Deleting temporary worker panel files..."
safe_delete "$rais_aux/worker_panel_temp.dta"
forvalues chunk = 0/9 {
    safe_delete "$rais_aux/worker_chunk_`chunk'.dta"
}
safe_delete "$rais_aux/worker_panel_chunked_temp.dta"

di "Cleanup completed!"
di "You can now check available disk space with: df -h"

