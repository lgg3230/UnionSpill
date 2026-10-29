#!/usr/bin/env python3
"""
Diagnostics for choosing the basis of the nonparametric average causal response
(ACR) of connectivity (Callaway, Goodman-Bacon & Sant'Anna 2025, Section 4;
3272_np_acr.do). For each outcome and setting it draws one figure:

  (a) Fit     binned means of the outcome change by connectivity (20 equal-count
              bins of exposed firms) with the fitted curves E[dY | D = d] of the
              four specifications of 3272 (linear, cubic polynomial, cubic
              B-spline and natural cubic spline, with npregress's one knot).
  (b) Slope   the derivative of each curve, ACRT(d); the ACR averages it over
              exposed firms, so the slope matters where the firms are:
  (c) Doses   the distribution of connectivity among exposed firms.
  (d) CV      10-fold cross-validated MSE (5 repetitions) of each basis family
              by basis dimension, relative to the linear fit.
  (e) ACR     the ACR and its 95% CI by basis dimension: a basis worth using
              should give a stable ACR as its dimension grows.

Settings
  raw   Panel A2 of 3272: exposed firms only, ddY = dY - mean(dY | D = 0) on the
        basis, no covariates.
  ctrl  Panel B of 3272: all untreated firms, ddY on 1{D > 0} and the basis
        (zero at D = 0), absorbing the paper's controls (own-outcome, employment
        and flows quartiles, base month, microregion, industry1). Estimated by
        Frisch-Waugh: every variable is demeaned on the fixed effects by
        alternating projections after dropping singletons (as reghdfe). CV folds
        reuse the full-sample demeaning, so the fixed effects are in-sample.

Bases as in 3272: interior knots at equally spaced quantiles of the dose among
exposed firms, boundary knots at its min and max; the B-spline drops one column
(the basis sums to one); the natural spline is linear beyond the boundary knots.
Dimension = number of dose terms: polynomial order p -> p; cubic B-spline with
k interior knots -> k + 3; natural spline with k interior knots -> k + 1 (k = 0
is linear). SEs are HC1; the ACR SE conditions on the observed doses.

Input:  Data/RAIS_aux/drdid_firm_wide.dta (3252_drdid.do)
Output: Tables/drdid/np_acr_diag.csv
        Graphs/drdid/np_acr_diag_<setting>_<outcome>.pdf

Usage: python 3273_np_acr_diagnostics.py [--outcomes lr_remdezr_h_w lr_remdezr_w]
       [--folds 10] [--reps 5]
"""

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "Data" / "RAIS_aux" / "drdid_firm_wide.dta"
TAB = ROOT / "Tables" / "drdid"
GRA = ROOT / "Graphs" / "drdid"

SEED = 20261029
TAGS = {"lr_remdezr_w": "w", "lr_remdezr_h_w": "hw", "l_firm_emp": "emp", "numb_clauses": "cl"}
YLAB = {"lr_remdezr_w": "log wages", "lr_remdezr_h_w": "log hourly wages",
        "l_firm_emp": "log employment", "numb_clauses": "number of clauses"}

# Specifications of 3272 (npregress chose one knot for both splines).
SPECS = [("linear", "poly", 1, "Linear", "#7f7f7f", (0, (4, 2))),
         ("poly3", "poly", 3, "Cubic polynomial", "#2166AC", "-"),
         ("bspline1", "bspline", 1, "Cubic B-spline, 1 knot", "#B2182B", "-"),
         ("nspline1", "nspline", 1, "Natural cubic spline, 1 knot", "#1B7837", (0, (6, 1.5, 1.5, 1.5)))]
FAMILIES = [("poly", range(1, 7), "Polynomial, order 1–6", "#2166AC", "o"),
            ("bspline", range(0, 9), "Cubic B-spline, 0–8 knots", "#B2182B", "s"),
            ("nspline", range(0, 9), "Natural cubic spline, 0–8 knots", "#1B7837", "^")]


