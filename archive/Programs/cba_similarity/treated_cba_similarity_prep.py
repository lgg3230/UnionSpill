"""
treated_cba_similarity_prep.py

MIRROR of cba_similarity_prep.py.

Computes CBA content similarity between TREATED firms and the flow-weighted
average of their CONNECTED UNTREATED partners, per firm x cba_period.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period_treated.dta  (exported by treated_cba_similarity.do)
    columns: identificad, cba_period, treat_ultra, lagos_sample_avg,
             in_balanced_panel, cl_*
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv

Outputs:
  Data/RAIS_aux/treated_cba_similarity_panel.dta
    one row per (treated firm, cba_period) with non-missing reference vector
  Data/RAIS_aux/totaluntreat_pw_n.dta
    one row per treated firm: identificad, totaluntreat_pw_n
    (sum of bilateral_conn_pw across untreated partners; firm-level, time-invariant)
"""

import pandas as pd
import numpy as np
import duckdb
import subprocess
from pathlib import Path

# Paths
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"
clauses_path     = rais_aux / "cba_clauses_by_period_treated.dta"
bilateral_path   = rais_aux / "bilateral_connectivity_2007_2011.csv"
output_path      = rais_aux / "treated_cba_similarity_panel.dta"
conn_output_path = rais_aux / "totaluntreat_pw_n.dta"

# Load clauses
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses)} observations")

clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  Treated firms: {len(treated_ids):,}  |  Untreated firms: {len(untreated_ids):,}")

# Load bilateral
print("Loading bilateral connectivity...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()
print(f"  {len(bilateral):,} bilateral pairs with positive weight")

# Build (treated firm i) → (untreated firm j) directed pairs (both orderings)
fwd = bilateral[
    bilateral["id_i"].isin(treated_ids) & bilateral["id_j"].isin(untreated_ids)
].rename(columns={"id_i": "firm_i", "id_j": "firm_j"})

rev = bilateral[
    bilateral["id_j"].isin(treated_ids) & bilateral["id_i"].isin(untreated_ids)
].rename(columns={"id_j": "firm_i", "id_i": "firm_j"})

bilateral_tu = pd.concat([fwd, rev], ignore_index=True).drop_duplicates(
    subset=["firm_i", "firm_j"]
)
print(f"  Treated→untreated pairs: {len(bilateral_tu):,}")
print(f"  Treated firms with at least one untreated connection: "
      f"{bilateral_tu['firm_i'].nunique():,}", flush=True)

# Compute weighted-avg untreated clause vector per (treated firm, cba_period)
print("Computing weighted-average reference vectors (treated → untreated avg)...", flush=True)

untreated_clauses = clauses[clauses.treat_ultra == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()
untreated_clauses.rename(columns={"identificad": "firm_j"}, inplace=True)

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='16GB'")
con.register("bilateral_tu",      bilateral_tu)
con.register("untreated_clauses", untreated_clauses)

clause_agg_sql = ",\n    ".join([
    f"SUM(t.{c} * b.weight) / SUM(b.weight) AS ref_{c}"
    for c in clause_vars
])

ref_df = con.execute(f"""
    SELECT
        b.firm_i       AS identificad,
        t.cba_period,
        {clause_agg_sql}
    FROM bilateral_tu b
    JOIN untreated_clauses t ON b.firm_j = t.firm_j
    GROUP BY b.firm_i, t.cba_period
""").fetch_arrow_table().to_pandas()

ref_clause_vars = [f"ref_{c}" for c in clause_vars]
print(f"  Reference vectors: {len(ref_df):,} firm-period obs  "
      f"({ref_df['identificad'].nunique():,} unique treated firms)", flush=True)

# Treated firm clause vectors
treated = clauses[clauses.treat_ultra == 1][
    ["identificad", "cba_period"] + clause_vars
].copy()

merged = treated.merge(ref_df, on=["identificad", "cba_period"], how="left")
ref_available = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Treated firm-period obs with reference: {ref_available.sum():,} / {len(merged):,}",
      flush=True)

# Compute 4 similarity measures (vectorized)
print("Computing similarity measures...", flush=True)

X     = merged[clause_vars].values.astype(float)
Y_raw = merged[ref_clause_vars].values.astype(float)
Y     = np.where(np.isnan(Y_raw), 0.0, Y_raw)
ref_ok = ref_available.values

# Cosine
norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine = np.where(
    ref_ok & (norm_x > 0) & (norm_y > 0),
    dot / (norm_x * norm_y),
    np.where(ref_ok, 0.0, np.nan)
)

# Bray-Curtis
abs_diff = np.abs(Y - X).sum(axis=1)
sum_tot  = (X + Y).sum(axis=1)
bray_curtis = np.where(
    ref_ok & (sum_tot > 0),
    1.0 - abs_diff / sum_tot,
    np.where(ref_ok, 1.0, np.nan)
)

# Total variation
x_tot   = X.sum(axis=1, keepdims=True)
y_tot   = Y.sum(axis=1, keepdims=True)
x_share = np.where(x_tot > 0, X / np.maximum(x_tot, 1e-15), 0.0)
y_share = np.where(y_tot > 0, Y / np.maximum(y_tot, 1e-15), 0.0)
total_variation = np.where(
    ref_ok,
    1.0 - 0.5 * np.abs(y_share - x_share).sum(axis=1),
    np.nan
)

# Ruzicka (weighted Jaccard)
sum_min = np.minimum(X, Y).sum(axis=1)
sum_max = np.maximum(X, Y).sum(axis=1)
ruzicka = np.where(
    ref_ok & (sum_max > 0),
    sum_min / np.maximum(sum_max, 1e-15),
    np.where(ref_ok, 1.0, np.nan)
)

merged["cosine"]          = cosine
merged["bray_curtis"]     = bray_curtis
merged["total_variation"] = total_variation
merged["ruzicka"]         = ruzicka

result = merged[
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "ruzicka"]
].copy()
result = result[ref_ok]

print(f"Saving {len(result):,} treated firm-period observations to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Per-treated-firm sum of bilateral weights to untreated partners
print("Computing totaluntreat_pw_n (sum of bilateral_conn_pw across untreated partners)...",
      flush=True)
conn_df = bilateral_tu.groupby("firm_i", as_index=False)["weight"].sum()
conn_df.columns = ["identificad", "totaluntreat_pw_n"]
print(f"  {len(conn_df):,} treated firms with positive untreated connectivity")
print(f"  totaluntreat_pw_n distribution: "
      f"mean={conn_df['totaluntreat_pw_n'].mean():.4f}, "
      f"p50={conn_df['totaluntreat_pw_n'].median():.4f}, "
      f"p90={conn_df['totaluntreat_pw_n'].quantile(0.9):.4f}, "
      f"max={conn_df['totaluntreat_pw_n'].max():.4f}")

conn_df.to_stata(str(conn_output_path), write_index=False, version=118)
print(f"Saved totaluntreat_pw_n to {conn_output_path}", flush=True)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: treated_cba_similarity_prep done",
     "-d", f"Saved {len(result):,} treated obs to treated_cba_similarity_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False
)
print("Done.", flush=True)
