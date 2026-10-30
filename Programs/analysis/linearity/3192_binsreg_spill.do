/*
================================================================================
3192_binsreg_spill.do — Binned scatter (binsreg) of the four main outcomes
against the spillover treatment term D = connectivity x Post
Cattaneo, Crump, Farrell & Feng (2024, AER; 2025, Stata Journal 25(1))

Run through the wrapper 3191_binsreg_spill.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs).

Graphical companion of 3142_linearity_twfe.do. Same data, sample, running
variable and fixed effects:

    D = totaltreat_pw_norm x Post   (connectivity scaled so 1 = 2009 p90)

  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp): Post = treat_year
  numb_clauses: Post = post_treat_cba, time = cba_period.

Every fixed effect of the headline spillover equation (3012 PART D) goes into
binsreg's absorb(), so the dots are the within-FE conditional mean of Y given D
(covariate adjustment inside the bin estimation, never pre-residualized).

Plot elements:
  dots   bin means, piecewise constant (dots(0 0))
  CIs    95% pointwise, piecewise linear with robust bias correction (ci(1 1))
  line   global linear fit with the same FEs (polyreg(1)): its slope equals the
         benchmark reghdfe coefficient on Post x connectivity (reported in the
         panel note).
The plotted x range is cut one unit past the top bin's dot (D has a long right
tail); the estimation uses the full sample.

Bins: ~66% of firm-years have D == 0 (every pre-period obs + every zero-conn
firm), so quantile-spaced knots stack at 0 (see 3142 HISTORY). As in 3142, the
number of bins J is chosen by binsregselect under evenly spaced placement
(IMSE-optimal DPI, ROT fallback), here for the plotted piecewise-constant dots
(bins(0 0)), and the J-1 inner knots sit at quantiles of D among D > 0, so 0 is
the left endpoint of bin 1. The y level of the dots is fixed by reghdfe's FE
normalization; only the shape / slope is meaningful.

Sample: the benchmark reghdfe's estimation sample e(sample) (singletons
dropped), so N and firm counts equal the main spillover table.

Data prep (Sections 1-2) is verbatim from 3142, i.e. from 3012 minus the
turnover merge, union controls, and percentile/ratio outcomes.

Output:
  $graphs/binsreg_spill_<outcome>.pdf     one panel per outcome
  $graphs/binsreg_spill_figure.tex        2x2 LaTeX figure (subcaption) of the four
                                          PDFs; written by hand, not by this file
  $tables/binsreg_spill_<outcome>.dta     plotted data (binsreg savedata)
  $tables/binsreg_spill_diag.csv          J, knots, benchmark beta, N
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3191_binsreg_spill.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/binsreg_spill_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap which binsreg
if _rc != 0 {
	di "Installing binsreg from SSC..."
	ssc install binsreg, replace
}

********************************************************************************
* SECTION 1: DATA (verbatim from 3012, turnover merge omitted)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

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

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: VARIABLE CREATION (verbatim from 3012)
********************************************************************************

* ── a) Treatment & CBA period indicators ──────────────────────────────────────

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* industry1 is stored as a string in the rebuilt panel; i.industry1 needs numeric
capture confirm string variable industry1
if _rc == 0 {
	destring industry1, replace force
}

* ── Connectivity scaling ──────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── b) Pre-treatment means ────────────────────────────────────────────────────

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

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── 4-bin controls ────────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
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

* Numeric firm id: binstest rejects string cluster variables
cap drop firm_num
egen long firm_num = group(identificad)

********************************************************************************
* SECTION 3: BENCHMARK + BINSREG FIGURES
********************************************************************************

local conn "totaltreat_pw_norm"
local csv  "$tables/binsreg_spill_diag.csv"

tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome,nbins_selected,j_method,nbins_plotted,knots,beta_reghdfe,se_reghdfe,n_reg,n_firms,share_d0" _n
file close `fh'

local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
capture confirm variable numb_clauses
if _rc == 0 local outcomes "`outcomes' numb_clauses"

foreach outcome of local outcomes {

	* ── Outcome-specific time structure ───────────────────────────────────────
	if "`outcome'" == "numb_clauses" {
		local tvar "cba_period"
		local post "post_treat_cba"
		local samp "`s_spill' & !missing(cba_period)"
		local xttl "Connectivity × Post-CBA"
	}
	else {
		local tvar "year"
		local post "treat_year"
		local samp "`s_spill'"
		local xttl "Connectivity × Post"
	}

	local absorb_full "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"
	local absorb_bt : subinstr local absorb_full "identificad" "firm_num"

	di _newline "============================================================"
	di "binsreg: `outcome'"
	di "============================================================"

	* ── Benchmark: 3012 PART D spillover regression ───────────────────────────
	reghdfe `outcome' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb_full') vce(cluster identificad)

	cap drop plot_sample
	gen byte plot_sample = e(sample)

	local beta    = _b[1.`post'#c.`conn']
	local se      = _se[1.`post'#c.`conn']
	local n_reg   = e(N)
	local n_firms = e(N_clust)

	cap drop D
	gen double D = `conn' * `post'
	label variable D "`xttl'"

	quietly count if plot_sample & D == 0
	local share_d0 = r(N) / `n_reg'

	* ── 1. Number of bins: IMSE-optimal DPI for the dots, ROT fallback ────────
	local J        = .
	local j_method "none"
	ereturn clear
	capture noisily binsregselect `outcome' D if plot_sample, ///
		absorb(`absorb_bt') bins(0 0) binspos(es) ///
		randcut(1) vce(cluster firm_num)
	if _rc == 0 {
		capture local J = e(nbinsdpi)
		if !missing(`J') {
			local j_method "dpi"
		}
		else {
			capture local J = e(nbinsrot_regul)
			if !missing(`J') local j_method "rot"
		}
	}
	if missing(`J') {
		di as error "binsregselect failed for `outcome'; skipping"
		continue
	}

	* ── 2. Inner knots at quantiles of D among D > 0 ─────────────────────────
	local knots ""
	_pctile D if plot_sample & D > 0, nq(`J')
	local prev = 0
	forvalues k = 1/`=`J'-1' {
		local q = r(r`k')
		if `q' > `prev' {
			local knots "`knots' `q'"
			local prev = `q'
		}
	}
	local nbp : word count `knots'
	local nbp = `nbp' + 1
	di "     selected J = `J' (`j_method'), bins plotted = `nbp'"

	* ── 3. Figure ────────────────────────────────────────────────────────────
	local bfmt = strtrim(string(`beta', "%9.4f"))
	local sfmt = strtrim(string(`se', "%9.4f"))

	if "`knots'" != "" local bpos "binspos(`knots')"
	else               local bpos "nbins(1)"

	* Plotted x range: D has a long right tail (top bin up to ~18), which would
	* squeeze the other bins against 0. Cut the plot (not the estimation) one
	* unit past the top bin's dot (= mean of D in that bin).
	local lastk : word `=`nbp'-1' of `knots'
	if "`lastk'" == "" local lastk = 0
	quietly summarize D if plot_sample & D > `lastk', meanonly
	local xmax = ceil(r(mean)) + 1

	binsreg `outcome' D if plot_sample, ///
		absorb(`absorb_bt') vce(cluster firm_num) ///
		`bpos' dots(0 0) ci(1 1) polyreg(1) ///
		plotxrange(0 `xmax') ///
		dotsplotopt(mcolor(navy) msize(medium)) ///
		ciplotopt(lcolor(navy%60)) ///
		polyregplotopt(lcolor(maroon) lpattern(dash) lwidth(medthick)) ///
		savedata("$tables/binsreg_spill_`outcome'") replace ///
		ytitle("") xtitle("`xttl'") ///
		note("Linear fit slope = `bfmt' (`sfmt')", ring(0) position(5) size(small) margin(medium)) ///
		legend(off) graphregion(color(white)) plotregion(color(white)) ///
		name(g_`outcome', replace)

	graph export "$graphs/binsreg_spill_`outcome'.pdf", replace

	file open `fh' using "`csv'", write append
	file write `fh' "`outcome',`J',`j_method',`nbp',`=strtrim("`knots'")',`beta',`se',`n_reg',`n_firms',`share_d0'" _n
	file close `fh'
}

di _newline "======================================================="
di "BINSREG SPILLOVER FIGURES"
di "======================================================="
type "`csv'"

di "Finished: `c(current_date)' `c(current_time)'"
capture log close
