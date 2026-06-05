#!/usr/bin/env python3
"""
Unified layer-outcomes prep with layer-level controls.

Produces firm_layer_outcomes_<layer>.dta with the same outcome columns as
06a/06b (layer_emp, lr_remdezr_layer, lr_remdezr_h_layer, l_layer_emp) plus
five layer-level controls aggregated within each (firm, layer, year) cell:

    mean_horas        : mean horascontr
    mean_age          : mean age
    share_female      : share genero == 0
    share_higher_ed   : share educ_bin == '2_higher'
    share_fixed_term  : share d_fixed_term == 1

Only cells with at least one worker (positive employment, positive wage and
hours) are kept — same universe as the existing non-zero-filled outcomes.

Supported layers: edu2, gender, race, occ4, occ5_sara, ten2.

Usage:
    python 06z_prep_outcomes_unified.py --layer ten2
    python 06z_prep_outcomes_unified.py --layer occ5_sara
    python 06z_prep_outcomes_unified.py --layer all
"""

import argparse
import os
import sys

import duckdb
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE, WORKER_PANEL_PARQUET

# --- Layer dispatch -----------------------------------------------------------

LAYER_SPECS = {
    "edu2": {
        "layer_expr":  ("CASE WHEN educ_bin = '0_no_hs' THEN 'no_hs' "
                        "ELSE 'has_hs' END"),
        "null_filter": "educ_bin IS NOT NULL AND CAST(educ_bin AS VARCHAR) != 'nan'",
    },
    "gender": {
        "layer_expr":  ("CASE WHEN genero = 0 THEN 'female' "
                        "     WHEN genero = 1 THEN 'male' END"),
        "null_filter": "genero IS NOT NULL",
    },
    "race": {
        "layer_expr":  ("CASE WHEN race_group = 'branca' THEN 'white' "
                        "     WHEN race_group IN ('parda','preta') THEN 'nonwhite' END"),
        "null_filter": "race_group IN ('branca','parda','preta')",
    },
    "occ4": {
        "layer_expr": (
            "CASE "
            "  WHEN FLOOR(ocup2002 / 100000) = 1       THEN '1_mgr' "
            "  WHEN FLOOR(ocup2002 / 100000) IN (2, 3) THEN '23_high' "
            "  WHEN FLOOR(ocup2002 / 100000) = 4       THEN '4_bur' "
            "  WHEN FLOOR(ocup2002 / 100000) >= 5      THEN '5p_low' "
            "  ELSE NULL END"
        ),
        "null_filter": "ocup2002 IS NOT NULL AND ocup2002 >= 1000",
    },
    "occ5_sara": {
        "layer_expr": (
            "CASE "
            "  WHEN FLOOR(ocup2002 / 10000) IN (11, 12, 13, 14)               THEN '1_mgr' "
            "  WHEN FLOOR(ocup2002 / 100000) = 2                               THEN '2_pro' "
            "  WHEN FLOOR(ocup2002 / 100000) BETWEEN 4 AND 9 "
            "       AND MOD(FLOOR(ocup2002 / 1000), 10) = 0                    THEN '3_bur' "
            "  WHEN FLOOR(ocup2002 / 100000) = 3                               THEN '4_tech' "
            "  WHEN FLOOR(ocup2002 / 100000) BETWEEN 4 AND 9                   THEN '5_low' "
            "  ELSE NULL END"
        ),
        "null_filter": "ocup2002 IS NOT NULL AND ocup2002 >= 1000",
    },
    "ten2": {
        "layer_expr": ("CASE WHEN tempempr <  12 THEN 'lt12mo' "
                       "     WHEN tempempr >= 12 THEN 'ge12mo' END"),
        "null_filter": "tempempr IS NOT NULL",
    },
}

# Controls that are mechanically degenerate within a given layer
# (the layer itself is a function of the would-be control).
DROP_CONTROLS = {
    "edu2":   ["share_higher_ed"],   # layer split is on educ_bin
    "gender": ["share_female"],      # layer split is on genero
    "ten2":   [],                    # tenure not in control list
    # occ4 / occ5_sara: no overlap with control list (occupation is the layer)
}


def build(layer: str) -> pd.DataFrame:
    spec = LAYER_SPECS[layer]
    layer_expr  = spec["layer_expr"]
    null_filter = spec["null_filter"]

    drop_controls = DROP_CONTROLS.get(layer, [])

    control_cols = []
    if "mean_horas"       not in drop_controls: control_cols.append("AVG(CAST(horascontr AS DOUBLE))               AS mean_horas")
    if "mean_age"         not in drop_controls: control_cols.append("AVG(age)                                       AS mean_age")
    if "share_female"     not in drop_controls: control_cols.append("AVG(CASE WHEN genero = 0 THEN 1.0 ELSE 0.0 END) AS share_female")
    if "share_higher_ed" not in drop_controls: control_cols.append("AVG(CASE WHEN CAST(educ_bin AS VARCHAR) = '2_higher' THEN 1.0 ELSE 0.0 END) AS share_higher_ed")
    if "share_fixed_term" not in drop_controls: control_cols.append("AVG(CAST(d_fixed_term AS DOUBLE))              AS share_fixed_term")

    control_sql = ",\n            ".join(control_cols)

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    q = f"""
        SELECT
            CAST(identificad AS VARCHAR)                            AS identificad,
            ({layer_expr})                                          AS layer_id,
            year,
            COUNT(PIS)                                              AS layer_emp,
            AVG(lr_remdezr)                                         AS lr_remdezr_layer,
            AVG(LOG(remdezr / NULLIF(horascontr, 0)))               AS lr_remdezr_h_layer,
            {control_sql}
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE {null_filter}
          AND ({layer_expr}) IS NOT NULL
          AND remdezr    > 0
          AND horascontr > 0
        GROUP BY identificad, ({layer_expr}), year
    """
    df = con.execute(q).fetch_arrow_table().to_pandas()
    df["l_layer_emp"] = np.log(df["layer_emp"].astype(float))
    # Reorder so outcome cols come first, controls after
    base = ["identificad", "layer_id", "year",
            "layer_emp", "lr_remdezr_layer", "lr_remdezr_h_layer", "l_layer_emp"]
    controls = [c for c in df.columns if c not in base]
    df = df[base + controls]
    return df


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layer", required=True,
                        choices=list(LAYER_SPECS.keys()) + ["all"])
    args = parser.parse_args()

    layers = list(LAYER_SPECS.keys()) if args.layer == "all" else [args.layer]
    os.makedirs(OUT_BASE, exist_ok=True)

    for layer in layers:
        print(f"\n=== Building outcomes (with controls) for layer: {layer} ===")
        df = build(layer)
        print(f"  Rows:           {len(df):,}")
        print(f"  Unique firms:   {df['identificad'].nunique():,}")
        print(f"  Layers:         {sorted(df['layer_id'].unique())}")
        print(f"  Year range:     {df['year'].min()}–{df['year'].max()}")
        print(f"  Control cols:   {[c for c in df.columns if c not in ['identificad','layer_id','year','layer_emp','lr_remdezr_layer','lr_remdezr_h_layer','l_layer_emp']]}")
        print(f"  Sample:\n{df.head(3).to_string(index=False)}")

        out_dta     = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}.dta")
        out_parquet = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}.parquet")
        df.to_stata(out_dta, write_index=False, version=118)
        df.to_parquet(out_parquet, index=False)
        print(f"  Saved {out_dta}")


if __name__ == "__main__":
    main()
