#!/usr/bin/env python3
"""
Script 10: Build firm×layer×year panels for cross-layer spillover exercise.

Cross-layer connectivity uses the exact formula derived from per-worker connectivity:

    cross_conn(l) = (1/(T-1)) * sum_yp [ 2 * FlowsWithTreat_yp(-l) / (n_{t-1}(l) + n_t(l)) ]

where:
    - FlowsWithTreat_yp(-l) = flows to/from treated firms from ALL layers except l, in year pair yp
    - n_{t-1}(l) + n_t(l)   = employment of focal layer l in both years of the pair

Employment and flows are taken directly from transitions_{layer}.parquet for all 4 year pairs
(0708, 0809, 0910, 1011), using record_type='out' for n_{t-1} and 'in' for n_t.

Panel: only observed firm×layer×year rows (no zero-filling for absent layers).
Wages remain NaN where missing; l_layer_emp is taken from outcomes as-is.

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/10_cross_layer_prep.py
"""

import subprocess
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

# ── Paths ────────────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parent.parent.parent
DATA_LC     = ROOT / "Data" / "layer_connectivity"
RAIS_FIRM   = ROOT / "Data" / "CBA_RAIS_firm_level"
TRANSITIONS = DATA_LC / "transitions_base"

FIRM_DTA   = RAIS_FIRM / "lagos_sample_sep24_pct_unionexp_ext_df2.dta"
YEAR_PAIRS = ["0708", "0809", "0910", "1011"]


# ── Load firm-level panel once ───────────────────────────────────────────────────
print("Loading firm-level panel...")
firm_df = pd.read_stata(
    FIRM_DTA,
    columns=["identificad", "year", "treat_ultra", "in_balanced_panel",
             "lagos_sample_avg", "firm_emp", "industry1", "mode_base_month",
             "microregion"],
)
firm_df = firm_df[firm_df["year"] >= 2009].copy()

spillover_mask = (
    (firm_df["treat_ultra"] == 0) &
    (firm_df["in_balanced_panel"] == 1) &
    (firm_df["lagos_sample_avg"] == 1)
)
spillover_firms = set(firm_df.loc[spillover_mask, "identificad"].unique())
print(f"  Spillover firms: {len(spillover_firms):,}")


# ── Compute cross_conn from transitions parquet ───────────────────────────────────
def compute_cross_conn(layer: str) -> pd.DataFrame:
    """
    For each (firm, focal_layer) in the transitions data, compute cross_conn
    using all 4 pre-treatment year pairs.

    Returns DataFrame with columns:
        identificad, layer_id, cross_conn, avg_emp_pre
    """
    parquet_path = str(TRANSITIONS / f"transitions_{layer}.parquet")
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")

    # Aggregate from transitions parquet:
    #   emp_t_minus_1 = count of 'out' records = workers present in year t-1
    #   emp_t         = count of 'in'  records = workers present in year t
    #   flows_treat   = movers to/from treated firms (both in and out directions)
    agg = con.execute(f"""
        SELECT
            identificad_focal                                               AS identificad,
            layer_id_focal                                                  AS layer_id,
            pair_label                                                      AS yp,
            SUM(CASE WHEN record_type = 'out' THEN 1 ELSE 0 END)           AS emp_t_minus_1,
            SUM(CASE WHEN record_type = 'in'  THEN 1 ELSE 0 END)           AS emp_t,
            SUM(CASE WHEN is_mover = 1 AND is_treated_contact = 1
                     THEN 1 ELSE 0 END)                                    AS flows_treat
        FROM read_parquet('{parquet_path}')
        GROUP BY 1, 2, 3
    """).df()

    print(f"  [{layer}] aggregated: {len(agg):,} firm×layer×pair rows")

    # emp_sum = n_{t-1}(l) + n_t(l) for each year pair
    agg["emp_sum"] = agg["emp_t_minus_1"] + agg["emp_t"]

    # Firm-level total flows to treated per year pair (sum over all layers)
    firm_yp_totals = (
        agg.groupby(["identificad", "yp"])["flows_treat"]
        .sum()
        .rename("firm_flows_treat_total")
        .reset_index()
    )
    agg = agg.merge(firm_yp_totals, on=["identificad", "yp"], how="left")

    # Other-layer flows = firm total minus focal layer's own flows
    agg["other_flows_treat"] = agg["firm_flows_treat_total"] - agg["flows_treat"]

    # Year-pair cross_conn = 2 * FlowsWithTreat(-l) / emp_sum(focal)
    # NaN where focal layer has zero employment in this year pair
    agg["cross_conn_yp"] = np.where(
        agg["emp_sum"] > 0,
        2.0 * agg["other_flows_treat"] / agg["emp_sum"],
        np.nan,
    )

    # Average cross_conn over year pairs (NaN year pairs skipped automatically)
    cross_avg = (
        agg.groupby(["identificad", "layer_id"])
        .apply(
            lambda g: pd.Series({
                "cross_conn": g["cross_conn_yp"].mean(),
                "n_yp_used":  int(g["cross_conn_yp"].notna().sum()),
            }),
            include_groups=False,
        )
        .reset_index()
    )

    # avg_emp_pre: mean of (n_{t-1} + n_t)/2 over all 4 year pairs
    # = average layer employment across the pre-treatment window
    emp_pre = (
        agg.groupby(["identificad", "layer_id"])["emp_sum"]
        .mean()
        .div(2)
        .rename("avg_emp_pre")
        .reset_index()
    )
    cross_avg = cross_avg.merge(emp_pre, on=["identificad", "layer_id"], how="left")

    # Set cross_conn to NaN where focal layer avg_emp_pre == 0
    cross_avg.loc[cross_avg["avg_emp_pre"] == 0, "cross_conn"] = np.nan

    print(f"  [{layer}] cross_conn non-missing: {cross_avg['cross_conn'].notna().mean():.3f}")
    print(f"  [{layer}] avg year pairs used:    {cross_avg['n_yp_used'].mean():.2f}")

    return cross_avg[["identificad", "layer_id", "cross_conn", "avg_emp_pre"]]