# ── Bases ────────────────────────────────────────────────────────────────────
def _bspl(x, t, p):
    """B-spline basis of degree p on full knot vector t (Cox-de Boor), n x (len(t)-p-1)."""
    m = len(t)
    B = np.zeros((len(x), m - 1))
    for i in range(m - 1):
        B[:, i] = (x >= t[i]) & (x < t[i + 1])
    last = max(i for i in range(m - 1) if t[i + 1] > t[i])
    B[:, last] = np.where(x == t[-1], 1.0, B[:, last])
    for k in range(1, p + 1):
        Bn = np.zeros((len(x), m - 1 - k))
        for i in range(m - 1 - k):
            a = (x - t[i]) / (t[i + k] - t[i]) if t[i + k] > t[i] else 0.0
            b = (t[i + k + 1] - x) / (t[i + k + 1] - t[i + 1]) if t[i + k + 1] > t[i + 1] else 0.0
            Bn[:, i] = a * B[:, i] + b * B[:, i + 1]
        B = Bn
    return B


def _dbspl(x, t, p):
    Bm = _bspl(x, t, p - 1)
    nb = len(t) - p - 1
    D = np.zeros((len(x), nb))
    for i in range(nb):
        if t[i + p] > t[i]:
            D[:, i] += p / (t[i + p] - t[i]) * Bm[:, i]
        if t[i + p + 1] > t[i + 1]:
            D[:, i] -= p / (t[i + p + 1] - t[i + 1]) * Bm[:, i + 1]
    return D


def _nsd(x, xi, k, deriv):
    K = len(xi) - 1
    if deriv:
        return (3 * np.clip(x - xi[k], 0, None) ** 2 - 3 * np.clip(x - xi[K], 0, None) ** 2) / (xi[K] - xi[k])
    return (np.clip(x - xi[k], 0, None) ** 3 - np.clip(x - xi[K], 0, None) ** 3) / (xi[K] - xi[k])


def _nspl(x, xi, deriv):
    """Natural cubic spline, truncated-power form (HTF eq. 5.4-5.5): x and K-2 terms."""
    K = len(xi)
    cols = [np.ones_like(x) if deriv else x.copy()]
    dK1 = _nsd(x, xi, K - 2, deriv)
    cols += [_nsd(x, xi, k, deriv) - dK1 for k in range(K - 2)]
    return np.column_stack(cols)


class Basis:
    """Dose basis fixed on the exposed sample xs; evaluates terms and derivatives at any x."""

    def __init__(self, kind, size, xs):
        self.kind, self.size = kind, size
        self.lo, self.hi = xs.min(), xs.max()
        q = np.sort(xs)
        self.inner = np.array([q[int(np.ceil(len(q) * j / (size + 1))) - 1] for j in range(1, size + 1)]) \
            if kind != "poly" else None
        # Polynomial in a rescaled dose for conditioning; derivatives rescaled back.
        self.c, self.s = xs.mean(), xs.std()

    def __call__(self, x):
        if self.kind == "poly":
            z = (x - self.c) / self.s
            B = np.column_stack([z ** j for j in range(1, self.size + 1)])
            D = np.column_stack([j * z ** (j - 1) / self.s for j in range(1, self.size + 1)])
        elif self.kind == "bspline":
            t = np.r_[[self.lo] * 4, self.inner, [self.hi] * 4]
            xc = np.clip(x, self.lo, self.hi)
            B, D = _bspl(xc, t, 3)[:, 1:], _dbspl(xc, t, 3)[:, 1:]
        else:
            xi = np.r_[self.lo, self.inner, self.hi]
            B, D = _nspl(x, xi, 0), _nspl(x, xi, 1)
        return B, D

    @property
    def dim(self):
        return {"poly": self.size, "bspline": self.size + 3, "nspline": self.size + 1}[self.kind]


# ── Estimation ───────────────────────────────────────────────────────────────
def drop_singletons(df, fes):
    while True:
        keep = np.ones(len(df), bool)
        for f in fes:
            keep &= df.groupby(f)[f].transform("size").to_numpy() > 1
        if keep.all():
            return df
        df = df[keep]


def demean(M, groups, tol=1e-9, maxit=20000):
    """Residualize the columns of M on several sets of fixed effects (alternating
    projections). Columns are standardized first (the map is linear), so the
    tolerance is relative."""
    sc = M.std(0)
    sc[sc == 0] = 1.0
    return _demean(M / sc, groups, tol, maxit) * sc


def _demean(M, groups, tol, maxit):
    M = M - M.mean(0)
    for _ in range(maxit):
        M0 = M.copy()
        for g in groups:
            sums = np.zeros((g.max() + 1, M.shape[1]))
            np.add.at(sums, g, M)
            M = M - (sums / np.bincount(g)[:, None])[g]
        if np.abs(M - M0).max() < tol:
            return M
    raise RuntimeError("demeaning did not converge")


