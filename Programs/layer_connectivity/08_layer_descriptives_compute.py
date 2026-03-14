#!/usr/bin/env python3
"""
Script 08a: Compute within-firm variance decomposition of layer connectivity.

Restricts to the spillover sample (untreated, balanced panel, lagos_sample_avg==1).
Computes ANOVA SS decomposition (exactly additive) and mean connectivity by sub-layer,
for three groups: all firms, small firms (<= median avg employment 2009-2011), large firms.

Output:
    Tables/layer_connectivity/layer_descriptives.csv
"""

import os
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import OUT_BASE

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT       = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAIS_FIRM  = os.path.join(ROOT, "Data", "CBA_RAIS_firm_level",
                          "lagos_sample_sep24_pct_unionexp_ext_df2.dta")
TABLES_DIR = os.path.join(ROOT, "Tables", "layer_connectivity")
os.makedirs(TABLES_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Layer definitions
# ---------------------------------------------------------------------------
LAYER_DEFS = {
    "edu": {
        "formal": "Education (3-levels)",
        "labels": {
            "0_no_hs":   "Less than high school",
            "1_hs":      "High school diploma",
            "2_higher":  "Higher education",
        },
    },
    "edu2": {
        "formal": "Education (2-levels)",
        "labels": {
            "no_hs":  "Less than high school",
            "has_hs": "High school or above",
        },
    },
    "gender": {
        "formal": "Gender",
        "labels": {
            "female": "Female",
            "male":   "Male",
        },
    },
    "race": {
        "formal": "Race",
        "labels": {
            "nonwhite": "Non-white",
            "white":    "White",
        },
    },
}

VAR = "layer_treat_pw_n"

# ---------------------------------------------------------------------------
# 1. Build spillover-sample firm set + size groups
# ---------------------------------------------------------------------------
print("Loading firm-level data...")
main = pd.read_stata(
    RAIS_FIRM,
    columns=["identificad", "year", "lagos_sample_avg",
             "in_balanced_panel", "treat_ultra", "firm_emp"],
)

firm_flags = main.groupby("identificad").agg(
    lagos=("lagos_sample_avg", "max"),
    balanced=("in_balanced_panel", "max"),
    treat=("treat_ultra", "max"),
).reset_index()
spill_firms = set(firm_flags.loc[
    (firm_flags["lagos"] == 1) & (firm_flags["balanced"] == 1) & (firm_flags["treat"] == 0),
    "identificad",
])
print(f"  Spillover sample: {len(spill_firms):,} firms")

# Average employment 2009-2011 within spillover sample
emp = (
    main[main["identificad"].isin(spill_firms) & main["year"].between(2009, 2011)]
    .groupby("identificad")["firm_emp"]
    .mean()
    .rename("avg_emp")
)
median_emp = emp.median()
size_group = (emp >= median_emp).map({True: "large", False: "small"})
print(f"  Median avg employment 2009–2011: {median_emp:.1f}")
print(f"  Small: {(size_group=='small').sum():,}  |  Large: {(size_group=='large').sum():,}")

GROUPS = {
    "all":   spill_firms,
    "small": set(size_group[size_group == "small"].index),
    "large": set(size_group[size_group == "large"].index),
}

# ---------------------------------------------------------------------------
# 2. Helper: ANOVA decomposition for a wide firm×layer matrix
# ---------------------------------------------------------------------------
def anova_decomp(wide, layer_ids):
    k = len(layer_ids)
    n = len(wide)
    N = n * k
    grand     = wide.values.mean()
    fmeans    = wide.mean(axis=1).values
    SS_t      = ((wide.values - grand) ** 2).sum()
    SS_w      = ((wide.values - fmeans[:, None]) ** 2).sum()
    SS_b      = k * ((fmeans - grand) ** 2).sum()
    assert abs(SS_t - SS_w - SS_b) < 1e-8
    vt = SS_t / (N - 1)
    vw = SS_w / (N - 1)
    vb = SS_b / (N - 1)
    wsd = wide.std(axis=1, ddof=1)
    return dict(
        n_firms=n, var_total=vt, var_within=vw, var_between=vb,
        pct_within=vw / vt * 100, pct_between=vb / vt * 100,
        wsd_mean=wsd.mean(), wsd_median=wsd.median(), frac_wsd_zero=(wsd == 0).mean(),
    )

# ---------------------------------------------------------------------------
# 3. Compute stats for each (group, layer_def, sub-layer)
# ---------------------------------------------------------------------------
rows = []

for group_name, firm_set in GROUPS.items():
    n_spill = len(firm_set)
    print(f"\n--- Group: {group_name} ({n_spill:,} firms) ---")

    for layer_def, meta in LAYER_DEFS.items():
        layer_ids = list(meta["labels"].keys())

        df = pd.read_stata(
            os.path.join(OUT_BASE, "final_measures",
                         f"firm_layer_connectivity_{layer_def}.dta")
        )
        df = df[df["identificad"].isin(firm_set)]

        wide_all = df.pivot(index="identificad", columns="layer_id", values=VAR)
        wide_all = wide_all.reindex(columns=layer_ids)

        # Fraction with >= 2 layers
        frac_ge2 = (wide_all.notna().sum(axis=1) >= 2).sum() / n_spill

        # Decomposition on firms with all layers
        wide = wide_all.dropna()
        stats = anova_decomp(wide, layer_ids)

        print(f"  {layer_def}: {stats['n_firms']:,} firms (all layers) | frac>=2: {frac_ge2:.3f}")

        # Average layer employment 2009-2011 from outcomes file
        outcomes = pd.read_stata(
            os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer_def}.dta"),
            columns=["identificad", "layer_id", "year", "layer_emp"],
        )
        outcomes = outcomes[
            outcomes["identificad"].isin(firm_set) & outcomes["year"].between(2009, 2011)
        ]
        avg_layer_emp = outcomes.groupby("layer_id")["layer_emp"].mean()

        for layer_id in layer_ids:
            sub = df[df["layer_id"] == layer_id][VAR]
            rows.append({
                "group":           group_name,
                "layer_def":       layer_def,
                "formal_def":      meta["formal"],
                "layer_id":        layer_id,
                "formal_layer":    meta["labels"][layer_id],
                "frac_ge2_layers": frac_ge2,
                "mean_conn":       sub.mean(),
                "avg_layer_emp":   avg_layer_emp.get(layer_id, float("nan")),
                **stats,
            })

out = pd.DataFrame(rows)
out_path = os.path.join(TABLES_DIR, "layer_descriptives.csv")
out.to_csv(out_path, index=False, float_format="%.6f")
print(f"\nSaved {len(out)} rows to {out_path}")
print(out[["group", "formal_def", "formal_layer", "mean_conn",
           "var_total", "var_within", "pct_within"]].to_string(index=False))
