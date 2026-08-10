"""
es_mincer_overlay_plot.py
Overlay event study plots: log December wage (lr_remdezr_w) vs
Mincer-residualized log wage (lr_remdezr_resid), for direct and spillover.
Black-and-white safe: filled square vs open circle, solid vs dashed CI lines.
Output:
  - Graphs/residuals/es_mincer_direct_overlay.pdf
  - Graphs/residuals/es_mincer_spill_overlay.pdf
"""

from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import matplotlib.lines as mlines
import scipy.stats as stats

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT       = Path(__file__).resolve().parent.parent.parent
tables_dir = ROOT / "Tables" / "residuals"
graphs_dir = ROOT / "Graphs" / "residuals"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Libertinus Serif font ─────────────────────────────────────────────────────
font_dir = ROOT / "fonts"
for fp in font_dir.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))

# ── B&W-safe style ────────────────────────────────────────────────────────────
# Residualized log wage: filled black square, solid lines
# Log wage:              open circle, dashed lines
BLACK     = "black"
GRAY      = "#555555"
BASE_YEAR = 2011
XLINE_POS = 2011.5
ALL_YEARS = list(range(2009, 2017))

RESID_STYLE = dict(color=BLACK, marker="s", linestyle="-",  label="Residualized log wage")
RAW_STYLE   = dict(color=GRAY,  marker="o", linestyle="--", label="Log wage")

plt.rcParams.update({
    "font.family":       "Libertinus Serif",
    "font.weight":       "bold",
    "font.size":         10,
    "axes.labelweight":  "bold",
    "axes.titleweight":  "bold",
    "axes.spines.top":   False,
    "axes.spines.right": False,
})


def stars(coef, se):
    t = abs(coef / se) if se > 0 else 0
    p = 2 * (1 - stats.norm.cdf(t))
    if p < 0.01: return "***"
    if p < 0.05: return "**"
    if p < 0.10: return "*"
    return ""


def load_data(stem):
    coefs   = pd.read_csv(tables_dir / f"es_mincer_{stem}_coefs.csv").sort_values("year")
    meta_df = pd.read_csv(tables_dir / f"es_mincer_{stem}_meta.csv")
    meta    = dict(zip(meta_df["key"], meta_df["val"]))
    return coefs, meta


def plot_series(ax, coefs, style, offset=0.0):
    """Plot CI bars + markers for one series. CI lines use style linestyle."""
    years = coefs["year"].values
    coef  = coefs["coef"].values
    ci_lo = coefs["ci_lo"].values
    ci_hi = coefs["ci_hi"].values
    color    = style["color"]
    linestyle = style["linestyle"]
    cap_w = 0.10

    for yr, lo, hi in zip(years, ci_lo, ci_hi):
        x = yr + offset
        ax.plot([x, x], [lo, hi], color=color, linewidth=1.0,
                linestyle=linestyle, zorder=2)
        ax.plot([x - cap_w, x + cap_w], [lo, lo], color=color,
                linewidth=1.0, zorder=2)
        ax.plot([x - cap_w, x + cap_w], [hi, hi], color=color,
                linewidth=1.0, zorder=2)

    base     = years == BASE_YEAR
    non_base = ~base
    # non-base: filled
    ax.scatter(years[non_base] + offset, coef[non_base],
               marker=style["marker"], s=40, color=color,
               zorder=3, linewidths=0)
    # base year: hollow
    ax.scatter(years[base] + offset, coef[base],
               marker=style["marker"], s=40,
               facecolors="white", edgecolors=color, linewidths=1.5, zorder=4)