def ols(X, y):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta


def hc1(X, e, df_extra=0):
    n, k = X.shape
    XtXi = np.linalg.pinv(X.T @ X)
    meat = (X * e[:, None]).T @ (X * e[:, None])
    return XtXi @ meat @ XtXi * n / (n - k - df_extra)


class Design:
    """One outcome x setting: data, transformation, and fit/ACR for any basis."""

    def __init__(self, df, y, setting):
        g = TAGS[y]
        own = [] if y == "l_firm_emp" else [f"{y}_pre4"]
        fes = own + ["l_firm_emp_pre4", "totalflows_pw_pre_07_114", "month0", "mreg0", "ind4"]
        d = df.assign(dy=df[f"y_{g}_3"] - df[f"y_{g}_2"], D=df["connn0"])
        d = d.dropna(subset=["dy", "D"] + fes)
        d["ddy"] = d["dy"] - d.loc[d.D == 0, "dy"].mean()
        self.xs = d.loc[d.D > 0, "D"].to_numpy()             # knots: exposed sample (3272's `ex`)
        self.setting = setting
        if setting == "raw":
            d = d[d.D > 0]
            self.groups, self.df_fe = None, 0
        else:
            d = drop_singletons(d, fes)
            self.groups = [pd.factorize(d[f])[0] for f in fes]
            # absorbed df as reghdfe counts it with nested/redundant levels ignored
            self.df_fe = sum(gr.max() + 1 for gr in self.groups) - len(fes)
        self.d = d
        self.D = d["D"].to_numpy()
        self.pos = self.D > 0
        self.y = d["ddy"].to_numpy()
        self.yt = demean(self.y[:, None], self.groups)[:, 0] if self.groups else self.y

    def design(self, basis):
        B, dB = basis(self.D)
        B[~self.pos], dB[~self.pos] = 0.0, 0.0
        if self.groups:
            X = demean(np.column_stack([self.pos.astype(float), B]), self.groups)
        else:
            X = np.column_stack([np.ones(len(self.y)), B])
        return X, dB

    def fit(self, basis):
        X, dB = self.design(basis)
        b = ols(X, self.yt)
        V = hc1(X, self.yt - X @ b, self.df_fe)
        g = np.r_[0.0, dB[self.pos].mean(0)]
        # part of the ACR from exposed firms below the 10th percentile of the dose
        low = self.D[self.pos] < np.percentile(self.D[self.pos], 10)
        acr_low = (dB[self.pos] @ b[1:] * low).mean()
        return {"beta": b, "V": V, "acr": g @ b, "se": float(np.sqrt(g @ V @ g)), "acr_low": acr_low}

    def cv_err(self, basis, folds, reps, seed):
        """Out-of-sample squared error of each exposed firm, averaged over repetitions.
        The same seed for every basis gives the same folds, so errors are paired."""
        X, _ = self.design(basis)
        rng = np.random.default_rng(seed)
        n, err = len(self.yt), np.zeros(len(self.yt))
        for _ in range(reps):
            fold = rng.permutation(np.arange(n) % folds)
            for f in range(folds):
                tr, te = fold != f, fold == f
                b = ols(X[tr], self.yt[tr])
                err[te] += (self.yt[te] - X[te] @ b) ** 2 / reps
        return err[self.pos]

    def curve(self, basis, beta, grid):
        """Fitted effect at dose d relative to zero-connectivity firms and its derivative:
        intercept + psi(d)'b (raw; ddY is already relative to D = 0) or
        b_pos + psi(d)'b (ctrl; holding the fixed effects fixed)."""
        B, dB = basis(grid)
        return beta[0] + B @ beta[1:], dB @ beta[1:]

    def bins(self, nb):
        """Equal-count bins of exposed firms. Coefficients on bin indicators, zero-
        connectivity firms omitted: bin means of ddY (raw), or the same regression
        with the fixed effects absorbed (ctrl; binscatter with covariates as in
        Cattaneo, Crump, Farrell & Feng 2024). Returns bin mean dose, coefficient,
        95% CI half-width, and firm-level points X b + e for exposed firms: their
        bin means equal the coefficients."""
        xe = self.D[self.pos]
        bid = np.empty(len(xe), int)
        for j, idx in enumerate(np.array_split(np.argsort(xe, kind="stable"), nb)):
            bid[idx] = j
        xm = np.array([xe[bid == j].mean() for j in range(nb)])
        if self.setting == "raw":
            ye = self.yt[self.pos]
            b = np.array([ye[bid == j].mean() for j in range(nb)])
            se = np.array([ye[bid == j].std(ddof=1) / np.sqrt((bid == j).sum()) for j in range(nb)])
            return xm, b, 1.96 * se, ye
        Z = np.zeros((len(self.D), nb))
        Z[np.flatnonzero(self.pos), bid] = 1.0
        Zt = demean(Z, self.groups)
        b = ols(Zt, self.yt)
        e = self.yt - Zt @ b
        se = np.sqrt(np.diag(hc1(Zt, e, self.df_fe)))
        return xm, b, 1.96 * se, (Z @ b + e)[self.pos]


