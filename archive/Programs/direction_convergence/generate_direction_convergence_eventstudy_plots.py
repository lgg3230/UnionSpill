"""
generate_direction_convergence_eventstudy_plots.py

Reads:
  Tables/direction_convergence/direction_convergence_eventstudy_results.csv
  Tables/direction_convergence/direction_convergence_treated_eventstudy_results.csv

Produces (one PDF + PNG per outcome):
  Graphs/direction_convergence/es_dirconv_<outcome>.{pdf,png}

Each plot overlays untreated-side and treated-side event-study coefficients
(connectivity × cba_period dummy, with cba_period == 2 omitted as base).
Vertical dashed line at 2.5 marks the post-Súmula cutoff.
"""

from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf"
try:
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"
except Exception:
    pass

this_dir     = Path(__file__).resolve().parent
project_root = this_dir.parent.parent
tables_dir   = project_root / "Tables" / "direction_convergence"
graphs_dir   = project_root / "Graphs" / "direction_convergence"
graphs_dir.mkdir(exist_ok=True, parents=True)

csv_u = tables_dir / "direction_convergence_eventstudy_results.csv"
csv_t = tables_dir / "direction_convergence_treated_eventstudy_results.csv"

OUTCOMES = [
    ("sim_cosine_shares",  "Cosine similarity (shares)"),
    ("sim_tv_shares",      "Total-variation similarity (shares)"),
    ("sim_ruzicka_counts", "Ruzicka similarity (counts)"),
    ("sim_bc_counts",      "Bray-Curtis similarity (counts)"),
]

df_u = pd.read_csv(csv_u)
df_t = pd.read_csv(csv_t)
for d in (df_u, df_t):
    d["outcome"] = d["outcome"].astype(str).str.strip()
    d["cba_period_val"] = d["cba_period_val"].astype(int)

UNTREATED_COLOR = "#2166AC"  # blue
TREATED_COLOR   = "#B2182B"  # red

for var, title in OUTCOMES:
    sub_u = df_u[df_u["outcome"] == var].sort_values("cba_period_val").copy()
    sub_t = df_t[df_t["outcome"] == var].sort_values("cba_period_val").copy()
    if sub_u.empty and sub_t.empty:
        print(f"  [skip] no rows for {var}")
        continue

    fig, ax = plt.subplots(figsize=(7.5, 4.2))

    def _plot(sub, color, label, x_offset):
        if sub.empty:
            return
        x = sub["cba_period_val"] + x_offset
        ax.errorbar(
            x, sub["coef"],
            yerr=[sub["coef"] - sub["ci_lower"], sub["ci_upper"] - sub["coef"]],
            fmt='o', color=color, ecolor=color, elinewidth=1.0,
            markersize=6, markerfacecolor="white", markeredgewidth=1.8,
            capsize=2, label=label,
        )
        ax.plot(x, sub["coef"], color=color, linewidth=0.9, alpha=0.6)

    _plot(sub_u, UNTREATED_COLOR, "Untreated focal (→ treated benchmark)", -0.06)
    _plot(sub_t, TREATED_COLOR,   "Treated focal (→ untreated benchmark)",  0.06)

    ax.axhline(0, color="black", linewidth=0.6)
    ax.axvline(2.5, color="gray", linestyle="--", linewidth=0.8, alpha=0.7)

    ax.set_xlabel("cba\\_period", fontsize=11)
    ax.set_ylabel(rf"$\beta$ (connectivity $\times$ period)", fontsize=11)
    ax.set_title(title, fontsize=12)

    periods = sorted(set(sub_u["cba_period_val"]).union(sub_t["cba_period_val"]))
    ax.set_xticks(periods)
    ax.set_xticklabels([str(p) for p in periods])

    ax.grid(True, alpha=0.2, linestyle=":")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.18),
              ncol=2, frameon=False, fontsize=9)

    plt.tight_layout()
    pdf_path = graphs_dir / f"es_dirconv_{var}.pdf"
    png_path = graphs_dir / f"es_dirconv_{var}.png"
    fig.savefig(pdf_path, bbox_inches="tight")
    fig.savefig(png_path, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {pdf_path.name} and {png_path.name}")
