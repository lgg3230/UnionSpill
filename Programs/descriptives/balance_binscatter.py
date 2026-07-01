"""
balance_binscatter.py  (Task 2)
Connectivity binscatters whose fitted slopes MATCH the balance table
(balance_table_task2): raw = column 5, residualized = column 6.

Reads:  Tables/descriptives/balance_binscatter_frame.csv   (from balance_table_task2.do)
        columns: totaltreat_pw_norm, <char>, resid_<char>, rc_<char>  (spillover sample)
Writes: Graphs/descriptives/balance_binscatter_raw.pdf
        Graphs/descriptives/balance_binscatter_resid.pdf

Each characteristic X is residualized (and connectivity is residualized as rc_X) on
X's own controls_y in the do-file, so the OLS slope of resid_X on rc_X equals the
table's col-6 coefficient (FWL); raw X on connectivity equals col 5. Every panel is
annotated with beta so the match to the table is visible. Run with /opt/homebrew/bin/python3.
"""
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path
plt.rcParams["font.family"] = "serif"

ROOT = Path(__file__).resolve().parent.parent.parent
TBL  = ROOT / "Tables/descriptives"
OUT  = ROOT / "Graphs/descriptives"; OUT.mkdir(parents=True, exist_ok=True)

# (var, label, display scale)  -- order matches the table rows (connectivity is the x-axis)
ROWS = [
    ("lr_remdezr_w",            "Log wages",              1.0),
    ("l_firm_emp",              "Log employment",         1.0),
    ("hs_c",                    "High-school share",      1.0),
    ("sup_c",                   "Higher-education share", 1.0),
    ("prop_female",             "Share female",           1.0),
    ("prop_non_white",          "Share non-white",        1.0),
    ("mean_age",                "Mean worker age (years)",1.0),
    ("avg_tenure",              "Mean tenure (years)",    1.0/12.0),  # months -> years
    ("numb_clauses",            "CBA clause count",       1.0),
    ("totalflows_pw_pre_07_11", "Worker flows (p.w.)",    1.0),
]
BLUE, RED = "#2166AC", "#B2182B"


def centered_grid(fig, n, ncol=3):
    gs = gridspec.GridSpec(int(np.ceil(n/ncol)), 2*ncol, figure=fig)
    full_rows, rem = n // ncol, n % ncol
    axes = []
    for i in range(n):
        row, cir = divmod(i, ncol)
        c0 = cir*2 if (row < full_rows or rem == 0) else (2*ncol - 2*rem)//2 + cir*2
        axes.append(fig.add_subplot(gs[row, c0:c0+2]))
    return axes


def ols_slope(x, y):
    """OLS slope with HC1-robust SE and two-sided p (matches Stata vce(robust))."""
    x = np.asarray(x, float); y = np.asarray(y, float)
    n = len(x); xb = x.mean(); dx = x - xb
    Sxx = (dx**2).sum()
    b = (dx*(y - y.mean())).sum()/Sxx
    a = y.mean() - b*xb
    e = y - a - b*x
    var_b = (n/(n-2)) * (e**2 * dx**2).sum() / Sxx**2       # HC1
    se = np.sqrt(var_b)
    import math
    p = math.erfc(abs(b/se)/math.sqrt(2))                    # normal approx (n large)
    return b, se, p


def stars(p):
    return "***" if p < .01 else "**" if p < .05 else "*" if p < .10 else ""


def binpoints(xplot, y, zref, ntot, n_pos=18):
    """Zero-connectivity firms (zref==0) -> one marker sized by their share; the
    positive-connectivity firms -> equal-frequency bins on the plotted x. Marker
    size thus reflects mass even in residualized space (where xplot has no zero mass).
    zref identifies the zero group (raw connectivity); xplot is the x actually drawn."""
    xplot = np.asarray(xplot, float); y = np.asarray(y, float); zref = np.asarray(zref, float)
    z = zref == 0
    bx, by, sz = [], [], []
    if z.any():
        bx.append(xplot[z].mean()); by.append(y[z].mean()); sz.append(z.sum()/ntot)
    xp, yp = xplot[~z], y[~z]
    if len(xp):
        d = pd.DataFrame({"x": xp, "y": yp})
        d["b"] = pd.qcut(d["x"].rank(method="first"), q=min(n_pos, len(d)), labels=False)
        g = d.groupby("b")[["x","y"]].mean(); cnt = d.groupby("b").size()/ntot
        bx += list(g["x"]); by += list(g["y"]); sz += list(cnt)
    return np.array(bx), np.array(by), np.array(sz)


