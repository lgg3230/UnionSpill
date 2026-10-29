#!/usr/bin/env python3
"""
Spillover responses by log connectivity: binned scatters and fitted curves in
log D, for two connectivity measures and several outcomes. Companion to
3273_np_acr_diagnostics.py (same estimation; there the curves are in D).

For each (measure, outcome) one figure, 2 x 4 panels:
  rows     no controls / with controls
  columns  firm-level scatter, 10, 20 and 50 equal-count bins of exposed firms
  curves   fitted in L = log D among exposed firms: linear, quadratic, and a
           natural cubic spline with 3 interior knots (quartiles of L); the
           x-axis is log scale, so the linear fit is a straight line.

Measures (firm-constant, 2009 value; scaled so 1 = 2009 p90 among untreated
balanced-panel firms, as the paper scales the per-worker measure):
  pw  totaltreat_pw_norm: flows to treated firms per worker (connn0 of 3252)
  pf  totaltreat_pf_n / p90: share of the firm's flows that go to treated firms.
      Undefined for firms with no flows at all (175 untreated firms); set to 0,
      so both measures share the zero-connectivity comparison group.

Outcomes (dY = 2012-16 mean - 2009-11 mean, balanced panel):
  pf: lr_remdezr_h_w, lr_remdezr_w
  pw: lr_remdezr_h_w, l_firm_emp, hiring_rate_u, prop_hs, prop_nhs,
      turnover_u (separation rate = quits + layoffs + other), quit_rate_u,
      layoff_rate_u
  Wages and employment come from drdid_firm_wide.dta (3252); the turnover
  rates are the paper's turnover-analysis rates (corrected_turnover_sample.csv,
  3082), with dY winsorized at the 1st/99th percentiles among untreated firms;
  prop_hs / prop_nhs (shares of workers with / without completed high school)
  come from the firm panel.

Estimation as in 3273: no controls = exposed firms only, ddY = dY - mean(dY |
D = 0) on the basis; with controls = all untreated firms, ddY on 1{D>0} and the
basis, absorbing quartiles of the own 2009-11 outcome (none for employment),
2009-11 employment and 2007-11 flows, base month, microregion and industry1
(singletons dropped). Bins are coefficients on bin indicators estimated jointly
with the controls; scatter points are bin effect + residual (50-bin model). The
own-outcome quartiles of the new outcomes are built as in 3082: 2009 rows of the
balanced panel, treated and untreated firms, missing set to 0.

Input:  Data/RAIS_aux/drdid_firm_wide.dta, Data/CBA_RAIS_firm_level/
        lagos_sample_sep24_pct_unionexp_ext_df2.dta, corrected_turnover_sample.csv
Output: Graphs/drdid/conn_fit_logd_<measure>_<outcome>.pdf
        Tables/drdid/conn_fit_logd.csv  (slope/ACR per unit of log D, by fit)

Usage: python 3274_conn_fit_logd.py
"""

import importlib.util
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("acr", HERE / "3273_np_acr_diagnostics.py")
acr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(acr)

ROOT = acr.ROOT
PANEL = ROOT / "Data" / "CBA_RAIS_firm_level" / "lagos_sample_sep24_pct_unionexp_ext_df2.dta"
TURN = ROOT / "Data" / "CBA_RAIS_firm_level" / "corrected_turnover_sample.csv"

RUNS = [("pf", "lr_remdezr_h_w"), ("pf", "lr_remdezr_w"),
        ("pw", "lr_remdezr_h_w"), ("pw", "l_firm_emp"), ("pw", "hiring_rate_u"),
        ("pw", "prop_hs"), ("pw", "prop_nhs"),
        ("pw", "turnover_u"), ("pw", "quit_rate_u"), ("pw", "layoff_rate_u")]
TURN_VARS = ["hiring_rate_u", "turnover_u", "quit_rate_u", "layoff_rate_u"]
MEASURE = {"pw": "flows to treated firms per worker", "pf": "share of flows to treated firms"}
YLAB = {**acr.YLAB, "hiring_rate_u": "hiring rate", "turnover_u": "separation rate",
        "quit_rate_u": "quit rate", "layoff_rate_u": "layoff rate",
        "prop_hs": "share with high school", "prop_nhs": "share without high school"}
FITS = [("lin", "poly", 1, "Linear in log D", "#7f7f7f", (0, (4, 2))),
        ("quad", "poly", 2, "Quadratic in log D", "#2166AC", "-"),
        ("ns3", "nspline", 3, "Natural cubic spline in log D, 3 knots", "#B2182B", "-")]
BINS = [10, 20, 50]


