#!/usr/bin/env python3
"""
generate_subgroup_coefplot.py
Coefficient plots for all three subgroup exercises.

Outputs (one per exercise × direct/spillover):
  Graphs/clause_types/coefplot_counts_direct.pdf
  Graphs/clause_types/coefplot_counts_spill.pdf
  Graphs/clause_types/coefplot_shares_direct.pdf
  Graphs/clause_types/coefplot_shares_spill.pdf
  Graphs/clause_types/coefplot_similarity_sg.pdf   (Exercise A)
"""

import re
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pathlib import Path

ROOT       = Path(__file__).resolve().parent.parent.parent
tables_dir = ROOT / "Tables" / "clause_types"
graphs_dir = ROOT / "Graphs" / "clause_types"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Font ──────────────────────────────────────────────────────────────────────
FONT_PATH = ROOT / "Programs" / "fonts" / "LibertinusSerif-Regular.otf"
if FONT_PATH.exists():
    fm.fontManager.addfont(str(FONT_PATH))
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Subgroup order (bottom → top matches reading order) ───────────────────────
SG_ORDER = ["sg11","sg12","sg13","sg14",
            "sg21","sg22","sg23","sg24",
            "sg31","sg32","sg33","sg34",
            "sg41","sg42","sg43","sg51",
            "sg61","sg62",
            "sg71","sg72","sg73",
            "sg81","sg82",
            "sg91"]

SH_ORDER = [s.replace("sg","sh") for s in SG_ORDER]

LABELS = {
    "sg11":"Wage adjustments", "sg12":"Wage payment",
    "sg13":"Other wages",      "sg14":"Other wage rules",
    "sg21":"Bonuses",          "sg22":"Pays",
    "sg23":"Assistances",      "sg24":"Other incentives",
    "sg31":"Separations",      "sg32":"Contract types",
    "sg33":"Hiring",           "sg34":"Other contracting",
    "sg41":"Staffing",         "sg42":"Working conditions",
    "sg43":"Empl. protections","sg51":"Workday",
    "sg61":"Injuries",         "sg62":"Prevention",
    "sg71":"Vacations",        "sg72":"Leaves",
    "sg73":"Other time off",   "sg81":"Union-firm relations",
    "sg82":"Union organization","sg91":"Bargaining",
}
LABELS.update({k.replace("sg","sh"): v for k, v in LABELS.items()})

# ── CSV helpers ───────────────────────────────────────────────────────────────

def parse_num(raw):
    if not raw or raw.strip() in ("--", ""):
        return None
    m = re.match(r"^([^*]+?)(\*{1,3})?$", raw.strip())
    if not m:
        return None
    try:
        return float(m.group(1).strip())
    except ValueError:
        return None

def load_coefs(csv_path):
    """Return dict: outcome -> {coef, se}"""
    if not csv_path.exists():
        print(f"  WARNING: {csv_path.name} not found")
        return {}
    df = pd.read_csv(csv_path, sep=None, engine="python", quotechar='"')
    # normalise column names
    df.columns = [c.strip().strip('"').lower() for c in df.columns]
    # semicolon-delimited inside rows is already split if sep=None detected it
    # fallback: re-parse
    if "row_type" not in df.columns:
        rows = []
        with open(csv_path) as f:
            next(f)
            for line in f:
                parts = line.strip().replace('"','').split(';')
                if len(parts) >= 6:
                    rows.append({"outcome": parts[2], "label": parts[3],
                                 "row_type": parts[4], "value": parts[5]})
        df = pd.DataFrame(rows)
    out = {}
    for _, row in df.iterrows():
        oc  = str(row.get("outcome","")).strip()
        rt  = str(row.get("row_type","")).strip()
        val = str(row.get("value","")).strip()
        if oc not in out:
            out[oc] = {}
        out[oc][rt] = val
    result = {}
    for oc, d in out.items():
        coef = parse_num(d.get("main",""))
        se   = parse_num(d.get("main_se",""))
        if coef is not None and se is not None:
            result[oc] = {"coef": coef, "se": se}
    return result

# ── Plot helper ───────────────────────────────────────────────────────────────

