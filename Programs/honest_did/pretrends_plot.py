#!/usr/bin/env python
"""
pretrends_plot.py  --  Roth (2022) pre-trends power diagnostics (Bassier-style).

Reads Tables/honest_did/pretrends_results.csv (from honest_did.do) and produces,
for each power level (50%, 80%), an 8-panel event-study figure overlaying:
  - the estimated event-study coefficients (+ CIs),
  - the hypothesized LINEAR pre-trend the pre-test would reject with that power, and
  - the expected coefficients CONDITIONAL ON PASSING the pre-test under that trend.
Also writes a summary table of the power-implied slopes for all 8 specs.

Run with the project conda python.
"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

HERE        = Path(__file__).resolve().parent
ROOT        = HERE.parent.parent
TABLES_DIR  = ROOT / "Tables" / "honest_did"
GRAPHS_DIR  = ROOT / "Graphs" / "honest_did"
GRAPHS_DIR.mkdir(parents=True, exist_ok=True)
RESULTS_CSV = TABLES_DIR / "pretrends_results.csv"

try:
    import matplotlib.font_manager as fm
    for fp in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
               str(HERE.parent / "fonts" / "LibertinusSerif-Regular.otf")]:
        if Path(fp).exists():
            fm.fontManager.addfont(fp)
            plt.rcParams["font.family"] = "Libertinus Serif"
            break
except Exception:
    pass

C_EST   = "black"     # estimated coefficients
C_TREND = "#B2182B"   # hypothesized trend (red)
C_COND  = "#2166AC"   # E[coef | passed pre-test] (blue)

OUTCOME_LABEL = {
    "lr_remdezr_w":   "Log monthly earnings",
    "lr_remdezr_h_w": "Log hourly earnings",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "# CBA clauses",
}
OUTCOME_ORDER = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
EFFECT_LABEL  = {"direct": "Direct", "spill": "Spillover"}


def main():
    df = pd.read_csv(RESULTS_CSV)
    df = df[df["time"].astype(str) != ""].copy()
    for c in ["power", "time", "coef", "ci_lo", "ci_hi", "trend", "cond_mean", "slope"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df = df.dropna(subset=["time"])

    # ── summary of power-implied slopes ──────────────────────────────────────
    sl = (df.groupby(["effect", "outcome", "power"])["slope"].first()
            .unstack("power").reset_index())
    sl.columns = ["effect", "outcome"] + [f"slope_p{int(c)}" for c in sl.columns[2:]]
    sl = sl.sort_values(["effect", "outcome"])
    sl.to_csv(TABLES_DIR / "pretrends_slopes.csv", index=False)
    print(sl.to_string(index=False))
    write_latex(df, sl)

    for power in sorted(df["power"].unique()):
        plot_grid(df, int(power))


def write_latex(df, sl):
    """Slope detectable at 50%/80% power, with the estimated mean post-effect for
    context (so the reader can compare 'undetectable trend' to the actual effect)."""
    meanpost = (df[df["time"] > 0].groupby(["effect", "outcome"])["coef"].mean())
    sl = sl.set_index(["effect", "outcome"])
    lines = [r"\begin{table}[H]", r"\centering", r"\scriptsize",
             r"\caption{Roth (2022) pre-trends power diagnostics}",
             r"\label{tab:pretrends_slopes}",
             r"\begin{tabular}{llccc}", r"\hline\hline",
             r"Effect & Outcome & Slope (50\% power) & Slope (80\% power) & Mean post-effect \\",
             r"\hline"]
    for effect in ["direct", "spill"]:
        for outcome in OUTCOME_ORDER:
            key = (effect, outcome)
            s50 = sl.loc[key, "slope_p50"] if key in sl.index else np.nan
            s80 = sl.loc[key, "slope_p80"] if key in sl.index else np.nan
            mp  = meanpost.get(key, np.nan)
            dag = r"$^{\dagger}$" if outcome == "numb_clauses" else ""
            lines.append(rf"{EFFECT_LABEL[effect]} & {OUTCOME_LABEL[outcome]}{dag} & "
                         rf"{s50:.4f} & {s80:.4f} & {mp:.4f} \\")
        lines.append(r"\hline")
    lines.append(r"\end{tabular}")
    lines.append(
        r"\begin{minipage}{0.92\textwidth}\scriptsize This table reports, for each of the 8 "
        r"main event studies, the slope of a linear pre-trend (per period) that the standard "
        r"pre-trends test would reject with 50\% and 80\% probability (Roth, 2022). A larger "
        r"detectable slope means the pre-test is less powered. ``Mean post-effect'' is the "
        r"average estimated post-treatment coefficient, shown for scale: if the slope a "
        r"well-powered test would catch is small relative to the estimated effect, the effect "
        r"is unlikely to be an artifact of an undetected linear pre-trend. See the companion "
        r"figures for the hypothesized trends and the coefficients expected conditional on "
        r"passing the pre-test. $^{\dagger}$ numb\_clauses has a single pre-period, so its "
        r"power diagnostic is degenerate and should be read with caution.\end{minipage}")
    lines.append(r"\end{table}")
    (TABLES_DIR / "pretrends_slopes.tex").write_text("\n".join(lines))
    print(f"wrote {TABLES_DIR/'pretrends_slopes.tex'}")


def plot_grid(df, power):
    sub = df[df["power"] == power]
    fig, axes = plt.subplots(len(OUTCOME_ORDER), 2,
                             figsize=(11, 2.5 * len(OUTCOME_ORDER)), squeeze=False)
    for ri, outcome in enumerate(OUTCOME_ORDER):
        for ci, effect in enumerate(["direct", "spill"]):
            ax = axes[ri][ci]
            g = sub[(sub["outcome"] == outcome) & (sub["effect"] == effect)].sort_values("time")
            if g.empty:
                ax.text(0.5, 0.5, "n/a", ha="center", va="center",
                        transform=ax.transAxes, color="gray")
            else:
                t = g["time"].values
                # estimated coefs + CI
                yerr = np.vstack([g["coef"] - g["ci_lo"], g["ci_hi"] - g["coef"]])
                ax.errorbar(t, g["coef"], yerr=yerr, fmt="o", color=C_EST,
                            ms=4, lw=1, capsize=2, zorder=3, label="Estimated")
                # hypothesized linear trend
                ax.plot(t, g["trend"], color=C_TREND, ls="--", lw=1.6, zorder=2,
                        label=f"Trend ({power}% power)")
                # expected coefs conditional on passing the pre-test
                ax.plot(t, g["cond_mean"], color=C_COND, ls=":", lw=1.6,
                        marker="s", ms=3, mfc="white", zorder=2,
                        label="E[coef | passed test]")
                ax.axhline(0, color="gray", lw=0.6)
                ax.axvline(-0.5, color="gray", lw=0.6, ls="-", alpha=0.5)
                slope = g["slope"].iloc[0]
                ax.text(0.02, 0.96, f"slope={slope:.4f}", transform=ax.transAxes,
                        ha="left", va="top", fontsize=7, color=C_TREND)
            if ri == 0:
                ax.set_title(EFFECT_LABEL[effect], fontsize=11, fontweight="bold")
            if ci == 0:
                ax.set_ylabel(OUTCOME_LABEL[outcome], fontsize=9, fontweight="bold")
            if ri == len(OUTCOME_ORDER) - 1:
                ax.set_xlabel("Event time (periods from treatment; ref = $-1$)", fontsize=9)

    handles = [
        Line2D([0], [0], color=C_EST, marker="o", ls="none", ms=4, label="Estimated coefficient (95% CI)"),
        Line2D([0], [0], color=C_TREND, ls="--", lw=1.6, label=f"Hypothesized trend ({power}% power)"),
        Line2D([0], [0], color=C_COND, ls=":", lw=1.6, marker="s", ms=3, mfc="white",
               label="E[coefficient | passed pre-test]"),
    ]
    fig.legend(handles=handles, loc="lower center", ncol=3, frameon=False,
               bbox_to_anchor=(0.5, -0.01))
    fig.tight_layout(rect=[0, 0.03, 1, 1])
    out = GRAPHS_DIR / f"pretrends_{power}.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
