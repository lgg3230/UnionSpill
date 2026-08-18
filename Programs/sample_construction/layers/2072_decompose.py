#!/usr/bin/env python3
"""
Script 2072: Multi-layer reconstruction check and contribution decomposition.

A. Reconstruction check — for each layer definition, verify that the
   employment-weighted average of layer_treat_pw_n reconstructs the
   firm-level totaltreat_pw_n (restricted to spillover sample).

B. Contribution decomposition — quantify which layer categories are the
   primary conduit of union spillovers (median and mean share per category).

Output:
    Data/layer_connectivity/validation/reconstruction_multi_layer.csv

Usage:
    python 2072_decompose.py
"""

import os
import sys
import subprocess

import duckdb
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE, ORIG_FIRM_CONN_PARQUET, ORIG_FIRM_CONN, CBA_FIRM

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
LAYERS = ["edu", "edu2", "gender", "race"]
SPILLOVER_DTA = os.path.join(CBA_FIRM, "lagos_sample_sep24_pct_unionexp_ext_df2.dta")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_spillover_ids(dta_path: str) -> set:
    """
    Load spillover sample firm IDs: treat_ultra==0, in_balanced_panel==1,
    lagos_sample_avg==1.  Read only year 2009 for speed.
    """
    df = pd.read_stata(
        dta_path,
        columns=["identificad", "year", "treat_ultra",
                 "in_balanced_panel", "lagos_sample_avg"],
    )
    df = df[df["year"] == 2009]
    mask = (
        (df["treat_ultra"] == 0) &
        (df["in_balanced_panel"] == 1) &
        (df["lagos_sample_avg"] == 1)
    )
    ids = set(df.loc[mask, "identificad"].astype(str).str.strip())
    print(f"  Spillover sample: {len(ids):,} firms (2009 slice)")
    return ids


def load_orig_connectivity() -> pd.DataFrame:
    """Load original firm-level totaltreat_pw_n."""
    if os.path.exists(ORIG_FIRM_CONN_PARQUET):
        df = pd.read_parquet(ORIG_FIRM_CONN_PARQUET)
    elif os.path.exists(ORIG_FIRM_CONN):
        df = pd.read_stata(ORIG_FIRM_CONN,
                           columns=["identificad", "totaltreat_pw_n"])
    else:
        raise FileNotFoundError(
            f"Original connectivity file not found:\n"
            f"  {ORIG_FIRM_CONN_PARQUET}\n  {ORIG_FIRM_CONN}"
        )
    return df[["identificad", "totaltreat_pw_n"]].rename(
        columns={"totaltreat_pw_n": "original"}
    )


