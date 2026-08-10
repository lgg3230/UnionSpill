"""
cba_similarity_focal_frozen_prep.py

Exercise B in the A/B/C decomposition:
  Hold the spillover (untreated focal) firm's clause vector FIXED at
  cba_period == 2, but let the treated partner reference MOVE with the
  current cba_period t. Uses the SAME uncorrected bilateral_conn_pw weights
  as Exercise A (`cba_similarity.do`) and Exercise C
  (`cba_similarity_pretreat_ref_uncorr_w.do`), so connectivity coefficients
  are directly comparable across all three.

  Similarity at (focal i, period t):
      sim_{it} = sim( u_{i,2},  T_{i,t} )
  where
      u_{i,2}     = focal firm i's clauses at cba_period 2  (FIXED)
      T_{i,t}     = Σ_k w_{ik} * x_{k,t}  / Σ_k w_{ik}      (MOVING)
      w_{ik}      = bilateral_conn_pw (uncorrected, i<j-biased)
      k ranges over treated firms with positive flow weight to i AND with a
      CBA at cba_period t.

  Contrast with Exercise C (pretreat_ref_uncorr_w_prep): there the focal
  moves and the partner reference is fixed at cba_period 2. Same weights,
  same sample, only the "frozen at period 2" side flips.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta            (firm × cba_period)
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv (pair weights)
  Data/RAIS_aux/cba_similarity_panel.dta             (sample-key for inner-merge)

Output:
  Data/RAIS_aux/cba_similarity_focal_frozen_panel.dta
    columns: identificad, cba_period, cosine, bray_curtis,
             total_variation, ruzicka
"""

import subprocess
from pathlib import Path

import numpy as np
import pandas as pd

# Paths
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"

clauses_path   = rais_aux / "cba_clauses_by_period.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"
output_path    = rais_aux / "cba_similarity_focal_frozen_panel.dta"
sample_path    = rais_aux / "cba_similarity_panel.dta"

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

treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  Treated firms in clauses: {len(treated_ids):,}  |  "
      f"Untreated firms in clauses: {len(untreated_ids):,}")

