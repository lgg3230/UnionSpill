/*
================================================================================
3142_linearity_twfe.do — Linearity test of the spillover DiD: Cattaneo binstest
on the TWFE spillover equation (no first difference, no manual residualization)
Cattaneo, Crump, Farrell, Feng (2024) sup-norm binstest

Run through the wrapper 3141_linearity_twfe.do, which sets the globals
($rais_firm, $rais_aux, $tables, $logs). Promoted 2026-10-05 from
archive/Programs/conn_margins/linearity_did_twfe.do; the HISTORY below refers to
runs of that file, logged under Logs/conn_margins/.

TWFE counterpart of linearity_did_fd.do. Instead of collapsing each firm to the
first difference mean(Y, post) - mean(Y, pre), the test runs on the firm-year
panel of the headline spillover DiD. The running variable is the treatment term

    D = totaltreat_pw_norm x Post

and every fixed effect of the published equation goes into binstest's absorb(),
so the covariate adjustment is done inside the bin estimation (Cattaneo et al.),
never by pre-residualizing Y or D.

HISTORY: the first version (run 5 Oct 2026, Logs/conn_margins/
linearity_did_twfe__5_Oct_2026_093338.log) tested the LEVEL with fixed
quantile-spaced nbins {10, 20, 50} and masspoints(nolocalcheck). Bins collapsed
to 5/8/18 under BOTH absorb sets and sup-t was 1e12-5e17: the cause is the mass
of D at exactly 0 (~66% of firm-years: every pre-period obs + every zero-conn
firm), which stacks the quantile knots at 0 -- not the number of fixed effects.

CURRENT SETUP follows Cattaneo, Crump, Farrell & Feng (2025, Stata Journal 25(1)):
  1. testmodelpoly(1) deriv(1): H0 "mu(D) is linear", tested as "mu'(D) is
     constant" -- the article's recommended linearity test (sec. 2.5 p.16,
     sec. 3.2 p.38). The level version (deriv(0)) depends on the covariate
     evaluation point, which absorb() fixes through reghdfe's FE
     normalization; with identical bins it disagreed with the first-difference
     test for every outcome while the slope version agreed (3172, 2026-10-06).
     Level-test runs: logs of 2026-10-05 10:43-16:01.
  2. Number of bins J chosen by binsregselect (the selector binstest calls
     internally): IMSE-optimal DPI choice for linear pieces, deriv(1) bins(1 1),
     falling back to the ROT choice when DPI fails, exactly as binstest does.
     randcut(1) makes the selection use the full sample (by default it draws
     an unseeded random subsample when n > 5000). The test then uses
     binstest's robust bias correction, one degree higher: testmodel(2 2)
     (secs. 2.2, 2.5).
  3. Default mass-point / degrees-of-freedom checks (no nolocalcheck), so a
     degenerate bin is refused instead of producing a meaningless sup-t
     (sec. 2.8.2). The atom at 0 is handled by knot placement: the J-1 inner
     knots sit at quantiles of D among D > 0 (binspos(numlist)), so 0 is the
     left endpoint of bin 1 rather than a stack of repeated knots. J itself is
     selected under evenly spaced placement (binspos(es)); quantile-spaced
     selection stacks knots at 0 the same way.
  4. vce(cluster firm): effective sample size = number of firms (sec. 2.8.3).
  5. Sample: binstest runs on the benchmark reghdfe's estimation sample,
     e(sample), so its establishment and observation counts equal those of the
     main spillover table (reghdfe's singleton drops are excluded).

One test per outcome, absorbing the full 3012 fixed-effect set. (The 10:20 run
also used a firm + time FE set as a diagnostic: it rejected linearity for
wages, employment and clauses, p 0.007-0.084.)

An earlier grid (5 Oct 2026, 10:08 log) also ran fixed J = 10 and 20 and an
evenly spaced test. With the full FE set no configuration rejected at 5%
(p 0.08-0.42); the evenly spaced test returned no result for every outcome.

SPECIFICATION — reproduces Programs/analysis/main_results/3012_pct_tfpw.do PART D:
  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp):
    reghdfe Y c.conn##i.treat_year if s_spill,
      absorb(identificad i.industry1#i.year i.mode_base_month#i.year
             i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
             ib0.totalflows_pw_pre_07_114#i.year) vce(cluster identificad)
  numb_clauses: same with #i.cba_period, c.conn##post_treat_cba,
    if s_spill & !missing(cba_period).
  Data prep (Sections 1-2 of 3012) is copied verbatim, except: the turnover
  merge, union controls, and percentile/ratio outcomes are omitted (none enters
  these four regressions); two-variable cap drops are split one per line.

Output ($tables = Tables/linearity/):
  linearity_did_twfe_diag.csv   one row per outcome
  -> table: 4240_table_linearity_latex.py
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3141_linearity_twfe.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
log using "$logs/linearity_twfe_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap which binstest
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
* SECTION 3: BENCHMARK + LINEARITY TEST
********************************************************************************

local conn "totaltreat_pw_norm"
local csv  "$tables/linearity_did_twfe_diag.csv"

tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome,nbins_selected,j_method,status,rc,nbins_formed,p_test,s_test,n_binstest,nclust_binstest,"
file write `fh' "stat_supt,pval,beta_reghdfe,se_reghdfe,n_reg,n_firms,df_a,df_a_initial,"
file write `fh' "share_d0,share_d0_pre,share_d0_zeroconn_post,ndist_d,ndist_dpos" _n
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
	}
	else {
		local tvar "year"
		local post "treat_year"
		local samp "`s_spill'"
	}

	local absorb_full "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"

	* binstest versions: numeric firm id in place of the string identificad
	* (identical groups, so identical within-projection)
	local absorb_bt : subinstr local absorb_full "identificad" "firm_num"

	di _newline "============================================================"
	di "TWFE linearity diagnostic: `outcome'"
	di "============================================================"

	* ── Benchmark: 3012 PART D spillover regression ───────────────────────────
	reghdfe `outcome' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb_full') vce(cluster identificad)

	* Test sample = this regression's estimation sample, so the linearity test
	* reports the same establishments and observations as the spillover table.
	cap drop test_sample
	gen byte test_sample = e(sample)

	local beta    = _b[1.`post'#c.`conn']
	local se      = _se[1.`post'#c.`conn']
	local n_reg   = e(N)
	local n_firms = e(N_clust)
	local df_a    = e(df_a)
	local df_a_i  = e(df_a_initial)

	di "  Benchmark (3012) beta = " %9.6f `beta' "  se = " %9.6f `se' "  N = `n_reg'  firms = `n_firms'"

	* ── Running variable and its mass at zero ─────────────────────────────────
	cap drop D
	gen double D = `conn' * `post'

	quietly count if test_sample
	local n_s = r(N)
	quietly count if test_sample & D == 0
	local share_d0 = r(N) / `n_s'
	quietly count if test_sample & `post' == 0
	local share_d0_pre = r(N) / `n_s'
	quietly count if test_sample & `post' == 1 & `conn' == 0
	local share_d0_zc = r(N) / `n_s'

	cap drop tag_d
	egen byte tag_d = tag(D) if test_sample
	quietly count if tag_d == 1
	local ndist_d = r(N)
	quietly count if tag_d == 1 & D > 0
	local ndist_dpos = r(N)
	drop tag_d

	di "  Share D==0: " %6.4f `share_d0' "  (pre-period " %6.4f `share_d0_pre' ///
		", zero-conn post " %6.4f `share_d0_zc' ")  |  distinct D: `ndist_d'  (D>0: `ndist_dpos')"

	* ── Linearity test, bins chosen by binsregselect ──────────────────────────
	* H0: mu(D) linear, tested on the slope (testmodelpoly(1) deriv(1));
	* binstest defaults for deriv(1) give bins(1 1) for selection and the
	* bias-corrected testmodel(2 2).

	* ── 1. Number of bins: IMSE-optimal DPI, ROT fallback (as binstest) ──
	local J        = .
	local j_method "none"
	ereturn clear
	capture noisily binsregselect `outcome' D if test_sample, ///
		absorb(`absorb_bt') deriv(1) bins(1 1) binspos(es) ///
		randcut(1) vce(cluster firm_num)
	local rc_sel = _rc
	if `rc_sel' == 0 {
		capture local J = e(nbinsdpi)
		if !missing(`J') {
			local j_method "dpi"
		}
		else {
			capture local J = e(nbinsrot_regul)
			if !missing(`J') local j_method "rot"
		}
	}

	* ── 2. Inner knots at quantiles of D among D > 0 (J bins -> J-1 knots);
	*       skip knots that repeat because of mass points among positives
	local knots ""
	if !missing(`J') & `J' >= 2 {
		_pctile D if test_sample & D > 0, nq(`J')
		local prev = 0
		forvalues k = 1/`=`J'-1' {
			local q = r(r`k')
			if `q' > `prev' {
				local knots "`knots' `q'"
				local prev = `q'
			}
		}
	}

	di "     selected J = `J' (`j_method')"

	* ── 3. Test ──────────────────────────────────────────────────────────
	local rc = .
	ereturn clear
	if "`knots'" != "" {
		capture noisily binstest `outcome' D if test_sample, ///
			absorb(`absorb_bt') ///
			testmodelpoly(1) deriv(1) binspos(`knots') ///
			nsims(2000) simsgrid(50) simsseed(12345) vce(cluster firm_num)
		local rc = _rc
	}

	* binstest exits with rc 0 on several failures (e.g. failed
	* degrees-of-freedom checks), so success = a returned statistic
	local stat   = .
	local pval   = .
	local nbf    = .
	local p_t    = .
	local s_t    = .
	local n_bt   = .
	local ncl_bt = .
	if `rc' == 0 {
		capture local stat   = e(stat_poly)
		capture local pval   = e(pval_poly)
		capture local nbf    = e(nbins)
		capture local p_t    = e(testmodel_p)
		capture local s_t    = e(testmodel_s)
		capture local n_bt   = e(N)
		capture local ncl_bt = e(Nclust)
	}
	if missing(`J') {
		local status "no_bins"
	}
	else if `rc' != 0 {
		local status "error"
	}
	else if missing(`stat') {
		local status "no_result"
	}
	else {
		local status "ok"
	}

	di "     status: `status' (rc `rc')  |  bins formed: `nbf'  |  N: `n_bt'" ///
		"  |  stat: " %9.4g `stat' "  |  p-val: " %6.4f `pval'

	file open `fh' using "`csv'", write append
	file write `fh' "`outcome',`J',`j_method',`status',`rc',`nbf',`p_t',`s_t',`n_bt',`ncl_bt',"
	file write `fh' "`stat',`pval',`beta',`se',`n_reg',`n_firms',`df_a',`df_a_i',"
	file write `fh' "`share_d0',`share_d0_pre',`share_d0_zc',`ndist_d',`ndist_dpos'" _n
	file close `fh'
}

di _newline "======================================================="
di "TWFE LINEARITY DIAGNOSTIC"
di "======================================================="
type "`csv'"

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

if c(os) == "Unix" shell source "$root/Programs/notify.sh" && ///
	notify "3142_linearity_twfe done" "TWFE binstest (selected bins) complete"
