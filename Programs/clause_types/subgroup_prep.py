"""
subgroup_prep.py
Computes CBA content similarity at the subgroup level (24 subgroups).
Aggregates cl_* clause-type counts to subgroup counts, then computes
flow-weighted cosine similarity between each untreated firm and its
connected treated firms, per firm × cba_period.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta  (exported by subgroup_analysis.do)
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv
  Data/CBA/clause_variables_cnes.xlsx      (subgroup mapping)

Output:
  Data/RAIS_aux/subgroup_similarity_panel.dta
    columns: identificad, cba_period, cosine_sg
"""

import pandas as pd
import numpy as np
import subprocess
from pathlib import Path

main     = Path("/kellogg/proj/lgg3230")
rais_aux = main / "UnionSpill/Data/RAIS_aux"
cba_dir  = main / "UnionSpill/Data/CBA"

clauses_path   = rais_aux / "cba_clauses_by_period.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"
xl_path        = cba_dir  / "clause_variables_cnes.xlsx"
output_path    = rais_aux / "subgroup_similarity_panel.dta"

# ── Subgroup mapping ──────────────────────────────────────────────────────────

SG_IDS = [11,12,13,14, 21,22,23,24, 31,32,33,34, 41,42,43,51,
          61,62, 71,72,73, 81,82, 91]

xl = pd.read_excel(xl_path)
subgroup_map = {}
for _, row in xl.iterrows():
    var = str(row["Variable"])
    sg_id = row["sub_group_id"]
    if pd.notna(sg_id) and var.startswith("cl_"):
        sg_id = int(sg_id)
        if sg_id in SG_IDS:
            subgroup_map.setdefault(sg_id, []).append(var)

sg_cols = [f"sg{s}" for s in SG_IDS]

# ── Load clause data ──────────────────────────────────────────────────────────

print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

# Aggregate to 24 subgroup counts
for sg_id, sg_var in zip(SG_IDS, sg_cols):
    cl_vars = [v for v in subgroup_map.get(sg_id, []) if v in clauses.columns]
    clauses[sg_var] = clauses[cl_vars].sum(axis=1) if cl_vars else 0.0

print(f"  {len(clauses):,} firm × cba_period obs  |  "
      f"{clauses['treat_ultra'].sum():,.0f} treated obs", flush=True)

# ── Load bilateral connectivity ───────────────────────────────────────────────

print("Loading bilateral connectivity...", flush=True)
bil = pd.read_csv(bilateral_path, dtype=str)
bil["identificad_i"] = bil["identificad_i"].str.strip().str[1:].str.zfill(14)
bil["identificad_j"] = bil["identificad_j"].str.strip().str[1:].str.zfill(14)

ratio_cols = [c for c in bil.columns if c.startswith("ratio_")]
for c in ratio_cols:
    bil[c] = pd.to_numeric(bil[c], errors="coerce").fillna(0)
bil["avg_conn"] = bil[ratio_cols].mean(axis=1)
bil = bil[bil["avg_conn"] > 0][["identificad_i", "identificad_j", "avg_conn"]]
print(f"  {len(bil):,} bilateral pairs with positive connectivity", flush=True)

# ── Compute subgroup-level cosine similarity ──────────────────────────────────

print("Computing subgroup-level cosine similarity...", flush=True)

treated   = clauses[clauses["treat_ultra"] == 1].set_index(["identificad", "cba_period"])
untreated = clauses[(clauses["treat_ultra"] == 0) &
                    (clauses["lagos_sample_avg"] == 1) &
                    (clauses["in_balanced_panel"] == 1)]

results = []

for _, row in untreated.iterrows():
    i       = row["identificad"]
    period  = row["cba_period"]
    v_i     = row[sg_cols].values.astype(float)
    norm_i  = np.linalg.norm(v_i)
    if norm_i == 0:
        continue

    # Flow weights to treated firms
    weights = bil[bil["identificad_i"] == i][["identificad_j", "avg_conn"]]
    if len(weights) == 0:
        continue

    # Treated vectors for this period
    treat_period = treated.xs(period, level="cba_period", drop_level=False) \
                          .reset_index() if period in treated.index.get_level_values("cba_period") else None
    if treat_period is None or len(treat_period) == 0:
        continue

    merged = weights.merge(treat_period[["identificad"] + sg_cols],
                           left_on="identificad_j", right_on="identificad", how="inner")
    if len(merged) == 0:
        continue

    w   = merged["avg_conn"].values
    w   = w / w.sum()
    ref = (merged[sg_cols].values * w[:, None]).sum(axis=0)
    norm_ref = np.linalg.norm(ref)
    if norm_ref == 0:
        continue

    cosine_sg = np.dot(v_i, ref) / (norm_i * norm_ref)
    results.append({"identificad": i, "cba_period": period, "cosine_sg": cosine_sg})

out = pd.DataFrame(results)
print(f"  Computed similarity for {len(out):,} firm × cba_period obs", flush=True)

out.to_stata(str(output_path), write_index=False, version=118)
print(f"Saved → {output_path}", flush=True)

subprocess.run(["curl", "-s", "-o", "/dev/null",
                "-H", "Title: subgroup_prep done",
                "-d", f"subgroup_prep.py finished. {len(out):,} obs.",
                "https://ntfy.sh/lgg3230-kellogg"])
