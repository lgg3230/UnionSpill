********************************************************************************
* PROJECT: UNION SPILLOVERS - MEMORY-EFFICIENT WORKER PANEL
* AUTHOR: LUIS GOMES
* PROGRAM: CREATE WORKER-LEVEL PANEL WITH MEMORY OPTIMIZATION
* STRATEGY: Chunked processing, data type optimization, streaming approach
********************************************************************************

set maxvar 32767
set matsize 11000
set more off

* Set memory and performance options
set memory 32g
set max_memory 64g

local years "2008 2009 2010 2011 2012 2013 2014 2015 2016"
local ipca  " 0.643834976197206 0.671594887351247 0.711277338716318 0.757534213038901 0.80176356558955 0.849153270408197 0.903562518222102 1 1.06287988213221 1.09420743038879"

* Strategy 1: Process and append year-by-year (streaming approach)
* This avoids loading all years into memory at once

di "Starting memory-efficient worker panel creation..."

* Initialize with first year
local first_year = 2008
local pos = `first_year' - 2007
local deflator : word `pos' of `ipca'

di "Processing year `first_year' (base year)..."
use "$rais_raw_dir/RAIS_`first_year'.dta", clear

* Keep only essential variables for worker panel
keep PIS identificad empem3112 tempempr horascontr remdezr remmedr salcontr ///
     tiposal dtadmissao causadesli mesdesli grinstrucao genero idade ///
     raca_cor clascnae20 municipio natjuridica

* Generate year and firm identifier
gen year = `first_year'
gen identificad_8 = substr(identificad,1,8)

* Create worker-firm identifier (unique worker-establishment pair)
gen worker_firm_id = PIS + "_" + identificad

* OPTIMIZED: Streamlined processing for worker panel
* Generate employment indicator
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

* Inflation adjustment
gen lr_salcontr_h = log(salcontr_h/`deflator')
gen lr_remdezr_h = log(remdezr_h/`deflator')
gen lr_remmedr_h = log(remmedr_h/`deflator')

* Date processing
gen dtadmissao_stata = date(dtadmissao, "DMY")
format dtadmissao_stata %td

* Worker ranking (select best spell per worker-firm pair)
gen rank_composite = horascontr + lr_remdezr_h/1000
set seed 12345
gen random = runiform()
gen rank_final = rank_composite + random/1000000

sort worker_firm_id rank_final
by worker_firm_id: gen final_rank = (_n == _N & empdec_lagos == 1)

* Keep only selected spells
keep if final_rank == 1

* OPTIMIZE DATA TYPES to save memory
compress
* Convert string variables to appropriate types
destring PIS, replace
destring identificad, replace
destring identificad_8, replace
destring municipio, replace

* Create industry variable
gen industry = substr(clascnae20,1,3)
destring industry, replace

* Keep only essential variables for worker panel
keep year PIS identificad identificad_8 worker_firm_id municipio industry ///
     clascnae20 natjuridica grinstrucao genero idade raca_cor ///
     empdec_lagos tempempr horascontr ///
     lr_salcontr_h lr_remdezr_h lr_remmedr_h ///
     salcontr_h remdezr_h remmedr_h ///
     dtadmissao_stata causadesli mesdesli

* Save first year
save "$rais_aux/worker_panel_temp.dta", replace

* Process remaining years and append
foreach year of local years {
    if `year' == `first_year' continue  // Skip first year (already processed)
    
    di "Processing year `year'..."
    
    local pos = `year' - 2007
    local deflator : word `pos' of `ipca'
    
    * Process year
    use "$rais_raw_dir/RAIS_`year'.dta", clear
    
    * Keep only essential variables
    keep PIS identificad empem3112 tempempr horascontr remdezr remmedr salcontr ///
         tiposal dtadmissao causadesli mesdesli grinstrucao genero idade ///
         raca_cor clascnae20 municipio natjuridica
    
    * Generate variables (same as above)
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
    
    * Inflation adjustment
    gen lr_salcontr_h = log(salcontr_h/`deflator')
    gen lr_remdezr_h = log(remdezr_h/`deflator')
    gen lr_remmedr_h = log(remmedr_h/`deflator')
    
    * Date processing
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
    
    * Keep only essential variables
    keep year PIS identificad identificad_8 worker_firm_id municipio industry ///
         clascnae20 natjuridica grinstrucao genero idade raca_cor ///
         empdec_lagos tempempr horascontr ///
         lr_salcontr_h lr_remdezr_h lr_remmedr_h ///
         salcontr_h remdezr_h remmedr_h ///
         dtadmissao_stata causadesli mesdesli
    
    * Append to existing panel
    append using "$rais_aux/worker_panel_temp.dta"
    
    * Save intermediate result
    save "$rais_aux/worker_panel_temp.dta", replace
    
    * Clear memory
    clear
}

* Final processing and save
use "$rais_aux/worker_panel_temp.dta", clear

* Sort by worker and year
sort PIS year

* Create worker-level variables
by PIS: gen worker_spells = _N
by PIS: gen worker_first_year = year[1]
by PIS: gen worker_last_year = year[_N]

* Create firm-level variables
by identificad year: gen firm_workers = _N
by identificad year: gen firm_avg_wage = mean(lr_remdezr_h)

* Save final worker panel
compress
save "$rais_aux/worker_panel_final.dta", replace

* Clean up temporary file
erase "$rais_aux/worker_panel_temp.dta"

di "Worker panel creation completed successfully!"
di "Final dataset saved as: worker_panel_final.dta"
