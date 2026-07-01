"""
firm_conn_residualize_plots.py  (Task 2)
Graphs for the connectivity residualization on the FULL variable set
(adds education shares, tenure, # clauses, mean age to the original 8),
for BOTH the spillover (untreated) sample and the treated firms.

Reads:  Tables/descriptives/firm_conn_frame.csv          (spillover sample)
        Tables/descriptives/firm_conn_frame_treated.csv  (treated firms)
        Tables/descriptives/binsreg/bs_*.dta             (binsreg; TODO, unused)
Writes (suffix "" = spillover, "_treated" = treated):
        Graphs/descriptives/conn_residualize_coefplot{sfx}.pdf
        Graphs/descriptives/binscatter_conn_full_raw{sfx}.pdf
        Graphs/descriptives/binscatter_conn_full_resid{sfx}.pdf
Run with /opt/homebrew/bin/python3.
"""
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path
plt.rcParams["font.family"] = "serif"

ROOT = Path(__file__).resolve().parent.parent.parent
TBL = ROOT / "Tables/descriptives"
outdir = ROOT / "Graphs/descriptives"; outdir.mkdir(parents=True, exist_ok=True)
BINS = TBL / "binsreg"

LABELS = [
    ("no_hs_c",        "% no high school"),
    ("hs_sup_c",       "% high school or college"),  # = hs_c + sup_c (= 1 - no_hs_c)
    ("mean_age",       "Mean worker age"),
    ("avg_tenure",     "Avg tenure (years)"),
    ("numb_clauses",   "# CBA clauses"),
    ("lr_remdezr_w",   "Log wages"),
    ("l_firm_emp",     "Log employment"),
    ("totalflows_pw_pre_07_11", "Per-worker flows (2007-11)"),
    ("prop_female",    "% female"),
    ("prop_non_white", "% non-white"),
]

def centered_grid(fig, n, ncol=3):
    """n panels in ncol columns; the incomplete last row is centered."""
    gs = gridspec.GridSpec(int(np.ceil(n/ncol)), 2*ncol, figure=fig)
    full_rows = n // ncol; rem = n % ncol; axes = []
    for i in range(n):
        row, cir = divmod(i, ncol)
        c0 = cir*2 if (row < full_rows or rem == 0) else (2*ncol - 2*rem)//2 + cir*2
        axes.append(fig.add_subplot(gs[row, c0:c0+2]))
    return axes

def binpoints(x, y, n_pos=18):
    """Zero-x firms -> one point (size = their share); positive x -> equal-
    frequency bins (size = bin share). Marker size thus reflects mass."""
    x = np.asarray(x, float); y = np.asarray(y, float)
    z = x == 0
    bx, by, sz = [], [], []
    if z.any():
        bx.append(x[z].mean()); by.append(y[z].mean()); sz.append(z.mean())
    xp, yp = x[~z], y[~z]
    if len(xp):
        d = pd.DataFrame({"x": xp, "y": yp})
        d["b"] = pd.qcut(d["x"].rank(method="first"), q=min(n_pos, len(d)), labels=False)
        g = d.groupby("b")[["x","y"]].mean(); cnt = d.groupby("b").size()/len(x)
        bx += list(g["x"]); by += list(g["y"]); sz += list(cnt)
    return np.array(bx), np.array(by), np.array(sz)

def panel_bin(ax, x, y, color="#2166AC", trim_lo=0.0, trim_hi=0.01):
    d = pd.DataFrame({"x": x, "y": y}).dropna()
    if len(d) < 50: return
    b1, b0 = np.polyfit(d.x, d.y, 1)                         # OLS on full data
    hi = d.x.quantile(1 - trim_hi); lo = d.x.quantile(trim_lo)
    dd = d[(d.x <= hi) & (d.x >= lo)]
    bx, by, sz = binpoints(dd.x.values, dd.y.values)
    ax.scatter(bx, by, s=30 + 600*sz, color=color, edgecolors="white",
               linewidths=0.6, zorder=4)
    xs = np.linspace(dd.x.min(), dd.x.max(), 100)
    ax.plot(xs, b0 + b1*xs, color="#B2182B", lw=1.6, zorder=3)


