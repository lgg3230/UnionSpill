/*
================================================================================
3165_figures_pure_control_cutoff_fine.do — Figures for the fine pure-control
cutoff set

Draws, from the CSVs written by 3162_pure_control_cutoff.do ($pcc_set = fine):

  1. Direct effect (Post x Treatment) against the comparison-group
     connectivity cutoff, one figure per outcome and cutoff set:
       deciles    0, P10 ... P90 (0.01 where it falls), All
       vingtiles  0, P5 ... P95 (0.01 where it falls), All
     Each point is the coefficient with its 95% CI; the hollow marker and the
     dashed line are the zero-connectivity baseline (published Panel A).
  2. Wage event studies (log hourly wages, log wages): the c = 0 baseline
     (hollow) and the P5, P10, P20 and P50 cutoffs overlaid, dodged within
     each year; 2011 omitted; 95% CIs; dashed line between 2011 and 2012.

A cutoff tied with an earlier one (same_as set in the cutoffs CSV) has no
estimates of its own: it is drawn once, with merged labels (e.g. "P5/P10").

Called by 3162 (fine set) after estimation. Also runs on its own, to redraw
the figures without re-estimating: with $tables / $graphs unset, it uses the
fine-set folders under the project root found from the working directory.

Input  ($tables = Tables/pure_control_cutoff_fine/):
  pure_control_cutoff.csv, pure_control_cutoff_cutoffs.csv,
  pure_control_cutoff_es.csv
Output ($graphs = Graphs/pure_control_cutoff_fine/), PDF + PNG each:
  pure_control_cutoff_<deciles|vingtiles>_<outcome>
  es_pure_control_cutoff_<lr_remdezr_h_w|lr_remdezr_w>
  -> LaTeX wrappers: 4281_figure_pure_control_cutoff_fine.py,
                     4282_figure_es_pure_control_cutoff.py
================================================================================
*/

version 17.0
set more off
set varabbrev off