# ── Data ─────────────────────────────────────────────────────────────────────
def build():
    """Firm-level frame of untreated firms: both measures, outcome changes, controls."""
    w = pd.read_stata(acr.DATA)
    p = pd.read_stata(PANEL, columns=["identificad", "year", "treat_ultra", "lagos_sample_avg",
                                      "in_balanced_panel", "totaltreat_pf_n", "prop_hs", "prop_nhs"])
    p = p[(p.year >= 2009) & (p.lagos_sample_avg == 1) & (p.in_balanced_panel == 1)]
    t = pd.read_csv(TURN, usecols=["identificad", "year"] + TURN_VARS, dtype={"identificad": str})
    p = p.merge(t, on=["identificad", "year"], how="left")

    pre, post = p[p.year.between(2009, 2011)], p[p.year.between(2012, 2016)]
    out = pd.DataFrame(index=pd.Index(p.identificad.unique(), name="identificad"))
    for v in TURN_VARS + ["prop_hs", "prop_nhs"]:
        m0 = pre.groupby("identificad")[v].mean()
        out[f"y_{v}_2"], out[f"y_{v}_3"] = m0, post.groupby("identificad")[v].mean()
        # own-outcome quartiles over all firms (treated and untreated), missing -> 0
        out[f"{v}_pre4"] = pd.qcut(m0, 4, labels=False, duplicates="drop").reindex(out.index).fillna(0)

    pf = p[p.year == 2009].set_index("identificad").totaltreat_pf_n
    untreated09 = p[(p.year == 2009) & (p.treat_ultra == 0)].set_index("identificad").totaltreat_pf_n
    out["pf"] = pf.fillna(0) / untreated09.fillna(0).quantile(0.9)

    w = w[w.treat_ultra == 0].merge(out, left_on="identificad", right_index=True, how="left")
    # Turnover rates have extreme firm-years (hiring and separation rates reach ~290):
    # winsorize their change dY at the 1st/99th percentiles among untreated firms.
    for v in TURN_VARS:
        dy = w[f"y_{v}_3"] - w[f"y_{v}_2"]
        w[f"y_{v}_3"] = w[f"y_{v}_2"] + dy.clip(*dy.quantile([0.01, 0.99]))
    return w.rename(columns={"connn0": "pw"})


TAG = {**acr.TAGS, **{v: v for v in TURN_VARS + ["prop_hs", "prop_nhs"]}}


class Design(acr.Design):
    """3273's Design with the dose and outcome chosen freely; the basis is in log D."""

    def __init__(self, df, measure, y, setting):
        own = [] if y == "l_firm_emp" else [f"{y}_pre4"]
        fes = own + ["l_firm_emp_pre4", "totalflows_pw_pre_07_114", "month0", "mreg0", "ind4"]
        g = TAG[y]
        d = df.assign(dy=df[f"y_{g}_3"] - df[f"y_{g}_2"], D=df[measure])
        d = d.dropna(subset=["dy", "D"] + fes)
        d["ddy"] = d["dy"] - d.loc[d.D == 0, "dy"].mean()
        d["L"] = np.log(d.D.where(d.D > 0))
        self.xs = d.loc[d.D > 0, "L"].to_numpy()
        self.setting = setting
        if setting == "raw":
            d = d[d.D > 0]
            self.groups, self.df_fe = None, 0
        else:
            d = acr.drop_singletons(d, fes)
            self.groups = [pd.factorize(d[f])[0] for f in fes]
            self.df_fe = sum(gr.max() + 1 for gr in self.groups) - len(fes)
        self.d = d
        self.D = d["D"].to_numpy()
        self.pos = self.D > 0
        self.y = d["ddy"].to_numpy()
        self.yt = acr.demean(self.y[:, None], self.groups)[:, 0] if self.groups else self.y

    def design(self, basis):
        # the basis is evaluated at log D; zero for zero-connectivity firms
        L = np.log(np.where(self.pos, self.D, 1.0))
        B, dB = basis(L)
        B[~self.pos], dB[~self.pos] = 0.0, 0.0
        if self.groups:
            X = acr.demean(np.column_stack([self.pos.astype(float), B]), self.groups)
        else:
            X = np.column_stack([np.ones(len(self.y)), B])
        return X, dB


