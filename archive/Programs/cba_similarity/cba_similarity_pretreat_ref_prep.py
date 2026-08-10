"""
cba_similarity_pretreat_ref_prep.py

Computes CBA content similarity between untreated firms and a FIXED
pre-treatment reference vector built from the clauses (in cba_period == 2)
of their connected treated partners.

Differs from cba_similarity_prep.py in two ways:
  (1) The reference vector for each untreated focal firm is fixed at
      cba_period == 2 (last pre-Sumula CBA) instead of moving with t. This
      lets the regression pick up "are untreated firms moving toward what
      the treated CBAs looked like before treatment?".
  (2) Per-pair connectivity weights are recomputed from the FOCAL firm's
      perspective (focal-firm denominator), correcting the i<j orientation
      bias in the bilateral CSV. The bilateral_connectivity.m output stores
      ratio_* with the smaller-ID firm's avg employment as denominator only;
      flows_* are symmetric across orientations, so we recompute weights
      per focal using the firm-year employment panel.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta            (exported by cba_similarity.do)
  Data/CBA_RAIS_firm_level/cba_rais_firm_2007_2016.dta (firm-year firm_emp)
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv   (pair flows)

Output:
  Data/RAIS_aux/cba_similarity_pretreat_ref_panel.dta
    one row per (untreated firm, cba_period) with non-missing reference;
    columns: identificad, cba_period, cosine, bray_curtis, total_variation, ruzicka
"""

import pandas as pd
import numpy as np
import subprocess
from pathlib import Path

# Paths
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"
rais_firm    = main / "UnionSpill/Data/CBA_RAIS_firm_level"

clauses_path   = rais_aux  / "cba_clauses_by_period.dta"
firm_path      = rais_firm / "cba_rais_firm_2007_2016.dta"
bilateral_path = rais_aux  / "bilateral_connectivity_2007_2011.csv"
output_path    = rais_aux  / "cba_similarity_pretreat_ref_panel.dta"

# ── Load clauses ───────────────────────────────────────────────────────────────
print("Loading clause data...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause variables, {len(clauses):,} observations")

clauses[clause_vars] = clauses[clause_vars].fillna(0)

# Collapse to firm × cba_period
clauses = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()

# ── Per-firm avg employment per year-pair (sample-restricted) ──────────────────
print("Loading firm-year employment panel...", flush=True)
firm = pd.read_stata(
    str(firm_path),
    columns=["identificad", "year", "firm_emp",
             "lagos_sample_avg", "in_balanced_panel", "treat_ultra"],
    convert_categoricals=False,
)
firm = firm[(firm.year.between(2007, 2011)) &
            (firm.lagos_sample_avg == 1) &
            (firm.in_balanced_panel == 1)].copy()
firm["identificad"] = firm["identificad"].astype(str).str.strip().str.zfill(14)

emp = (firm.pivot_table(index="identificad", columns="year",
                        values="firm_emp", aggfunc="first")
            .rename(columns={2007: "e07", 2008: "e08", 2009: "e09",
                             2010: "e10", 2011: "e11"}))
emp["ae0708"] = (emp["e07"] + emp["e08"]) / 2
emp["ae0809"] = (emp["e08"] + emp["e09"]) / 2
emp["ae0910"] = (emp["e09"] + emp["e10"]) / 2
emp["ae1011"] = (emp["e10"] + emp["e11"]) / 2

treat_status = firm.groupby("identificad")["treat_ultra"].max()
print(f"  Sample firms with employment: {len(emp):,}  "
      f"(treated: {(treat_status == 1).sum():,}, "
      f"untreated: {(treat_status == 0).sum():,})", flush=True)

# ── Bilateral pairs: stack both orientations + focal-firm-corrected weights ───
print("Loading bilateral connectivity...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
flow_cols = ["flows_0708", "flows_0809", "flows_0910", "flows_1011"]
b = bilateral[["identificad_i", "identificad_j"] + flow_cols].copy()
b["id_i"] = b["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
b["id_j"] = b["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]

fwd = b.rename(columns={"id_i": "focal", "id_j": "partner"})[["focal", "partner"] + flow_cols]
rev = b.rename(columns={"id_j": "focal", "id_i": "partner"})[["focal", "partner"] + flow_cols]
pairs = pd.concat([fwd, rev], ignore_index=True)
print(f"  {len(pairs):,} (focal, partner) rows after stacking both orientations")

# Restrict focal/partner to lagos+balanced sample
pairs = pairs.merge(
    emp[["ae0708", "ae0809", "ae0910", "ae1011"]],
    left_on="focal", right_index=True, how="inner",
)
pairs = pairs[pairs["partner"].isin(emp.index)].copy()
print(f"  {len(pairs):,} pairs after restricting to sample firms", flush=True)


def safe_div(num, den):
    """flows_t / avg_emp_t, NaN when either is non-positive."""
    num = np.asarray(num, dtype=float)
    den = np.asarray(den, dtype=float)
    return np.where((den > 0) & (num > 0), num / np.maximum(den, 1e-15), np.nan)


pairs["r0708"] = safe_div(pairs["flows_0708"].values, pairs["ae0708"].values)
pairs["r0809"] = safe_div(pairs["flows_0809"].values, pairs["ae0809"].values)
pairs["r0910"] = safe_div(pairs["flows_0910"].values, pairs["ae0910"].values)
pairs["r1011"] = safe_div(pairs["flows_1011"].values, pairs["ae1011"].values)

# Mean across non-missing year-pairs (matches the bilateral_conn_pw convention
# in bilateral_connectivity.m, but with FOCAL firm's avg-emp as denominator).
pairs["weight"] = pairs[["r0708", "r0809", "r0910", "r1011"]].mean(axis=1)
pairs = pairs[(pairs["weight"].notna()) & (pairs["weight"] > 0)][
    ["focal", "partner", "weight"]
].copy()

# Filter: focal untreated, partner treated
pairs = pairs[(pairs["focal"].map(treat_status) == 0) &
              (pairs["partner"].map(treat_status) == 1)].copy()
print(f"  Untreated→treated pairs (orientation-corrected): {len(pairs):,}")
print(f"  Untreated focals with at least one treated partner: "
      f"{pairs['focal'].nunique():,}", flush=True)

# ── Reference clause vector at cba_period == 2 (treated partners) ─────────────
print("Building fixed pre-treatment (cba_period==2) reference vectors...", flush=True)

cl2 = clauses[(clauses["cba_period"] == 2) & (clauses["treat_ultra"] == 1)][
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

print(f"  Reference vectors built for {len(ref):,} untreated focal firms",
      flush=True)

# ── Merge the (constant) reference into the focal firm's per-period clauses ───
untreated = clauses[clauses["treat_ultra"] == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()

merged = untreated.merge(ref, on="identificad", how="left")
ref_available = ~merged[ref_clause_vars].isna().all(axis=1)
print(f"  Untreated firm-period obs with reference: "
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

# ── Save ──────────────────────────────────────────────────────────────────────
result = merged.loc[
    ref_ok,
    ["identificad", "cba_period", "cosine", "bray_curtis", "total_variation", "ruzicka"],
].copy()

print(f"Saving {len(result):,} firm-period observations to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_pretreat_ref_prep done",
     "-d", f"Saved {len(result):,} obs to cba_similarity_pretreat_ref_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