# ── Process each layer ───────────────────────────────────────────────────────────
LAYERS = ["edu", "edu2", "gender", "race"]

for layer in LAYERS:
    print(f"\n{'='*60}")
    print(f"LAYER: {layer}")
    print(f"{'='*60}")

    outcomes_dta = DATA_LC / f"firm_layer_outcomes_{layer}.dta"
    conn_dta     = DATA_LC / "final_measures" / f"firm_layer_connectivity_{layer}.dta"
    out_dta      = DATA_LC / f"cross_layer_balanced_{layer}.dta"

    # ── Load outcomes (only observed rows, 2009–2016) ────────────────────────
    print(f"  Loading outcomes...")
    outcomes_df = pd.read_stata(
        outcomes_dta,
        columns=["identificad", "layer_id", "year",
                 "layer_emp", "l_layer_emp", "lr_remdezr_layer", "lr_remdezr_h_layer"],
    )
    outcomes_df = outcomes_df[
        (outcomes_df["year"] >= 2009) &
        (outcomes_df["identificad"].isin(spillover_firms))
    ].copy()
    print(f"  Observed rows (spillover firms, 2009+): {len(outcomes_df):,}")

    # ── Merge own-layer connectivity ─────────────────────────────────────────
    print(f"  Loading own connectivity...")
    conn_df = pd.read_stata(
        conn_dta,
        columns=["identificad", "layer_id", "layer_treat_pw_n"],
    )
    panel = outcomes_df.merge(conn_df, on=["identificad", "layer_id"], how="left")
    panel["layer_treat_pw_n"] = panel["layer_treat_pw_n"].fillna(0)

    # ── Compute cross_conn from transitions parquet (all 4 year pairs) ───────
    print(f"  Computing cross_conn from transitions parquet...")
    cross_df = compute_cross_conn(layer)
    panel = panel.merge(cross_df, on=["identificad", "layer_id"], how="left")

    # ── Merge firm-level controls ────────────────────────────────────────────
    panel = panel.merge(
        firm_df[["identificad", "year", "firm_emp", "industry1",
                 "mode_base_month", "microregion",
                 "treat_ultra", "in_balanced_panel", "lagos_sample_avg"]],
        on=["identificad", "year"],
        how="left",
    )

    # ── Diagnostics ─────────────────────────────────────────────────────────
    print(f"  Final obs:              {len(panel):,}")
    print(f"  cross_conn missing:     {panel['cross_conn'].isna().mean():.3f}")
    print(f"  cross_conn > 0:         {(panel['cross_conn'] > 0).mean():.3f}")
    print(f"  lr_remdezr missing:     {panel['lr_remdezr_layer'].isna().mean():.3f}")

    # ── Save ─────────────────────────────────────────────────────────────────
    print(f"  Saving to {out_dta.name}...")
    panel.to_stata(str(out_dta), write_index=False, version=118)
    print(f"  Saved.")

print("\nAll layers done.")

subprocess.run([
    "curl", "-s", "-o", "/dev/null",
    "-H", "Title: cross_layer_prep done",
    "-d", "10_cross_layer_prep.py finished — exact formula, all 4 year pairs, no zero-fill",
    "https://ntfy.sh/lgg3230-kellogg",
])