# ── Low-dimensional alternatives: piecewise-linear spline and P-spline ───────
PLIN_KNOTS = [(1.0,), (0.5,), (1.0, 2.0), (0.5, 1.0, 2.0)]


class PLin:
    """Piecewise-linear spline in D with knots at fixed values of D: D, (D - k)+.
    The ACR is the segment slopes weighted by the exposed firms in each segment."""

    def __init__(self, knots):
        self.knots = tuple(knots)

    def __call__(self, x):
        B = np.column_stack([x] + [np.clip(x - k, 0, None) for k in self.knots])
        D = np.column_stack([np.ones_like(x)] + [(x > k).astype(float) for k in self.knots])
        return B, D


def pspline(des, nseg=20, deg=3, order=2):
    """P-spline (Eilers & Marx 1996): cubic B-spline basis on nseg equal-width
    segments of the exposed dose range, with a penalty on order-th differences of
    the coefficients, chosen by GCV. The full basis sums to 1{D>0}, so no separate
    intercept (raw) or exposure indicator (ctrl) enters; as the penalty grows the
    fit tends to a + b*D among exposed firms, i.e. the linear specification with
    its step at zero. Returns the GCV fit and, as a check, the fit at the largest
    penalty. SEs are sandwich (HC1-type), conditional on the penalty."""
    lo, hi = des.xs.min(), des.xs.max()
    dx = (hi - lo) / nseg
    t = lo + dx * np.arange(-deg, nseg + deg + 1)
    xc = np.clip(des.D, lo, hi)
    B, dB = _bspl(xc, t, deg), _dbspl(xc, t, deg)
    B[~des.pos], dB[~des.pos] = 0.0, 0.0
    X = demean(B, des.groups) if des.groups else B
    k = X.shape[1]
    Dm = np.diff(np.eye(k), n=order, axis=0)
    P = Dm.T @ Dm
    XtX, Xty = X.T @ X, X.T @ des.yt
    n = len(des.yt) - des.df_fe
    scale = np.trace(XtX) / np.trace(P)
    g = dB[des.pos].mean(0)

    def at(lam):
        A = np.linalg.inv(XtX + lam * P)
        b = A @ Xty
        e = des.yt - X @ b
        edf = np.trace(A @ XtX)
        meat = (X * e[:, None]).T @ (X * e[:, None])
        V = A @ meat @ A * n / (n - edf)
        return {"lam": lam, "edf": edf, "gcv": n * (e @ e) / (n - edf) ** 2,
                "acr": g @ b, "se": float(np.sqrt(g @ V @ g)), "beta": b}

    grid = [at(scale * 10.0 ** p) for p in np.arange(-6, 8.01, 0.25)]
    return min(grid, key=lambda r: r["gcv"]), grid[-1], (t, deg)


LL_BANDWIDTHS = [0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]


def _ll_weights(x, h):
    """Local linear smoother with a Gaussian kernel in D: rows give the fitted level
    and slope at each x_i as linear combinations of the outcomes."""
    u = x[None, :] - x[:, None]
    k = np.exp(-0.5 * (u / h) ** 2)
    s0, s1, s2 = k.sum(1), (k * u).sum(1), (k * u * u).sum(1)
    det = (s0 * s2 - s1 ** 2)[:, None]
    L = k * (s2[:, None] - u * s1[:, None]) / det
    S = k * (u * s0[:, None] - s1[:, None]) / det
    return L, S


