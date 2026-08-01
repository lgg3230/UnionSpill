#!/usr/bin/env python3
"""
Distribution plots: Treated vs All Untreated vs Zero Connectivity Untreated

Three grouped bar charts (B&W-safe, Libertinus Serif font):
  1. Regional distribution         -> Graphs/descriptives/distro_region.pdf
  2. Broad industry distribution   -> Graphs/descriptives/distro_broad_industry.pdf
  3. Mode base month distribution  -> Graphs/descriptives/distro_mode_base_month.pdf

Sample: year == 2011, lagos_sample_avg == 1, in_balanced_panel == 1
Groups:
  - Treated             : treat_ultra == 1
  - All untreated       : treat_ultra == 0  (all controls)
  - Zero connectivity untreated : treat_ultra == 0 & totaltreat_pw_n == 0  (subset)
"""

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import matplotlib.patches as mpatches

# -- Paths ---------------------------------------------------------------------

ROOT      = Path(__file__).resolve().parent.parent.parent
DATA_DIR  = ROOT / "Data" / "CBA_RAIS_firm_level"
FONTS_DIR = ROOT / "Programs" / "fonts"
GRAPH_DIR = ROOT / "Graphs" / "descriptives"
GRAPH_DIR.mkdir(parents=True, exist_ok=True)

# -- Font setup (Libertinus Serif) ---------------------------------------------

for ttf in FONTS_DIR.glob("LibertinusSerif-*.ttf"):
    fm.fontManager.addfont(str(ttf))

_prop = fm.FontProperties(fname=str(FONTS_DIR / "LibertinusSerif-Regular.ttf"))
FONT_NAME = _prop.get_name()

plt.rcParams.update({
    "font.family":     FONT_NAME,
    "font.weight":     "bold",
    "font.size":       9,
    "axes.titlesize":  10,
    "axes.titleweight": "bold",
    "axes.labelsize":  9,
    "axes.labelweight": "bold",
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "legend.fontsize": 8,
    "pdf.fonttype":    42,
    "ps.fonttype":     42,
})

# -- B&W-safe style constants --------------------------------------------------

# Groups: treated | untreated (all controls) | zero-conn (subset of untreated)
GROUPS       = ["treated", "untreated", "zero"]
GROUP_LABELS = ["Treated", "All untreated", "Zero connectivity untreated"]

DARK_BLUE  = "#08306b"
LIGHT_BLUE = "#6baed6"

BAR_FC    = [DARK_BLUE,  LIGHT_BLUE, "#ffffff"]
BAR_EC    = [DARK_BLUE,  LIGHT_BLUE, DARK_BLUE]
BAR_HATCH = [None,       None,       "////"]
BAR_LW    = [0.6,        0.6,        0.6]

# -- Load and filter data ------------------------------------------------------

COLS = ["year", "treat_ultra", "totaltreat_pw_n",
        "lagos_sample_avg", "in_balanced_panel",
        "big_region", "big_industry", "mode_base_month"]

print("Loading data ...")
df_full = pd.read_stata(DATA_DIR / "lagos_sample_sep24_pct_unionexp_ext_df2.dta",
                        columns=COLS)

mask = (df_full["year"] == 2011) & \
       (df_full["lagos_sample_avg"] == 1) & \
       (df_full["in_balanced_panel"] == 1)
df = df_full.loc[mask].copy()

# Group masks (untreated and zero overlap: zero is a subset of untreated)
MASKS = {
    "treated":   df["treat_ultra"] == 1,
    "untreated": df["treat_ultra"] == 0,
    "zero":      (df["treat_ultra"] == 0) & (df["totaltreat_pw_n"] == 0),
}

print(f"  Treated: {MASKS['treated'].sum():,}  |"
      f"  All untreated: {MASKS['untreated'].sum():,}  |"
      f"  Zero connectivity untreated: {MASKS['zero'].sum():,}")

# -- Map raw CNAE 2-digit codes -> 18 broad industry categories ----------------

def map_broad_industry(v):
    if pd.isna(v):
        return np.nan
    v = int(v)
    if v in (1, 2, 3):             return 1   # Farming/fishing
    if 5  <= v <= 9:               return 2   # Extractive ind.
    if 10 <= v <= 33:              return 3   # Manufacturing
    if 35 <= v <= 39:              return 4   # Utilities
    if 41 <= v <= 43:              return 5   # Construction
    if 45 <= v <= 47:              return 6   # Trade/commerce
    if 49 <= v <= 53:              return 7   # Transportation
    if 55 <= v <= 56:              return 8   # Hospitality
    if 58 <= v <= 63:              return 9   # Communication
    if 64 <= v <= 66:              return 10  # Banking/finance
    if v == 68:                    return 11  # Real estate
    if (69 <= v <= 75) or \
       (77 <= v <= 79):            return 12  # Professional act.
    if 80 <= v <= 82:              return 13  # Admin. act.
    if v == 84:                    return 14  # Public admin.
    if v == 85:                    return 15  # Education
    if 86 <= v <= 88:              return 16  # Health
    if 90 <= v <= 91:              return 17  # Culture/sports
    if 92 <= v <= 99:              return 18  # Other
    return np.nan

