#!/usr/bin/env python3
"""
Compare edu (3-bin) vs edu2 (2-bin) layer definitions on two dimensions:
  1. Multi-layered firms: firms present in more than one layer
  2. Within-firm variability: std of ratio_total across layers, within firm
"""

import os
import sys
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import OUT_BASE, PAIR_LABELS, CBA_RAIS_FIRM, FIRM_STATUS_PARQUET

LAYERS = ["edu", "edu2"]
PAIRS  = list(PAIR_LABELS.values())  # ["0708","0809","0910","1011"]


def load_firm_status() -> pd.DataFrame:
    """
    Read treat_ultra and in_balanced_panel from parquet cache (fast) or
    chunked DTA fallback (slow, 56 GB file).
    """
    print("Loading firm status (treat_ultra, in_balanced_panel)...")
    if os.path.exists(FIRM_STATUS_PARQUET):
        df = pd.read_parquet(FIRM_STATUS_PARQUET)
        df["identificad"] = df["identificad"].astype(str)
    else:
        reader = pd.read_stata(
            CBA_RAIS_FIRM,
            columns=["identificad", "treat_ultra", "in_balanced_panel"],
            chunksize=200_000,
            convert_categoricals=False,
        )
        chunks = []
        for chunk in reader:
            chunk["identificad"] = chunk["identificad"].astype(str)
            chunks.append(chunk.drop_duplicates("identificad"))
        df = pd.concat(chunks, ignore_index=True).drop_duplicates("identificad")
    print(f"  Firm status loaded: {len(df):,} firms")
    return df[["identificad", "treat_ultra", "in_balanced_panel"]]


def load_long(layer: str) -> pd.DataFrame:
    """Load components_{layer}.parquet — one row per (firm, layer, pair)."""
    path = os.path.join(OUT_BASE, "connectivity_components", f"components_{layer}.parquet")
    return pd.read_parquet(path)


def multilayer_stats(df: pd.DataFrame, label: str):
    """Count firms by number of distinct layers they appear in."""
    layers_per_firm = (
        df.groupby("identificad_focal")["layer_id_focal"]
        .nunique()
        .rename("n_layers")
    )
    total_firms = len(layers_per_firm)
    multi = (layers_per_firm > 1).sum()
    print(f"\n[{label}] Multi-layered firms")
    print(f"  Total firms:          {total_firms:,}")
    print(f"  Multi-layered (>1):   {multi:,}  ({100*multi/total_firms:.1f}%)")
    print(f"  Distribution of layer counts:")
    print(layers_per_firm.value_counts().sort_index().to_string())
    return layers_per_firm


def within_firm_variability(df: pd.DataFrame, label: str):
    """
    For each firm × pair, compute std of ratio_total across its layers.
    Then average that std across pairs (NaN-aware).
    Reports mean and median of the per-firm average std.
    """
    # Only firms with >1 layer have meaningful within-firm variance
    multi_firms = (
        df.groupby("identificad_focal")["layer_id_focal"]
        .nunique()
        .pipe(lambda s: s[s > 1])
        .index
    )
    df_multi = df[df["identificad_focal"].isin(multi_firms)].copy()

    # std of ratio_total across layers within (firm, pair)
    within_std = (
        df_multi.groupby(["identificad_focal", "pair_label"])["ratio_total"]
        .std()
        .rename("std_ratio_total")
        .reset_index()
    )

    # NaN-aware average across pairs per firm
    avg_std = (
        within_std.groupby("identificad_focal")["std_ratio_total"]
        .mean()
    )

    print(f"\n[{label}] Within-firm variability of ratio_total (multi-layered firms only, n={len(avg_std):,})")
    print(f"  Mean  within-firm std:   {avg_std.mean():.4f}")
    print(f"  Median within-firm std:  {avg_std.median():.4f}")
    print(f"  P75:                     {avg_std.quantile(0.75):.4f}")
    print(f"  P90:                     {avg_std.quantile(0.90):.4f}")
    print(f"  Max:                     {avg_std.max():.4f}")
    return avg_std


def main():
    firm_status = load_firm_status()
    control_bp = set(
        firm_status.loc[
            (firm_status["treat_ultra"] == 0) & (firm_status["in_balanced_panel"] == 1),
            "identificad"
        ]
    )
    print(f"Control firms in balanced panel: {len(control_bp):,}")

    results = {}
    for layer in LAYERS:
        print(f"\n{'='*50}")
        print(f" Layer: {layer}")
        print(f"{'='*50}")
        df = load_long(layer)
        df = df[df["identificad_focal"].isin(control_bp)].copy()
        print(f"  Rows after filter (control BP): {len(df):,}")

        lp = multilayer_stats(df, layer)
        vs = within_firm_variability(df, layer)
        results[layer] = {"layers_per_firm": lp, "within_std": vs}

    print(f"\n{'='*50}")
    print(" SUMMARY COMPARISON")
    print(f"{'='*50}")
    for layer in LAYERS:
        lp = results[layer]["layers_per_firm"]
        vs = results[layer]["within_std"]
        total  = len(lp)
        multi  = (lp > 1).sum()
        print(f"\n{layer}:")
        print(f"  Multi-layered firms:     {multi:,} / {total:,} ({100*multi/total:.1f}%)")
        print(f"  Mean within-firm std:    {vs.mean():.4f}")
        print(f"  Median within-firm std:  {vs.median():.4f}")


if __name__ == "__main__":
    main()
