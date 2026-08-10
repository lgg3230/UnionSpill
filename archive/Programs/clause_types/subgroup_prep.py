"""
subgroup_prep.py
Computes CBA content similarity at the subgroup level (24 subgroups).
Aggregates cl_* clause-type counts to subgroup counts, then computes
flow-weighted cosine similarity between each untreated firm and its
connected treated firms, per firm × cba_period.

Mirrors the structure of cba_similarity_prep.py so the sample is comparable
to the firm-level cosine exercise.

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
import duckdb
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

# Collapse to firm × cba_period (in case of multiple year rows per period)
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

treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  {len(clauses):,} firm × cba_period obs  |  "
      f"Treated firms: {len(treated_ids):,}  |  Untreated firms: {len(untreated_ids):,}",
      flush=True)

# ── Load bilateral connectivity ───────────────────────────────────────────────

print("Loading bilateral connectivity...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))

# IDs are 15-digit integers with a leading "1"; strip to 14 digits
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]

# Pre-treatment weight: use bilateral_conn_pw (per-worker aggregate)
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()

print(f"  {len(bilateral):,} bilateral pairs with positive weight", flush=True)

# ── Build (untreated firm i) → (treated firm j) directed pairs ────────────────
# Bilateral CSV stores each pair once in canonical order; check both directions.

fwd = bilateral[
    bilateral["id_i"].isin(untreated_ids) & bilateral["id_j"].isin(treated_ids)
].rename(columns={"id_i": "firm_i", "id_j": "firm_j"})

rev = bilateral[
    bilateral["id_j"].isin(untreated_ids) & bilateral["id_i"].isin(treated_ids)
].rename(columns={"id_j": "firm_i", "id_i": "firm_j"})

bilateral_ut = pd.concat([fwd, rev], ignore_index=True).drop_duplicates(
    subset=["firm_i", "firm_j"]
)
print(f"  Untreated→treated pairs: {len(bilateral_ut):,}")
print(f"  Untreated firms with at least one treated connection: "
      f"{bilateral_ut['firm_i'].nunique():,}", flush=True)

# ── Flow-weighted average subgroup vector per (untreated firm, cba_period) ────

print("Computing weighted-average reference vectors...", flush=True)

treated_sg = clauses[clauses.treat_ultra == 1][
    ["identificad", "cba_period"] + sg_cols
].copy()
treated_sg.rename(columns={"identificad": "firm_j"}, inplace=True)

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='16GB'")
con.register("bilateral_ut", bilateral_ut)
con.register("treated_sg",   treated_sg)

sg_agg_sql = ",\n    ".join([
    f"SUM(t.{c} * b.weight) / SUM(b.weight) AS ref_{c}"
    for c in sg_cols
])

ref_df = con.execute(f"""
    SELECT
        b.firm_i       AS identificad,
        t.cba_period,
        {sg_agg_sql}
    FROM bilateral_ut b
    JOIN treated_sg t ON b.firm_j = t.firm_j
    GROUP BY b.firm_i, t.cba_period
""").fetch_arrow_table().to_pandas()

ref_sg_cols = [f"ref_{c}" for c in sg_cols]
print(f"  Reference vectors: {len(ref_df):,} firm-period obs  "
      f"({ref_df['identificad'].nunique():,} unique firms)", flush=True)

# ── Merge untreated firm subgroup vectors with reference vectors ──────────────

untreated = clauses[clauses.treat_ultra == 0][
    ["identificad", "cba_period"] + sg_cols
].copy()

merged = untreated.merge(ref_df, on=["identificad", "cba_period"], how="left")

ref_available = ~merged[ref_sg_cols].isna().all(axis=1)
print(f"  Firm-period obs with reference: {ref_available.sum():,} / {len(merged):,}",
      flush=True)

# ── Cosine similarity (vectorized) ────────────────────────────────────────────

X = merged[sg_cols].values.astype(float)
Y_raw = merged[ref_sg_cols].values.astype(float)
Y = np.where(np.isnan(Y_raw), 0.0, Y_raw)
ref_ok = ref_available.values

norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine_sg = np.where(
    ref_ok & (norm_x > 0) & (norm_y > 0),
    dot / np.maximum(norm_x * norm_y, 1e-15),
    np.where(ref_ok, 0.0, np.nan)
)

merged["cosine_sg"] = cosine_sg

# ── Save output ───────────────────────────────────────────────────────────────

result = merged[["identificad", "cba_period", "cosine_sg"]].copy()
result = result[ref_ok]

print(f"Saving {len(result):,} firm-period observations to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: subgroup_prep done",
     "-d", f"Saved {len(result):,} obs to subgroup_similarity_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False
)
