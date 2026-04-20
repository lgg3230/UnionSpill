********************************************************************************
* Program:    prep_entry_exit_data.do
* Purpose:    Build analysis-ready dataset for entry/exit regressions.
*             Merges CBA variables from the main balanced dataset onto the
*             unbalanced panel. Resolves missing microregion and industry1
*             for the ~2,840 exiting firms not in the balanced dataset.
*             Creates presence indicators and expands to all firm×year cells.
* Inputs:     cba_rais_firm_unbal_flows.dta  (unbalanced outcomes + connectivity)
*             lagos_sample_sep24_pct_unionexp_ext_df2.dta  (main CBA vars)
*             mun_microregion_ibge.dta        (municipio → microregion crosswalk)
*             rais_firm_2009.dta              (industry1 for extra firms)
*             totalflows_wide_2007_2011.csv   (pre-treatment total flows bins)
* Output:     Data/entry_exit/entry_exit_panel.dta
* Called by:  _run_entry_exit.do (stage 4)
********************************************************************************

version 17.0
set more off

di "=== prep_entry_exit_data.do started: `c(current_date)' `c(current_time)' ==="

********************************************************************************
* SECTION 1: LOAD UNBALANCED PANEL
********************************************************************************

use "$rais_firm/cba_rais_firm_unbal_flows.dta", clear
keep if lagos_sample_unbal_avg == 1

di "Obs in unbalanced panel (lagos_sample_unbal_avg==1): " _N

********************************************************************************
* SECTION 2: MERGE CBA VARIABLES FROM MAIN BALANCED DATASET
* (1:1 on identificad × year — gives vars for the 16,471 overlapping firms)
********************************************************************************

preserve
    use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
    keep identificad year industry1 microregion mode_base_month ///
         numb_clauses cba_period avg_file_date earliest2009_avg second_cba_avg ///
         lr_remdezr_w lr_remdezr_h_w ///
         pre_treat_cba post_treat_cba
    tempfile main_vars
    save `main_vars'
restore

merge 1:1 identificad year using `main_vars', keep(master match) nogen

* Flag extra firms (not in balanced dataset → CBA vars are still missing)
cap drop _extra_firm
gen byte _extra_firm = missing(microregion)
count if _extra_firm == 1 & year == 2009
di "Extra (exiting) firms with missing CBA vars in 2009: " r(N)

********************************************************************************
* SECTION 3: FILL MICROREGION FOR EXTRA FIRMS (via municipio crosswalk)
********************************************************************************

preserve
    use "$main/UnionSpill/Data/IBGE/mun_microregion_ibge.dta", clear
    * crosswalk has both as str; destring microregion to match main dataset (long)
    destring microregion, replace force
    rename microregion microregion_ibge
    tempfile crosswalk
    save `crosswalk'
restore

* municipio is str6 in both datasets → merge directly
merge m:1 municipio using `crosswalk', keep(master match) nogen

replace microregion = microregion_ibge if _extra_firm == 1 & !missing(microregion_ibge)
cap drop microregion_ibge

count if _extra_firm == 1 & missing(microregion)
di "Extra firms still missing microregion after crosswalk: " r(N)

********************************************************************************
* SECTION 4: FILL INDUSTRY1 FOR EXTRA FIRMS (from RAIS 2009)
* industry1 = real("1" + substr(clascnae20, 1, 3)) per 041_merge_cba_rais.do
********************************************************************************

* Build a list of extra firm IDs
preserve
    keep if _extra_firm == 1
    keep identificad
    bys identificad: keep if _n == 1
    tempfile extra_ids
    save `extra_ids'
restore

preserve
    use "$rais_firm/rais_firm_2009.dta", clear
    keep identificad clascnae20
    bys identificad: keep if _n == 1
    * Only keep extra firms
    merge 1:1 identificad using `extra_ids', keep(match) nogen
    * Compute industry1 the same way as 041_merge_cba_rais.do
    gen industry1_rais = real("1" + substr(clascnae20, 1, 3))
    keep identificad industry1_rais
    tempfile industry_extra
    save `industry_extra'
restore

merge m:1 identificad using `industry_extra', keep(master match) nogen
replace industry1 = industry1_rais if _extra_firm == 1 & !missing(industry1_rais)
cap drop industry1_rais