# ── Figure ───────────────────────────────────────────────────────────────────
def figure(measure, y, designs, fitsets):
    nc = 1 + len(BINS)
    fig, axes = plt.subplots(2, nc, figsize=(3.3 * nc, 6.6), sharex=True)
    binned_axes, scat_axes, bin_ext, pts_all = [], [], [], []
    for i, (setting, rlab) in enumerate(acr.ROWS):
        des, fits = designs[setting], fitsets[setting]
        xe = des.D[des.pos]
        grid = np.linspace(np.log(xe.min()), np.log(xe.max()), 400)
        _, _, _, pts = des.bins(max(BINS))
        pts_all.append(pts)
        for j in range(nc):
            ax = axes[i, j]
            if j == 0:
                ax.scatter(xe, pts, s=4, color="0.35", alpha=0.25, lw=0, rasterized=True)
                scat_axes.append(ax)
            else:
                xm, b, ci, _ = des.bins(BINS[j - 1])
                ax.errorbar(xm, b, yerr=ci, fmt="o", ms=3.5, color="0.25", mfc="white",
                            elinewidth=0.7, capsize=0, zorder=3)
                bin_ext.append((b, ci))
                binned_axes.append(ax)
            for key, kind, size, lab, col, ls in FITS:
                bas, r = fits[key]
                lev, _ = des.curve(bas, r["beta"], grid)
                ax.plot(np.exp(grid), lev, color=col, ls=ls, lw=1.6, label=lab)
            ax.axhline(0, color="0.6", lw=0.6, zorder=0)
            ax.set_xscale("log")
            acr.style(ax)
            if i == 0:
                ax.set_title("Firm-level scatter" if j == 0 else f"{BINS[j - 1]} bins",
                             fontsize=9.5, weight="bold")
            if i == 1:
                ax.set_xlabel(f"Connectivity D, {MEASURE[measure]}\n(log scale; 1 = 2009 p90)", fontsize=8)
        axes[i, 0].set_ylabel(f"{rlab}\n\nChange in {YLAB[y]}\nrelative to zero connectivity", fontsize=8.5)

    # Robust limits: a few bins of outcomes with outliers (hiring_rate_u reaches 293)
    # would otherwise flatten every panel; such bins are clipped.
    b_all = np.concatenate([b for b, _ in bin_ext])
    ci_med = np.median(np.concatenate([ci for _, ci in bin_ext]))
    lo, hi = np.percentile(b_all, 3) - 1.5 * ci_med, np.percentile(b_all, 97) + 1.5 * ci_med
    for ax in binned_axes:
        ax.set_ylim(lo, hi)
    q = np.percentile(np.concatenate(pts_all), [1, 99])
    for ax in scat_axes:
        ax.set_ylim(q[0], q[1])
    h, l = axes[0, 1].get_legend_handles_labels()
    fig.legend(h, l, loc="upper center", bbox_to_anchor=(0.5, 0.0), ncol=3, frameon=False, fontsize=8.5)
    fig.tight_layout()
    out = acr.GRA / f"conn_fit_logd_{measure}_{y}.pdf"
    fig.savefig(out, bbox_inches="tight", dpi=200)
    plt.close(fig)
    return out


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    df = build()
    rows = []
    for measure, y in RUNS:
        designs, fitsets = {}, {}
        for setting in ("raw", "ctrl"):
            des = Design(df, measure, y, setting)
            fits = {key: (b := acr.Basis(kind, size, des.xs), des.fit(b)) for key, kind, size, *_ in FITS}
            designs[setting], fitsets[setting] = des, fits
            for key, (bas, r) in fits.items():
                rows.append({"measure": measure, "outcome": y, "setting": setting, "fit": key,
                             "acr_per_logD": r["acr"], "se": r["se"],
                             "n": len(des.y), "n_exposed": int(des.pos.sum())})
            # quadratic in z = (L - c)/s: sign and t-stat of the squared term, turning point in D
            bq, rq = fits["quad"]
            q = rq["beta"]
            quad = rows[-2]
            quad["sq_t"] = q[2] / np.sqrt(rq["V"][2, 2])
            quad["turning_point_D"] = float(np.exp(bq.c + bq.s * -q[1] / (2 * q[2])))
            quad["curvature"] = "U" if q[2] > 0 else "inverted U"
            print(f"{measure} {y:15s} {setting:4s} n={len(des.y)} exposed={des.pos.sum()}: "
                  + ", ".join(f"{k} {fits[k][1]['acr']:+.4f} ({fits[k][1]['se']:.4f})" for k in fits)
                  + f"; quad {quad['curvature']} (t={quad['sq_t']:.1f}) at D={quad['turning_point_D']:.2f}")
        print(f"  -> {figure(measure, y, designs, fitsets)}")
    pd.DataFrame(rows).to_csv(acr.TAB / "conn_fit_logd.csv", index=False)
    print(f"Wrote {acr.TAB / 'conn_fit_logd.csv'}")


if __name__ == "__main__":
    main()