def process_layer(layer: str, spillover_ids: set, df_orig: pd.DataFrame) -> list[dict]:
    """
    For one layer definition:
      - Run reconstruction check (returns one set of stats)
      - Run contribution decomposition (returns per-category shares)
    Returns a list of dicts, one row per layer category.
    """
    trans_path = os.path.join(OUT_BASE, "transitions_base",
                              f"transitions_{layer}.parquet")
    measures_path = os.path.join(OUT_BASE, "final_measures",
                                 f"firm_layer_connectivity_{layer}.parquet")
    dta_path = measures_path.replace(".parquet", ".dta")

    if not os.path.exists(trans_path):
        print(f"  [SKIP] Transitions not found: {trans_path}")
        return []
    if os.path.exists(measures_path):
        df_layer = pd.read_parquet(measures_path)
    elif os.path.exists(dta_path):
        df_layer = pd.read_stata(dta_path)
    else:
        print(f"  [SKIP] Final measures not found: {measures_path}")
        return []

    # Keep only spillover sample
    df_layer["identificad"] = df_layer["identificad"].astype(str).str.strip()
    df_layer = df_layer[df_layer["identificad"].isin(spillover_ids)]
    print(f"  [{layer}] layer measures rows in spillover sample: {len(df_layer):,}")

    # ------------------------------------------------------------------
    # Step A: per-pair employment weights via DuckDB
    # ------------------------------------------------------------------
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    df_emp_pair = con.execute(f"""
        SELECT
            identificad_focal AS identificad,
            layer_id_focal    AS layer_id,
            pair_label,
            COUNT(*)          AS E
        FROM read_parquet('{trans_path}')
        WHERE layer_id_focal IS NOT NULL AND layer_id_focal != 'nan'
        GROUP BY identificad_focal, layer_id_focal, pair_label
    """).fetch_arrow_table().to_pandas()

    df_emp_pair["identificad"] = df_emp_pair["identificad"].astype(str).str.strip()
    df_emp_pair = df_emp_pair[df_emp_pair["identificad"].isin(spillover_ids)]

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
    df_merged["weighted_measure"] = df_merged["weight"] * df_merged["layer_treat_pw_n"]

    # Per (firm, pair): NaN-aware weighted sum
    def _pair_contribution(g):
        if g["layer_treat_pw_n"].notna().any():
            return g["weighted_measure"].sum(skipna=True)
        return float("nan")

    df_pair_contrib = (
        df_merged.groupby(["identificad", "pair_label"])
        .apply(_pair_contribution, include_groups=False)
        .reset_index(name="reconstructed_pair")
    )

    # NaN-aware mean across 4 pairs per firm
    df_reconstructed = (
        df_pair_contrib.groupby("identificad")["reconstructed_pair"]
        .mean()
        .reset_index(name="reconstructed")
    )

    # Restrict original to spillover sample
    df_orig_sample = df_orig.copy()
    df_orig_sample["identificad"] = df_orig_sample["identificad"].astype(str).str.strip()
    df_orig_sample = df_orig_sample[df_orig_sample["identificad"].isin(spillover_ids)]

    df_cmp = df_reconstructed.merge(df_orig_sample, on="identificad", how="inner")
    df_cmp = df_cmp.dropna(subset=["reconstructed", "original"])

    n_firms_recon = len(df_cmp)
    if n_firms_recon < 2:
        print(f"  [{layer}] Not enough firms for reconstruction check.")
        pearson_corr = np.nan
        mean_abs_diff = np.nan
    else:
        pearson_corr = df_cmp["reconstructed"].corr(df_cmp["original"])
        mean_abs_diff = (df_cmp["reconstructed"] - df_cmp["original"]).abs().mean()
        print(f"  [{layer}] n_firms={n_firms_recon:,}  "
              f"r={pearson_corr:.4f}  "
              f"mean_abs_diff={mean_abs_diff:.6f}")

    # ------------------------------------------------------------------
    # Step B: contribution decomposition
    # ------------------------------------------------------------------
    # Per (firm, layer): mean contribution across pairs
    df_merged["contribution"] = df_merged["weight"] * df_merged["layer_treat_pw_n"]

    # Only use firm-pair combos where at least one layer has a valid measure
    contrib = (
        df_merged.groupby(["identificad", "layer_id"])["contribution"]
        .mean()
        .reset_index(name="mean_contribution")
    )

    # Firm total
    firm_total = (
        contrib.groupby("identificad")["mean_contribution"]
        .sum()
        .rename("firm_total")
    )
    contrib = contrib.join(firm_total, on="identificad")
    contrib["share"] = contrib["mean_contribution"] / contrib["firm_total"]

    # Summary stats per layer category (within spillover sample)
    summary = (
        contrib.groupby("layer_id")["share"]
        .agg(median_share="median", mean_share="mean")
        .reset_index()
    )

    # Assemble output rows — one per layer category
    rows = []
    for _, row in summary.iterrows():
        rows.append({
            "layer_def":      layer,
            "layer_id":       row["layer_id"],
            "n_firms_recon":  n_firms_recon,
            "pearson_corr":   pearson_corr,
            "mean_abs_diff":  mean_abs_diff,
            "median_share":   row["median_share"],
            "mean_share":     row["mean_share"],
        })

    return rows


def main():
    print("=== 04b: Multi-layer reconstruction check and decomposition ===\n")

    out_dir = os.path.join(OUT_BASE, "validation")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "reconstruction_multi_layer.csv")

    # Load shared inputs
    print("Loading spillover sample IDs...")
    spillover_ids = load_spillover_ids(SPILLOVER_DTA)

    print("\nLoading original firm-level connectivity...")
    df_orig = load_orig_connectivity()

    # Process all layers
    all_rows = []
    for layer in LAYERS:
        print(f"\n--- Layer: {layer} ---")
        rows = process_layer(layer, spillover_ids, df_orig)
        all_rows.extend(rows)

    if not all_rows:
        print("\nNo results produced — check that all input files exist.")
        sys.exit(1)

    df_out = pd.DataFrame(all_rows)
    df_out.to_csv(out_path, index=False)
    print(f"\nOutput saved to {out_path}")
    print(df_out.to_string(index=False))

    # Notify
    subprocess.run([
        "curl", "-s", "-o", "/dev/null",
        "-H", "Title: Done",
        "-d", "2072_decompose.py complete",
        "https://ntfy.sh/lgg3230-kellogg",
    ])

    print("\nDone.")


if __name__ == "__main__":
    main()