count if _extra_firm == 1 & missing(industry1)
di "Extra firms still missing industry1 after RAIS 2009 lookup: " r(N)

********************************************************************************
* SECTION 4b: FILL MODE_BASE_MONTH FOR EXTRA FIRMS (from CBA dataset)
* mode_base_month is missing for extra firms after the Section 2 merge because
* those firms are not in the balanced sample. However, they satisfy the CBA
* requirement (just not the employment/pos_emp requirement), so mode_base_month
* should be available in the CBA firm-level dataset.
* NOTE: Use save/reload instead of preserve to avoid double-memory with a
*       large (465-var) source file.
********************************************************************************

* Save current panel to tempfile
tempfile analysis_panel_4b
save `analysis_panel_4b'

* Load CBA dataset — keep only what is needed, filter to extra firms only
* `extra_ids' tempfile from Section 4 still holds the 1,476 extra firm IDs
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep identificad mode_base_month
bys identificad: keep if _n == 1
merge 1:1 identificad using `extra_ids', keep(match) nogen
rename mode_base_month mode_base_month_cba
tempfile mbm_cba
save `mbm_cba'

* Restore panel and merge
use `analysis_panel_4b', clear
merge m:1 identificad using `mbm_cba', keep(master match) nogen
replace mode_base_month = mode_base_month_cba if _extra_firm == 1 & missing(mode_base_month)
cap drop mode_base_month_cba

count if _extra_firm == 1 & missing(mode_base_month)
di "Extra firms still missing mode_base_month after CBA lookup: " r(N)

********************************************************************************
* SECTION 5: TOTALFLOWS PRE-TREATMENT BINS
* totalflows_pw_pre_07_114: 4-bin quartile cut of avg 2007-2011 per-worker flows
* Balanced-panel firms: compute from totalflows_wide_2007_2011.csv
* Extra (exiting) firms: assign 0 (reference bin — not in the flows CSV)
********************************************************************************

preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile tf_wide
    save `tf_wide'
restore

merge m:1 identificad using `tf_wide', keep(master match) nogen

* Average per-worker pairwise flows over 2007-2011 year pairs
cap drop totalflows_pw_pre_07_11
cap drop _tf_cnt
gen double totalflows_pw_pre_07_11 = 0
gen byte   _tf_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    capture confirm variable `yp'
    if _rc == 0 {
        replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
        replace _tf_cnt = _tf_cnt + 1 if !missing(`yp')
    }
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / _tf_cnt if _tf_cnt > 0
replace totalflows_pw_pre_07_11 = . if _tf_cnt == 0
cap drop _tf_cnt
cap drop totalflows_07_08
cap drop totalflows_08_09
cap drop totalflows_09_10
cap drop totalflows_10_11
cap drop totalflows_pw_07_08
cap drop totalflows_pw_08_09
cap drop totalflows_pw_09_10
cap drop totalflows_pw_10_11

* 4-bin quartile cut from year-2009 obs; 0 = extra firms or no flows
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009, group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}
label var totalflows_pw_pre_07_114 "4-bin totalflows pw 2007-2011 (0=extra/no-flow firms)"
cap drop totalflows_pw_pre_07_11

********************************************************************************
* SECTION 6: CONNECTIVITY SCALING
* Normalize totaltreat_pw_n by p90 of the unbalanced spillover sample in 2009
********************************************************************************

cap drop totaltreat_pw_norm
sum totaltreat_pw_n if lagos_sample_unbal_avg==1 & treat_ultra==0 & year==2009, detail
local p90_unbal = r(p90)
di "p90 of totaltreat_pw_n (unbal spillover, 2009) = " `p90_unbal'
gen double totaltreat_pw_norm = totaltreat_pw_n / `p90_unbal'
label var totaltreat_pw_norm "Connectivity scaled to p90 of unbal spillover sample (2009)"

********************************************************************************
* SECTION 7: WAGE FOR EXTRA FIRMS
* lr_remdezr_w and lr_remdezr_h_w come from the worker-level dataset (_w =
* worker-level source, not winsorized). For the 16,471 overlapping firms they
* are already merged from the main dataset in Section 2.
* For the ~2,840 extra (exiting) firms not in the balanced sample, we fill
* lr_remdezr_w from lr_remdezr in the unbalanced panel — both are computed
* from the same RAIS spell-selected worker records in rais_firm_YYYY.dta.
* lr_remdezr_h_w (hourly) is not available in the unbalanced panel; those
* firms remain missing for hourly wage regressions.
********************************************************************************