def panel(ax, x, y, trim_lo, trim_hi, zref=None, xlim=None):
    d = pd.DataFrame({"x": x, "y": y, "z": (x if zref is None else zref)}).dropna()
    if len(d) < 50:
        return None
    b, se, p = ols_slope(d.x.values, d.y.values)            # slope on FULL data (= table)
    ntot = len(d)
    dz = d[d.z == 0]                                         # zero-connectivity group (kept whole)
    dp = d[d.z != 0]                                         # positive group -> trim x for display
    if len(dp):
        hi = dp.x.quantile(1 - trim_hi); lo = dp.x.quantile(trim_lo)
        dp = dp[(dp.x <= hi) & (dp.x >= lo)]
    dd = pd.concat([dz, dp])
    bx, by, sz = binpoints(dd.x.values, dd.y.values, dd.z.values, ntot)
    ax.scatter(bx, by, s=30 + 600*sz, color=BLUE, edgecolors="white", linewidths=0.6, zorder=4)
    x0, x1 = xlim if xlim is not None else (dd.x.min(), dd.x.max())
    xs = np.linspace(x0, x1, 100)
    a = d.y.mean() - b*d.x.mean()
    ax.plot(xs, a + b*xs, color=RED, lw=1.6, zorder=3)
    if xlim is not None:
        ax.set_xlim(xlim)
    ax.text(0.04, 0.93, rf"$\beta={b:.4f}${stars(p)}", transform=ax.transAxes,
            fontsize=8.5, va="top", ha="left",
            bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.7))
    return b


def make_grid(df, xfmt, yfmt, fname, suptitle, xlab, trim_lo, trim_hi, zref_col=None, xlim=None):
    n = len(ROWS); nrow = int(np.ceil(n/3))
    fig = plt.figure(figsize=(13.5, 3.05*nrow + 0.9))
    axes = centered_grid(fig, n, ncol=3)
    slopes = {}
    for ax, (v, lab, sc) in zip(axes, ROWS):
        xc, yc = xfmt(v), yfmt(v)
        if xc in df and yc in df:
            zref = df[zref_col] if (zref_col and zref_col in df) else None
            b = panel(ax, df[xc], sc*df[yc], trim_lo, trim_hi, zref=zref, xlim=xlim)
            if b is not None:
                slopes[v] = b
        ax.set_title(lab, fontsize=9.5)
        ax.set_xlabel(xlab, fontsize=8); ax.tick_params(labelsize=7.5)
        for s in ["top", "right"]:
            ax.spines[s].set_visible(False)
    fig.suptitle(suptitle, fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.985])
    fig.savefig(OUT / fname, bbox_inches="tight", dpi=150); plt.close(fig)
    return slopes


def main():
    f = TBL / "balance_binscatter_frame.csv"
    df = pd.read_csv(f, na_values=[".", ""])
    for c in df.columns:
        if c != "identificad":
            df[c] = pd.to_numeric(df[c], errors="coerce")
    n = len(df)
    XR = "Connectivity (normalized; top 1% trimmed)"
    XC = "Connectivity, residualized on the row's controls"
    raw = make_grid(df, lambda v: "totaltreat_pw_norm", lambda v: v,
                    "balance_binscatter_raw.pdf",
                    f"Connectivity and pre-reform characteristics — raw (spillover sample, n={n:,})",
                    XR, 0.0, 0.01, xlim=(0, 4))
    res = make_grid(df, lambda v: f"rc_{v}", lambda v: f"resid_{v}",
                    "balance_binscatter_resid.pdf",
                    f"Residualized on the row's main-spec controls (spillover sample, n={n:,})",
                    XC, 0.01, 0.01, zref_col="totaltreat_pw_norm", xlim=(-2, 3))
    print("panel slopes (raw = table col 5, resid = table col 6):")
    for v, lab, _ in ROWS:
        print(f"  {lab:26} raw {raw.get(v, float('nan')):+.4f}   resid {res.get(v, float('nan')):+.4f}")


if __name__ == "__main__":
    main()
