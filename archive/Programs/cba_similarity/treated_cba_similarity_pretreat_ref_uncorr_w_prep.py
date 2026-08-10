"""
treated_cba_similarity_pretreat_ref_uncorr_w_prep.py

MIRROR of cba_similarity_pretreat_ref_uncorr_w_prep.py with focal/partner roles swapped.

For each treated focal firm, computes a fixed pre-treatment reference vector
from the clauses (in cba_period == 2) of its connected UNTREATED partners,
weighted by the ORIGINAL i<j-biased bilateral_conn_pw (no focal-firm
denominator correction). Pair-twin of treated_cba_similarity_pretreat_ref_prep.py:
the only thing that changes between the two scripts is the weight definition.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period_treated.dta    (exported by treated_cba_similarity_pretreat_ref_uncorr_w.do)
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv   (pair weights)

Output:
  Data/RAIS_aux/treated_cba_similarity_pretreat_ref_uncorr_w_panel.dta
    one row per (treated firm, cba_period) with non-missing reference;
    columns: identificad, cba_period, cosine, bray_curtis, total_variation, ruzicka
"""

import pandas as pd
import numpy as np
import subprocess
from pathlib import Path

# Paths
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"

clauses_path   = rais_aux / "cba_clauses_by_period_treated.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"
output_path    = rais_aux / "treated_cba_similarity_pretreat_ref_uncorr_w_panel.dta"

# ── Load clauses ───────────────────────────────────────────────────────────────
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses):,} observations")

clauses[clause_vars] = clauses[clause_vars].fillna(0)

clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

# ── Treat-status sets from the clauses table (matches cba_similarity_prep.py) ──
# No firm-panel-based pair restriction here: the regression-side `s_treat`
# filter handles the focal-side balanced-panel requirement; the partner side
# is NOT restricted, exactly as in the original moving-reference exercise.
treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  Treated firms in clauses: {len(treated_ids):,}  |  "
      f"Untreated firms in clauses: {len(untreated_ids):,}")

# ── Bilateral pairs: bilateral_conn_pw (same value for both orientations) ─────
print("Loading bilateral connectivity (original weights)...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()
print(f"  {len(bilateral):,} bilateral pairs with positive weight")

# Treated focal → untreated partner (RECIPROCAL direction).
fwd = bilateral[
    bilateral["id_i"].isin(treated_ids) & bilateral["id_j"].isin(untreated_ids)
].rename(columns={"id_i": "focal", "id_j": "partner"})

rev = bilateral[
    bilateral["id_j"].isin(treated_ids) & bilateral["id_i"].isin(untreated_ids)
].rename(columns={"id_j": "focal", "id_i": "partner"})

pairs = pd.concat([fwd, rev], ignore_index=True).drop_duplicates(
    subset=["focal", "partner"]
)[["focal", "partner", "weight"]]
print(f"  Treated→untreated pairs (original weights): {len(pairs):,}")
print(f"  Treated focals with at least one untreated partner: "
      f"{pairs['focal'].nunique():,}", flush=True)

# ── Reference clause vector at cba_period == 2 (UNTREATED partners) ───────────
print("Building fixed pre-treatment (cba_period==2) reference vectors...", flush=True)

cl2 = clauses[(clauses["cba_period"] == 2) & (clauses["treat_ultra"] == 0)][
    ["identificad"] + clause_vars
].rename(columns={"identificad": "partner"})

merged_pairs = pairs.merge(cl2, on="partner", how="inner")
print(f"  {len(merged_pairs):,} (focal, partner) rows with period-2 clause data")

w = merged_pairs["weight"].values
w_total = merged_pairs.groupby("focal")["weight"].sum()

weighted_clauses = merged_pairs[clause_vars].multiply(w, axis=0)
weighted_clauses["focal"] = merged_pairs["focal"].values
ref = weighted_clauses.groupby("focal").sum().div(w_total, axis=0).reset_index()
ref = ref.rename(columns={"focal": "identificad"})
ref.columns = ["identificad"] + [f"ref_{c}" for c in clause_vars]
ref_clause_vars = [f"ref_{c}" for c in clause_vars]

print(f"  Reference vectors built for {len(ref):,} treated focal firms",
      flush=True)

# ── Merge the (constant) reference into the focal firm's per-period clauses ───
treated = clauses[clauses["treat_ultra"] == 1][
    ["identificad", "cba_period"] + clause_vars
].copy()

merged = treated.merge(ref, on="identificad", how="left")
ref_available = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Treated firm-period obs with reference: "
      f"{ref_available.sum():,} / {len(merged):,}", flush=True)

# ── Compute four similarity measures (vectorized; identical to upstream) ──────
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

# ── Restrict to firm-periods present in the moving-reference panel ────────────
# Inner-merge on (identificad, cba_period) with treated_cba_similarity_panel.dta
# so this panel matches the moving-reference treated sample exactly. The ONLY
# thing that differs across the two tables is whether similarity is measured
# against the moving same-period reference or the fixed period-2 reference.
sample_keys_path = rais_aux / "treated_cba_similarity_panel.dta"
print(f"Inner-merging with {sample_keys_path.name} on (identificad, cba_period)...",
      flush=True)
sample_keys = pd.read_stata(str(sample_keys_path),
                            columns=["identificad", "cba_period"],
                            convert_categoricals=False)
sample_keys["identificad"] = sample_keys["identificad"].astype(str).str.strip().str.zfill(14)
sample_keys = sample_keys.drop_duplicates(subset=["identificad", "cba_period"])

# ── Save ──────────────────────────────────────────────────────────────────────
result = merged.loc[
    ref_ok,
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "ruzicka"],
].copy()

n_before = len(result)
result = result.merge(sample_keys, on=["identificad", "cba_period"], how="inner")
print(f"  Firm-period obs: {n_before:,} → {len(result):,} after inner-merge "
      f"(dropped {n_before - len(result):,} rows not in moving-ref treated sample)",
      flush=True)

print(f"Saving {len(result):,} treated firm-period observations to {output_path}",
      flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: treated_cba_similarity_pretreat_ref_uncorr_w_prep done",
     "-d", f"Saved {len(result):,} treated obs to "
           f"treated_cba_similarity_pretreat_ref_uncorr_w_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
