"""
plot_similarity_headline_coefplot.py

Coefficient plot of the CBA-similarity spillover headline for four similarity
measures, under two choices of partner reference:

  (Panel A) Partner reference T_{i,t} = flow-weighted average of treated
            firms with positive connectivity to focal i.  (Sample: 6,943
            firm-period obs across 1,652 untreated establishments.)
  (Panel B) Average-treated reference: T_t = simple unweighted mean of all
            treated firms' clause vectors in period t.  (Sample: 19,693
            firm-period obs across 4,142 untreated establishments.)

Both panels estimate:
    sim_{it} = alpha_i + F_{it} + beta * (conn_i x post_t) + eps_{it}
on the full untreated balanced spillover panel and report the same beta.

Outputs:
  Graphs/cba_similarity/similarity_headline_coefplot.pdf
"""

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

plt.rcParams["font.family"] = "DejaVu Sans"

ROOT = Path(__file__).resolve().parent.parent.parent
TABLES = ROOT / "Tables" / "cba_similarity"
OUT_DIR = ROOT / "Graphs" / "cba_similarity"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Measure ordering shared by both panels (top = cosine, bottom = Ruzicka).
MEASURES = [
    ("cosine",          "Cosine"),
    ("total_variation", "Total variation"),
    ("bray_curtis",     "Bray–Curtis"),
    ("ruzicka",         "Ruzicka"),
]

PANELS = [
    {
        "title": "Panel A. Connectivity-weighted partner reference",
        "csv":   TABLES / "results_spill_cba_similarity_tfpw_07_11.csv",
        "spec":  "cba_similarity_tfpw_07_11",
        "color": "#2166AC",
    },
    {
        "title": "Panel B. Average-treated reference",
        "csv":   TABLES / "results_spill_cba_similarity_avg_tfpw_07_11.csv",
        "spec":  "cba_similarity_avg_tfpw_07_11",
        "color": "#B2182B",
    },
]


def parse_num(s):
    return float(str(s).replace("*", "").replace(",", "").strip())


def load_panel(csv_path: Path, spec: str) -> dict:
    df = pd.read_csv(csv_path, sep=";")
    df.columns = [c.strip() for c in df.columns]
    for c in ("spec", "section", "outcome", "row_type"):
        if df[c].dtype == object:
            df[c] = df[c].str.strip().str.strip('"')

    out = {}
    for measure, _label in MEASURES:
        sub = df[(df["spec"] == spec) & (df["outcome"] == measure)]
        if sub.empty:
            continue
        rec = {r["row_type"]: r["value"] for _, r in sub.iterrows()}
        out[measure] = {
            "main":     parse_num(rec["main"]),
            "se":       parse_num(rec["main_se"]),
            "baseline": parse_num(rec["baseline_mean"]),
            "n_obs":    rec["n_obs"],
            "n_estab":  rec["n_estab"],
            "stars":    str(rec["main"]).count("*"),
        }
    return out


def main() -> None:
    panel_data = [load_panel(p["csv"], p["spec"]) for p in PANELS]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.8), sharey=True)

    for ax, panel, results in zip(axes, PANELS, panel_data):
        y_positions = list(range(len(MEASURES)))
        for i, (measure, label) in enumerate(MEASURES):
            r = results.get(measure)
            if r is None:
                continue
            y = len(MEASURES) - 1 - i
            ax.axhline(y=y, color="gray", linestyle="-", linewidth=0.5, alpha=0.2,
                       zorder=1)
            ax.errorbar(
                r["main"], y,
                xerr=1.96 * r["se"],
                fmt="o", color=panel["color"], ecolor=panel["color"],
                markerfacecolor="white", markeredgewidth=2, markersize=9,
                capsize=4, capthick=1.2, elinewidth=1.2, zorder=3,
            )
            stars = "*" * r["stars"]
            ax.text(
                r["main"] + 1.96 * r["se"] * 1.05, y,
                f"  {r['main']:.4f}{stars}",
                va="center", ha="left",
                fontsize=9, color=panel["color"],
            )

        ax.axvline(0.0, color="black", linewidth=0.6, alpha=0.7)
        ax.set_yticks([len(MEASURES) - 1 - i for i in range(len(MEASURES))])
        ax.set_yticklabels([m[1] for m in MEASURES], fontweight="bold")
        ax.set_xlabel(r"$\hat\beta$ on conn $\times$ post", fontsize=10)
        ax.set_title(panel["title"], fontsize=10, loc="left")
        n_obs = next(iter(results.values()))["n_obs"] if results else ""
        n_estab = next(iter(results.values()))["n_estab"] if results else ""
        ax.text(
            0.98, 0.02,
            f"N obs = {n_obs}\nEstab. = {n_estab}",
            transform=ax.transAxes, ha="right", va="bottom",
            fontsize=8, color="gray",
        )

    plt.tight_layout()
    out_path = OUT_DIR / "similarity_headline_coefplot.pdf"
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
