********************************************************************************
* UNION SPILLOVERS — NONPARAMETRIC AVERAGE CAUSAL RESPONSE OF CONNECTIVITY
* Purpose: TWFE with a continuous treatment need not recover the average causal
*          response (Callaway, Goodman-Bacon & Sant'Anna 2025, "CGBS"). Following
*          CGBS Section 4 and Appendix Table C9 of the QJE national-health-
*          insurance paper (Docs/ATT/qjag024), estimate E[dY | D = d] flexibly
*          among exposed firms and average its derivative over them:
*              ACRT^glob = E[ dE[dY|D]/dD | D > 0 ].
* Input:   $rais_aux/drdid_firm_wide.dta (3252_drdid.do): firm-level pre (2009-11)
*          and post (2012-16) means; clauses use CBA periods 1-2 and 3-6.
* Output:  $tables/np_acr.csv; auto-runs 4380_table_np_acr_latex.py.
*
* Sample: untreated, balanced-panel firms. Dose D = connectivity scaled to its
* 2009 p90 (the paper's regressor). dY = post mean - pre mean, and
* ddY = dY - mean(dY | D = 0) (CGBS eq. 4.2).
*
* Columns:
*   twfe      dY on D, all untreated firms (the collapsed analog of the paper's
*             TWFE; Panel B absorbs the paper's controls)
*   poly      cubic polynomial in D
*   bspline   cubic B-spline in D
*   nspline   natural cubic spline in D
*   binary    dY on 1{D > 0}: the binarized DiD, CGBS's ATT^glob
* Panels:
*   A   the QJE code: npregress series (polynomial(3), bspline, spline; knots
*       chosen by its cross-validation) of ddY on D among exposed firms, then
*       margins dydx(d) over them. No covariates.
*   A2  the same with explicit bases: cubic polynomial, cubic B-spline, natural
*       cubic spline, with the number of interior knots npregress chose, placed
*       at equally spaced quantiles of D among exposed firms (boundary knots at
*       the min and max). No covariates; exposed firms only.
*   B   A2's bases with the paper's controls: all untreated firms, ddY on
*       1{D>0} and the basis (zero at D = 0; CGBS footnote 9), absorbing in
*       differences the own-outcome, employment and flows quartiles, base
*       month, microregion and industry1.
*   (A2 vs B isolates the controls; A vs A2 the knot placement.)
* ACR = average over exposed firms of the fitted derivative, a linear
*   combination of the basis coefficients (lincom), derivatives analytic; like
*   margins after npregress, the SE conditions on the observed doses. Robust
*   SEs = clustered by firm (one row per firm). Bases are QR-orthonormalized.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/np_acr_`d'_`t'.log", replace text

* ── Basis functions (Mata) ─────────────────────────────────────────────────
mata:
mata clear

// Cox-de Boor: B-spline basis of degree p on the full knot vector t (boundary
// knots repeated p+1 times). Returns n x (cols(t)-p-1).
real matrix _bspl(real colvector x, real rowvector t, real scalar p)
{
	real scalar n, m, i, k, last
	real matrix B, Bn
	real colvector a, b
	n = rows(x); m = cols(t)
	B = J(n, m-1, 0)
	for (i = 1; i <= m-1; i++) B[., i] = (x :>= t[i]) :& (x :< t[i+1])
	last = max(select(1..(m-1), t[2..m] :> t[1..(m-1)]))
	B[., last] = B[., last] :| (x :== t[m])
	for (k = 1; k <= p; k++) {
		Bn = J(n, m-1-k, 0)
		for (i = 1; i <= m-1-k; i++) {
			a = (t[i+k] > t[i])     ? (x :- t[i]) :/ (t[i+k] - t[i])         : J(n, 1, 0)
			b = (t[i+k+1] > t[i+1]) ? (t[i+k+1] :- x) :/ (t[i+k+1] - t[i+1]) : J(n, 1, 0)
			Bn[., i] = a :* B[., i] + b :* B[., i+1]
		}
		B = Bn
	}
	return(B)
}

// Derivative of the degree-p B-spline basis.
real matrix _dbspl(real colvector x, real rowvector t, real scalar p)
{
	real scalar m, nb, i
	real matrix Bm, D
	Bm = _bspl(x, t, p-1)
	m = cols(t); nb = m-p-1
	D = J(rows(x), nb, 0)
	for (i = 1; i <= nb; i++) {
		if (t[i+p] > t[i])     D[., i] = D[., i] + p / (t[i+p] - t[i]) * Bm[., i]
		if (t[i+p+1] > t[i+1]) D[., i] = D[., i] - p / (t[i+p+1] - t[i+1]) * Bm[., i+1]
	}
	return(D)
}

// Natural cubic spline, truncated-power form (Hastie, Tibshirani & Friedman,
// eq. 5.4-5.5) on knots xi (boundary knots included). Returns x and the K-2
// nonlinear terms; deriv = 1 returns their derivatives.
real matrix _nspl(real colvector x, real rowvector xi, real scalar deriv)
{
	real scalar K, k
	real matrix N
	real colvector dK1
	K = cols(xi)
	dK1 = _nsd(x, xi, K-1, deriv)
	N = deriv ? J(rows(x), 1, 1) : x
	for (k = 1; k <= K-2; k++) N = N, (_nsd(x, xi, k, deriv) - dK1)
	return(N)
}
real colvector _nsd(real colvector x, real rowvector xi, real scalar k, real scalar deriv)
{
	real scalar K
	K = cols(xi)
	if (deriv) return((3 * ((x :- xi[k]) :* (x :> xi[k])):^2 - 3 * ((x :- xi[K]) :* (x :> xi[K])):^2) / (xi[K] - xi[k]))
	return((((x :- xi[k]) :* (x :> xi[k])):^3 - ((x :- xi[K]) :* (x :> xi[K])):^3) / (xi[K] - xi[k]))
}

// Write basis b1..bk and derivative db1..dbk for observations with touse = 1
// (zero elsewhere). type: "poly", "bspline", "nspline"; nint interior knots at
// equally spaced quantiles of the dose among touse observations.
void _makebasis(string scalar dose, string scalar touse, string scalar type, real scalar nint)
{
	real colvector x, q
	real rowvector inner, t
	real matrix B, D
	real scalar j, k
	x = st_data(., dose, touse)
	if (type == "poly") {
		B = x, x:^2, x:^3
		D = J(rows(x), 1, 1), 2*x, 3*x:^2
	}
	else {
		inner = J(1, nint, .)
		for (j = 1; j <= nint; j++) {
			q = sort(x, 1)
			inner[j] = q[ceil(rows(q) * j / (nint + 1))]
		}
		if (type == "bspline") {
			t = J(1, 4, min(x)), inner, J(1, 4, max(x))
			B = _bspl(x, t, 3); D = _dbspl(x, t, 3)
			B = B[., 2..cols(B)]; D = D[., 2..cols(D)]   // drop one: the basis sums to 1
		}
		else {
			t = min(x), inner, max(x)
			B = _nspl(x, t, 0); D = _nspl(x, t, 1)
		}
	}
	// Orthonormalize (B = QR, use Q and D R^-1): same span, same fitted curve and
	// derivative, but well-conditioned (the raw columns reach 1e3-1e4 on this dose).
	{
		real matrix Q, R
		qrd(B, Q = ., R = .)
		Q = Q[., 1..cols(B)]; R = R[1..cols(B), .]
		B = Q
		D = (lusolve(R', D'))'
	}
	for (k = 1; k <= cols(B); k++) {
		(void) st_addvar("double", ("b" + strofreal(k), "db" + strofreal(k)))
		st_store(., "b" + strofreal(k), touse, B[., k])
		st_store(., "db" + strofreal(k), touse, D[., k])
	}
	st_numscalar("r(nb)", cols(B))
}
end

* Basis variables: drop, build, zero-fill outside touse.
capture program drop _basis
program define _basis, rclass
	args dose touse type nint
	capture drop b?
	capture drop db?
	capture drop b??
	capture drop db??
	mata: _makebasis("`dose'", "`touse'", "`type'", `nint')
	local nb = r(nb)
	forvalues k = 1/`nb' {
		quietly replace b`k' = 0 if missing(b`k')
		quietly replace db`k' = 0 if missing(db`k')
	}
	return scalar nb = `nb'
end

* ACR = average over the exposed estimation sample of sum_k b_k * dpsi_k(D).
capture program drop _acr
program define _acr, rclass
	args nb sample
	local expr ""
	forvalues k = 1/`nb' {
		quietly sum db`k' if `sample', meanonly
		local expr "`expr' + (`r(mean)') * _b[b`k']"
	}
	lincom `=substr("`expr'", 4, .)'
	return scalar b = r(estimate)
	return scalar se = r(se)
end

* ── Output ────────────────────────────────────────────────────────────────
tempname fh
file open `fh' using "$tables/np_acr.csv", write replace
file write `fh' "outcome;panel;spec;b;se;p;n;n_exposed;nknots" _n
file close `fh'

capture program drop _wr
program define _wr
	args y panel spec b se n ne nk
	local p = .
	if !missing(`se') & `se' > 0 local p = 2 * normal(-abs(`b' / `se'))
	tempname fh
	file open `fh' using "$tables/np_acr.csv", write append
	file write `fh' "`y';`panel';`spec';" %20.12g (`b') ";" %20.12g (`se') ";" %12.8f (`p') ";`n';`ne';`nk'" _n
	file close `fh'
end

* ── Estimation ────────────────────────────────────────────────────────────
use "$rais_aux/drdid_firm_wide.dta", clear
keep if treat_ultra == 0
gen double D = connn0
gen byte pos = (D > 0)
label var D "Connectivity to treated firms, scaled to the 2009 p90"

local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"
local tag_lr_remdezr_w   "w"
local tag_lr_remdezr_h_w "hw"
local tag_l_firm_emp     "emp"
local tag_numb_clauses   "cl"

foreach y of local outcomes {
	local g "`tag_`y''"
	local own "`y'_pre4"
	if "`y'" == "l_firm_emp" local own ""
	local fe "`own' l_firm_emp_pre4 totalflows_pw_pre_07_114 month0 mreg0 ind4"

	cap drop dy
	cap drop ddy
	cap drop smp
	gen double dy = y_`g'_3 - y_`g'_2
	gen byte smp = !missing(dy, D)
	foreach v of local fe {
		quietly replace smp = 0 if missing(`v')
	}
	quietly sum dy if smp & !pos
	gen double ddy = dy - r(mean)
	quietly count if smp & pos
	local ne = r(N)
	quietly count if smp
	local n = r(N)
	di _newline as result "=== `y': `n' untreated firms, `ne' exposed"

	* ---- TWFE (collapsed) and binarized DiD -------------------------------
	quietly regress dy D if smp, vce(robust)
	_wr `y' A twfe `=_b[D]' `=_se[D]' `e(N)' `ne' .
	quietly regress dy pos if smp, vce(robust)
	_wr `y' A binary `=_b[pos]' `=_se[pos]' `e(N)' `ne' .
	quietly reghdfe dy D if smp, absorb(`fe') vce(robust)
	quietly count if e(sample) & pos
	_wr `y' B twfe `=_b[D]' `=_se[D]' `e(N)' `r(N)' .
	quietly reghdfe dy pos if smp, absorb(`fe') vce(robust)
	quietly count if e(sample) & pos
	_wr `y' B binary `=_b[pos]' `=_se[pos]' `e(N)' `r(N)' .

	* ---- Panel A: the QJE code (npregress series) ---------------------------
	cap drop ex
	gen byte ex = smp & pos
	cap drop d
	gen double d = D
	foreach spec in poly bspline nspline {
		local o = cond("`spec'" == "poly", "polynomial(3)", cond("`spec'" == "bspline", "bspline", "spline"))
		quietly npregress series ddy d if ex, `o' vce(robust)
		local nk_`spec' = cond("`spec'" == "poly", 0, real("`e(knots)'"))
		quietly margins, dydx(d)
		_wr `y' A `spec' `=el(r(b),1,1)' `=sqrt(el(r(V),1,1))' `ne' `ne' `nk_`spec''
	}
	drop d
	di as text "  npregress knots: B-spline `nk_bspline', spline `nk_nspline'"

	* ---- Panels A2 and B: explicit bases, npregress's number of knots --------
	foreach spec in poly bspline nspline {
		_basis D ex `spec' `nk_`spec''
		local nb = r(nb)
		local bl ""
		forvalues k = 1/`nb' {
			local bl "`bl' b`k'"
		}
		quietly regress ddy `bl' if ex, vce(robust)
		quietly _acr `nb' "e(sample)"
		_wr `y' A2 `spec' `r(b)' `r(se)' `e(N)' `e(N)' `nk_`spec''
		quietly reghdfe ddy pos `bl' if smp, absorb(`fe') vce(robust)
		local omit = 0
		foreach v of local bl {
			if _se[`v'] == 0 local omit = 1
		}
		if `omit' di as error "  `spec': a basis column was omitted in Panel B"
		quietly count if e(sample) & pos
		local neB = r(N)
		quietly _acr `nb' "e(sample) & pos"
		_wr `y' B `spec' `r(b)' `r(se)' `e(N)' `neB' `nk_`spec''
	}
}

di _newline as result "All estimation complete."
log close

if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/drdid/4380_table_np_acr_latex.py" "$tables"

********************************************************************************
* END OF DO-FILE
********************************************************************************