# ── Bilateral pairs: bilateral_conn_pw (same as Exercises A & C) ──────────────
print("Loading bilateral connectivity (uncorrected weights)...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()
print(f"  {len(bilateral):,} bilateral pairs with positive weight")

# Untreated focal → treated partner (both orientations)
fwd = bilateral[
    bilateral["id_i"].isin(untreated_ids) & bilateral["id_j"].isin(treated_ids)
].rename(columns={"id_i": "focal", "id_j": "partner"})
rev = bilateral[
    bilateral["id_j"].isin(untreated_ids) & bilateral["id_i"].isin(treated_ids)
].rename(columns={"id_j": "focal", "id_i": "partner"})
pairs = pd.concat([fwd, rev], ignore_index=True).drop_duplicates(
    subset=["focal", "partner"]
)[["focal", "partner", "weight"]]
print(f"  Untreated→treated pairs: {len(pairs):,}", flush=True)
print(f"  Untreated focals with at least one treated partner: "
      f"{pairs['focal'].nunique():,}", flush=True)

# ── Build MOVING partner reference T_{i,t} per (focal, period) ────────────────
# For every cba_period t in {1..6}, compute the flow-weighted average of treated
# partners' clauses at period t, using weights w_{ik} = bilateral_conn_pw.
print("Building per-period moving treated reference vectors...", flush=True)

treated_clauses = clauses[clauses["treat_ultra"] == 1][
    ["identificad", "cba_period"] + clause_vars
].rename(columns={"identificad": "partner"})

# Cross focal × partner × partner-period
merged_pairs = pairs.merge(treated_clauses, on="partner", how="inner")
print(f"  (focal, partner, period) triples: {len(merged_pairs):,}", flush=True)

# Per-(focal, period) weight totals — denominator includes only partners with
# CBAs at that period (NaN-aware: partners without CBA at t don't contribute).
w_totals = (merged_pairs.groupby(["focal", "cba_period"])["weight"]
            .sum()
            .reset_index()
            .rename(columns={"weight": "w_total"}))

weighted = merged_pairs[clause_vars].multiply(merged_pairs["weight"], axis=0)
weighted["focal"]      = merged_pairs["focal"].values
weighted["cba_period"] = merged_pairs["cba_period"].values
T_ref = weighted.groupby(["focal", "cba_period"]).sum().reset_index()
T_ref = T_ref.merge(w_totals, on=["focal", "cba_period"], how="inner")
for c in clause_vars:
    T_ref[c] = T_ref[c] / T_ref["w_total"]
T_ref = T_ref.drop(columns=["w_total"])
T_ref = T_ref.rename(columns={"focal": "identificad",
                              **{c: f"ref_{c}" for c in clause_vars}})
print(f"  Per-(focal, period) reference rows: {len(T_ref):,}", flush=True)

# ── Build FIXED focal vector u_{i,2} (untreated focal at cba_period 2) ────────
print("Building fixed period-2 focal clause vectors...", flush=True)
u_p2 = clauses[(clauses["cba_period"] == 2) & (clauses["treat_ultra"] == 0)][
    ["identificad"] + clause_vars
].copy()
print(f"  {len(u_p2):,} untreated focal firms with period-2 clauses", flush=True)

# ── Merge: u_{i,2} broadcast against every (i, t) reference row ───────────────
merged = T_ref.merge(u_p2, on="identificad", how="inner")
print(f"  (focal, period) rows with both u_{{i,2}} and T_{{i,t}}: "
      f"{len(merged):,}", flush=True)

# ── Compute four similarity measures (identical formulas to upstream prep) ────
print("Computing similarity measures...", flush=True)
ref_clause_vars = [f"ref_{c}" for c in clause_vars]

X = merged[clause_vars].values.astype(float)      # u_{i,2}, FIXED
Y = merged[ref_clause_vars].values.astype(float)  # T_{i,t}, MOVING

norm_x = np.linalg.norm(X, axis=1)
norm_y = np.linalg.norm(Y, axis=1)
dot    = (X * Y).sum(axis=1)
cosine = np.where(
    (norm_x > 0) & (norm_y > 0),
    dot / np.maximum(norm_x * norm_y, 1e-15),
    0.0,
)

abs_diff = np.abs(Y - X).sum(axis=1)
sum_tot  = (X + Y).sum(axis=1)
bray_curtis = np.where(sum_tot > 0,
                       1.0 - abs_diff / np.maximum(sum_tot, 1e-15),
                       1.0)

x_tot   = X.sum(axis=1, keepdims=True)
y_tot   = Y.sum(axis=1, keepdims=True)
x_share = np.where(x_tot > 0, X / np.maximum(x_tot, 1e-15), 0.0)
y_share = np.where(y_tot > 0, Y / np.maximum(y_tot, 1e-15), 0.0)
total_variation = 1.0 - 0.5 * np.abs(y_share - x_share).sum(axis=1)

sum_min = np.minimum(X, Y).sum(axis=1)
sum_max = np.maximum(X, Y).sum(axis=1)
ruzicka = np.where(sum_max > 0,
                   sum_min / np.maximum(sum_max, 1e-15),
                   1.0)

merged["cosine"]          = cosine
merged["bray_curtis"]     = bray_curtis
merged["total_variation"] = total_variation
merged["ruzicka"]         = ruzicka

result = merged[["identificad", "cba_period",
                 "cosine", "bray_curtis", "total_variation", "ruzicka"]].copy()

# ── Inner-merge with cba_similarity_panel for sample match ────────────────────
print(f"Inner-merging with {sample_path.name} on (identificad, cba_period)...",
      flush=True)
sample_keys = pd.read_stata(str(sample_path),
                            columns=["identificad", "cba_period"],
                            convert_categoricals=False)
sample_keys["identificad"] = sample_keys["identificad"].astype(str).str.strip().str.zfill(14)
sample_keys = sample_keys.drop_duplicates(subset=["identificad", "cba_period"])

n_before = len(result)
result = result.merge(sample_keys, on=["identificad", "cba_period"], how="inner")
print(f"  Firm-period obs: {n_before:,} → {len(result):,} after inner-merge "
      f"(dropped {n_before - len(result):,} rows not in moving-ref sample)",
      flush=True)

# Sanity check at period 2: since u_{i,2} == clauses at period 2 and T_{i,2}
# is the moving reference at period 2 (= treated partners at period 2), this
# should match the period-2 row of Exercise A's headline panel.
n_p2 = (result["cba_period"] == 2).sum()
if n_p2 > 0:
    p2_check = result[result["cba_period"] == 2][
        ["cosine", "bray_curtis", "total_variation", "ruzicka"]
    ].mean()
    print(f"  Period-2 mean similarities (should equal Exercise A's period 2): "
          f"{p2_check.to_dict()}", flush=True)

print(f"Saving {len(result):,} firm-period observations to {output_path}",
      flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_focal_frozen_prep done",
     "-d", f"Saved {len(result):,} obs to cba_similarity_focal_frozen_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
