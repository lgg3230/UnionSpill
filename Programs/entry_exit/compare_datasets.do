********************************************************************************
* ENTRY/EXIT PIPELINE — DATASET COMPARISON
* Compares cba_rais_firm_unbal_flows.dta (new, unbalanced)
*      vs  cba_rais_firm_2009_2016_flows_1.dta (existing, balanced-panel sample)
*
* Restricts both datasets to 2009-2016 (analysis years).
* Generates a summary comparison CSV at $tables/comparison_summary.csv
********************************************************************************

version 17.0
set more off
clear all

global klc       "/kellogg/proj/lgg3230"
global main      "$klc"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables/entry_exit"

********************************************************************************
** PART 0 — Label helpers
********************************************************************************

* Used to label samples in output
label define samp_lbl 0 "Balanced (existing)" 1 "Unbalanced (new)"

********************************************************************************
** PART 1 — Load OLD dataset, tag, keep analysis years
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if inrange(year, 2009, 2016)
keep if lagos_sample_avg == 1 & in_balanced_panel == 1   // baseline restriction used in results.do

gen sample = 0
label values sample samp_lbl

tempfile old_data
save `old_data'

********************************************************************************
** PART 2 — Load NEW dataset, tag, keep analysis years
********************************************************************************

// New dataset saved as .dta by merge_connectivity_unbal.py
use "$rais_firm/cba_rais_firm_unbal_flows.dta", clear
keep if lagos_sample_unbal_avg == 1   // CBA requirement, no pos_emp

gen sample = 1
label values sample samp_lbl

tempfile new_data
save `new_data'

********************************************************************************
** PART 3 — Firm-level presence indicator
********************************************************************************

