********************************************************************************
* PROJECT: UNION SPILLOVERS — Randomization inference (Referee 3)
* PROGRAM: 2107_export_bin_keys.do
* PURPOSE: Export pre-treatment size and wage bins per firm, to add to the
*          industry x negotiation-month reshuffle cells (2108, 2093).
*          Bins are the main-specification controls (2091, lines 64-103) cut at
*          4, 10 and 20 groups, as in the finer-bins robustness (3052):
*            size<k>  : l_firm_emp_pre    (log mean employment 2009-2011)
*            wage<k>  : lr_remdezr_h_w_pre (mean log hourly wage 2009-2011)
*          Cut points use 2009 balanced-panel firms, so size4 / wage4 equal
*          l_firm_emp_pre4 / lr_remdezr_h_w_pre4 (asserted below).
* OUTPUT:  Data/rand_inference/firm_bins_pre.csv (one row per firm in
*          firm_keys_2009_ext.csv; bins missing outside the balanced panel)
********************************************************************************
version 17.0
clear all
set more off

if "$root" == "" global root "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$root/Data/CBA_RAIS_firm_level"
global outdir    "$root/Data/rand_inference"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── pre-treatment means (verbatim, 2091) ────────────────────────────────────
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	bys identificad: egen lr_remdezr_h_w_pre_o = mean(lr_remdezr_h_w) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_h_w_pre = min(lr_remdezr_h_w_pre_o)
	drop lr_remdezr_h_w_pre_o
}
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── bins: 2009 balanced-panel cut points, constant within firm ──────────────
foreach k in 4 10 20 {
	quietly {
		egen size`k'_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(`k')
		bys identificad: egen size`k' = min(size`k'_o)
		egen wage`k'_o = cut(lr_remdezr_h_w_pre) if year == 2009 & in_balanced_panel == 1, group(`k')
		bys identificad: egen wage`k' = min(wage`k'_o)
		drop size`k'_o wage`k'_o
	}
}

* ── check: quartiles are the main-specification bins ───────────────────────
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	egen lr_remdezr_h_w_pre4_o = cut(lr_remdezr_h_w_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_h_w_pre4 = min(lr_remdezr_h_w_pre4_o)
}
assert size4 == l_firm_emp_pre4
assert wage4 == lr_remdezr_h_w_pre4

* ── export: same firm universe as firm_keys_2009_ext.csv (2091) ─────────────
keep if lagos_sample_avg == 1 & year == 2009
keep identificad in_balanced_panel l_firm_emp_pre lr_remdezr_h_w_pre size4 size10 size20 wage4 wage10 wage20
order identificad
foreach v in size4 size10 size20 wage4 wage10 wage20 {
	quietly count if missing(`v') & in_balanced_panel == 1
	di as result "`v': " r(N) " balanced firms with missing bin"
}
drop in_balanced_panel
compress
export delimited using "$outdir/firm_bins_pre.csv", replace
di as result "Exported firm_bins_pre.csv: " _N " rows"