# ---------- figure builders (take a dataframe + output suffix/label) ----------
def coefplot(df, fname, title, color="#2166AC"):
    rows = []
    for v, lab in LABELS:
        if v not in df or f"resid_{v}" not in df: continue
        raw = df[["totaltreat_pw_norm", v]].dropna().corr().iloc[0,1]
        par = df[["resid_conn", f"resid_{v}"]].dropna().corr().iloc[0,1]
        rows.append((lab, raw, par))
    rows = sorted(rows, key=lambda r: r[1])
    fig, ax = plt.subplots(figsize=(7.2, len(rows)*0.46 + 1.0))
    for i, (lab, raw, par) in enumerate(rows):
        ax.plot([raw, par], [i, i], color="gray", lw=0.6, alpha=0.5, zorder=1)
        ax.scatter(raw, i, s=55, facecolors="white", edgecolors=color, linewidths=2,
                   zorder=3, label="Raw" if i==0 else None)
        ax.scatter(par, i, s=55, color="#B2182B", zorder=3,
                   label="After main-spec controls" if i==0 else None)
    ax.axvline(0, color="k", lw=0.8)
    ax.set_yticks(range(len(rows))); ax.set_yticklabels([r[0] for r in rows], fontsize=9)
    ax.set_xlabel("Correlation with connectivity", fontweight="bold")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.06), ncol=2, frameon=False, fontsize=9)
    ax.set_title(title, fontsize=10)
    for s in ["top","right"]: ax.spines[s].set_visible(False)
    fig.tight_layout(); fig.savefig(outdir / fname, bbox_inches="tight"); plt.close(fig)

def make_grid(df, xcol, ycol_fmt, fname, suptitle, xlab, trim_lo, trim_hi, color="#2166AC"):
    n = len(LABELS); nrow = int(np.ceil(n/3))
    fig = plt.figure(figsize=(13.5, 3.05*nrow + 0.9))
    axes = centered_grid(fig, n, ncol=3)               # incomplete last row centered
    for ax, (v, lab) in zip(axes, LABELS):
        yc = ycol_fmt(v)
        if xcol in df and yc in df:
            panel_bin(ax, df[xcol], df[yc], color=color, trim_lo=trim_lo, trim_hi=trim_hi)
        ax.set_title(lab, fontsize=9.5)
        ax.set_xlabel(xlab, fontsize=8); ax.tick_params(labelsize=7.5)
        for s in ["top","right"]: ax.spines[s].set_visible(False)
    fig.suptitle(suptitle, fontsize=11)
    fig.tight_layout(rect=[0,0,1,0.985])
    fig.savefig(outdir / fname, bbox_inches="tight", dpi=150); plt.close(fig)

def make_binsreg_grid(fname, suptitle, xlab, color="#2166AC"):
    """Cattaneo et al. (2024) covariate-adjusted binscatter. TODO: looked off;
    kept here but not called (see do-file do_binsreg flag)."""
    n = len(LABELS)
    fig = plt.figure(figsize=(13.5, 12.5)); axes = centered_grid(fig, n, ncol=3)
    for ax, (v, lab) in zip(axes, LABELS):
        f = BINS / f"bs_{v}.dta"
        if f.exists():
            b = pd.read_stata(f); dots = b.dropna(subset=["dots_x"]).sort_values("dots_x")
            if "CI_x" in b.columns:
                ci = b.dropna(subset=["CI_x"])
                ax.vlines(ci["CI_x"], ci["CI_l"], ci["CI_r"], color=color, lw=1.0, alpha=0.65, zorder=2)
            ax.plot(dots["dots_x"], dots["dots_fit"], color=color, lw=0.8, alpha=0.5, zorder=3)
            ax.scatter(dots["dots_x"], dots["dots_fit"], s=26, color=color,
                       edgecolors="white", linewidths=0.6, zorder=4)
        ax.set_title(lab, fontsize=9.5); ax.set_xlabel(xlab, fontsize=8); ax.tick_params(labelsize=7.5)
        for s in ["top","right"]: ax.spines[s].set_visible(False)
    fig.suptitle(suptitle, fontsize=11); fig.tight_layout(rect=[0,0,1,0.985])
    fig.savefig(outdir / fname, bbox_inches="tight", dpi=150); plt.close(fig)