if `"$tables"' == "" | `"$graphs"' == "" {
	if `"$root"' == "" {
		local _d = subinstr(`"`c(pwd)'"', "\", "/", .)
		while `"`_d'"' != "" & !fileexists(`"`_d'/Programs/0000_master.do"') {
			local _d = substr(`"`_d'"', 1, max(strrpos(`"`_d'"', "/") - 1, 0))
		}
		global root `"`_d'"'
	}
	if !fileexists(`"$root/Programs/0000_master.do"') {
		di as error "Project root not found: run from inside the project or set \$tables and \$graphs."
		exit 601
	}
	global tables "$root/Tables/pure_control_cutoff_fine"
	global graphs "$root/Graphs/pure_control_cutoff_fine"
}
cap mkdir "$graphs"

local blue     "33 102 172"
local outcomes "lr_remdezr_h_w lr_remdezr_w l_firm_emp numb_clauses"

********************************************************************************
* 1. INPUTS
********************************************************************************

* Cutoffs: est = the sample that carries the estimates (itself unless tied).
import delimited using "$tables/pure_control_cutoff_cutoffs.csv", ///
	clear varnames(1) stringcols(_all)
gen double cutoff = real(cutoff_raw)        // missing for "all": sorts last
replace same_as = strtrim(same_as)
gen est = cond(same_as != "", same_as, sample)
gen lab = cond(sample == "zero", "0", cond(sample == "fixed_001", "0.01", ///
	cond(sample == "all", "All", "P" + string(real(substr(sample, 2, .))))))
keep sample est cutoff lab
tempfile cuts
save `cuts'

* Post x Treatment and its SE, one row per sample x outcome.
import delimited using "$tables/pure_control_cutoff.csv", ///
	clear varnames(1) stringcols(_all)
keep if inlist(row_type, "main", "main_se")
gen double v = real(value)
keep section outcome row_type v
reshape wide v, i(section outcome) j(row_type) string
rename (section vmain vmain_se) (est b se)
tempfile res
save `res'

********************************************************************************
* 2. COEFFICIENT BY CUTOFF (deciles, vingtiles)
********************************************************************************

foreach set in deciles vingtiles {

	use `cuts', clear
	if "`set'" == "deciles" local qre "^p[1-9]0$"      // p10 ... p90
	else                    local qre "^p[0-9][0-9]$"  // p05 ... p95
	keep if inlist(sample, "zero", "fixed_001", "all") | regexm(sample, "`qre'")

	* Tied cutoffs: one point per estimated sample, labels merged.
	sort est sample
	by est: replace lab = lab[_n-1] + "/" + lab if _n > 1
	by est: keep if _n == _N

	merge 1:m est using `res', keep(master match)
	assert _merge == 3
	drop _merge
	sort outcome cutoff
	by outcome: gen x = _n

	if "`set'" == "deciles" local xlab_opt "angle(45) labsize(small)"
	else                    local xlab_opt "angle(90) labsize(small)"

	foreach o of local outcomes {
		preserve
		keep if outcome == "`o'"
		sort x
		local n = _N
		local xl ""
		forvalues i = 1/`n' {
			local xl `"`xl' `i' "`=lab[`i']'""'
		}
		quietly sum b if est == "zero", meanonly
		local b0 = r(mean)
		gen double hi = b + 1.96*se
		gen double lo = b - 1.96*se

		* y axis spans every CI and zero, with labels over the whole range.
		quietly sum lo, meanonly
		local ymin = min(r(min), 0)
		quietly sum hi, meanonly
		local ymax = max(r(max), 0)
		_natscale `ymin' `ymax' 5
		local ylab "`r(min)'(`r(delta)')`r(max)'"

		twoway ///
			(rcap hi lo x, lcolor("`blue'") lwidth(medthin)) ///
			(scatter b x if est != "zero", msymbol(O) mcolor("`blue'") msize(small)) ///
			(scatter b x if est == "zero", msymbol(Oh) mcolor("`blue'") msize(medium) mlwidth(medthick)), ///
			yline(0, lcolor(gs10) lwidth(thin)) ///
			yline(`b0', lcolor("`blue'%60") lpattern(dash) lwidth(thin)) ///
			xlabel(`xl', `xlab_opt' nogrid) xscale(range(0.4 `=`n' + 0.6')) ///
			ylabel(`ylab', angle(horizontal) grid glcolor(gs15)) ///
			xtitle("Connectivity cutoff {it:c}") ytitle("Coefficient") ///
			legend(off) graphregion(color(white)) bgcolor(white) ///
			xsize(4) ysize(3)

		graph export "$graphs/pure_control_cutoff_`set'_`o'.pdf", as(pdf) replace
		graph export "$graphs/pure_control_cutoff_`set'_`o'.png", as(png) width(1600) replace
		restore
	}
}

********************************************************************************
* 3. WAGE EVENT STUDIES (c = 0, P5, P10, P20, P50)
********************************************************************************

* Series: one per estimated sample, baseline first, then by cutoff.
use `cuts', clear
keep if inlist(sample, "zero", "p05", "p10", "p20", "p50")
replace lab = "" if sample == "zero"
sort est sample
by est: replace lab = lab[_n-1] + "/" + lab if _n > 1
by est: keep if _n == _N
sort cutoff
gen k = _n
gen legend = cond(est == "zero", "{it:c} = 0 (baseline)", ///
	lab + " ({it:c} = " + strtrim(string(cutoff, "%6.4f")) + ")")
local K = _N
forvalues k = 1/`K' {
	local leg`k' = legend[`k']
}
keep est k
rename est sample
tempfile series
save `series'

import delimited using "$tables/pure_control_cutoff_es.csv", ///
	clear varnames(1) stringcols(1 2)
merge m:1 sample using `series', keep(match) nogen
gen double hi = b + 1.96*se
gen double lo = b - 1.96*se
gen double x  = year - 0.28 + 0.56*(k - 1)/max(`K' - 1, 1)

* Baseline in the project blue (hollow); the cutoffs in a fixed categorical
* order, each with its own marker shape so the series also read in grayscale.
local colors `""`blue'" "235 104 52" "27 175 122" "237 161 0" "232 123 164""'
local syms   "Oh S T D X"

foreach o in lr_remdezr_h_w lr_remdezr_w {
	local plots ""
	local order ""
	forvalues k = 1/`K' {
		local c : word `k' of `colors'
		local m : word `k' of `syms'
		local plots `"`plots' (rcap hi lo x if outcome == "`o'" & k == `k', lcolor("`c'") lwidth(thin))"'
		local plots `"`plots' (scatter b x if outcome == "`o'" & k == `k', msymbol(`m') mcolor("`c'") msize(small))"'
		local order `"`order' `=2*`k'' `"`leg`k''"'"'
	}

	twoway `plots', ///
		xline(2011.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
		yline(0, lcolor(gs10) lwidth(thin)) ///
		xlabel(2009(1)2016, labsize(small) nogrid) ///
		ylabel(, angle(horizontal) grid glcolor(gs15)) ///
		xtitle("Year") ytitle("Coefficient") ///
		legend(order(`order') cols(2) position(6) size(small) region(lcolor(white))) ///
		graphregion(color(white)) bgcolor(white) ///
		xsize(4) ysize(3.5)

	graph export "$graphs/es_pure_control_cutoff_`o'.pdf", as(pdf) replace
	graph export "$graphs/es_pure_control_cutoff_`o'.png", as(png) width(1600) replace
}
