#!/usr/bin/env python3
"""
Script 08a: Compute within-firm variance decomposition of layer connectivity.

Restricts to the spillover sample (untreated, balanced panel, lagos_sample_avg==1).
Computes ANOVA SS decomposition (exactly additive) and mean connectivity by sub-layer.

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
ROOT         = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAIS_FIRM    = os.path.join(ROOT, "Data", "CBA_RAIS_firm_level",
                            "lagos_sample_sep24_pct_unionexp_ext_df2.dta")
TABLES_DIR   = os.path.join(ROOT, "Tables", "layer_connectivity")
os.makedirs(TABLES_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Layer definitions: layer_def key → (formal name, {layer_id: formal label})
# ---------------------------------------------------------------------------
LAYER_DEFS = {
    "edu": {
        "formal": "Education (tertile)",
        "labels": {
            "0_no_hs": "Less than high school",
            "1_hs":    "High school diploma",
            "2_higher":"Higher education",
        },
    },
    "edu2": {
        "formal": "Education (binary)",
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
# 1. Build spillover-sample firm set
# ---------------------------------------------------------------------------
print("Loading firm-level sample flags...")
main = pd.read_stata(
    RAIS_FIRM,
    columns=["identificad", "year", "lagos_sample_avg", "in_balanced_panel", "treat_ultra"],
)
firm_flags = main.groupby("identificad").agg(
    lagos=("lagos_sample_avg", "max"),
    balanced=("in_balanced_panel", "max"),
    treat=("treat_ultra", "max"),
).reset_index()
spill_firms = set(
    firm_flags.loc[
        (firm_flags["lagos"] == 1)
        & (firm_flags["balanced"] == 1)
        & (firm_flags["treat"] == 0),
        "identificad",
    ]
)
print(f"  Spillover sample: {len(spill_firms):,} firms")

# ---------------------------------------------------------------------------
# 2. Compute statistics for each layer definition
# ---------------------------------------------------------------------------
rows = []

for layer_def, meta in LAYER_DEFS.items():
    print(f"\nProcessing: {layer_def}")
    conn_path = os.path.join(OUT_BASE, "final_measures",
                             f"firm_layer_connectivity_{layer_def}.dta")
    df = pd.read_stata(conn_path)
    df = df[df["identificad"].isin(spill_firms)]

    # Layer order follows LAYER_DEFS dict order
    layer_ids = list(meta["labels"].keys())
    k = len(layer_ids)

    # Keep only firms where all layers are observed
    wide = df.pivot(index="identificad", columns="layer_id", values=VAR)
    wide = wide[layer_ids].dropna()
    n_firms = len(wide)
    N = n_firms * k

    print(f"  Firms with all {k} layers: {n_firms:,}")

    # ── ANOVA SS decomposition (exactly additive) ──
    grand_mean  = wide.values.mean()
    firm_means  = wide.mean(axis=1).values

    SS_total   = ((wide.values - grand_mean) ** 2).sum()
    SS_within  = ((wide.values - firm_means[:, None]) ** 2).sum()
    SS_between = k * ((firm_means - grand_mean) ** 2).sum()
    assert abs(SS_total - SS_within - SS_between) < 1e-8

    var_total   = SS_total   / (N - 1)
    var_within  = SS_within  / (N - 1)
    var_between = SS_between / (N - 1)

    # ── Within-firm SD distribution ──
    wsd = wide.std(axis=1, ddof=1)

    # ── One row per sub-layer for mean connectivity ──
    for layer_id in layer_ids:
        sub = df[df["layer_id"] == layer_id][VAR]
        rows.append(
            {
                "layer_def":      layer_def,
                "formal_def":     meta["formal"],
                "layer_id":       layer_id,
                "formal_layer":   meta["labels"][layer_id],
                "n_firms":        n_firms,
                "mean_conn":      sub.mean(),
                "var_total":      var_total,
                "var_within":     var_within,
                "var_between":    var_between,
                "pct_within":     var_within  / var_total * 100,
                "pct_between":    var_between / var_total * 100,
                "wsd_mean":       wsd.mean(),
                "wsd_median":     wsd.median(),
                "frac_wsd_zero":  (wsd == 0).mean(),
            }
        )

out = pd.DataFrame(rows)
out_path = os.path.join(TABLES_DIR, "layer_descriptives.csv")
out.to_csv(out_path, index=False, float_format="%.6f")
print(f"\nSaved to {out_path}")
print(out[["formal_def", "formal_layer", "mean_conn",
           "var_total", "var_within", "var_between",
           "pct_within", "pct_between"]].to_string(index=False))
