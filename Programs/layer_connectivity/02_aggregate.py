#!/usr/bin/env python3
"""
Script 02: Aggregate transition records to (firm, layer, year_pair) level.

Computes:
  - ratio_total:   movers to treated / all workers
  - ratio_same:    movers to treated in same layer / workers with observed dest layer
  - ratio_cross:   movers to treated in cross layer / workers with observed dest layer

Outputs long and wide parquet files.

Usage:
    python 02_aggregate.py --layer occ3
    python 02_aggregate.py --layer edu
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import LAYER_DEFS, PAIR_LABELS, OUT_BASE


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(LAYER_DEFS.keys()))
    return p.parse_args()


def main():
    args = parse_args()
    print(f"Aggregating transitions for layer: {args.layer}")

    in_path  = os.path.join(OUT_BASE, "transitions_base",
                            f"transitions_{args.layer}.parquet")
    out_dir  = os.path.join(OUT_BASE, "connectivity_components")
    os.makedirs(out_dir, exist_ok=True)

    long_path = os.path.join(out_dir, f"components_{args.layer}.parquet")
    wide_path = os.path.join(out_dir, f"wide_{args.layer}.parquet")

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    # Register the input parquet
    con.execute(f"CREATE VIEW transitions AS SELECT * FROM read_parquet('{in_path}')")

    # Aggregate
    query = """
        SELECT
            identificad_t,
            layer_id_t,
            pair_label,
            COUNT(*)                                            AS E,
            SUM(is_treated_dest)                               AS M_total,
            -- Cross/within: only count movers with observed destination layer
            SUM(CASE WHEN layer_id_t1 IS NOT NULL THEN 1 ELSE 0 END)
                                                               AS N_dest_layer_obs,
            SUM(CASE WHEN is_treated_dest = 1
                      AND layer_id_t1 IS NOT NULL
                      AND layer_id_t1 = layer_id_t
                 THEN 1 ELSE 0 END)                            AS M_same,
            SUM(CASE WHEN is_treated_dest = 1
                      AND layer_id_t1 IS NOT NULL
                      AND layer_id_t1 != layer_id_t
                 THEN 1 ELSE 0 END)                            AS M_cross
        FROM transitions
        WHERE layer_id_t IS NOT NULL
          AND layer_id_t != 'nan'
        GROUP BY identificad_t, layer_id_t, pair_label
    """
    df = con.execute(query).fetch_arrow_table().to_pandas()

    # Cast COUNT() columns from Decimal to float to avoid DivisionUndefined errors
    for col in ["E", "M_total", "M_same", "M_cross", "N_dest_layer_obs"]:
        df[col] = df[col].astype(float)

    # Compute ratios (replace 0 denominator with NaN → ratio becomes NaN)
    df["ratio_total"] = df["M_total"] / df["E"]
    N = df["N_dest_layer_obs"].replace(0, np.nan)
    df["ratio_same"]  = df["M_same"]  / N
    df["ratio_cross"] = df["M_cross"] / N

    print(f"Long components: {len(df):,} rows")
    df.to_parquet(long_path, index=False)

    # Reshape to wide: one row per (identificad, layer_id)
    pair_values = list(PAIR_LABELS.values())  # ["0708","0809","0910","1011"]

    df_wide = df.pivot_table(
        index=["identificad_t", "layer_id_t"],
        columns="pair_label",
        values=["ratio_total", "ratio_same", "ratio_cross"],
        aggfunc="first",
    )
    df_wide.columns = [f"{metric}_{pair}" for metric, pair in df_wide.columns]
    df_wide = df_wide.reset_index()
    df_wide = df_wide.rename(columns={"identificad_t": "identificad",
                                       "layer_id_t":    "layer_id"})

    print(f"Wide components: {len(df_wide):,} rows")
    df_wide.to_parquet(wide_path, index=False)
    print("Done.")


if __name__ == "__main__":
    main()
