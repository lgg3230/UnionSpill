********************************************************************************
* UNION SPILLOVERS — MINCER RESIDUALIZATION (Stata/reghdfe)
*
* Purpose: Residualize log December wages and log hourly wages on worker
*          characteristics using reghdfe's varying-slopes absorb, then
*          collapse to firm × year and export CSV consumed by
*          4112_mincer.do.
*
* Specification (Gui's R formula translated to Stata):
*   outcome ~ 1 | race_group^grinstrucao^genero^year[age1, age2, age3, age4]
*   =>
*   reghdfe outcome, absorb(cell_id i.cell_id#c.age1 i.cell_id#c.age2
*                            i.cell_id#c.age3 i.cell_id#c.age4)
*
* Output: Data/CBA_RAIS_firm_level/mincer_residuals_firm_year.csv
*   identificad, year,
*   lr_remdezr_resid, lr_remdezr_mean, n_workers_dezr,
*   lr_hourly_resid,  lr_hourly_mean,  n_workers_hourly
*
* Runtime: ~12-22 min (Stata-MP)
*   - Python export: ~1 min  (skipped if DTA already exists)
*   - reghdfe x2:   ~10-20 min
*   - Collapse/export: <1 min
*
* Run standalone:
*   module load stata/17
*   stata-mp -b do Programs/residuals/011f_mincer_residuals.do
********************************************************************************

capture log close

// ─── GLOBALS (set here for standalone use; overridden by 0000_master.do) ────────

if "`c(username)'" == "lgg3230" {
	global klc      "/kellogg/proj/lgg3230"
	global main     "$klc"
}
if "`c(username)'" == "luisg" {
	global main     "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication_Mar 2"
}

global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global programs  "$main/UnionSpill/Programs"
global logs      "$main/UnionSpill/Logs"

// ─── LOG ─────────────────────────────────────────────────────────────────────

set more off
set varabbrev off

local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/011f_mincer_residuals_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* STEP 1 — Export parquet to DTA (skip if DTA already present)
********************************************************************************

local dta_path "$rais_firm/worker_panel_mincer.dta"

capture confirm file "`dta_path'"
if _rc != 0 {
	di as result "DTA not found. Running Python export ..."
	shell ~/.conda/envs/venv_python312/bin/python "$programs/011f_mincer_export.py"
	di as result "Python export complete."
}
else {
	di as result "DTA found — skipping Python export."
}

********************************************************************************
* STEP 2 — Load
********************************************************************************

di _newline(1)
di as result "Loading `dta_path' ..."
use "`dta_path'", clear
di as result "  Rows loaded: " _N

********************************************************************************
* STEP 3 — Sample restriction (mirrors R drop_na on required vars)
********************************************************************************

* Drop rows missing education, gender, or age (required for cell_id and FE)
keep if !missing(grinstrucao, genero, age)

* race_group is a string — drop empty or "." values
drop if race_group == "" | race_group == "."

di as result "  Rows after sample restriction: " _N

********************************************************************************
* STEP 4 — Age polynomials
********************************************************************************

gen double age1 = age
gen double age2 = age^2
gen double age3 = age^3
gen double age4 = age^4

********************************************************************************
* STEP 5 — Cell identifier (numeric, required for i. factor notation in absorb)
********************************************************************************

* Cell = race_group × grinstrucao × genero × year
* (mirrors Gui's race_group^grinstrucao^genero^year)
egen long cell_id = group(race_group grinstrucao genero year)

qui tab cell_id
di as result "  Number of cells: " r(r)

********************************************************************************
* STEP 5b — Memory cleanup (drop variables no longer needed before reghdfe)
********************************************************************************

* Keep only: outcomes, age polynomials, cell_id, and id/year for collapse
* Dropping: remdezr, horascontr, genero, grinstrucao, race_group, age (raw)
keep identificad year lr_remdezr lr_hourly age1 age2 age3 age4 cell_id

compress
di as result "  Variables kept: " c(k)
di as result "  Memory after cleanup: " %6.0fc c(memory) " MB"

********************************************************************************
* STEP 6 — Residualize log December wage
********************************************************************************

di _newline(1)
di as result "========================================================"
di as result "Outcome: lr_remdezr (log December wage)"
di as result "========================================================"

* reghdfe with varying slopes: cell_id intercept + cell_id-specific age slopes
* This implements: lr_remdezr = α(cell) + Σ βₖ(cell)·ageᵏ + ε
* NOTE: no i. prefix — reghdfe absorb handles demeaning internally

timer clear 1
timer on 1
di as result "  TIMING: lr_remdezr reghdfe started: `c(current_date)' `c(current_time)'"

reghdfe lr_remdezr if !missing(lr_remdezr), ///
    absorb(cell_id cell_id#c.age1 cell_id#c.age2 ///
           cell_id#c.age3 cell_id#c.age4) ///
    residuals(lr_remdezr_resid)

timer off 1
timer list 1
di as result "  TIMING: lr_remdezr reghdfe finished: `c(current_date)' `c(current_time)'"

qui sum lr_remdezr_resid
di as result "  Residual mean : " %9.6f r(mean) "  (should be ~0)"
di as result "  Residual std  : " %9.4f r(sd)
di as result "  Obs in regression: " e(N)

********************************************************************************
* STEP 7 — Residualize log hourly wage
********************************************************************************

di _newline(1)
di as result "========================================================"
di as result "Outcome: lr_hourly (log hourly wage)"
di as result "========================================================"

timer clear 2
timer on 2
di as result "  TIMING: lr_hourly reghdfe started: `c(current_date)' `c(current_time)'"

reghdfe lr_hourly if !missing(lr_hourly), ///
    absorb(cell_id cell_id#c.age1 cell_id#c.age2 ///
           cell_id#c.age3 cell_id#c.age4) ///
    residuals(lr_hourly_resid)

timer off 2
timer list 2
di as result "  TIMING: lr_hourly reghdfe finished: `c(current_date)' `c(current_time)'"

qui sum lr_hourly_resid
di as result "  Residual mean : " %9.6f r(mean) "  (should be ~0)"
di as result "  Residual std  : " %9.4f r(sd)
di as result "  Obs in regression: " e(N)

********************************************************************************
* STEP 8 — Collapse to firm × year
********************************************************************************

di _newline(1)
di as result "Collapsing to firm x year ..."

* Convert string identificad to numeric so export delimited writes plain numbers
* (4112_mincer.do reads the CSV and runs tostring...format(%014.0f))
capture destring identificad, replace

collapse                                              ///
    (mean)  lr_remdezr_resid                          ///
            lr_remdezr_mean = lr_remdezr              ///
            lr_hourly_resid                           ///
            lr_hourly_mean  = lr_hourly               ///
    (count) n_workers_dezr   = lr_remdezr_resid       ///
            n_workers_hourly = lr_hourly_resid,        ///
    by(identificad year)

di as result "  Firm-year rows: " _N
di as result "  Unique firms  : " _N  // approximate; tab would be slow

********************************************************************************
* STEP 9 — Export CSV (same format as Python version; consumed by 4112_mincer.do)
********************************************************************************

local csv_out "$rais_firm/mincer_residuals_firm_year.csv"
export delimited "`csv_out'", replace

di as result "Exported: `csv_out'"

* Quick sanity check on residual means
qui sum lr_remdezr_resid
di as result "lr_remdezr_resid mean (firm-level): " %9.6f r(mean)
qui sum lr_hourly_resid
di as result "lr_hourly_resid  mean (firm-level): " %9.6f r(mean)

di _newline(1)
di as result "Finished: `c(current_date)' `c(current_time)'"

log close

********************************************************************************
* END OF DO-FILE
********************************************************************************