replace lr_remdezr_w = lr_remdezr if _extra_firm == 1 & missing(lr_remdezr_w)
label var lr_remdezr_w "Log real Dec wage, worker-level (main dataset or RAIS unbal)"

count if _extra_firm == 1 & missing(lr_remdezr_w)
di "Extra firms still missing lr_remdezr_w: " r(N)

********************************************************************************
* SECTION 8: ENTRY/EXIT INDICATORS (before expand)
********************************************************************************

* present_in_year: always 1 at this stage (real observations)
cap drop present_in_year
gen byte present_in_year = 1
label var present_in_year "Firm has real observations in this year"

* present_all_pretreat: firm observed in ALL of 2009, 2010, 2011
cap drop _pretreat_yrs
cap drop present_all_pretreat
bys identificad: egen _pretreat_yrs = total(inrange(year,2009,2011))
gen byte present_all_pretreat = (_pretreat_yrs == 3)
cap drop _pretreat_yrs
label var present_all_pretreat "Firm observed in all pretreatment years (2009, 2010, 2011)"

* present_all_analysis: firm observed in all 8 analysis years (2009-2016)
cap drop present_all_analysis
gen byte present_all_analysis = in_balanced_panel
label var present_all_analysis "Firm observed in all analysis years (2009-2016)"

********************************************************************************
* SECTION 9: TREATMENT TIMING INDICATORS
********************************************************************************

cap drop treat_year
cap drop placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year <  2011)
label var treat_year   "Post-treatment period (year >= 2012)"
label var placebo_year "Pre-treatment period (year < 2011)"

********************************************************************************
* SECTION 10: PRE-TREATMENT MEANS AND 4-BIN CONTROLS
********************************************************************************

* Pre-treatment firm employment (average 2009-2011, then log)
cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
    bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
    drop firm_emp_pre_o
}
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment (avg 2009-2011)"

* Pre-treatment outcome means for bins
cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
quietly {
    bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year,2009,2011)
    bys identificad: egen lr_remdezr_w_pre   = min(lr_remdezr_w_pre_o)
    drop lr_remdezr_w_pre_o
}
label var lr_remdezr_w_pre "Pre-treatment mean log real wage (avg 2009-2011)"

* 4-bin quartile cuts (from 2009 observations, full unbalanced sample)
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
    replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)
}
label var l_firm_emp_pre4 "Quartile bin of log pre-treatment employment (0=ref)"

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
quietly {
    egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) if year == 2009, group(4)
    bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
    drop lr_remdezr_w_pre4_o
    replace lr_remdezr_w_pre4 = 0 if missing(lr_remdezr_w_pre4)
}
label var lr_remdezr_w_pre4 "Quartile bin of pre-treatment log real wage (0=ref)"

cap drop lr_remdezr_h_w_pre_o
cap drop lr_remdezr_h_w_pre
quietly {
    bys identificad: egen lr_remdezr_h_w_pre_o = mean(lr_remdezr_h_w) if inrange(year,2009,2011)
    bys identificad: egen lr_remdezr_h_w_pre   = min(lr_remdezr_h_w_pre_o)
    drop lr_remdezr_h_w_pre_o
}
label var lr_remdezr_h_w_pre "Pre-treatment mean log real hourly wage (avg 2009-2011)"

cap drop lr_remdezr_h_w_pre4_o
cap drop lr_remdezr_h_w_pre4
quietly {
    egen lr_remdezr_h_w_pre4_o = cut(lr_remdezr_h_w_pre) if year == 2009, group(4)
    bys identificad: egen lr_remdezr_h_w_pre4 = min(lr_remdezr_h_w_pre4_o)
    drop lr_remdezr_h_w_pre4_o
    replace lr_remdezr_h_w_pre4 = 0 if missing(lr_remdezr_h_w_pre4)
}
label var lr_remdezr_h_w_pre4 "Quartile bin of pre-treatment log real hourly wage (0=ref)"