def local_linear(des, h, tol=1e-10, maxit=500):
    """Local linear ACR: E[ddY | D] fitted among exposed firms by local linear
    regression with bandwidth h (units of D), its slope averaged over exposed firms.
    With controls (ctrl), the fixed effects enter additively and are estimated
    jointly by backfitting: alternate the local linear fit on ddY net of the fixed
    effects and the fixed-effect projection of ddY net of the fit (zero for
    zero-connectivity firms). The ACR is a linear combination of the outcomes, so
    its SE is heteroskedasticity-robust conditional on the fixed effects. LOO-CV
    uses the smoother's diagonal. As h grows, the fit tends to the linear
    specification."""
    x = des.D[des.pos]
    L, S = _ll_weights(x, h)
    if des.groups:
        m = np.zeros(len(des.y))
        for _ in range(maxit):
            v = des.y - m
            fe = v - demean(v[:, None], des.groups)[:, 0]
            z = (des.y - fe)[des.pos]
            m_new = np.zeros_like(m)
            m_new[des.pos] = L @ z
            if np.abs(m_new - m).max() < tol:
                break
            m = m_new
        m = m_new
    else:
        z = des.y[des.pos]
    fit = L @ z
    e = z - fit
    c = S.mean(0)                                   # ACR = c @ z
    cv = np.mean((e / (1 - np.diag(L))) ** 2)
    n = len(z)
    return {"h": h, "acr": c @ z, "se": float(np.sqrt(np.sum(c ** 2 * e ** 2) * n / (n - np.trace(L)))),
            "cv": cv, "edf": float(np.trace(L)), "x": x, "fit": fit, "slope": S @ z}


def ll_figure(y, ll, ref):
    """ACR and LOO-CV by bandwidth, with and without controls."""
    fig, (axC, axA) = plt.subplots(1, 2, figsize=(10, 3.8))
    for setting, lab, col, mk in (("raw", "No controls", "#7f7f7f", "o"), ("ctrl", "With controls", "#2166AC", "s")):
        r = ll[ll.setting == setting].sort_values("h")
        axC.plot(r.h, 100 * (r.cv / r.cv.iloc[-1] - 1), color=col, marker=mk, ms=5, lw=1.4, label=lab)
        best = r.loc[r.cv.idxmin()]
        axC.plot(best.h, 100 * (best.cv / r.cv.iloc[-1] - 1), marker=mk, ms=11, mfc="none", mec=col, mew=1.6)
        off = 0.96 if setting == "raw" else 1.04
        axA.errorbar(r.h * off, r.acr, yerr=1.96 * r.se, color=col, marker=mk, ms=5, lw=1.2,
                     elinewidth=0.8, capsize=0, label=lab)
        axA.plot(best.h * off, best.acr, marker=mk, ms=11, mfc="none", mec=col, mew=1.6)
        axA.axhline(ref[setting], color=col, lw=0.9, ls="--")
    for ax in (axC, axA):
        ax.set_xscale("log")
        ax.set_xlabel("Bandwidth h (units of scaled connectivity)", fontsize=9)
        ax.axhline(0, color="0.6", lw=0.6)
        style(ax)
    axC.set_ylabel(f"LOO-CV MSE, % vs. h = {LL_BANDWIDTHS[-1]:g}", fontsize=9)
    axA.set_ylabel("ACR and 95% CI", fontsize=9)
    axC.text(0, 1.03, "(a) Out-of-sample fit (circled: minimum)", transform=axC.transAxes, fontsize=9, weight="bold")
    axA.text(0, 1.03, "(b) ACR by bandwidth (dashed: linear)", transform=axA.transAxes, fontsize=9, weight="bold")
    axA.legend(fontsize=8, frameon=False, loc="lower right")
    fig.tight_layout()
    out = GRA / f"np_acr_locallinear_{y}.pdf"
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    return out


# ── Figure ───────────────────────────────────────────────────────────────────


def style(ax):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.tick_params(labelsize=8)
    ax.grid(axis="y", color="0.9", lw=0.6)
    ax.set_axisbelow(True)


