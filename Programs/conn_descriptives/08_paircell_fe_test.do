********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: Test paircell FE regression vs interaction approach
* PURPOSE: Compare pre→post coefficient under different specifications
********************************************************************************

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

global klc "/kellogg/proj/lgg3230"
global rais_aux "$klc/UnionSpill/Data/RAIS_aux"

********************************************************************************
* STEP 1: LOAD DATA AND CREATE PAIRCELL IDENTIFIER
********************************************************************************

di _newline(2) "=== Loading data ==="

use "$rais_aux/bilateral_regression_data.dta", clear

di "Total observations: " _N

* Create industry x microregion cell identifiers for i and j
* Use string concatenation for unique identification
gen str20 cell_i = string(industry1_i) + "_" + string(microregion_i)
gen str20 cell_j = string(industry1_j) + "_" + string(microregion_j)

* Create UNORDERED paircell (so i-j and j-i map to same cell)
gen str41 cell_min = cond(cell_i < cell_j, cell_i, cell_j)
gen str41 cell_max = cond(cell_i < cell_j, cell_j, cell_i)

* Create interaction term
gen pre_x_same_indmicro = z_bilateral_conn_pre * same_industry_micro

********************************************************************************
* STEP 2: TEST ON TINY SUBSAMPLE (0.1%)
********************************************************************************

di _newline(2) "=== Testing on 0.1% subsample ==="

preserve

set seed 12345
sample 0.1

di "Subsample observations: " _N

* Create paircell group on subsample
egen paircell = group(cell_min cell_max)
di "Number of paircells in subsample: "
distinct paircell

* --- Specification 1: Baseline (no cell controls) ---
di _newline "--- Spec 1: Baseline ---"
reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    noabsorb vce(robust)
local b1 = _b[z_bilateral_conn_pre]
local r2_1 = e(r2)

* --- Specification 2: With interaction ---
di _newline "--- Spec 2: With interaction (pre × same_industry_micro) ---"
reghdfe z_bilateral_conn_post z_bilateral_conn_pre pre_x_same_indmicro ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    noabsorb vce(robust)
local b2_main = _b[z_bilateral_conn_pre]
local b2_int = _b[pre_x_same_indmicro]
local r2_2 = e(r2)

* --- Specification 3: With paircell FE ---
di _newline "--- Spec 3: With paircell FE ---"
reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    absorb(paircell) vce(robust)
local b3 = _b[z_bilateral_conn_pre]
local r2_3 = e(r2_within)

di _newline(2) "=== SUBSAMPLE RESULTS SUMMARY ==="
di "Spec 1 (baseline):    beta_pre = " %9.6f `b1' "  R2 = " %9.6f `r2_1'
di "Spec 2 (interaction): beta_pre = " %9.6f `b2_main' "  beta_int = " %9.6f `b2_int' "  R2 = " %9.6f `r2_2'
di "Spec 3 (paircell FE): beta_pre = " %9.6f `b3' "  R2_within = " %9.6f `r2_3'
di _newline "If paircell FE coefficient << baseline, confirms low within-cell persistence"

restore

********************************************************************************
* STEP 3: RUN ON FULL DATA (if subsample worked)
********************************************************************************

di _newline(2) "=== Running on FULL dataset ==="

* Create paircell group on full data - this may take time
di "Creating paircell identifier on full data..."
egen paircell = group(cell_min cell_max)
di "Number of unique paircells: "
distinct paircell

* --- Full Specification 1: Baseline ---
di _newline "--- Full Spec 1: Baseline ---"
timer on 2
reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    noabsorb vce(robust)
timer off 2
estimates store full_baseline
local fb1 = _b[z_bilateral_conn_pre]
local fr2_1 = e(r2)

* --- Full Specification 2: With interaction ---
di _newline "--- Full Spec 2: With interaction ---"
timer on 3
reghdfe z_bilateral_conn_post z_bilateral_conn_pre pre_x_same_indmicro ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    noabsorb vce(robust)
timer off 3
estimates store full_interaction
local fb2_main = _b[z_bilateral_conn_pre]
local fb2_int = _b[pre_x_same_indmicro]
local fr2_2 = e(r2)

* --- Full Specification 3: With paircell FE ---
di _newline "--- Full Spec 3: With paircell FE (may take a while) ---"
timer on 4
reghdfe z_bilateral_conn_post z_bilateral_conn_pre ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    absorb(paircell) vce(robust)
timer off 4
estimates store full_paircell
local fb3 = _b[z_bilateral_conn_pre]
local fr2_3 = e(r2_within)

********************************************************************************
* STEP 4: DISPLAY FINAL RESULTS
********************************************************************************

di _newline(3) "========================================"
di "        FULL DATASET RESULTS SUMMARY"
di "========================================"
di _newline "Observations: " _N
di _newline "Specification                          beta_pre      R2"
di "---------------------------------------------------------------"
di "1. Baseline (no FE)                    " %9.6f `fb1' "   " %9.6f `fr2_1'
di "2. + Interaction (pre × same_indmicro)"
di "      main effect:                     " %9.6f `fb2_main'
di "      interaction:                     " %9.6f `fb2_int' "   " %9.6f `fr2_2'
di "3. + Paircell FE                       " %9.6f `fb3' "   " %9.6f `fr2_3' " (within)"
di "---------------------------------------------------------------"
di _newline "Interpretation:"
di "- If beta_pre in Spec 3 << Spec 1: most persistence is between-paircell"
di "- If interaction in Spec 2 is negative: same-cell pairs have weaker persistence"
di "- Decomposition found within-cell R2 = 3.1%, between-cell R2 = 18.6%"

timer off 1
timer list

di _newline "=== DONE ==="
