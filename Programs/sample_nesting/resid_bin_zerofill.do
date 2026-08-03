********************************************************************************
* resid_bin_zerofill.do
*
* Why do establishments with a missing pre-treatment wage end up in bin 0 of the
* Mincer-residual control?
*
* Two things to establish:
*   (a) WHY the bin is missing before the fill. `egen cut(...) , group(4)` is
*       evaluated only on `year == 2009 & in_balanced_panel == 1`, so an
*       establishment gets no bin if it has no 2009 balanced-panel row OR if its
*       pre-treatment mean is itself missing.
*   (b) WHAT the fill does. cut(...) group(4) numbers bins 0,1,2,3, so bin 0 is
*       the BOTTOM QUARTILE, and the absorb uses ib0.<v>_pre4#i.year, making it
*       the omitted category. Filling missing with 0 therefore pools unknown
*       establishments together with genuine bottom-quartile ones rather than
*       giving them their own category.
*
* Output: counts only, to the log.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

global main      "/gpfs/kellogg/proj/lgg3230"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/sample_nesting/resid_bin_zerofill_`d'_`t'.log", replace text

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_firm/mincer_residuals_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile mincer
	save `mincer'
restore
merge 1:1 identificad year using `mincer', keep(master match) nogen

keep if year >= 2009
keep if lagos_sample_avg == 1

* Pre-treatment means, exactly as in Main_Results_mincer.do
foreach v in lr_remdezr_w lr_remdezr_resid {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* Bins BEFORE any zero-fill
foreach v in lr_remdezr_w lr_remdezr_resid {
	cap drop `v'_pre4_raw_o
	cap drop `v'_pre4_raw
	quietly {
		egen `v'_pre4_raw_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4_raw = min(`v'_pre4_raw_o)
		drop `v'_pre4_raw_o
	}
}

* Does the establishment have a 2009 balanced-panel row at all?
cap drop has_2009_bal
bysort identificad: egen byte has_2009_bal = max(year == 2009 & in_balanced_panel == 1)

preserve
	bysort identificad: keep if _n == 1

	di as result "=== Bin values produced by cut(..., group(4)) ==="
	di as result "(0 is the BOTTOM quartile and, via ib0., the omitted category)"
	tab lr_remdezr_resid_pre4_raw, missing

	di _newline(1)
	di as result "=== Why is the residual bin missing before the fill? ==="
	count if missing(lr_remdezr_resid_pre4_raw)
	di as result "  establishments with missing residual bin: " r(N)
	count if missing(lr_remdezr_resid_pre4_raw) & has_2009_bal == 0
	di as result "    no 2009 balanced-panel row:             " r(N)
	count if missing(lr_remdezr_resid_pre4_raw) & has_2009_bal == 1 & missing(lr_remdezr_resid_pre)
	di as result "    has 2009 row but pre-mean missing:      " r(N)
	count if missing(lr_remdezr_resid_pre4_raw) & has_2009_bal == 1 & !missing(lr_remdezr_resid_pre)
	di as result "    has 2009 row and pre-mean present:      " r(N)

	di _newline(1)
	di as result "=== Do raw and residual bins go missing together? ==="
	tab2 lr_remdezr_w_pre4_raw lr_remdezr_resid_pre4_raw, missing firstonly

	di _newline(1)
	di as result "=== What the zero-fill does to bin 0 ==="
	count if lr_remdezr_resid_pre4_raw == 0
	local genuine = r(N)
	count if missing(lr_remdezr_resid_pre4_raw)
	local filled = r(N)
	di as result "  genuine bottom-quartile establishments: `genuine'"
	di as result "  establishments filled into bin 0:       `filled'"
	di as result "  bin 0 after the fill:                   " `genuine' + `filled'

	di _newline(1)
	di as result "=== Pre-treatment residual of genuine bin-0 vs filled establishments ==="
	di as result "genuine bin 0:"
	summ lr_remdezr_resid_pre if lr_remdezr_resid_pre4_raw == 0
	di as result "filled (pre-mean is missing by construction, so nothing to summarize):"
	count if missing(lr_remdezr_resid_pre4_raw) & !missing(lr_remdezr_resid_pre)
	di as result "  filled establishments WITH a pre-mean: " r(N)
restore

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Zero-fill bin check done" "why missing wage lands in bin 0"