def figure(des, y, setting, fits, fam_rows, ref):
    xe = des.D[des.pos]
    grid = np.exp(np.linspace(np.log(xe.min()), np.log(xe.max()), 400))
    xm, bc, ci, _ = des.bins(20)
    bins = np.column_stack([xm, bc, ci])

    fig = plt.figure(figsize=(11, 8.2))
    gs = fig.add_gridspec(3, 2, height_ratios=[3, 3, 1.1], width_ratios=[1.15, 1], hspace=0.35, wspace=0.22)
    axF, axS, axH = fig.add_subplot(gs[0, 0]), fig.add_subplot(gs[1, 0]), fig.add_subplot(gs[2, 0])
    axC, axA = fig.add_subplot(gs[0, 1]), fig.add_subplot(gs[1:, 1])
    axS.sharex(axF), axH.sharex(axF)

    # (a) fit and (b) slope
    axF.errorbar(bins[:, 0], bins[:, 1], yerr=bins[:, 2], fmt="o", ms=4, color="0.25",
                 mfc="white", elinewidth=0.8, capsize=0, zorder=3, label="Binned means (95% CI)")
    deriv_at_obs = []
    for key, kind, size, lab, col, ls in SPECS:
        bas, r = fits[key]
        lev, der = des.curve(bas, r["beta"], grid)
        lab_acr = f"{lab} (ACR {r['acr']:.4f})"
        axF.plot(grid, lev, color=col, ls=ls, lw=1.8, label=lab_acr)
        axS.plot(grid, der, color=col, ls=ls, lw=1.8)
        deriv_at_obs.append(bas(xe)[1] @ r["beta"][1:])
    lo, hi = bins[:, 1].min() - bins[:, 2].max(), bins[:, 1].max() + bins[:, 2].max()
    pad = 0.35 * (hi - lo)
    axF.set_ylim(lo - pad, hi + pad)
    axF.axhline(0, color="0.6", lw=0.6)
    axF.set_xscale("log")
    axF.set_ylabel(f"Change in {YLAB[y]}\nrelative to zero connectivity", fontsize=9)
    axF.legend(fontsize=7.5, frameon=False, loc="best")
    axF.text(0.0, 1.02, "(a) Fit: E[ΔY | D = d]", transform=axF.transAxes, fontsize=9, weight="bold")

    q = np.percentile(np.concatenate(deriv_at_obs), [2, 98])
    span = q[1] - q[0]
    axS.set_ylim(q[0] - 0.15 * span, q[1] + 0.15 * span)
    axS.axhline(0, color="0.6", lw=0.6)
    axS.set_ylabel("Slope ACRT(d)", fontsize=9)
    axS.text(0.0, 1.02, "(b) Slope ACRT(d); ACR = its mean over exposed firms",
             transform=axS.transAxes, fontsize=9, weight="bold")

    # (c) doses
    edges = np.exp(np.linspace(np.log(xe.min()), np.log(xe.max()), 41))
    axH.hist(xe, bins=edges, color="0.55", edgecolor="white", linewidth=0.5)
    for ax in (axF, axS, axH):
        for qq in np.percentile(xe, [10, 50, 90]):
            ax.axvline(qq, color="0.5", lw=0.6, ls=":", zorder=0)
    for qq, t in zip(np.percentile(xe, [10, 50, 90]), ("p10", "p50", "p90")):
        axH.text(qq, 1.0, t, fontsize=7, ha="center", va="bottom", transform=axH.get_xaxis_transform())
    axH.set_xlabel("Scaled connectivity D (log scale; 1 = 2009 p90 among untreated)", fontsize=9)
    axH.set_ylabel("Firms", fontsize=9)
    axH.text(0.0, 1.22, "(c) Connectivity of exposed firms", transform=axH.transAxes, fontsize=9, weight="bold")
    plt.setp(axF.get_xticklabels(), visible=False)
    plt.setp(axS.get_xticklabels(), visible=False)

    # (d) CV and (e) ACR by dimension
    off = {"poly": -0.18, "bspline": 0.0, "nspline": 0.18}
    for fam, sizes, lab, col, mk in FAMILIES:
        r = fam_rows[fam_rows.family == fam].sort_values("dim")
        x = r.dim + off[fam]
        axC.errorbar(x, r.cv_rel_pct, yerr=1.96 * r.cv_rel_se_pct, color=col, marker=mk, ms=5, lw=1.4,
                     elinewidth=0.8, capsize=0, label=lab)
        best = r.iloc[int(np.argmin(r.cv_mse.to_numpy()))]
        axC.plot(best.dim + off[fam], best.cv_rel_pct, marker=mk, ms=11, mfc="none", mec=col, mew=1.6)
        axA.errorbar(x, r.acr, yerr=1.96 * r.se, color=col, marker=mk, ms=5, lw=1.2,
                     elinewidth=0.8, capsize=0, label=lab)
        sel = r[r["size"] == {"poly": 3, "bspline": 1, "nspline": 1}[fam]]
        axA.plot(sel.dim + off[fam], sel.acr, marker=mk, ms=11, mfc="none", mec=col, mew=1.6)
    axC.axhline(0, color="0.6", lw=0.6)
    axC.set_ylabel("CV MSE, % above linear (95% CI)", fontsize=9)
    axC.set_xlabel("Basis dimension (number of dose terms)", fontsize=9)
    axC.legend(fontsize=7.5, frameon=False, loc="lower left")
    axC.text(0.0, 1.02, "(d) Out-of-sample fit vs. linear (circled: minimum)", transform=axC.transAxes,
             fontsize=9, weight="bold")

    axA.axhline(0, color="0.6", lw=0.6)
    axA.axhline(ref["twfe"], color="0.2", lw=1.0, ls="--")
    axA.text(axA.get_xlim()[1], ref["twfe"], "TWFE slope ", fontsize=7.5, va="bottom", ha="right")
    axA.set_ylabel("ACR and 95% CI", fontsize=9)
    axA.set_xlabel("Basis dimension (number of dose terms)", fontsize=9)
    axA.legend(fontsize=7.5, frameon=False, loc="lower left")
    axA.text(0.0, 1.01, "(e) ACR by basis dimension (circled: 3272's choice)", transform=axA.transAxes,
             fontsize=9, weight="bold")
    for ax in (axF, axS, axH, axC, axA):
        style(ax)

    out = GRA / f"np_acr_diag_{setting}_{y}.pdf"
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    return out


