********************************************************************************
* validate_hourly_wage_rais_firm.do
*
* PURPOSE: Validate lr_remdezr_h from rais_firm_YYYY.dta as a source for
*          log real hourly wages in the entry/exit panel.
*
*   Step 1 — Stack lr_remdezr_h from rais_firm_2009–2016 into a long panel.
*   Step 2 — Merge onto entry_exit_panel.dta and check coverage.
*   Step 3 — For balanced-panel firms, compare lr_remdezr_h (rais_firm source)
*             against lr_remdezr_h_w (worker-panel source) via correlation and
*             mean absolute difference.
*
* If validation passes, lr_remdezr_h from rais_firm can replace lr_remdezr_h_w
* as the hourly-wage source in prep_entry_exit_data.do, giving uniform coverage
* across balanced and extra (exiting) firms.
********************************************************************************

version 17.0
set more off

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"

di "=== validate_hourly_wage_rais_firm.do: `c(current_date)' `c(current_time)' ==="

********************************************************************************
* STEP 1 — STACK lr_remdezr_h ACROSS ALL YEARS
********************************************************************************

di _newline "--- Step 1: building stacked rais_firm hourly wage panel ---"

tempfile stacked
local first 1

forvalues yr = 2009/2016 {
    preserve
        use "$rais_firm/rais_firm_`yr'.dta", clear
        keep identificad lr_remdezr_h lr_remdezr
        gen int year = `yr'
        if `first' {
            save `stacked'
            local first 0
        }
        else {
            append using `stacked'
            save `stacked', replace
        }
    restore
}

* Quick coverage check on the stacked file
use `stacked', clear
di "Stacked panel: " _N " firm×year obs"
count if !missing(lr_remdezr_h)
di "  with non-missing lr_remdezr_h: " r(N)
count if missing(lr_remdezr_h)
di "  missing lr_remdezr_h: " r(N)

********************************************************************************
* STEP 2 — MERGE ONTO ENTRY/EXIT PANEL; CHECK COVERAGE
********************************************************************************

di _newline "--- Step 2: merging onto entry_exit_panel ---"

use "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear

* Rename incoming variables to avoid collision with existing ones
tempfile stacked_renamed
use `stacked', clear
rename lr_remdezr_h    lr_remdezr_h_rf    // _rf = rais_firm source
rename lr_remdezr      lr_remdezr_rf
save `stacked_renamed'

use "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", clear
merge 1:1 identificad year using `stacked_renamed', keep(master match) nogen

di _newline "Coverage (present_in_year == 1 obs only):"
count if present_in_year == 1
local n_real = r(N)
di "  Total real obs: " `n_real'

count if present_in_year == 1 & !missing(lr_remdezr_h_rf)
local n_has_hourly = r(N)
di "  With lr_remdezr_h (rais_firm): " `n_has_hourly' " (" %4.1f (`n_has_hourly'/`n_real'*100) "%)"

count if present_in_year == 1 & missing(lr_remdezr_h_rf)
di "  Missing lr_remdezr_h (rais_firm): " r(N)

* Coverage by firm type
di _newline "Coverage by firm type (year 2009, present_in_year==1):"
foreach grp in "in_balanced_panel==1" "in_balanced_panel==0" {
    count if present_in_year==1 & year==2009 & `grp'
    local n_grp = r(N)
    count if present_in_year==1 & year==2009 & `grp' & !missing(lr_remdezr_h_rf)
    di "  `grp': " r(N) "/" `n_grp' " have hourly wage"
}

********************************************************************************
* STEP 3 — VALIDATION: COMPARE WITH lr_remdezr_h_w FOR BALANCED-PANEL FIRMS
********************************************************************************

di _newline "--- Step 3: validation against lr_remdezr_h_w (balanced panel) ---"

* Restrict to balanced-panel firms with present real obs
keep if in_balanced_panel == 1 & present_in_year == 1

count if !missing(lr_remdezr_h_w) & !missing(lr_remdezr_h_rf)
di "Balanced-panel obs with both vars non-missing: " r(N)

* Correlation
corr lr_remdezr_h_w lr_remdezr_h_rf
di "Correlation between lr_remdezr_h_w and lr_remdezr_h_rf: " r(rho)

* Mean absolute difference
gen double _diff = lr_remdezr_h_w - lr_remdezr_h_rf
sum _diff, detail
di "Mean difference (h_w minus h_rf):    " r(mean)
di "Mean absolute difference:            " r(mean) " (see below for abs)"
gen double _absdiff = abs(_diff)
sum _absdiff, detail
di "Mean abs diff: " r(mean)
di "P50  abs diff: " r(p50)
di "P95  abs diff: " r(p95)
di "P99  abs diff: " r(p99)

* Scatter check: how many obs differ by more than 0.01 log points?
count if _absdiff > 0.01 & !missing(_absdiff)
di "Obs with |diff| > 0.01: " r(N) " (" %4.1f (r(N)/_N*100) "% of balanced-panel obs)"
count if _absdiff > 0.05 & !missing(_absdiff)
di "Obs with |diff| > 0.05: " r(N)

di _newline "=== Validation complete: `c(current_date)' `c(current_time)' ==="

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && \
    notify "Hourly wage validation done" "validate_hourly_wage_rais_firm.do"