* For each dataset, mark whether a firm is present in every year 2009-2016
foreach ds in old new {
    use ``ds'_data', clear

    forvalues y = 2009/2016 {
        gen _has`y' = (year == `y')
        bys identificad: egen _present`y' = max(_has`y')
        drop _has`y'
    }

    gen present_all_years = (_present2009 == 1 & _present2010 == 1 & ///
        _present2011 == 1 & _present2012 == 1 & _present2013 == 1 & ///
        _present2014 == 1 & _present2015 == 1 & _present2016 == 1)

    drop _present*
    save ``ds'_data', replace
}

********************************************************************************
** PART 4 — Stack for comparison
********************************************************************************

use `old_data', clear
append using `new_data'

* Neutral counter for collapse (avoids conflict with by-variables)
gen byte _one = 1

********************************************************************************
** PART 5 — Comparison table 1: Observation and firm counts
********************************************************************************

* Total obs per sample × year
preserve
    collapse (count) n_obs = _one, by(sample year)
    list, sep(0)
    export delimited "$tables/compare_obs_by_year.csv", replace
restore

* Unique firms per sample
preserve
    bys sample identificad: keep if _n == 1
    collapse (count) n_firms = _one, by(sample)
    list
    export delimited "$tables/compare_firm_counts.csv", replace
restore

* Treatment breakdown per sample
preserve
    bys sample identificad: keep if _n == 1
    collapse (count) n_firms = _one (sum) n_treat = treat_ultra, by(sample)
    gen n_control = n_firms - n_treat
    list
    export delimited "$tables/compare_treat_counts.csv", replace
restore

* Firms present in all 8 years vs not
preserve
    bys sample identificad: keep if _n == 1
    collapse (sum) n_full_panel = present_all_years (count) n_firms = _one, by(sample)
    gen share_full_panel = n_full_panel / n_firms
    list
    export delimited "$tables/compare_panel_balance.csv", replace
restore

********************************************************************************
** PART 6 — Comparison table 2: Mean outcomes by sample
********************************************************************************

preserve
    keep if inrange(year, 2009, 2016)
    collapse (mean) mean_l_firm_emp    = l_firm_emp     ///
                    mean_lr_remdezr    = lr_remdezr     ///
                    mean_lr_remmedr    = lr_remmedr      ///
                    mean_treat_ultra   = treat_ultra     ///
                    mean_avg_ftreat_pf_n = avg_ftreat_pf_n ///
                    (sd)   sd_l_firm_emp  = l_firm_emp   ///
                           sd_lr_remdezr = lr_remdezr    ///
             , by(sample)
    list, sep(0)
    export delimited "$tables/compare_means.csv", replace
restore

********************************************************************************
** PART 7 — Comparison table 3: Means by treat_ultra × sample
********************************************************************************

preserve
    keep if inrange(year, 2009, 2016)
    collapse (mean) mean_l_firm_emp  = l_firm_emp   ///
                    mean_lr_remdezr  = lr_remdezr   ///
                    mean_avg_ftreat_pf_n = avg_ftreat_pf_n ///
             , by(sample treat_ultra)
    list, sep(0)
    export delimited "$tables/compare_means_by_treat.csv", replace
restore

********************************************************************************
** PART 8 — Comparison table 4: Connectivity distribution
********************************************************************************

preserve
    keep if year == 2011   // one obs per firm, pre-treatment
    foreach ds_val in 0 1 {
        sum avg_ftreat_pf_n if sample == `ds_val', detail
    }
    collapse (p10) p10 = avg_ftreat_pf_n ///
             (p25) p25 = avg_ftreat_pf_n ///
             (p50) p50 = avg_ftreat_pf_n ///
             (p75) p75 = avg_ftreat_pf_n ///
             (p90) p90 = avg_ftreat_pf_n ///
             (mean) mean = avg_ftreat_pf_n ///
             (count) n = avg_ftreat_pf_n ///
             , by(sample)
    list, sep(0)
    export delimited "$tables/compare_connectivity_dist.csv", replace
restore

********************************************************************************
** PART 9 — Comparison table 5: Entry/exit counts
**   For the NEW dataset only — classify firms by first/last year observed
********************************************************************************

preserve
    keep if sample == 1
    bys identificad: egen first_year = min(year)
    bys identificad: egen last_year  = max(year)
    bys identificad: keep if _n == 1

    * Entrants: first appear after 2009
    gen entrant    = (first_year > 2009)
    * Exiters: last observed before 2016
    gen exiter     = (last_year < 2016)
    * Always present
    gen always_in  = (first_year == 2009 & last_year == 2016)

    tab treat_ultra entrant,   row
    tab treat_ultra exiter,    row
    tab treat_ultra always_in, row

    collapse (count) n_firms = _one ///
             (sum) n_entrant = entrant n_exiter = exiter n_always = always_in ///
             , by(treat_ultra)
    list, sep(0)
    export delimited "$tables/compare_entry_exit_counts.csv", replace
restore

********************************************************************************
** PART 10 — New firms in unbalanced: not in balanced sample
********************************************************************************

* Firms in new dataset but NOT in old dataset
preserve
    use `new_data', clear
    bys identificad: keep if _n == 1
    gen in_new = 1
    tempfile new_ids
    save `new_ids'

    use `old_data', clear
    bys identificad: keep if _n == 1
    gen in_old = 1
    merge 1:1 identificad using `new_ids', nogen keepusing(in_new)
    replace in_new = 0 if missing(in_new)
    replace in_old = 0 if missing(in_old)

    gen status = ""
    replace status = "only_old" if in_old == 1 & in_new == 0
    replace status = "only_new" if in_old == 0 & in_new == 1
    replace status = "both"     if in_old == 1 & in_new == 1

    tab status
    gen byte _one = 1
    collapse (count) n = _one (mean) treat_ultra, by(status)
    list, sep(0)
    export delimited "$tables/compare_firm_overlap.csv", replace
restore

di "=== Comparison complete. CSVs written to $tables ==="

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Comparison done" "compare_datasets.do finished"