FIT_BINS = [10, 20, 50]
ROWS = [("raw", "No controls"), ("ctrl", "With controls")]


def fit_figure(y, designs, fitsets):
    """Panel (a) only, in versions: rows = without / with controls; columns = the
    firm-level scatter, then 10, 20 and 50 equal-count bins; the four fitted
    curves in every panel."""
    nc = 1 + len(FIT_BINS)
    fig, axes = plt.subplots(2, nc, figsize=(3.3 * nc, 6.6), sharex=True)
    binned_axes, scat_axes, bin_ext, pts_all = [], [], [], []
    for i, (setting, rlab) in enumerate(ROWS):
        des, fits = designs[setting], fitsets[setting]
        xe = des.D[des.pos]
        grid = np.linspace(xe.min(), xe.max(), 800)
        _, _, _, pts = des.bins(max(FIT_BINS))
        pts_all.append(pts)
        for j in range(nc):
            ax = axes[i, j]
            if j == 0:
                ax.scatter(xe, pts, s=4, color="0.35", alpha=0.25, lw=0, rasterized=True)
                scat_axes.append(ax)
            else:
                xm, b, ci, _ = des.bins(FIT_BINS[j - 1])
                ax.errorbar(xm, b, yerr=ci, fmt="o", ms=3.5, color="0.25", mfc="white",
                            elinewidth=0.7, capsize=0, zorder=3)
                bin_ext += [(b - ci).min(), (b + ci).max()]
                binned_axes.append(ax)
            for key, kind, size, lab, col, ls in SPECS:
                bas, r = fits[key]
                lev, _ = des.curve(bas, r["beta"], grid)
                ax.plot(grid, lev, color=col, ls=ls, lw=1.6, label=f"{lab}")
            ax.axhline(0, color="0.6", lw=0.6, zorder=0)
            style(ax)
            if i == 0:
                ax.set_title("Firm-level scatter" if j == 0 else f"{FIT_BINS[j - 1]} bins",
                             fontsize=9.5, weight="bold")
            if i == 1:
                ax.set_xlabel("Scaled connectivity D", fontsize=8.5)
        axes[i, 0].set_ylabel(f"{rlab}\n\nChange in {YLAB[y]}\nrelative to zero connectivity", fontsize=8.5)

    lo, hi = min(bin_ext), max(bin_ext)
    pad = 0.08 * (hi - lo)
    for ax in binned_axes:
        ax.set_ylim(lo - pad, hi + pad)
    q = np.percentile(np.concatenate(pts_all), [1, 99])
    for ax in scat_axes:
        ax.set_ylim(q[0], q[1])
    h, l = axes[0, 1].get_legend_handles_labels()
    fig.legend(h, l, loc="upper center", bbox_to_anchor=(0.5, 0.0), ncol=4, frameon=False, fontsize=8.5)
    fig.tight_layout()
    out = GRA / f"np_acr_fit_{y}.pdf"
    fig.savefig(out, bbox_inches="tight", dpi=200)
    plt.close(fig)
    return out


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outcomes", nargs="+", default=["lr_remdezr_h_w", "lr_remdezr_w"])
    ap.add_argument("--folds", type=int, default=10)
    ap.add_argument("--reps", type=int, default=5)
    a = ap.parse_args()

    df = pd.read_stata(DATA)
    df = df[df.treat_ultra == 0]
    rows, extra, ll_rows = [], [], []
    for y in a.outcomes:
        designs, fitsets = {}, {}
        for setting in ("raw", "ctrl"):
            des = Design(df, y, setting)
            fits = {}
            designs[setting], fitsets[setting] = des, fits
            for key, kind, size, *_ in SPECS:
                bas = Basis(kind, size, des.xs)
                fits[key] = (bas, des.fit(bas))
            # TWFE slope reference: linear in D (ctrl: plus 1{D>0}, as Panel B twfe has no pos)
            Xl = demean(des.D[:, None], des.groups) if des.groups else np.column_stack([np.ones(len(des.D)), des.D])
            ref = {"twfe": ols(Xl, des.yt)[-1]}
            fam = []
            e_lin = des.cv_err(Basis("poly", 1, des.xs), a.folds, a.reps, SEED)
            for kind, sizes, *_ in FAMILIES:
                for s in sizes:
                    bas = Basis(kind, s, des.xs)
                    r = des.fit(bas)
                    dif = des.cv_err(bas, a.folds, a.reps, SEED) - e_lin
                    fam.append({"outcome": y, "setting": setting, "family": kind, "size": s, "dim": bas.dim,
                                "acr": r["acr"], "se": r["se"], "acr_below_p10": r["acr_low"],
                                "cv_mse": e_lin.mean() + dif.mean(),
                                "cv_rel_pct": 100 * dif.mean() / e_lin.mean(),
                                "cv_rel_se_pct": 100 * dif.std(ddof=1) / np.sqrt(len(dif)) / e_lin.mean(),
                                "n": len(des.y), "n_exposed": int(des.pos.sum())})
            fam = pd.DataFrame(fam)
            rows.append(fam)
            for kn in PLIN_KNOTS:
                r = des.fit(PLin(kn))
                extra.append({"outcome": y, "setting": setting, "estimator": "plin",
                              "spec": "knots at D = " + ", ".join(f"{k:g}" for k in kn),
                              "acr": r["acr"], "se": r["se"], "edf": len(kn) + 1})
            for nseg in (20, 40):
                best, stiff, _ = pspline(des, nseg=nseg)
                extra.append({"outcome": y, "setting": setting, "estimator": "pspline",
                              "spec": f"{nseg} segments, GCV", "acr": best["acr"], "se": best["se"],
                              "edf": best["edf"], "log10_lambda": np.log10(best["lam"])})
                extra.append({"outcome": y, "setting": setting, "estimator": "pspline",
                              "spec": f"{nseg} segments, largest penalty (check: = linear)",
                              "acr": stiff["acr"], "se": stiff["se"], "edf": stiff["edf"]})
            out = figure(des, y, setting, fits, fam, ref)
            print(f"{y} {setting}: n={len(des.y)}, exposed={des.pos.sum()}; "
                  + ", ".join(f"{k} {fits[k][1]['acr']:.4f} ({fits[k][1]['se']:.4f})" for k in fits)
                  + f"\n  -> {out}")
        print(f"  -> {fit_figure(y, designs, fitsets)}")
        llr = pd.DataFrame([{"outcome": y, "setting": s, **{k: v for k, v in local_linear(designs[s], h).items()
                                                            if k in ("h", "acr", "se", "cv", "edf")}}
                            for s in ("raw", "ctrl") for h in LL_BANDWIDTHS])
        ll_rows.append(llr)
        ref = {s: fitsets[s]["linear"][1]["acr"] for s in ("raw", "ctrl")}
        print(f"  -> {ll_figure(y, llr, ref)}")
    pd.concat(rows).to_csv(TAB / "np_acr_diag.csv", index=False)
    pd.DataFrame(extra).to_csv(TAB / "np_acr_extra.csv", index=False)
    pd.concat(ll_rows).to_csv(TAB / "np_acr_ll.csv", index=False)
    print(f"Wrote {TAB / 'np_acr_diag.csv'}, np_acr_extra.csv and np_acr_ll.csv")


if __name__ == "__main__":
    main()