def coefplot(coefs_A, coefs_B, coefs_C, order, title_suffix, out_path,
             xlabel="Coefficient"):
    """Horizontal coefplot with three sets of estimates (Panels A/B/C)."""
    # Filter to outcomes present in at least one panel
    outcomes = [o for o in order if any(o in c for c in [coefs_A, coefs_B, coefs_C])]
    n = len(outcomes)
    if n == 0:
        print(f"  No data for {out_path.name}")
        return

    fig, ax = plt.subplots(figsize=(8, n * 0.55 + 1.2))

    colors = {"A": "#2166AC", "B": "#4DAC26", "C": "#D01C8B"}
    offsets = {"A": 0.2, "B": 0, "C": -0.2}
    markers = {"A": "o", "B": "s", "C": "^"}

    legend_handles = []

    for panel, coefs in [("A", coefs_A), ("B", coefs_B), ("C", coefs_C)]:
        col = colors[panel]
        off = offsets[panel]
        mk  = markers[panel]
        xs, ys = [], []
        xerr_lo, xerr_hi = [], []
        for i, oc in enumerate(outcomes):
            if oc in coefs:
                c  = coefs[oc]["coef"]
                se = coefs[oc]["se"]
                xs.append(c)
                ys.append(i + off)
                xerr_lo.append(1.96 * se)
                xerr_hi.append(1.96 * se)
        if xs:
            ax.errorbar(xs, ys, xerr=[xerr_lo, xerr_hi],
                        fmt=mk, color=col, markerfacecolor="white",
                        markeredgecolor=col, markeredgewidth=1.8,
                        markersize=6, linewidth=0, elinewidth=1.2,
                        capsize=2.5, label=f"Panel {panel}")
            h, = ax.plot([], [], mk, color=col, markerfacecolor="white",
                         markeredgecolor=col, markeredgewidth=1.8,
                         markersize=6, label=f"Panel {panel}")
            legend_handles.append(h)

    ax.axvline(0, color="black", linewidth=0.7, linestyle="--")
    for i in range(n):
        ax.axhline(i, color="gray", linewidth=0.4, alpha=0.25)

    ax.set_yticks(range(n))
    ax.set_yticklabels([LABELS.get(o, o) for o in outcomes], fontsize=8, fontweight="bold")
    ax.set_xlabel(xlabel, fontweight="bold")
    ax.set_ylim(-0.6, n - 0.4)
    ax.legend(handles=legend_handles, loc="upper center",
              bbox_to_anchor=(0.5, -0.12), ncol=3, frameon=False, fontsize=8)

    fig.tight_layout()
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {out_path.name}")


def coefplot_spill(coefs, order, out_path, xlabel="Coefficient"):
    """Horizontal coefplot for spillover (single set of estimates)."""
    outcomes = [o for o in order if o in coefs]
    n = len(outcomes)
    if n == 0:
        print(f"  No data for {out_path.name}")
        return

    fig, ax = plt.subplots(figsize=(8, n * 0.55 + 1.2))

    xs = [coefs[o]["coef"] for o in outcomes]
    se = [coefs[o]["se"]   for o in outcomes]

    ax.errorbar(xs, range(n), xerr=[1.96 * s for s in se],
                fmt="o", color="#B2182B", markerfacecolor="white",
                markeredgecolor="#B2182B", markeredgewidth=1.8,
                markersize=6, linewidth=0, elinewidth=1.2, capsize=2.5)

    ax.axvline(0, color="black", linewidth=0.7, linestyle="--")
    for i in range(n):
        ax.axhline(i, color="gray", linewidth=0.4, alpha=0.25)

    ax.set_yticks(range(n))
    ax.set_yticklabels([LABELS.get(o, o) for o in outcomes], fontsize=8, fontweight="bold")
    ax.set_xlabel(xlabel, fontweight="bold")
    ax.set_ylim(-0.6, n - 0.4)

    fig.tight_layout()
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {out_path.name}")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Exercise B: Clause counts")
    coefplot(
        load_coefs(tables_dir / "results_A_subgroup_counts.csv"),
        load_coefs(tables_dir / "results_B_subgroup_counts.csv"),
        load_coefs(tables_dir / "results_C_subgroup_counts.csv"),
        SG_ORDER, "counts_direct",
        graphs_dir / "coefplot_counts_direct.pdf",
    )
    coefplot_spill(
        load_coefs(tables_dir / "results_spill_subgroup_counts.csv"),
        SG_ORDER,
        graphs_dir / "coefplot_counts_spill.pdf",
    )

    print("Exercise C: Composition shares")
    coefplot(
        load_coefs(tables_dir / "results_A_subgroup_shares.csv"),
        load_coefs(tables_dir / "results_B_subgroup_shares.csv"),
        load_coefs(tables_dir / "results_C_subgroup_shares.csv"),
        SH_ORDER, "shares_direct",
        graphs_dir / "coefplot_shares_direct.pdf",
    )
    coefplot_spill(
        load_coefs(tables_dir / "results_spill_subgroup_shares.csv"),
        SH_ORDER,
        graphs_dir / "coefplot_shares_spill.pdf",
    )

    print("Exercise A: Subgroup similarity")
    sim = load_coefs(tables_dir / "results_spill_subgroup_similarity.csv")
    if "cosine_sg" in sim:
        c  = sim["cosine_sg"]["coef"]
        se = sim["cosine_sg"]["se"]
        print(f"  cosine_sg spillover: {c:.4f} (SE {se:.4f})")
    else:
        print("  cosine_sg result not found in CSV")

if __name__ == "__main__":
    main()
