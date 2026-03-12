#!/usr/bin/env python3
"""
Script 02d: Aggregate demographic transition records to (firm, layer, year_pair) level.

Identical logic to 02_aggregate.py; handles gender and race layers.

Usage:
    python 02d_aggregate_demog.py --layer gender
    python 02d_aggregate_demog.py --layer race
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import PAIR_LABELS, OUT_BASE


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=["gender", "race"])
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

    con.execute(f"CREATE VIEW transitions AS SELECT * FROM read_parquet('{in_path}')")

    query = """
        WITH agg AS (
            SELECT
                identificad_focal,
                layer_id_focal,
                pair_label,
                SUM(CASE WHEN record_type = 'out' THEN 1 ELSE 0 END)   AS E_t,
                SUM(CASE WHEN record_type = 'in'  THEN 1 ELSE 0 END)   AS E_t1,
                (SUM(CASE WHEN record_type = 'out' THEN 1 ELSE 0 END)
               + SUM(CASE WHEN record_type = 'in'  THEN 1 ELSE 0 END)) / 2.0  AS E_avg,
                SUM(is_treated_contact)                                 AS M_total,
                SUM(CASE WHEN layer_id_contact IS NOT NULL THEN 1 ELSE 0 END)
                                                                        AS N_contact_layer_obs,
                SUM(CASE WHEN is_treated_contact = 1
                          AND layer_id_contact IS NOT NULL
                          AND layer_id_contact = layer_id_focal
                     THEN 1 ELSE 0 END)                                AS M_same,
                SUM(CASE WHEN is_treated_contact = 1
                          AND layer_id_contact IS NOT NULL
                          AND layer_id_contact != layer_id_focal
                     THEN 1 ELSE 0 END)                                AS M_cross,
                SUM(CASE WHEN record_type = 'out' AND is_mover = 1 THEN 1 ELSE 0 END) AS M_out_any,
                SUM(CASE WHEN record_type = 'in'  AND is_mover = 1 THEN 1 ELSE 0 END) AS M_in_any
            FROM transitions
            WHERE layer_id_focal IS NOT NULL
              AND layer_id_focal != 'nan'
            GROUP BY identificad_focal, layer_id_focal, pair_label
        )
        SELECT
            *,
            (M_out_any + M_in_any) / NULLIF(E_avg, 0) AS totalflows_layer_pw
        FROM agg
    """
    df = con.execute(query).fetch_arrow_table().to_pandas()

    for col in ["E_t", "E_t1", "E_avg", "M_total", "M_same", "M_cross",
                "N_contact_layer_obs", "M_out_any", "M_in_any"]:
        df[col] = df[col].astype(float)

    df["ratio_total"] = df["M_total"] / df["E_avg"].replace(0, np.nan)
    N = df["N_contact_layer_obs"].replace(0, np.nan)
    df["ratio_same"]  = df["M_same"]  / N
    df["ratio_cross"] = df["M_cross"] / N

    print(f"Long components: {len(df):,} rows")
    df.to_parquet(long_path, index=False)

    pair_values = list(PAIR_LABELS.values())

    df_wide = df.pivot_table(
        index=["identificad_focal", "layer_id_focal"],
        columns="pair_label",
        values=["ratio_total", "ratio_same", "ratio_cross", "totalflows_layer_pw"],
        aggfunc="first",
    )
    df_wide.columns = [f"{metric}_{pair}" for metric, pair in df_wide.columns]
    df_wide = df_wide.reset_index()
    df_wide = df_wide.rename(columns={"identificad_focal": "identificad",
                                       "layer_id_focal":    "layer_id"})

    print(f"Wide components: {len(df_wide):,} rows")
    df_wide.to_parquet(wide_path, index=False)
    print("Done.")


if __name__ == "__main__":
    main()
