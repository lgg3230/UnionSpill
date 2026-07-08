********************************************************************************
* PROJECT: UNION SPILLOVERS — Randomization inference (Task 5)
* PROGRAM: 02_export_regression_frame.do
* PURPOSE: Reproduce the EXACT pre-treatment construction + FE bins used by the
*          spillover spec (Main_Results_pct_tfpw_07_11.do), export a clean
*          regression frame (all Lagos balanced firms) for the Python permutation
*          engine, and record the published baseline spillover coefficients as
*          the validation target.
* NOTE:    Pre-treatment bins are treated-set-INDEPENDENT (fixed across placebo
*          replications); only connectivity changes. Construction copied verbatim
*          from Main_Results lines 109-329.
********************************************************************************
version 17.0
clear all
set more off

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global outdir    "$main/UnionSpill/Data/rand_inference"
global logs      "$main/UnionSpill/Logs/rand_inference"

local d : display %tdDD_Mon_CCYY date(c(current_date), "DMY")
local d = subinstr(trim("`d'"), " ", "_", .)
log using "$logs/02_export_regression_frame_`d'.log", replace text

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── merge total pre-treatment pairwise flows (verbatim, Main_Results 70-91) ──
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

* ── period indicators (verbatim) ────────────────────────────────────────────
cap drop placebo_year
gen byte placebo_year = (year < 2011)
cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── connectivity scaling (verbatim) ─────────────────────────────────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── pre-treatment means for base outcomes (verbatim) ────────────────────────
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── 4-bin controls (verbatim) ───────────────────────────────────────────────
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── CBA-period structure + clause-count bins (verbatim, for numb_clauses) ────
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
cap drop pre_treat_cba
gen pre_treat_cba = cond(cba_period < 2, 1, 0)
cap drop post_treat_cba
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}
cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
	replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
}

* ── BASELINE COEFFICIENTS: spillover (conn) and direct Panel A (treated) ─────
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local conn        "totaltreat_pw_norm"
local s_direct_A  "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

capture postutil clear
tempname pf
postfile `pf' str12 mode str20 outcome double bhat double se double nobs double nclust ///
	using "$outdir/baseline_coefs.dta", replace

* Spillover (untreated sample; conn x post). Year outcomes then clause count.
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', absorb(`absorb') vce(cluster identificad)
	post `pf' ("spillover") ("`outcome'") (_b[1.treat_year#c.`conn']) (_se[1.treat_year#c.`conn']) (e(N)) (e(N_clust))
	di as result "SPILL `outcome': b = " %9.5f _b[1.treat_year#c.`conn']
}
local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), absorb(`absorb_cba') vce(cluster identificad)
post `pf' ("spillover") ("numb_clauses") (_b[1.post_treat_cba#c.`conn']) (_se[1.post_treat_cba#c.`conn']) (e(N)) (e(N_clust))
di as result "SPILL numb_clauses: b = " %9.5f _b[1.post_treat_cba#c.`conn']

* Direct effect, Panel A (treated + zero-connectivity controls; treated x post).
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
	reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A', absorb(`absorb') vce(cluster identificad)
	post `pf' ("direct") ("`outcome'") (_b[1.treat_ultra#1.treat_year]) (_se[1.treat_ultra#1.treat_year]) (e(N)) (e(N_clust))
	di as result "DIRECT `outcome': b = " %9.5f _b[1.treat_ultra#1.treat_year]
}
reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct_A' & !missing(cba_period), absorb(`absorb_cba') vce(cluster identificad)
post `pf' ("direct") ("numb_clauses") (_b[1.treat_ultra#1.post_treat_cba]) (_se[1.treat_ultra#1.post_treat_cba]) (e(N)) (e(N_clust))
di as result "DIRECT numb_clauses: b = " %9.5f _b[1.treat_ultra#1.post_treat_cba]
postclose `pf'

* ── EXPORT firm keys for CEM strata (ALL analysis-sample firms, 2009) ───────
* Strata built from the main-specification controls: industry, microregion,
* negotiation month, pre-treatment size, and pre-treatment worker flows.
preserve
	keep if lagos_sample_avg==1 & year==2009
	keep identificad treat_ultra in_balanced_panel totaltreat_pw_n ///
	     industry1 microregion mode_base_month ///
	     firm_emp l_firm_emp turnover totalflows_pw_pre_07_11
	order identificad
	compress
	export delimited using "$outdir/firm_keys_2009_ext.csv", replace
	di as result "Exported firm_keys_2009_ext.csv: " _N " rows"
restore

* ── EXPORT the regression frame (all analysis-sample balanced firms) ────────
keep if lagos_sample_avg==1 & in_balanced_panel==1

keep identificad year treat_ultra treat_year placebo_year ///
     cba_period pre_treat_cba post_treat_cba ///
     lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses ///
     industry1 mode_base_month microregion ///
     lr_remdezr_w_pre4 lr_remdezr_h_w_pre4 l_firm_emp_pre4 numb_clauses_pre4 totalflows_pw_pre_07_114 ///
     totaltreat_pw_n totaltreat_pw_norm totaltreat_pw_n_p90 ///
     firm_emp turnover

order identificad year
compress
save "$outdir/spill_frame.dta", replace
di as result "Exported spill_frame.dta: " _N " rows"

log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "rand_inference 02_export_regression_frame"
