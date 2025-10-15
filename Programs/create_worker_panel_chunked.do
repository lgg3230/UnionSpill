********************************************************************************
* PROJECT: UNION SPILLOVERS - CHUNKED WORKER PANEL CREATION
* AUTHOR: LUIS GOMES
* PROGRAM: CREATE WORKER PANEL WITH CHUNKED PROCESSING FOR LARGE DATASETS
* STRATEGY: Process by worker chunks, firm chunks, or time periods
********************************************************************************

set maxvar 32767
set matsize 11000
set more off

* Memory settings
set memory 64g
set max_memory 128g

local years "2008 2009 2010 2011 2012 2013 2014 2015 2016"
local ipca  " 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"

* Strategy 1: Process by worker chunks (first digits of PIS)
* This allows processing subsets of workers at a time

local worker_chunks "0 1 2 3 4 5 6 7 8 9"

foreach chunk of local worker_chunks {
    di "Processing worker chunk starting with `chunk'..."
    
    * Process each year for this worker chunk
    local first_iteration = 1
    
    foreach year of local years {
        di "  Processing year `year' for worker chunk `chunk'..."
        
        local pos = `year' - 2007
        local deflator : word `pos' of `ipca'
        
        * Load year data
        use "$rais_raw_dir/RAIS_`year'.dta", clear
        
        * Filter to worker chunk (first digit of PIS)
        gen pis_first_digit = substr(PIS, 1, 1)
        keep if pis_first_digit == "`chunk'"
        
        * Process data (same as efficient version)
        keep PIS identificad empem3112 tempempr horascontr remdezr remmedr salcontr ///
             tiposal dtadmissao causadesli mesdesli grinstrucao genero idade ///
             raca_cor clascnae20 municipio natjuridica
        
        gen year = `year'
        gen identificad_8 = substr(identificad,1,8)
        gen worker_firm_id = PIS + "_" + identificad
        gen empdec_lagos = empem3112*(tempempr>1)
        
        * Wage processing
        gen salcontr_m = salcontr
        replace salcontr_m = 2 * salcontr if tiposal == 2
        replace salcontr_m = 4.348 * salcontr if tiposal == 3
        replace salcontr_m = 30.436875 * salcontr if tiposal == 4
        replace salcontr_m = 4.348 * horascontr * salcontr if tiposal == 5
        
        gen salcontr_h = salcontr_m/(horascontr*4.348)
        gen remdezr_h = remdezr/(horascontr*4.348)
        gen remmedr_h = remmedr/(horascontr*4.348)
        
        gen lr_salcontr_h = log(salcontr_h/`deflator')
        gen lr_remdezr_h = log(remdezr_h/`deflator')
        gen lr_remmedr_h = log(remmedr_h/`deflator')
        
        gen dtadmissao_stata = date(dtadmissao, "DMY")
        format dtadmissao_stata %td
        
        * Worker ranking
        gen rank_composite = horascontr + lr_remdezr_h/1000
        set seed 12345
        gen random = runiform()
        gen rank_final = rank_composite + random/1000000
        
        sort worker_firm_id rank_final
        by worker_firm_id: gen final_rank = (_n == _N & empdec_lagos == 1)
        
        keep if final_rank == 1
        
        * Optimize data types
        compress
        destring PIS, replace
        destring identificad, replace
        destring identificad_8, replace
        destring municipio, replace
        
        gen industry = substr(clascnae20,1,3)
        destring industry, replace
        
        keep year PIS identificad identificad_8 worker_firm_id municipio industry ///
             clascnae20 natjuridica grinstrucao genero idade raca_cor ///
             empdec_lagos tempempr horascontr ///
             lr_salcontr_h lr_remdezr_h lr_remmedr_h ///
             salcontr_h remdezr_h remmedr_h ///
             dtadmissao_stata causadesli mesdesli
        
        * Save or append
        if `first_iteration' == 1 {
            save "$rais_aux/worker_chunk_`chunk'.dta", replace
            local first_iteration = 0
        }
        else {
            append using "$rais_aux/worker_chunk_`chunk'.dta"
            save "$rais_aux/worker_chunk_`chunk'.dta", replace
        }
        
        * Clear memory
        clear
    }
}

* Combine all worker chunks
di "Combining worker chunks..."

* Start with first chunk
use "$rais_aux/worker_chunk_0.dta", clear

foreach chunk of local worker_chunks {
    if `chunk' == 0 continue
    
    di "  Appending chunk `chunk'..."
    append using "$rais_aux/worker_chunk_`chunk'.dta"
    
    * Save intermediate result
    save "$rais_aux/worker_panel_chunked_temp.dta", replace
    
    * Clean up chunk file
    erase "$rais_aux/worker_chunk_`chunk'.dta"
}

* Final processing
sort PIS year

* Create worker-level variables
by PIS: gen worker_spells = _N
by PIS: gen worker_first_year = year[1]
by PIS: gen worker_last_year = year[_N]

* Create firm-level variables
by identificad year: gen firm_workers = _N
by identificad year: gen firm_avg_wage = mean(lr_remdezr_h)

* Save final dataset
compress
save "$rais_aux/worker_panel_chunked_final.dta", replace

* Clean up
erase "$rais_aux/worker_chunk_0.dta"
erase "$rais_aux/worker_panel_chunked_temp.dta"

di "Chunked worker panel creation completed!"
di "Final dataset: worker_panel_chunked_final.dta"
