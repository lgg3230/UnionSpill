"""
cba_self_similarity_prep.py

Computes within-firm CBA self-similarity: for each firm i and CBA period t,
similarity between firm i's clause vector at period t and its OWN clause
vector at the last pre-Sumula period (cba_period == 2).

This is the "content stability" outcome — answers the question "are firms
drifting from their own pre-treatment CBAs?" The downstream regression is
identical to cba_similarity.do (and treated_cba_similarity.do) except the
outcome is replaced with this self-similarity measure.

The same panel is used for both the untreated and treated regression .do
files — each filters at regression time via its own sample restriction.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta  (exported by cba_self_similarity.do
  or cba_similarity.do — both write the same file)

Output:
  Data/RAIS_aux/cba_self_similarity_panel.dta
    one row per (firm, cba_period) with non-missing self-reference;
    columns: identificad, cba_period, cosine, bray_curtis, total_variation, ruzicka
"""

import pandas as pd
import numpy as np
import subprocess
from pathlib import Path

# Paths
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"

clauses_path = rais_aux / "cba_clauses_by_period.dta"
sample_path  = rais_aux / "cba_similarity_panel.dta"
output_path  = rais_aux / "cba_self_similarity_panel.dta"

# ── Load clauses ───────────────────────────────────────────────────────────────
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses):,} observations")

clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period (in case of multiple year rows per period)
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

# ── Load (identificad, cba_period) keys from spillover-similarity sample ──────
# Match the (firm, period) sample used in cba_similarity.do. We inner-merge on
# (identificad, cba_period) at the END so that every row in this output panel
# also exists in cba_similarity_panel.dta — the regression sample is identical.
print("Loading sample keys from cba_similarity_panel.dta...", flush=True)
sample_keys = pd.read_stata(str(sample_path),
                            columns=["identificad", "cba_period"],
                            convert_categoricals=False)
sample_keys["identificad"] = sample_keys["identificad"].astype(str).str.strip().str.zfill(14)
sample_keys = sample_keys.drop_duplicates(subset=["identificad", "cba_period"])
print(f"  {len(sample_keys):,} firm-period rows in spillover sample "
      f"({sample_keys['identificad'].nunique():,} firms)", flush=True)

# ── Build per-firm period-2 reference vector ───────────────────────────────────
print("Building period-2 self-reference vectors...", flush=True)
ref = clauses[clauses["cba_period"] == 2][["identificad"] + clause_vars].copy()
ref.columns = ["identificad"] + [f"ref_{c}" for c in clause_vars]
ref_clause_vars = [f"ref_{c}" for c in clause_vars]
print(f"  {len(ref):,} firms with a period-2 CBA", flush=True)

# Merge each firm's own period-2 vector onto every (firm, cba_period) row
merged = clauses.merge(ref, on="identificad", how="left")
ref_available = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Firm-period obs with a period-2 self-reference: "
      f"{ref_available.sum():,} / {len(merged):,}", flush=True)

# ── Compute four similarity measures (identical formulas to upstream prep) ────
print("Computing similarity measures...", flush=True)

X     = merged[clause_vars].values.astype(float)
Y_raw = merged[ref_clause_vars].values.astype(float)
Y     = np.where(np.isnan(Y_raw), 0.0, Y_raw)
ref_ok = ref_available.values

norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine = np.where(
    ref_ok & (norm_x > 0) & (norm_y > 0),
    dot / np.maximum(norm_x * norm_y, 1e-15),
    np.where(ref_ok, 0.0, np.nan),
)

abs_diff = np.abs(Y - X).sum(axis=1)
sum_tot  = (X + Y).sum(axis=1)
bray_curtis = np.where(
    ref_ok & (sum_tot > 0),
    1.0 - abs_diff / np.maximum(sum_tot, 1e-15),
    np.where(ref_ok, 1.0, np.nan),
)

x_tot   = X.sum(axis=1, keepdims=True)
y_tot   = Y.sum(axis=1, keepdims=True)
x_share = np.where(x_tot > 0, X / np.maximum(x_tot, 1e-15), 0.0)
y_share = np.where(y_tot > 0, Y / np.maximum(y_tot, 1e-15), 0.0)
total_variation = np.where(
    ref_ok,
    1.0 - 0.5 * np.abs(y_share - x_share).sum(axis=1),
    np.nan,
)

sum_min = np.minimum(X, Y).sum(axis=1)
sum_max = np.maximum(X, Y).sum(axis=1)
ruzicka = np.where(
    ref_ok & (sum_max > 0),
    sum_min / np.maximum(sum_max, 1e-15),
    np.where(ref_ok, 1.0, np.nan),
)

merged["cosine"]          = cosine
merged["bray_curtis"]     = bray_curtis
merged["total_variation"] = total_variation
merged["ruzicka"]         = ruzicka

# ── Save ──────────────────────────────────────────────────────────────────────
result = merged.loc[
    ref_ok,
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "ruzicka"],
].copy()

# Inner-merge on (identificad, cba_period) with the moving-reference panel so
# the regression sample is identical to cba_similarity_table.tex.
n_before = len(result)
result = result.merge(sample_keys, on=["identificad", "cba_period"], how="inner")
print(f"  Firm-period obs: {n_before:,} → {len(result):,} after inner-merge "
      f"(dropped {n_before - len(result):,} rows not in moving-ref sample)",
      flush=True)

# Sanity check: cba_period == 2 should yield similarity == 1 by construction
n_p2 = (result["cba_period"] == 2).sum()
if n_p2 > 0:
    p2_check = result[result["cba_period"] == 2][
        ["cosine", "bray_curtis", "total_variation", "ruzicka"]
    ].mean()
    print(f"  Sanity (period 2 should be 1.0): {p2_check.to_dict()}", flush=True)

print(f"Saving {len(result):,} firm-period observations to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_self_similarity_prep done",
     "-d", f"Saved {len(result):,} obs to cba_self_similarity_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
