#!/usr/bin/env python
"""
honest_did_F1.py
Builds Fenizia & Saggio (2024, Fig. F.1)-style three-panel figures for the
UnionSpill direct (Sample A) and spillover event studies, entirely from EXISTING
coefficient outputs (no re-estimation):

  Panel (a)  Event study + linear pre-trend extrapolation
             event-study coefficients (+95% CI), with an OLS line fit on the
             PRE-period coefficients only, extrapolated through the post period.
  Panel (b)  Rotated event study
             coefficients minus the extrapolated line (the "honest" detrended
             view); the linear trend is treated as fixed (CI half-widths kept).
  Panel (c)  HonestDiD (Rambachan-Roth 2023) sensitivity
             robust 95% CI for the first post-period coefficient as the
             sensitivity parameter grows, OLS CI overlaid, breakdown marked.
             Restriction = the primary one for that effect (note 4b):
               direct  -> Delta^SD (smoothness, M)
               spill   -> Delta^RM (relative magnitudes, Mbar)

Inputs:
  Tables/honest_did/pretrends_results.csv  (per-period coef/ci; power=50 rows)
  Tables/honest_did/honest_did_results.csv (RR sensitivity grid)
  Tables/honest_did/honest_did_breakdown.csv (breakdown values + flags)

One figure per effect: honest_did_F1_{direct,spill}.{pdf,png}, rows = outcomes.

Run with the project conda python:
  ~/.conda/envs/venv_python312/bin/python Programs/honest_did/honest_did_F1.py
"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

HERE       = Path(__file__).resolve().parent
ROOT       = HERE.parent.parent
TABLES_DIR = ROOT / "Tables" / "honest_did"
GRAPHS_DIR = ROOT / "Graphs" / "honest_did"
GRAPHS_DIR.mkdir(parents=True, exist_ok=True)

PRETRENDS_CSV = TABLES_DIR / "pretrends_results.csv"
RESULTS_CSV   = TABLES_DIR / "honest_did_results.csv"
BREAKDOWN_CSV = TABLES_DIR / "honest_did_breakdown.csv"

# ── fonts (Libertinus Serif; silent fallback) ───────────────────────────────
try:
    import matplotlib.font_manager as fm
    _variants = ["LibertinusSerif-Regular.otf", "LibertinusSerif-Italic.otf",
                 "LibertinusSerif-Bold.otf", "LibertinusSerif-BoldItalic.otf"]
    _loaded = False
    for d in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts",
              str(HERE.parent / "fonts")]:
        if Path(d).exists():
            for v in _variants:
                fp = Path(d) / v
                if fp.exists():
                    fm.fontManager.addfont(str(fp)); _loaded = True
            if _loaded:
                break
    if _loaded:
        plt.rcParams["font.family"]      = "Libertinus Serif"
        plt.rcParams["mathtext.fontset"] = "custom"
        plt.rcParams["mathtext.rm"]      = "Libertinus Serif"
        plt.rcParams["mathtext.it"]      = "Libertinus Serif:italic"
        plt.rcParams["mathtext.bf"]      = "Libertinus Serif:bold"
        plt.rcParams["mathtext.fallback"] = "cm"
except Exception:
    pass

C_COEF   = "#222222"   # event-study point estimates
C_TREND  = "#2166AC"   # extrapolated linear pre-trend (blue)
C_ROBUST = "#B2182B"   # robust honest-DiD band (red)
C_OLS    = "#2166AC"   # original OLS CI (blue)

OUTCOME_LABEL = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages",
                 "l_firm_emp": "Log employment", "numb_clauses": "\\# CBA clauses"}
OUTCOMES      = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
EFFECT_LABEL  = {"direct": "Direct effect (Sample A)", "spill": "Spillover effect"}
# primary restriction per effect (design note 4b)
PRIMARY_RESTR = {"direct": "sd", "spill": "rm"}
RESTR_NAME    = {"rm": r"$\Delta^{RM}$ (relative magnitudes)",
                 "sd": r"$\Delta^{SD}$ (smoothness)"}
RESTR_X       = {"rm": r"$\bar{M}$", "sd": r"$M$"}
TARGET        = "p1"   # first post-period (headline; most robust)
YEAR0         = 2012   # event time t=0 (first post period) = calendar 2012
# numb_clauses runs on CBA negotiation periods, not calendar years: event time
# t maps to CBA period t+3 (period 2 = reference at t=-1). Everything else is
# on calendar years (t=-1 -> 2011 reference, t=0 -> 2012 first post).


def x_ticklabels(outcome, t):
    if outcome == "numb_clauses":
        return [f"P{int(v) + 3}" for v in t]      # CBA periods 1..6
    return [str(int(v) + YEAR0) for v in t]       # calendar years


def load_coefs():
    df = pd.read_csv(PRETRENDS_CSV)
    df = df[df["power"].astype(str) == "50"].copy()
    for c in ["time", "coef", "ci_lo", "ci_hi"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


def fit_pretrend(t, b, t_ref=-1):
    """OLS line through pre-period coefficients (event time <= t_ref).
    Returns slope, intercept fit on {t <= t_ref}."""
    mask = t <= t_ref
    A = np.vstack([t[mask], np.ones(mask.sum())]).T
    slope, intercept = np.linalg.lstsq(A, b[mask], rcond=None)[0]
    return slope, intercept


def panel_eventstudy(ax, g, show_ylabel):
    outcome = g["outcome"].iloc[0]
    t  = g["time"].values
    b  = g["coef"].values
    lo = g["ci_lo"].values
    hi = g["ci_hi"].values
    slope, intc = fit_pretrend(t, b)
    line = slope * t + intc
    ax.axhline(0, color="black", lw=0.7)
    ax.axvline(-0.5, color="gray", lw=0.7, ls=":")          # reform line (event time)
    ax.errorbar(t, b, yerr=[b - lo, hi - b], fmt="o", ms=4, color=C_COEF,
                ecolor=C_COEF, elinewidth=1.1, capsize=2, zorder=3)
    ax.plot(t, line, color=C_TREND, lw=1.6, ls="--", zorder=2,
            label="Linear pre-trend (extrapolated)")
    ax.set_xticks(t)
    ax.set_xticklabels(x_ticklabels(outcome, t), fontsize=6.5, rotation=45)
    if show_ylabel:
        ax.set_ylabel("(a) Event study\n+ extrapolation", fontsize=8.5)
    return slope, intc


def panel_rotated(ax, g, slope, intc, show_ylabel):
    outcome = g["outcome"].iloc[0]
    t  = g["time"].values
    b  = g["coef"].values
    lo = g["ci_lo"].values
    hi = g["ci_hi"].values
    line = slope * t + intc
    br = b - line
    lor = lo - line
    hir = hi - line
    ax.axhline(0, color="black", lw=0.7)
    ax.axvline(-0.5, color="gray", lw=0.7, ls=":")
    ax.errorbar(t, br, yerr=[br - lor, hir - br], fmt="o", ms=4, color=C_ROBUST,
                ecolor=C_ROBUST, elinewidth=1.1, capsize=2, zorder=3)
    ax.set_xticks(t)
    ax.set_xticklabels(x_ticklabels(outcome, t), fontsize=6.5, rotation=45)
    if show_ylabel:
        ax.set_ylabel("(b) Rotated\nevent study", fontsize=8.5)


def panel_sensitivity(ax, effect, outcome, restr, res, bd, show_ylabel):
    g = res[(res["effect"] == effect) & (res["outcome"] == outcome) &
            (res["restriction"] == restr) & (res["target"] == TARGET)]
    grid = g[g["is_original"] == 0].sort_values("m")
    og   = g[g["is_original"] == 1]
    m, lb, ub = grid["m"].values, grid["lb"].values, grid["ub"].values
    ax.axhline(0, color="black", lw=0.7)
    # robust band as a function of the sensitivity parameter
    ax.fill_between(m, lb, ub, color=C_ROBUST, alpha=0.18, zorder=1)
    ax.plot(m, lb, color=C_ROBUST, lw=1.3, zorder=2)
    ax.plot(m, ub, color=C_ROBUST, lw=1.3, zorder=2, label="Robust 95% CI")
    # original OLS CI as a horizontal reference band
    if not og.empty:
        o_lb = float(og["lb"].iloc[0]); o_ub = float(og["ub"].iloc[0])
        ax.axhspan(o_lb, o_ub, color=C_OLS, alpha=0.12, zorder=0)
        ax.axhline(o_lb, color=C_OLS, lw=0.9, ls=":")
        ax.axhline(o_ub, color=C_OLS, lw=0.9, ls=":", label="Original OLS CI")
    # breakdown marker (annotated at the breakdown line, inside the axes)
    brow = bd[(bd["effect"] == effect) & (bd["outcome"] == outcome) &
              (bd["restriction"] == restr) & (bd["target"] == TARGET)]
    if not brow.empty:
        r = brow.iloc[0]
        flag = str(r["flag"])
        ymax = max(ub.max(), float(og["ub"].iloc[0]) if not og.empty else ub.max())
        if flag.startswith("OLS n.s."):
            ax.text(0.5, 0.92, "OLS CI already includes 0", transform=ax.transAxes,
                    ha="center", va="top", fontsize=7.5, color="dimgray")
        elif r["status"] == "at_min":
            ax.text(0.5, 0.92, f"crosses 0 at {RESTR_X[restr]} = 0",
                    transform=ax.transAxes, ha="center", va="top",
                    fontsize=7.5, color="dimgray")
        else:
            val = float(r["breakdown"])
            ax.axvline(val, color="black", lw=1.0, ls="--", zorder=4)
            txt = f"breakdown {RESTR_X[restr]} = {val:.3g}"
            ax.annotate(txt, xy=(val, ymax), xytext=(4, -2),
                        textcoords="offset points", ha="left", va="top",
                        fontsize=7, color="black")
    ax.set_xlim(m.min(), m.max())
    ax.set_xlabel(RESTR_X[restr], fontsize=10)
    if show_ylabel:
        ax.set_ylabel("(c) HonestDiD\nsensitivity", fontsize=8.5)


def build(effect, coefs, res, bd):
    restr = PRIMARY_RESTR[effect]
    nrow = len(OUTCOMES)
    fig, axes = plt.subplots(nrow, 3, figsize=(11, 2.7 * nrow), squeeze=False)
    for ri, outcome in enumerate(OUTCOMES):
        g = coefs[(coefs["effect"] == effect) &
                  (coefs["outcome"] == outcome)].sort_values("time")
        slope, intc = panel_eventstudy(axes[ri][0], g, show_ylabel=True)
        panel_rotated(axes[ri][1], g, slope, intc, show_ylabel=True)
        panel_sensitivity(axes[ri][2], effect, outcome, restr, res, bd,
                          show_ylabel=True)
        # row label (outcome) on the far left, above the y-axis label
        axes[ri][0].set_title(OUTCOME_LABEL[outcome], fontsize=10,
                              fontweight="bold", loc="left")
    # column headers on the top row
    axes[0][0].annotate("(a) Coefficients + linear extrapolation",
                        xy=(0.5, 1.18), xycoords="axes fraction", ha="center",
                        fontsize=8.5, color="dimgray")
    axes[0][1].annotate("(b) Rotated (detrended) event study",
                        xy=(0.5, 1.18), xycoords="axes fraction", ha="center",
                        fontsize=8.5, color="dimgray")
    axes[0][2].annotate(f"(c) Sensitivity: {RESTR_NAME[restr]}",
                        xy=(0.5, 1.18), xycoords="axes fraction", ha="center",
                        fontsize=8.5, color="dimgray")
    handles = [
        Line2D([0], [0], color=C_COEF, marker="o", lw=1.1, ms=4,
               label="Event-study coef. (95% CI)"),
        Line2D([0], [0], color=C_TREND, lw=1.6, ls="--",
               label="Linear pre-trend (extrapolated)"),
        Patch(facecolor=C_ROBUST, alpha=0.3, label="Robust 95% CI band"),
        Line2D([0], [0], color=C_OLS, lw=0.9, ls=":", label="Original OLS CI"),
        Line2D([0], [0], color="black", lw=1.0, ls="--", label="Breakdown value"),
    ]
    fig.legend(handles=handles, loc="lower center", ncol=3, frameon=False,
               bbox_to_anchor=(0.5, -0.02), fontsize=8)
    fig.suptitle(EFFECT_LABEL[effect], fontsize=12, fontweight="bold", y=1.0)
    fig.tight_layout(rect=[0, 0.04, 1, 0.96], h_pad=3.2, w_pad=2.0)
    out = GRAPHS_DIR / f"honest_did_F1_{effect}.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out}")


def main():
    coefs = load_coefs()
    res = pd.read_csv(RESULTS_CSV)
    if "target" not in res.columns:
        res["target"] = "p1"
    for c in ["m", "lb", "ub", "is_original"]:
        res[c] = pd.to_numeric(res[c], errors="coerce")
    bd = pd.read_csv(BREAKDOWN_CSV)
    for effect in ["direct", "spill"]:
        build(effect, coefs, res, bd)


if __name__ == "__main__":
    main()