* numb_clauses pre-treatment bins (CBA firms only)
capture confirm variable numb_clauses
if _rc == 0 {
    cap drop numb_clauses_pre_o
    cap drop numb_clauses_pre
    cap drop numb_clauses_pre4_o
    cap drop numb_clauses_pre4
    quietly {
        bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) ///
            if inrange(cba_period,1,2)
        bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
        drop numb_clauses_pre_o
        * bin within firms that have any CBA observation in 2009
        egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009, group(4)
        bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
        drop numb_clauses_pre4_o
        replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
    }
    label var numb_clauses_pre  "Pre-treatment mean clause count (CBA periods 1-2)"
    label var numb_clauses_pre4 "Quartile bin of pre-treatment clause count (0=ref)"
}

********************************************************************************
* SECTION 11: EXPAND TO FULL FIRM×YEAR PANEL (2009-2016)
* After expansion, present_in_year=0 marks padded (synthetic) rows.
* Outcomes and year-varying vars are missing in padded rows.
********************************************************************************

* fillin creates all firm×year combinations; _fillin=1 for new rows
fillin identificad year

* diagnostics: are firms entering/exiting?
bysort year: tab _fillin // ->  detects in which year there are more or less observations
// pattern is clear: in 2009 there where zero firms with fillin==1, this means that no obs 
// were added that year -> there is net exit of firms

* all firms have connectivity in 2009?

count if missing(totaltreat_pw_n) & year==2009 // -> there are 5

* all firms have positive employmetn in 2009?

count if firm_emp>0 & !missing(l_firm_emp)  & year==2009 // yes, they do




replace present_in_year = 0 if _fillin == 1
drop _fillin

* Recreate time dummies (needed for padded rows too)
cap drop treat_year
cap drop placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year <  2011)

* Fill firm-level constants into padded rows using pre-treatment observations as source
* (year <= 2011 & present_in_year == 1). Entrant firms with no pre-treatment presence
* remain missing and are naturally excluded from the LPM regressions.
* NOTE: the previous bys (present_in_year v) approach was broken — padded rows
* (present_in_year=0) sorted first, so v[1] was always missing.
foreach v in treat_ultra microregion industry1 mode_base_month ///
             in_balanced_panel lagos_sample_unbal_avg ///
             present_all_pretreat present_all_analysis ///
             l_firm_emp_pre l_firm_emp_pre4 ///
             lr_remdezr_w_pre lr_remdezr_w_pre4 ///
             lr_remdezr_h_w_pre lr_remdezr_h_w_pre4 ///
             totalflows_pw_pre_07_114 {
    capture confirm variable `v'
    if _rc == 0 {
        gen double _src_fill = `v' if year <= 2011 & present_in_year == 1
        bys identificad: egen double _val_fill = min(_src_fill)
        replace `v' = _val_fill if missing(`v') & !missing(_val_fill)
        cap drop _src_fill
        cap drop _val_fill
    }
}

* Fill numb_clauses pre-treatment constants if available
foreach v in numb_clauses_pre numb_clauses_pre4 {
    capture confirm variable `v'
    if _rc == 0 {
        gen double _src_fill = `v' if year <= 2011 & present_in_year == 1
        bys identificad: egen double _val_fill = min(_src_fill)
        replace `v' = _val_fill if missing(`v') & !missing(_val_fill)
        cap drop _src_fill
        cap drop _val_fill
    }
}

* Fill connectivity measures into padded rows using pre-treatment observations only
* (year <= 2011 & present_in_year == 1 as source; entrant firms remain missing)
foreach v in totaltreat_pw_n totaltreat_pw_norm {
    capture confirm variable `v'
    if _rc == 0 {
        gen double _pretreat_val = `v' if year <= 2011 & present_in_year == 1
        bys identificad: egen double _fill_val = min(_pretreat_val)
        replace `v' = _fill_val if missing(`v') & !missing(_fill_val)
        cap drop _pretreat_val
        cap drop _fill_val
    }
}

********************************************************************************
* SECTION 12: SAVE
********************************************************************************

di "=== Summary ==="
di "Total obs (expanded panel): " _N
count if present_in_year == 1
di "Real obs: " r(N)
count if present_in_year == 0
di "Padded obs (firm absent in year): " r(N)
count if present_in_year == 1 & present_all_pretreat == 1
di "Real obs, present all pretreat years: " r(N)

compress
save "$main/UnionSpill/Data/entry_exit/entry_exit_panel.dta", replace

di "=== prep_entry_exit_data.do done: `c(current_date)' `c(current_time)' ==="
