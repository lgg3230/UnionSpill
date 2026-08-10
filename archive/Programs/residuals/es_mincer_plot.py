"""
es_mincer_plot.py
Event study plots for Mincer-residualized log December wages.
Reads CSVs produced by es_mincer.do and produces two PDF figures:
  - es_mincer_direct.pdf  (direct effect, Panel A)
  - es_mincer_spill.pdf   (spillover effect)
Style matches the coefplot template used in the turnover pipeline.
"""

from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT       = Path(__file__).resolve().parent.parent.parent
tables_dir = ROOT / "Tables" / "residuals"
graphs_dir = ROOT / "Graphs" / "residuals"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Libertinus Serif font ─────────────────────────────────────────────────────
font_dir = ROOT / "fonts"
for fp in font_dir.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))

# ── Shared plot style ─────────────────────────────────────────────────────────
BLUE       = "#2166AC"
BASE_YEAR  = 2011
XLINE_POS  = 2011.5          # dashed vertical line between 2011 and 2012
ALL_YEARS  = list(range(2009, 2017))

plt.rcParams.update({
    "font.family":        "Libertinus Serif",
    "font.weight":        "bold",
    "font.size":          10,
    "axes.labelweight":   "bold",
    "axes.titleweight":   "bold",
    "xtick.labelsize":    9,
    "ytick.labelsize":    9,
    "axes.spines.top":    False,
    "axes.spines.right":  False,
})


def load_data(stem):
    """Return (coefs_df, meta_dict) for a given file stem (direct or spill)."""
    coefs = pd.read_csv(tables_dir / f"es_mincer_{stem}_coefs.csv")
    coefs = coefs.sort_values("year").reset_index(drop=True)

    meta_df = pd.read_csv(tables_dir / f"es_mincer_{stem}_meta.csv")
    meta = dict(zip(meta_df["key"], meta_df["val"]))
    return coefs, meta


def make_event_study_plot(coefs, meta, ytitle, out_path):
    """
    Plot a vertical event study (time on x-axis, coefficient on y-axis).
    Replicates the coefplot template: square markers, rcap CIs, yline(0),
    dashed xline at 2011.5, pre-trend p-value note below plot, post annotation.
    """
    years  = coefs["year"].values
    coef   = coefs["coef"].values
    ci_lo  = coefs["ci_lo"].values
    ci_hi  = coefs["ci_hi"].values

    fig, ax = plt.subplots(figsize=(7, 4.3))
    # Reserve space: bottom for x-label + note, left for y-label
    fig.subplots_adjust(left=0.13, right=0.97, top=0.95, bottom=0.26)
    ax.set_facecolor("white")
    fig.patch.set_facecolor("white")

    # ── CI bars (rcap style) ──────────────────────────────────────────────────
    for yr, lo, hi in zip(years, ci_lo, ci_hi):
        ax.plot([yr, yr], [lo, hi], color=BLUE, linewidth=1.2, zorder=2)
        cap_w = 0.12
        ax.plot([yr - cap_w, yr + cap_w], [lo, lo], color=BLUE, linewidth=1.2, zorder=2)
        ax.plot([yr - cap_w, yr + cap_w], [hi, hi], color=BLUE, linewidth=1.2, zorder=2)

    # ── Markers ───────────────────────────────────────────────────────────────
    ax.scatter(years, coef, marker="s", s=45, color=BLUE, zorder=3, linewidths=0)

    # ── Base-year marker (hollow square) ──────────────────────────────────────
    base_mask = years == BASE_YEAR
    ax.scatter(years[base_mask], coef[base_mask],
               marker="s", s=45,
               facecolors="white", edgecolors=BLUE, linewidths=1.5, zorder=4)

    # ── Reference lines ───────────────────────────────────────────────────────
    ax.axhline(0, color="black", linewidth=0.8, linestyle="-", zorder=1)
    ax.axvline(XLINE_POS, color="black", linewidth=0.9, linestyle="--", alpha=0.7, zorder=1)

    # ── Axes formatting ───────────────────────────────────────────────────────
    ax.set_xticks(ALL_YEARS)
    ax.set_xticklabels([str(y) for y in ALL_YEARS], fontsize=9, fontweight="bold")
    ax.set_xlabel("Year", fontsize=10, fontweight="bold")
    ax.set_ylabel(ytitle, fontsize=10, fontweight="bold")
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.3f"))
    for lbl in ax.get_yticklabels():
        lbl.set_fontweight("bold")

    # ── Horizontal faded guide lines — only for ticks within the visible range ─
    fig.canvas.draw()
    ymin, ymax = ax.get_ylim()
    for ytick in ax.get_yticks():
        if ymin <= ytick <= ymax:
            ax.axhline(ytick, color="gray", linewidth=0.5, linestyle="-", alpha=0.25, zorder=0)

    # ── Post-treatment coefficient annotation (upper right, inside axes) ──────
    b_post  = meta.get("post_coef", float("nan"))
    se_post = meta.get("post_se",   float("nan"))
    if b_post == b_post:   # not NaN
        ax.text(
            0.72, 0.95,
            f"{b_post:.4f} ({se_post:.4f})",
            color=BLUE, fontsize=8, ha="center", va="top",
            transform=ax.transAxes,
        )

    # ── Pre-trend p-value note below the plot, in figure coordinates ──────────
    pre_pval = meta.get("pre_pval", float("nan"))
    if pre_pval == pre_pval:   # not NaN
        fig.text(
            0.13, 0.11,
            f"Note: P-value for placebo pre-trend = {pre_pval:.3f}",
            ha="left", va="bottom", fontsize=8, color="black",
        )

    fig.savefig(out_path, format="pdf", bbox_inches="tight", dpi=150)
    plt.close(fig)
    print(f"Saved: {out_path}")


# ── Direct effects (Panel A) ──────────────────────────────────────────────────
coefs_d, meta_d = load_data("direct")
make_event_study_plot(
    coefs_d, meta_d,
    ytitle="Dynamic DiD coefficients",
    out_path=graphs_dir / "es_mincer_direct.pdf",
)

# ── Spillover ─────────────────────────────────────────────────────────────────
coefs_s, meta_s = load_data("spill")
make_event_study_plot(
    coefs_s, meta_s,
    ytitle="Dynamic DiD coefficients",
    out_path=graphs_dir / "es_mincer_spill.pdf",
)

print("All event study plots complete.")
