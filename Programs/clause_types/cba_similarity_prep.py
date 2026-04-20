"""
cba_similarity_prep.py
Computes CBA content similarity between untreated firms and their flow-weighted
average of connected treated firms, per firm × cba_period.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta  (exported by cba_similarity.do)
    columns: identificad, cba_period, treat_ultra, lagos_sample_avg,
             in_balanced_panel, cl_*
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv
    columns: identificad_i, identificad_j, bilateral_conn_pw, ...

Output:
  Data/RAIS_aux/cba_similarity_panel.dta
    columns: identificad, cba_period, cosine, bray_curtis, total_variation, jaccard
    one row per (untreated firm, cba_period) with a non-missing reference vector
"""

import pandas as pd
import numpy as np
import duckdb
import subprocess
import sys
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
main     = Path("/kellogg/proj/lgg3230")
rais_aux = main / "UnionSpill/Data/RAIS_aux"

clauses_path  = rais_aux / "cba_clauses_by_period.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"
output_path   = rais_aux / "cba_similarity_panel.dta"

# ── Load clause data (exported from Stata with cba_period already computed) ───
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)

# identificad should already be a 14-digit string from Stata's tostring
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses)} observations")

# Fill missing clause counts with 0 (missing = no clause of that type)
clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period (in case of multiple year rows per period)
# keep boolean flags as max so any-True becomes True
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  Treated firms: {len(treated_ids):,}  |  Untreated firms: {len(untreated_ids):,}")

# ── Load bilateral connectivity ────────────────────────────────────────────────
print("Loading bilateral connectivity...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))

# IDs are 15-digit integers with a leading "1"; strip to 14 digits
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]

# Pre-treatment weight: use bilateral_conn_pw (already a per-worker aggregate)
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()

print(f"  {len(bilateral):,} bilateral pairs with positive weight")

# ── Build (untreated firm i) → (treated firm j) directed pairs ─────────────────
# Bilateral CSV may have pairs in either ordering; check both directions.
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

# ── Compute flow-weighted average clause vector per (untreated firm, cba_period)
print("Computing weighted-average reference vectors...", flush=True)

treated_clauses = clauses[clauses.treat_ultra == 1][
    ["identificad", "cba_period"] + clause_vars
].copy()
treated_clauses.rename(columns={"identificad": "firm_j"}, inplace=True)

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='16GB'")
con.register("bilateral_ut",    bilateral_ut)
con.register("treated_clauses", treated_clauses)

clause_agg_sql = ",\n    ".join([
    f"SUM(t.{c} * b.weight) / SUM(b.weight) AS ref_{c}"
    for c in clause_vars
])

ref_df = con.execute(f"""
    SELECT
        b.firm_i       AS identificad,
        t.cba_period,
        {clause_agg_sql}
    FROM bilateral_ut b
    JOIN treated_clauses t ON b.firm_j = t.firm_j
    GROUP BY b.firm_i, t.cba_period
""").fetch_arrow_table().to_pandas()

ref_clause_vars = [f"ref_{c}" for c in clause_vars]
print(f"  Reference vectors: {len(ref_df):,} firm-period obs  "
      f"({ref_df['identificad'].nunique():,} unique firms)", flush=True)

# ── Merge untreated firm clause vectors with reference vectors ─────────────────
untreated = clauses[clauses.treat_ultra == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()

merged = untreated.merge(ref_df, on=["identificad", "cba_period"], how="left")

# Indicator: reference available (not all NaN)
ref_available = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Firm-period obs with reference: {ref_available.sum():,} / {len(merged):,}",
      flush=True)

# ── Compute 4 similarity measures (vectorized) ─────────────────────────────────
print("Computing similarity measures...", flush=True)

X = merged[clause_vars].values.astype(float)          # untreated firm vectors
Y_raw = merged[ref_clause_vars].values.astype(float)  # reference vectors (may have NaN)

# Replace NaN in Y with 0 for computation; mask with ref_available at the end
Y = np.where(np.isnan(Y_raw), 0.0, Y_raw)
ref_ok = ref_available.values

# Cosine similarity
norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine = np.where(
    ref_ok & (norm_x > 0) & (norm_y > 0),
    dot / (norm_x * norm_y),
    np.where(ref_ok, 0.0, np.nan)   # zero norm → similarity = 0
)

# Bray-Curtis similarity: 1 - sum|y-x| / sum(y+x)
abs_diff = np.abs(Y - X).sum(axis=1)
sum_tot  = (X + Y).sum(axis=1)
bray_curtis = np.where(
    ref_ok & (sum_tot > 0),
    1.0 - abs_diff / sum_tot,
    np.where(ref_ok, 1.0, np.nan)   # both zero → perfect similarity
)

# Total variation similarity: 1 - 0.5 * sum|y_share - x_share|
x_tot   = X.sum(axis=1, keepdims=True)
y_tot   = Y.sum(axis=1, keepdims=True)
x_share = np.where(x_tot > 0, X / np.maximum(x_tot, 1e-15), 0.0)
y_share = np.where(y_tot > 0, Y / np.maximum(y_tot, 1e-15), 0.0)
total_variation = np.where(
    ref_ok,
    1.0 - 0.5 * np.abs(y_share - x_share).sum(axis=1),
    np.nan
)

# Jaccard similarity: |A ∩ B| / |A ∪ B|
x_pres = X > 0
y_pres = Y > 0
n_inter = (x_pres & y_pres).sum(axis=1)
n_union = (x_pres | y_pres).sum(axis=1)
jaccard = np.where(
    ref_ok & (n_union > 0),
    n_inter / np.maximum(n_union, 1),
    np.where(ref_ok, 1.0, np.nan)
)

merged["cosine"]          = cosine
merged["bray_curtis"]     = bray_curtis
merged["total_variation"] = total_variation
merged["jaccard"]         = jaccard

# ── Save output ────────────────────────────────────────────────────────────────
result = merged[
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "jaccard"]
].copy()
result = result[ref_ok]   # keep only obs with reference vectors

print(f"Saving {len(result):,} firm-period observations to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

print("Done.", flush=True)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_prep done",
     "-d", f"Saved {len(result):,} obs to cba_similarity_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False
)