def single_panel(df, xcol, ycol, lab, fname, xlab, color, trim_lo, trim_hi):
    fig, ax = plt.subplots(figsize=(5.0, 3.8))
    if xcol in df and ycol in df:
        panel_bin(ax, df[xcol], df[ycol], color=color, trim_lo=trim_lo, trim_hi=trim_hi)
    ax.set_title(lab, fontsize=10); ax.set_xlabel(xlab, fontsize=9)
    for s in ["top","right"]: ax.spines[s].set_visible(False)
    fig.tight_layout(); fig.savefig(outdir / fname, bbox_inches="tight", dpi=150); plt.close(fig)


def run(frame_csv, sfx, sample_label, color="#2166AC"):
    if not frame_csv.exists():
        print(f"SKIP {sample_label}: {frame_csv.name} not found"); return
    df = pd.read_csv(frame_csv, na_values=[".", ""])
    for c in df.columns:
        if c != "identificad": df[c] = pd.to_numeric(df[c], errors="coerce")
    # combined high-school-or-college share (= 1 - %no-HS) and its residual
    if {"hs_c", "sup_c"} <= set(df.columns):
        df["hs_sup_c"] = df["hs_c"] + df["sup_c"]
    if {"resid_hs_c", "resid_sup_c"} <= set(df.columns):
        df["resid_hs_sup_c"] = df["resid_hs_c"] + df["resid_sup_c"]
    # tenure: months -> years (residual is linear, so divide it too)
    if "avg_tenure" in df: df["avg_tenure"] = df["avg_tenure"] / 12.0
    if "resid_avg_tenure" in df: df["resid_avg_tenure"] = df["resid_avg_tenure"] / 12.0
    n = len(df)
    XLR = "Connectivity (normalized; top 1% trimmed)"
    XLC = "Connectivity, residualized on controls"
    coefplot(df, f"conn_residualize_coefplot{sfx}.pdf",
             f"Raw vs. control-conditional correlation with connectivity — {sample_label} (n={n:,})",
             color=color)
    make_grid(df, "totaltreat_pw_norm", lambda v: v, f"binscatter_conn_full_raw{sfx}.pdf",
              f"Connectivity vs. firm characteristics — raw — {sample_label} "
              "(marker size ∝ share of firms; zero-connectivity firms = one large point)",
              XLR, 0.0, 0.01, color=color)
    make_grid(df, "resid_conn", lambda v: f"resid_{v}", f"binscatter_conn_full_resid{sfx}.pdf",
              f"Residualized on main-spec controls — {sample_label} "
              "(residualize-then-bin; marker size ∝ share of firms)",
              XLC, 0.01, 0.01, color=color)
    # individual per-variable PDFs (raw + residualized)
    for v, lab in LABELS:
        single_panel(df, "totaltreat_pw_norm", v, lab,
                     f"binscatter_conn_{v}_raw{sfx}.pdf", XLR, color, 0.0, 0.01)
        single_panel(df, "resid_conn", f"resid_{v}", lab,
                     f"binscatter_conn_{v}_resid{sfx}.pdf", XLC, color, 0.01, 0.01)
    print(f"  {sample_label}: 2 grids + {2*len(LABELS)} individual panels (n={n:,})")

print("Wrote:")
run(TBL / "firm_conn_frame.csv",         "",         "spillover (untreated) sample", "#2166AC")
# Treated-firm connectivity graph deprecated in favor of the Task-2 balance table (balance_table_task2). Re-enable if needed.
# run(TBL / "firm_conn_frame_treated.csv", "_treated", "treated firms",                "#E08214")
