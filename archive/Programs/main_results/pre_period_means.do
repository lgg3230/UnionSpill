********************************************************************************
* STAGE 0: CANONICAL PRE-PERIOD MEANS
*
* Purpose: One canonical source of pre-period dependent-variable means for every
*          regression table in the Replication report.
*
* Convention (revision plan 2026-07-30, task 6):
*   - Mean is over TREATED AND CONTROL OBSERVATIONS POOLED, i.e. over each
*     panel's ESTIMATION SAMPLE, not the control group alone.
*   - Pre period is 2009-2011, via the house `<outcome>_pre` construction:
*     firm-level mean of the outcome over 2009-2011, evaluated once per firm
*     at year == 2009.
*
*   DELIBERATE DEPARTURE FROM EXISTING CODE:
*   4092_composition.do and 4082_turnover.do currently compute
*   their mean_pre row over the CONTROL GROUP ONLY (`s_use_pre` excludes
*   treated firms), even though the table note in Draft.tex reads "average
*   across establishments in each panel's estimation sample". This script
*   implements the note's (and the revision request's) definition: pooled over
*   the estimation sample. Composition and turnover means are regenerated from
*   this file so every table shares one definition.
*
* Connectivity: uses whatever panel $rais_firm points at. The current-
*   connectivity wrapper points it at CBA_RAIS_firm_level_currentconn_overlay,
*   where totaltreat_pw_n is the current recomputable measure. This script uses
*   totaltreat_pw_n only for SAMPLE DEFINITION (==0, <=0.01), never normalized,
*   so it does not depend on totaltreat_pw_norm.
*
* Output: $tables/pre_period_means.csv
*         sample_id;outcome_var;mean;sd;n_obs;n_estabs;pre_window
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/pre_period_means_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Panel source: $rais_firm"
di "Tables target: $tables"

********************************************************************************
* SECTION 1: DATA
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Panel rows after sample keep: " _N

********************************************************************************
* SECTION 2: SAMPLE DEFINITIONS
********************************************************************************
* Copied verbatim from 4092_composition.do (lines 256-259).

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

local sample_ids "direct_A direct_B direct_C spill"

********************************************************************************
* SECTION 3: OUTCOME LIST
********************************************************************************
* Union of outcomes in the Replication report's regression tables. Variables
* absent from this panel are skipped and reported.

local cand_outcomes ""
local cand_outcomes "`cand_outcomes' lr_remdezr_w lr_remdezr_h_w l_firm_emp"
local cand_outcomes "`cand_outcomes' numb_clauses l_numb_clauses"
local cand_outcomes "`cand_outcomes' avg_tenure male_prop white_prop prop_nhs prop_hs prop_sup prop_hs_plus avg_age"
local cand_outcomes "`cand_outcomes' l_avg_tenure l_male_prop l_white_prop l_prop_nhs l_prop_hs l_prop_sup l_prop_hs_plus l_avg_age"
local cand_outcomes "`cand_outcomes' retention_u retention_yoy_u hiring_rate_u turnover_u quit_rate_u layoff_rate_u churn_rate_u l_total_hours"

local outcomes ""
local skipped  ""
foreach v of local cand_outcomes {
	capture confirm variable `v'
	if _rc == 0 {
		local outcomes "`outcomes' `v'"
	}
	else {
		local skipped "`skipped' `v'"
	}
}

di as result "Outcomes found:  `outcomes'"
di as result "Outcomes SKIPPED (not in panel): `skipped'"

********************************************************************************
* SECTION 4: PRE-PERIOD FIRM AVERAGES
********************************************************************************
* House construction, copied from main_results.do lines 110-117.

foreach outcome of local outcomes {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

di as result "Pre-period firm averages built."

********************************************************************************
* SECTION 5: WRITE CSV
********************************************************************************

capture erase "$tables/pre_period_means.csv"
tempname fh
file open `fh' using "$tables/pre_period_means.csv", write replace
file write `fh' "sample_id;outcome_var;mean;sd;n_obs;n_estabs;pre_window" _n
file close `fh'

local csv "$tables/pre_period_means.csv"

foreach sid of local sample_ids {
	local cond "`s_`sid''"
	di as result _newline "=== SAMPLE: `sid' ==="
	di "   condition: `cond'"

	foreach outcome of local outcomes {

		* Pooled over the estimation sample, one obs per firm (year 2009)
		quietly sum `outcome'_pre if `cond' & year == 2009
		local m   = r(mean)
		local sd  = r(sd)
		local nes = r(N)

		* Underlying pre-period firm-year count
		quietly count if `cond' & inrange(year, 2009, 2011) & !missing(`outcome')
		local nob = r(N)

		file open `fh' using "`csv'", write append
		file write `fh' `""`sid'";"`outcome'";"' %12.4f (`m') `";"' %12.4f (`sd') ///
			`";"' %12.0f (`nob') `";"' %12.0f (`nes') `";"2009-2011""' _n
		file close `fh'

		di "   `outcome': mean=" %9.4f `m' "  n_estabs=" `nes'
	}
}

di as result _newline "Written: `csv'"

********************************************************************************
* SECTION 6: SANITY CHECKS
********************************************************************************

di as result _newline "=== SANITY CHECKS ==="

foreach sid of local sample_ids {
	quietly sum lr_remdezr_w_pre if `s_`sid'' & year == 2009
	local m = r(mean)
	di "lr_remdezr_w  `sid': " %9.4f `m' "   implied R$ " %9.1f exp(`m')
	if (`m' < 7.0 | `m' > 9.0) di as error "  ^^ OUT OF PLAUSIBLE RANGE (expected 7.0-9.0)"
}

foreach sid of local sample_ids {
	quietly sum l_firm_emp_pre if `s_`sid'' & year == 2009
	local m = r(mean)
	di "l_firm_emp    `sid': " %9.4f `m' "   implied headcount " %9.1f exp(`m')
	if (`m' < 1.5 | `m' > 6.0) di as error "  ^^ OUT OF PLAUSIBLE RANGE (expected 1.5-6.0)"
}

capture confirm variable numb_clauses_pre
if _rc == 0 {
	foreach sid of local sample_ids {
		quietly sum numb_clauses_pre if `s_`sid'' & year == 2009
		local m = r(mean)
		di "numb_clauses  `sid': " %9.4f `m'
		if (`m' < 15 | `m' > 45) di as error "  ^^ OUT OF PLAUSIBLE RANGE (expected 15-45)"
	}
}

di as result _newline "Outcomes SKIPPED (not in panel): `skipped'"

log close
di as result "Finished: `c(current_date)' `c(current_time)'"
