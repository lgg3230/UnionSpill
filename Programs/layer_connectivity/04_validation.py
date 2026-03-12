#!/usr/bin/env python3
"""
Script 04: Validation and diagnostics.

A. Coverage diagnostics: distribution of count_n across (firm, layer) cells.
B. Reconstruction check: employment-weighted average of layer measures vs original
   firm-level totaltreat_pw_n (which differs: that is the all-worker firm measure).
C. Layer mixing summary: within/cross-layer shares across all movers.

Usage:
    python 04_validation.py --layer occ3
    python 04_validation.py --layer edu
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import LAYER_DEFS, OUT_BASE, ORIG_FIRM_CONN, ORIG_FIRM_CONN_PARQUET


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(LAYER_DEFS.keys()))
    return p.parse_args()


def coverage_diagnostics(df: pd.DataFrame, layer: str, out_dir: str):
    """Distribution of count_n across (firm, layer) cells."""
    count_col = "layer_treat_pw_n_count_n"
    if count_col not in df.columns:
        print(f"  Warning: column {count_col} not found; skipping coverage diagnostics")
        return

    total = len(df)
    rows = []
    for k in range(5):
        n = (df[count_col] == k).sum()
        rows.append({"count_n": k, "n_cells": n, "share": n / total})
    n_missing = df["layer_treat_pw_n"].isna().sum()
    rows.append({"count_n": "missing", "n_cells": n_missing,
                 "share": n_missing / total})

    cov_df = pd.DataFrame(rows)
    out_path = os.path.join(out_dir, f"coverage_{layer}.csv")
    cov_df.to_csv(out_path, index=False)
    print(f"  Coverage saved to {out_path}")
    print(cov_df.to_string(index=False))


def reconstruction_check(df_layer: pd.DataFrame, layer: str, out_dir: str):
    """
    Employment-weighted average of layer_treat_pw_n should approximate
    the original firm-level totaltreat_pw_n.

    Issues 15 & 17: compute reconstruction per year pair (not pooled across all
    4 pairs), using a NaN-aware average across pairs.  Rows with NaN
    layer_treat_pw_n are excluded from the weighted sum rather than filled
    with 0 (which would bias the reconstruction downward).
    """
    trans_path = os.path.join(OUT_BASE, "transitions_base",
                              f"transitions_{layer}.parquet")
    if not os.path.exists(trans_path):
        print("  Transitions parquet not found; skipping reconstruction check.")
        return

    # Issue 15: compute per-pair firm-layer employment (E)
    con = duckdb.connect()
    df_emp_pair = con.execute(f"""
        SELECT
            identificad_t AS identificad,
            layer_id_t    AS layer_id,
            pair_label,
            COUNT(*)      AS E
        FROM read_parquet('{trans_path}')
        WHERE layer_id_t IS NOT NULL AND layer_id_t != 'nan'
        GROUP BY identificad_t, layer_id_t, pair_label
    """).fetch_arrow_table().to_pandas()

    # Firm-level total employment per year pair
    df_firm_pair = (
        df_emp_pair.groupby(["identificad", "pair_label"])["E"]
        .sum()
        .reset_index()
        .rename(columns={"E": "E_firm"})
    )
    df_merged = df_emp_pair.merge(df_firm_pair, on=["identificad", "pair_label"])
    df_merged = df_merged.merge(
        df_layer[["identificad", "layer_id", "layer_treat_pw_n"]],
        on=["identificad", "layer_id"],
        how="left",
    )
    df_merged["weight"] = df_merged["E"] / df_merged["E_firm"]

    # Issue 17: do NOT fill NaN with 0; use NaN × weight = NaN so that
    # missing-layer rows are excluded from each pair's contribution.
    df_merged["weighted_measure"] = df_merged["weight"] * df_merged["layer_treat_pw_n"]

    # Contribution per (firm, pair): employment-weighted sum of layer measure.
    # Returns NaN when all layers in a firm-pair have no measure.
    def _pair_contribution(g):
        if g["layer_treat_pw_n"].notna().any():
            return g["weighted_measure"].sum(skipna=True)
        return float("nan")

    df_pair_contrib = (
        df_merged.groupby(["identificad", "pair_label"])
        .apply(_pair_contribution)
        .reset_index(name="reconstructed_pair")
    )

    # NaN-aware average across year pairs per firm
    df_reconstructed = (
        df_pair_contrib.groupby("identificad")["reconstructed_pair"]
        .mean()  # pandas mean() skips NaN by default (skipna=True)
        .reset_index(name="reconstructed")
    )

    # Load original firm-level measure (parquet preferred, DTA fallback)
    if os.path.exists(ORIG_FIRM_CONN_PARQUET):
        df_orig = pd.read_parquet(ORIG_FIRM_CONN_PARQUET)
    elif os.path.exists(ORIG_FIRM_CONN):
        df_orig = pd.read_stata(ORIG_FIRM_CONN, columns=["identificad", "totaltreat_pw_n"])
    else:
        print(f"  {ORIG_FIRM_CONN_PARQUET} not found; skipping reconstruction check.")
        return
    df_orig = df_orig.rename(columns={"totaltreat_pw_n": "original"})

    df_cmp = df_reconstructed.merge(df_orig, on="identificad", how="inner")
    df_cmp = df_cmp.dropna(subset=["reconstructed", "original"])

    if len(df_cmp) < 2:
        print("  Not enough firms for reconstruction check.")
        return

    # Issue 14: use pandas .corr() instead of scipy pearsonr
    corr = df_cmp["reconstructed"].corr(df_cmp["original"])
    diff = (df_cmp["reconstructed"] - df_cmp["original"]).abs()

    summary = pd.DataFrame([{
        "n_firms":       len(df_cmp),
        "pearson_corr":  corr,
        "mean_abs_diff": diff.mean(),
        "max_abs_diff":  diff.max(),
    }])

    out_path = os.path.join(out_dir, f"reconstruction_check_{layer}.csv")
    summary.to_csv(out_path, index=False)
    print(f"  Reconstruction check saved to {out_path}")
    print(summary.to_string(index=False))


def layer_mixing_summary(layer: str, out_dir: str):
    """
    Compute within/cross-layer flow shares across all movers with non-NULL layer_id_t1.
    """
    trans_path = os.path.join(OUT_BASE, "transitions_base",
                              f"transitions_{layer}.parquet")
    if not os.path.exists(trans_path):
        print("  Transitions parquet not found; skipping layer mixing summary.")
        return

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    # Overall mixing
    df_overall = con.execute(f"""
        SELECT
            'all_destinations'  AS destination_type,
            layer_id_t          AS origin_layer,
            COUNT(*)            AS n_movers,
            SUM(CASE WHEN layer_id_t1 = layer_id_t THEN 1 ELSE 0 END) AS n_same_layer,
            SUM(CASE WHEN layer_id_t1 != layer_id_t THEN 1 ELSE 0 END) AS n_cross_layer
        FROM read_parquet('{trans_path}')
        WHERE layer_id_t1 IS NOT NULL
          AND layer_id_t  IS NOT NULL
          AND layer_id_t  != 'nan'
          AND layer_id_t1 != 'nan'
          AND identificad_t1 != ''
          AND identificad_t1 != identificad_t
        GROUP BY layer_id_t
    """).fetch_arrow_table().to_pandas()

    df_treated = con.execute(f"""
        SELECT
            'treated_destinations' AS destination_type,
            layer_id_t             AS origin_layer,
            COUNT(*)               AS n_movers,
            SUM(CASE WHEN layer_id_t1 = layer_id_t THEN 1 ELSE 0 END) AS n_same_layer,
            SUM(CASE WHEN layer_id_t1 != layer_id_t THEN 1 ELSE 0 END) AS n_cross_layer
        FROM read_parquet('{trans_path}')
        WHERE layer_id_t1 IS NOT NULL
          AND layer_id_t  IS NOT NULL
          AND layer_id_t  != 'nan'
          AND layer_id_t1 != 'nan'
          AND identificad_t1 != ''
          AND identificad_t1 != identificad_t
          AND is_treated_dest = 1
        GROUP BY layer_id_t
    """).fetch_arrow_table().to_pandas()

    df_mix = pd.concat([df_overall, df_treated], ignore_index=True)
    df_mix["share_same_layer"]  = df_mix["n_same_layer"]  / df_mix["n_movers"]
    df_mix["share_cross_layer"] = df_mix["n_cross_layer"] / df_mix["n_movers"]

    out_path = os.path.join(out_dir, f"layer_mixing_summary_{layer}.csv")
    df_mix.to_csv(out_path, index=False)
    print(f"  Layer mixing summary saved to {out_path}")
    print(df_mix.to_string(index=False))


def main():
    args = parse_args()
    print(f"Running validation for layer: {args.layer}")

    out_dir = os.path.join(OUT_BASE, "validation")
    os.makedirs(out_dir, exist_ok=True)

    # Load final measures — parquet preferred, DTA fallback
    parquet_path = os.path.join(OUT_BASE, "final_measures",
                                f"firm_layer_connectivity_{args.layer}.parquet")
    dta_path     = os.path.join(OUT_BASE, "final_measures",
                                f"firm_layer_connectivity_{args.layer}.dta")
    if os.path.exists(parquet_path):
        df = pd.read_parquet(parquet_path)
    elif os.path.exists(dta_path):
        df = pd.read_stata(dta_path)
    else:
        print(f"Final measures file not found: {parquet_path}")
        sys.exit(1)

    print("\n=== A. Coverage Diagnostics ===")
    coverage_diagnostics(df, args.layer, out_dir)

    print("\n=== B. Reconstruction Check ===")
    reconstruction_check(df, args.layer, out_dir)

    print("\n=== C. Layer Mixing Summary ===")
    layer_mixing_summary(args.layer, out_dir)

    print("\nValidation complete.")


if __name__ == "__main__":
    main()
