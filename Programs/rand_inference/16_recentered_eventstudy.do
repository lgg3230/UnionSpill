********************************************************************************
* 16_recentered_eventstudy.do
* Two-panel event-study figure for the log-wage spillover under recentering,
* replacing the recentered-connectivity table.
*   RIGHT panel: connectivity x year coefficients, main spillover (baseline) and
*                recentered spillover (controlling for counterfactual exposure),
*                overlaid.
*   LEFT panel : counterfactual exposure (mu) x year coefficients + 95% CIs.
* Pooled DiD estimates are annotated in-plot, in the fashion of the main-results
* event studies (Main_Results_pct_tfpw_07_11.do). Industry x negotiation-month
* reshuffle scheme (mu_C_ind_month).
* Output: Graphs/rand_inference/es_recentered_lr_remdezr_w.pdf (+ paper Figures/Main)
********************************************************************************
version 17.0
set more off
global randdir  "/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference"
global graphs   "/kellogg/proj/lgg3230/UnionSpill/Graphs/rand_inference"
global paperfig "/kellogg/proj/lgg3230/UnionSpill/UnionSpill-paper/Figures/Main"
cap mkdir "$graphs"

use "$randdir/spill_frame.dta", clear
merge m:1 identificad using "$randdir/expected_exposure.dta", keep(master match) nogen
keep if treat_ultra == 0

cap drop treat_year
gen byte treat_year = (year >= 2012)
cap drop placebo_year
gen byte placebo_year = (year < 2011)

local out  "lr_remdezr_w"
local conn "totaltreat_pw_norm"
local mu   "mu_C_ind_month"
local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local absorb  "`base_fe' ib0.`out'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year"

* ── pooled DiD estimates (for in-plot annotation) ────────────────────────────
reghdfe `out' c.`conn'##i.treat_year, absorb(`absorb') vce(cluster identificad)
local b0  = _b[1.treat_year#c.`conn']
local se0 = _se[1.treat_year#c.`conn']

reghdfe `out' c.`conn'##i.treat_year c.`mu'##i.treat_year, absorb(`absorb') vce(cluster identificad)
local b1  = _b[1.treat_year#c.`conn']
local se1 = _se[1.treat_year#c.`conn']
local bm  = _b[1.treat_year#c.`mu']
local sem = _se[1.treat_year#c.`mu']

local b0s = string(`b0', "%5.4f")
local se0s = string(`se0', "%5.4f")
local b1s = string(`b1', "%5.4f")
local se1s = string(`se1', "%5.4f")
local bms = string(`bm', "%5.4f")
local sems = string(`sem', "%5.4f")

* ── event-study regressions (reference year 2011) ────────────────────────────
reghdfe `out' c.`conn'##ib2011.year, absorb(`absorb') vce(cluster identificad)
estimates store es_base
testparm c.`conn'#i(2009 2010).year
local pbase = string(r(p), "%5.3f")

reghdfe `out' c.`conn'##ib2011.year c.`mu'##ib2011.year, absorb(`absorb') vce(cluster identificad)
estimates store es_rec
testparm c.`conn'#i(2009 2010).year
local prec = string(r(p), "%5.3f")
testparm c.`mu'#i(2009 2010).year
local pmu = string(r(p), "%5.3f")

* common vertical scale so the two panels are comparable; square canvas
local yopt "ylabel(-0.005(0.005)0.015, labsize(medium)) yscale(range(-0.006 0.016))"
local sq   "xsize(3) ysize(3) aspectratio(1)"

* ── SPILLOVER panel: main + recentered (subfigure a, left) ───────────────────
coefplot ///
    (es_base, offset(-0.12) msymbol(diamond) mcolor(navy)  ciopts(recast(rcap) color(navy))  label("Main")) ///
    (es_rec,  offset(0.12)  msymbol(square)  mcolor(maroon) ciopts(recast(rcap) color(maroon)) label("Recentered")), ///
    keep(*#*c.`conn') vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    coeflabels(2009.year#c.`conn' = "2009" 2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" 2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" 2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" 2016.year#c.`conn' = "2016") ///
    `yopt' ytitle("Dynamic DiD coefficient", size(medium)) ///
    note("Pre-trend p: main = `pbase', recentered = `prec'", size(small)) ///
    graphregion(color(white)) bgcolor(white) ///
    legend(ring(0) position(6) rows(1) size(small) region(lcolor(none))) ///
    text(0.0140 1.4 "Main: `b0s' (`se0s')", color(navy) size(small) placement(e)) ///
    text(0.0120 1.4 "Recentered: `b1s' (`se1s')", color(maroon) size(small) placement(e)) ///
    `sq' name(gSpill, replace)
graph export "$graphs/es_spill_lr_remdezr_w.pdf", as(pdf) replace
cap graph export "$paperfig/es_spill_lr_remdezr_w.pdf", as(pdf) replace

* ── COUNTERFACTUAL exposure panel (subfigure b, right) ───────────────────────
coefplot (es_rec, msymbol(circle) mcolor(dkgreen) ciopts(recast(rcap) color(dkgreen))), ///
    keep(*#*c.`mu') vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    coeflabels(2009.year#c.`mu' = "2009" 2010.year#c.`mu' = "2010" ///
               2011.year#c.`mu' = "2011" 2012.year#c.`mu' = "2012" ///
               2013.year#c.`mu' = "2013" 2014.year#c.`mu' = "2014" ///
               2015.year#c.`mu' = "2015" 2016.year#c.`mu' = "2016") ///
    `yopt' ytitle("Dynamic DiD coefficient", size(medium)) ///
    note("Pre-trend p = `pmu'", size(small)) ///
    graphregion(color(white)) bgcolor(white) legend(off) ///
    text(0.0140 2.0 "Pooled: `bms' (`sems')", color(dkgreen) size(small) placement(e)) ///
    `sq' name(gExp, replace)
graph export "$graphs/es_counterfactual_lr_remdezr_w.pdf", as(pdf) replace
cap graph export "$paperfig/es_counterfactual_lr_remdezr_w.pdf", as(pdf) replace

di as result "=== es_spill + es_counterfactual PDFs written ==="
di as result "pooled: main `b0s' (`se0s'); recentered `b1s' (`se1s'); mu `bms' (`sems')"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "ES recentered done" "es_spill + es_counterfactual written"
