********************************************************************************
* MAIN ANALYSIS DATASET SMOKE TEST
*
* Non-destructive test:
*   - loads the protected main analysis dataset
*   - checks key variables used by downstream analysis
*   - keeps a small firm sample in tempfiles only
*   - merges totalflows_wide_2007_2011.csv
*   - creates common treatment/connectivity variables
*   - runs lightweight summary/regression checks
*
* This does not test full reconstruction from raw RAIS/CBA. It tests whether the
* current analysis dataset is usable after cleanup.
********************************************************************************

version 17.0
set more off
set varabbrev off
clear all

global klc "/kellogg/proj/lgg3230"
global project "$klc/UnionSpill"
global data "$project/Data"
global rais_aux "$data/RAIS_aux"
global rais_firm "$data/CBA_RAIS_firm_level"

local protected "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
local totalflows "$rais_aux/totalflows_wide_2007_2011.csv"

capture confirm file "`protected'"
if _rc {
    di as error "Protected dataset not found: `protected'"
    exit 601
}

capture confirm file "`totalflows'"
if _rc {
    di as error "Totalflows CSV not found: `totalflows'"
    exit 601
}

di as result "Loading protected analysis dataset..."
use "`protected'", clear

local required_vars ///
    identificad year lagos_sample_avg treat_ultra firm_emp l_firm_emp ///
    lr_remdezr lr_remmedr hiring turnover ///
    avg_file_date earliest2009_avg second_cba_avg ///
    totaltreat_pw_n totaltreat_pf_n avg_ftreat_pf_n

foreach v of local required_vars {
    capture confirm variable `v'
    if _rc {
        di as error "Required variable missing: `v'"
        exit 111
    }
}

keep if year >= 2009
keep if lagos_sample_avg == 1

set seed 12345
egen firm_tag = tag(identificad)
gen double sample_draw = runiform() if firm_tag
sort sample_draw identificad year
egen firm_rank = rank(sample_draw) if firm_tag, unique
bys identificad: egen sample_firm_rank = min(firm_rank)
keep if sample_firm_rank <= 250
drop firm_tag sample_draw firm_rank sample_firm_rank

tempfile sample_data
save `sample_data'

di as result "Merging totalflows controls into sample..."
preserve
    import delimited "`totalflows'", clear
    tostring identificad, replace format(%014.0f) force
    tempfile totalflows_wide
    save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen int totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    capture confirm variable `yp'
    if _rc {
        di as error "Missing totalflows column after merge: `yp'"
        exit 111
    }
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
    if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

cap drop placebo_year
cap drop treat_year
cap drop cba_period

gen byte placebo_year = (year < 2011)
gen byte treat_year = (year >= 2012)

gen byte cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & missing(cba_period)
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & missing(cba_period)
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & missing(cba_period)
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & missing(cba_period)

di as result "Smoke-test summaries..."
count
egen smoke_firm_tag = tag(identificad)
count if smoke_firm_tag
drop smoke_firm_tag
summ firm_emp l_firm_emp lr_remdezr lr_remmedr totaltreat_pw_n totaltreat_pf_n avg_ftreat_pf_n totalflows_pw_pre_07_11

di as result "Smoke-test regression..."
reg lr_remdezr i.treat_year##i.treat_ultra c.totaltreat_pw_n c.totalflows_pw_pre_07_11, vce(robust)

di as result "Smoke test completed successfully. No permanent files were written."