df["broad_industry"] = df["big_industry"].apply(map_broad_industry)

# -- Helper: compute pct distribution ------------------------------------------

def group_pct(df, cat_col, cat_vals, cat_labels):
    """
    Returns a DataFrame with one row per category and one column per group,
    containing the share (%) of observations in that category within each group.
    Uses MASKS to support overlapping groups (e.g. zero subset of untreated).
    """
    rows = []
    for val, lbl in zip(cat_vals, cat_labels):
        row = {"label": lbl, "sort_key": val}
        for g in GROUPS:
            sub = df[MASKS[g]]
            row[g] = 100.0 * (sub[cat_col] == val).sum() / len(sub) if len(sub) else 0.0
        rows.append(row)
    return pd.DataFrame(rows).sort_values("sort_key")

# -- Helper: draw grouped bar chart --------------------------------------------

def draw_bars(ax, pct_df, ylim=None, ytick_step=None):
    n_cats  = len(pct_df)
    width   = 0.25
    offsets = np.array([-1, 0, 1]) * width
    xs      = np.arange(n_cats)

    for i, (g, fc, ec, hatch, lw) in enumerate(
            zip(GROUPS, BAR_FC, BAR_EC, BAR_HATCH, BAR_LW)):
        ax.bar(xs + offsets[i], pct_df[g], width=width,
               facecolor=fc, edgecolor=ec, hatch=hatch,
               linewidth=lw, zorder=3)

    ax.set_xticks(xs)
    ax.set_xticklabels(pct_df["label"], rotation=40, ha="right", fontsize=8, fontweight="bold")
    ax.set_ylabel("Percent", fontsize=9, fontweight="bold")
    for lbl in ax.get_yticklabels():
        lbl.set_fontweight("bold")
    ax.yaxis.grid(True, linestyle="--", linewidth=0.5, alpha=0.5, zorder=0)
    ax.set_axisbelow(True)
    ax.spines[["top", "right"]].set_visible(False)

    if ylim is not None:
        ax.set_ylim(0, ylim)
    if ytick_step is not None:
        ymax = ylim if ylim is not None else ax.get_ylim()[1]
        ax.set_yticks(np.arange(0, ymax + 0.001, ytick_step))

    legend_handles = [
        mpatches.Patch(facecolor=fc, edgecolor=ec, hatch=hatch,
                       linewidth=lw, label=lbl)
        for fc, ec, hatch, lw, lbl in
        zip(BAR_FC, BAR_EC, BAR_HATCH, BAR_LW, GROUP_LABELS)
    ]
    leg = ax.legend(handles=legend_handles, loc="upper center",
                    bbox_to_anchor=(0.5, -0.28), ncol=3, frameon=False, fontsize=8)
    for txt in leg.get_texts():
        txt.set_fontweight("bold")


# == 1. REGIONAL DISTRIBUTION ==================================================

region_vals   = [1, 2, 3, 4, 5]
region_labels = ["North", "Northeast", "Southeast", "South", "Midwest"]

pct_region = group_pct(df, "big_region", region_vals, region_labels)
pct_region = pct_region.sort_values("treated").reset_index(drop=True)

fig, ax = plt.subplots(figsize=(7, 4))
draw_bars(ax, pct_region, ylim=70, ytick_step=10)
fig.tight_layout()
out = GRAPH_DIR / "distro_region.pdf"
fig.savefig(out, bbox_inches="tight")
plt.close(fig)
print(f"Saved: {out}")


# == 2. BROAD INDUSTRY DISTRIBUTION ============================================

industry_vals   = list(range(1, 19))
industry_labels = [
    "Farming/fishing",   # 1
    "Extractive ind.",   # 2
    "Manufacturing",     # 3
    "Utilities",         # 4
    "Construction",      # 5
    "Trade/commerce",    # 6
    "Transportation",    # 7
    "Hospitality",       # 8
    "Communication",     # 9
    "Banking/finance",   # 10
    "Real estate",       # 11
    "Professional act.", # 12
    "Admin. act.",       # 13
    "Public admin.",     # 14
    "Education",         # 15
    "Health",            # 16
    "Culture/sports",    # 17
    "Other",             # 18
]

pct_ind = group_pct(df, "broad_industry", industry_vals, industry_labels)

fig, ax = plt.subplots(figsize=(7, 4))
draw_bars(ax, pct_ind, ylim=35, ytick_step=5)
fig.tight_layout()
out = GRAPH_DIR / "distro_broad_industry.pdf"
fig.savefig(out, bbox_inches="tight")
plt.close(fig)
print(f"Saved: {out}")


# == 3. MODE BASE MONTH DISTRIBUTION ===========================================

month_vals   = list(range(1, 13))
month_labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

pct_month = group_pct(df, "mode_base_month", month_vals, month_labels)

fig, ax = plt.subplots(figsize=(7, 4))
draw_bars(ax, pct_month, ylim=35, ytick_step=5)
fig.tight_layout()
out = GRAPH_DIR / "distro_mode_base_month.pdf"
fig.savefig(out, bbox_inches="tight")
plt.close(fig)
print(f"Saved: {out}")

print("Done.")
