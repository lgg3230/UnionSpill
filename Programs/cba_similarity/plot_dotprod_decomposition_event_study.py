"""
plot_dotprod_decomposition_event_study.py

Reads Tables/cba_similarity/results_event_study_decomposition.csv and produces
event-study figures for the four similarity measures used in the bilinear
decomposition exercise.

Each figure plots period-specific betas of similarity outcome on the
connectivity-by-period interaction (cba_period == 2 is the omitted reference).
Series per figure are the A/B/C (and cross for the bilinear measures) outcomes.

Output files (Graphs/cba_similarity/):
  - event_study_decomposition_raw.pdf            (A/B/C/cross, raw bilinear)
  - event_study_decomposition_shares.pdf         (A/B/C/cross, shares bilinear)
  - event_study_decomposition_cosine.pdf         (A/B/C, cosine)
  - event_study_decomposition_ruzicka.pdf        (A/B/C, Ruzicka)

A second set with the "_union" suffix uses the union x period FE specs.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

plt.rcParams["font.family"] = "DejaVu Sans"

ROOT = Path(__file__).resolve().parent.parent.parent
CSV_PATH = ROOT / "Tables" / "cba_similarity" / "results_event_study_decomposition.csv"
OUT_DIR = ROOT / "Graphs" / "cba_similarity"
OUT_DIR.mkdir(parents=True, exist_ok=True)

FIGURES = {
    "raw": {
        "spec": "dotprod_raw",
        "outcomes": [
            ("dot_raw_A", "A: both move",      "#2166AC", "o"),
            ("dot_raw_B", "B: focal anchored", "#B2182B", "s"),
            ("dot_raw_C", "C: partner anchored","#4A7C30", "^"),
            ("dot_raw_cross", "Cross: joint deltas", "#7F3F98", "D"),
        ],
        "title": "Bilinear decomposition: raw inner product",
        "ylabel": r"$\hat\beta_{p}$ (raw inner product)",
    },
    "shares": {
        "spec": "dotprod_shares",
        "outcomes": [
            ("dot_shares_A", "A: both move",      "#2166AC", "o"),
            ("dot_shares_B", "B: focal anchored", "#B2182B", "s"),
            ("dot_shares_C", "C: partner anchored","#4A7C30", "^"),
            ("dot_shares_cross", "Cross: joint deltas", "#7F3F98", "D"),
        ],
        "title": "Bilinear decomposition: shares inner product",
        "ylabel": r"$\hat\beta_{p}$ (shares)",
    },
    "cosine": {
        "spec": "cosine_pretrend_anchored",
        "outcomes": [
            ("cos_A", "A: both move",      "#2166AC", "o"),
            ("cos_B", "B: focal anchored", "#B2182B", "s"),
            ("cos_C", "C: partner anchored","#4A7C30", "^"),
        ],
        "title": "Cosine similarity",
        "ylabel": r"$\hat\beta_{p}$ (cosine)",
    },
    "ruzicka": {
        "spec": "ruzicka_pretrend_anchored",
        "outcomes": [
            ("ruz_A", "A: both move",      "#2166AC", "o"),
            ("ruz_B", "B: focal anchored", "#B2182B", "s"),
            ("ruz_C", "C: partner anchored","#4A7C30", "^"),
        ],
        "title": "Ruzicka similarity",
        "ylabel": r"$\hat\beta_{p}$ (Ruzicka)",
    },
}

ALL_PERIODS = [1, 2, 3, 4, 5, 6]
REF_PERIOD = 2

def load_es(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path, sep=";")
    df.columns = [c.strip() for c in df.columns]
    for c in ("spec", "outcome"):
        if df[c].dtype == object:
            df[c] = df[c].str.strip().str.strip('"')
    df["period"] = df["period"].astype(int)
    df["beta"] = df["beta"].astype(float)
    df["se"] = df["se"].astype(float)
    df["ci_lower"] = df["beta"] - 1.96 * df["se"]
    df["ci_upper"] = df["beta"] + 1.96 * df["se"]
    return df


def plot_event_study(df: pd.DataFrame, spec: str, outcomes, title: str,
                     ylabel: str, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 4.6))

    for outcome, label, color, marker in outcomes:
        dx = 0.0
        sub = df[(df["spec"] == spec) & (df["outcome"] == outcome)].copy()
        if sub.empty:
            continue

        rows = []
        for p in ALL_PERIODS:
            if p == REF_PERIOD:
                rows.append({"period": p, "beta": 0.0, "ci_lower": 0.0, "ci_upper": 0.0, "is_ref": True})
            else:
                r = sub[sub["period"] == p]
                if r.empty:
                    continue
                rows.append({
                    "period": p,
                    "beta": float(r["beta"].iloc[0]),
                    "ci_lower": float(r["ci_lower"].iloc[0]),
                    "ci_upper": float(r["ci_upper"].iloc[0]),
                    "is_ref": False,
                })
        s = pd.DataFrame(rows).sort_values("period")

        non_ref = s[~s["is_ref"]]
        ax.errorbar(non_ref["period"] + dx, non_ref["beta"],
                    yerr=[non_ref["beta"] - non_ref["ci_lower"],
                          non_ref["ci_upper"] - non_ref["beta"]],
                    fmt=marker, color=color, ecolor=color,
                    markersize=6, capsize=3, capthick=1.0, elinewidth=1.0,
                    label=label, zorder=3)

        ref = s[s["is_ref"]]
        ax.plot(ref["period"] + dx, ref["beta"], marker=marker,
                markerfacecolor="white", markeredgecolor=color, markersize=7,
                markeredgewidth=1.5, linestyle="None", zorder=4)

        ax.plot(s["period"] + dx, s["beta"], color=color, linewidth=1.0,
                alpha=0.5, zorder=2)

    ax.axhline(0.0, color="black", linewidth=0.6, alpha=0.7)
    ax.axvline(REF_PERIOD + 0.5, color="gray", linestyle="--", linewidth=0.8, alpha=0.7)
    ax.set_xticks(ALL_PERIODS)
    ax.set_xticklabels([f"p{p}" if p != REF_PERIOD else f"p{p}\n(ref)" for p in ALL_PERIODS])
    ax.set_xlabel("CBA period")
    ax.set_ylabel(ylabel)
    if title:
        ax.set_title(title, fontsize=11)
    ax.legend(loc="best", frameon=False, fontsize=9)

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out_path}")


def main() -> None:
    df = load_es(CSV_PATH)

    for key, cfg in FIGURES.items():
        plot_event_study(
            df=df, spec=cfg["spec"], outcomes=cfg["outcomes"],
            title=cfg["title"], ylabel=cfg["ylabel"],
            out_path=OUT_DIR / f"event_study_decomposition_{key}.pdf",
        )

        union_spec = cfg["spec"] + "_union"
        if (df["spec"] == union_spec).any():
            plot_event_study(
                df=df, spec=union_spec, outcomes=cfg["outcomes"],
                title=cfg["title"] + " (union x period FE)",
                ylabel=cfg["ylabel"],
                out_path=OUT_DIR / f"event_study_decomposition_{key}_union.pdf",
            )


if __name__ == "__main__":
    main()