def make_overlay_plot(coefs_resid, meta_resid, coefs_raw, meta_raw, ytitle, out_path):
    fig, ax = plt.subplots(figsize=(7, 5.3))   # +1 inch height
    fig.subplots_adjust(left=0.13, right=0.97, top=0.95, bottom=0.22)
    ax.set_facecolor("white")
    fig.patch.set_facecolor("white")

    plot_series(ax, coefs_resid, RESID_STYLE, offset=-0.1)
    plot_series(ax, coefs_raw,   RAW_STYLE,   offset=+0.1)

    # Reference lines
    ax.axhline(0, color="black", linewidth=0.8, zorder=1)
    ax.axvline(XLINE_POS, color="black", linewidth=0.9, linestyle="--", alpha=0.7, zorder=1)

    # Axes formatting
    ax.set_xticks(ALL_YEARS)
    ax.set_xticklabels([str(y) for y in ALL_YEARS], fontsize=9, fontweight="bold")
    ax.set_xlabel("Year", fontsize=10, fontweight="bold")
    ax.set_ylabel(ytitle, fontsize=10, fontweight="bold")
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.3f"))
    for lbl in ax.get_yticklabels():
        lbl.set_fontweight("bold")

    # Horizontal guide lines (within visible range only)
    fig.canvas.draw()
    ymin, ymax = ax.get_ylim()
    for ytick in ax.get_yticks():
        if ymin <= ytick <= ymax:
            ax.axhline(ytick, color="gray", linewidth=0.5, alpha=0.25, zorder=0)

    # Legend
    leg_resid = mlines.Line2D([], [], color=BLACK, marker="s", markersize=7,
                               linewidth=1, linestyle="-",
                               label="Residualized log wage")
    leg_raw   = mlines.Line2D([], [], color=GRAY,  marker="o", markersize=7,
                               linewidth=1, linestyle="--",
                               label="Log wage")
    ax.legend(handles=[leg_resid, leg_raw], fontsize=8,
              frameon=False, loc="upper left",
              prop={"weight": "bold", "size": 8})

    # ── Pooled DiD annotations side by side ───────────────────────────────────
    b_r  = meta_resid.get("post_coef", float("nan"))
    se_r = meta_resid.get("post_se",   float("nan"))
    b_w  = meta_raw.get("post_coef",   float("nan"))
    se_w = meta_raw.get("post_se",     float("nan"))
    if b_r == b_r and b_w == b_w:
        s_r = stars(b_r, se_r)
        s_w = stars(b_w, se_w)
        ax.text(0.38, 0.97,
                f"{b_r:.4f}{s_r} ({se_r:.4f})",
                color=BLACK, fontsize=8, fontweight="bold",
                ha="center", va="top", transform=ax.transAxes)
        ax.text(0.75, 0.97,
                f"{b_w:.4f}{s_w} ({se_w:.4f})",
                color=GRAY, fontsize=8, fontweight="bold",
                ha="center", va="top", transform=ax.transAxes)

    # Note below plot
    pre_pval     = meta_resid.get("pre_pval", float("nan"))
    pre_pval_raw = meta_raw.get("pre_pval",   float("nan"))
    if pre_pval == pre_pval:
        fig.text(
            0.13, 0.09,
            f"Note: P-value for placebo pre-trend \u2014 residualized: {pre_pval:.3f},"
            f" log wage: {pre_pval_raw:.3f}",
            ha="left", va="bottom", fontsize=8, color="black", fontweight="bold",
        )

    fig.savefig(out_path, format="pdf", bbox_inches="tight", dpi=150)
    plt.close(fig)
    print(f"Saved: {out_path}")


# ── Direct overlay ────────────────────────────────────────────────────────────
coefs_rd, meta_rd = load_data("direct")
coefs_raw_d, meta_raw_d = load_data("raw_direct")
make_overlay_plot(
    coefs_rd, meta_rd, coefs_raw_d, meta_raw_d,
    ytitle="Dynamic DiD coefficients",
    out_path=graphs_dir / "es_mincer_direct_overlay.pdf",
)

# ── Spillover overlay ─────────────────────────────────────────────────────────
coefs_sp, meta_sp = load_data("spill")
coefs_raw_s, meta_raw_s = load_data("raw_spill")
make_overlay_plot(
    coefs_sp, meta_sp, coefs_raw_s, meta_raw_s,
    ytitle="Dynamic DiD coefficients",
    out_path=graphs_dir / "es_mincer_spill_overlay.pdf",
)

print("All overlay plots complete.")
