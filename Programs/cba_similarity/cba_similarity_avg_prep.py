"""
cba_similarity_avg_prep.py
Computes CBA content similarity between each untreated firm and the simple
(unweighted) average CBA across ALL treated firms, per cba_period.

Because every period has a well-defined average treated CBA, ALL untreated
firms receive a reference vector regardless of bilateral connectivity.

Input:
  Data/RAIS_aux/cba_clauses_by_period.dta  (exported by cba_similarity_avg.do)
    columns: identificad, cba_period, treat_ultra, lagos_sample_avg,
             in_balanced_panel, cl_*

Output:
  Data/RAIS_aux/cba_similarity_avg_panel.dta
    columns: identificad, cba_period, cosine, bray_curtis, total_variation, ruzicka
"""

import pandas as pd
import numpy as np
import subprocess
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
main     = Path("/kellogg/proj/lgg3230")
rais_aux = main / "UnionSpill/Data/RAIS_aux"

clauses_path = rais_aux / "cba_clauses_by_period.dta"
output_path  = rais_aux / "cba_similarity_avg_panel.dta"

# ── Load clause data ──────────────────────────────────────────────────────────
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses)} observations")

clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period (average across year rows within a period)
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

n_treated   = clauses.loc[clauses.treat_ultra == 1, "identificad"].nunique()
n_untreated = clauses.loc[clauses.treat_ultra == 0, "identificad"].nunique()
print(f"  Treated firms: {n_treated:,}  |  Untreated firms: {n_untreated:,}")

# ── Compute simple average treated clause vector per cba_period ───────────────
print("Computing average treated CBA per period...", flush=True)
treated = clauses[clauses.treat_ultra == 1]
ref_df = treated.groupby("cba_period")[clause_vars].mean().reset_index()
ref_df.rename(columns={c: f"ref_{c}" for c in clause_vars}, inplace=True)

print("  Periods with treated reference:")
for _, row in ref_df.iterrows():
    print(f"    cba_period {int(row.cba_period)}: "
          f"{treated[treated.cba_period == row.cba_period]['identificad'].nunique():,} treated firms")

# ── Merge reference into untreated panel ─────────────────────────────────────
untreated = clauses[clauses.treat_ultra == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()

merged = untreated.merge(ref_df, on="cba_period", how="left")

ref_clause_vars = [f"ref_{c}" for c in clause_vars]
ref_ok = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Firm-period obs with reference: {ref_ok.sum():,} / {len(merged):,}",
      flush=True)

# ── Compute 4 similarity measures (vectorized) ────────────────────────────────
print("Computing similarity measures...", flush=True)

X = merged[clause_vars].values.astype(float)
Y_raw = merged[ref_clause_vars].values.astype(float)
Y = np.where(np.isnan(Y_raw), 0.0, Y_raw)
ref_ok_arr = ref_ok.values

# Cosine
norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine = np.where(
    ref_ok_arr & (norm_x > 0) & (norm_y > 0),
    dot / (norm_x * norm_y),
    np.where(ref_ok_arr, 0.0, np.nan)
)

# Bray-Curtis
abs_diff = np.abs(Y - X).sum(axis=1)
sum_tot  = (X + Y).sum(axis=1)
bray_curtis = np.where(
    ref_ok_arr & (sum_tot > 0),
    1.0 - abs_diff / sum_tot,
    np.where(ref_ok_arr, 1.0, np.nan)
)

# Total variation
x_tot   = X.sum(axis=1, keepdims=True)
y_tot   = Y.sum(axis=1, keepdims=True)
x_share = np.where(x_tot > 0, X / np.maximum(x_tot, 1e-15), 0.0)
y_share = np.where(y_tot > 0, Y / np.maximum(y_tot, 1e-15), 0.0)
total_variation = np.where(
    ref_ok_arr,
    1.0 - 0.5 * np.abs(y_share - x_share).sum(axis=1),
    np.nan
)

# Ruzicka (weighted Jaccard)
sum_min = np.minimum(X, Y).sum(axis=1)
sum_max = np.maximum(X, Y).sum(axis=1)
ruzicka = np.where(
    ref_ok_arr & (sum_max > 0),
    sum_min / np.maximum(sum_max, 1e-15),
    np.where(ref_ok_arr, 1.0, np.nan)
)

merged["cosine"]          = cosine
merged["bray_curtis"]     = bray_curtis
merged["total_variation"] = total_variation
merged["ruzicka"]         = ruzicka

result = merged[
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "ruzicka"]
].copy()
result = result[ref_ok_arr]

print(f"Saving {len(result):,} firm-period observations "
      f"({result['identificad'].nunique():,} firms) to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)
print("Done.", flush=True)

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_avg_prep done",
     "-d", f"Saved {len(result):,} obs ({result['identificad'].nunique():,} firms)",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False
)
