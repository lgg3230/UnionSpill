"""
cba_similarity_decomp_avg_prep.py

Ordered decomposition of the CBA similarity change, average-reference branch.

For each untreated focal firm i and CBA period t we need three similarity
scores per measure S in {cosine, bray_curtis, total_variation, ruzicka}:

  curr  : S(u_{it}, T_t)    — both sides move (headline avg-ref outcome)
  uref2 : S(u_{it}, T_2)    — focal moves, avg-treated reference frozen at p2
  u2ref : S(u_{i2}, T_t)    — focal frozen at p2, avg-treated reference moves

T_t is the simple unweighted mean of clause vectors across all treated firms
with a CBA at period t. It does not depend on i.

Note on TreatedMove (u2ref) interpretation under the average reference:
T_t is the same for all i, so the conn x post coefficient on S(u_{i2}, T_t)
identifies whether the universal treated drift coincidentally aligns with
high-connectivity firms' period-2 profiles. This is typically near zero by
construction; the column is reported as a sanity check.

Restrictions:
  - Focal must be untreated.
  - For curr: focal must have u_{it} (clauses at period t) and T_t (at least
    one treated firm with a CBA at t).
  - For uref2: needs u_{it} and T_2 (treated firms with CBA at period 2 —
    this is universal across i once it exists at all).
  - For u2ref: needs u_{i2} (focal has CBA at period 2) and T_t.

Final sample = inner-merge of all three score panels on (identificad, cba_period).

Input:
  Data/RAIS_aux/cba_clauses_by_period.dta  (exported by cba_similarity_avg.do)

Output:
  Data/RAIS_aux/cba_similarity_decomp_avg_panel.dta
      one row per (untreated firm, cba_period) with all three scores
      non-missing for all four measures; 12 similarity columns + IDs.
"""

from pathlib import Path
import subprocess

import numpy as np
import pandas as pd

main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"

clauses_path = rais_aux / "cba_clauses_by_period.dta"
output_path  = rais_aux / "cba_similarity_decomp_avg_panel.dta"

MEASURES = ["cosine", "bray_curtis", "total_variation", "ruzicka"]


def compute_similarities(X: np.ndarray, Y_raw: np.ndarray) -> dict:
    """Vectorized cosine, BC, TV, Ruzicka between rows of X and Y. NaN-aware."""
    ref_ok = ~np.isnan(Y_raw).all(axis=1)
    Y = np.where(np.isnan(Y_raw), 0.0, Y_raw)

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

    return dict(cosine=cosine, bray_curtis=bray_curtis,
                total_variation=total_variation, ruzicka=ruzicka)


# ── Load clause data ──────────────────────────────────────────────────────────
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

n_treated   = clauses.loc[clauses.treat_ultra == 1, "identificad"].nunique()
n_untreated = clauses.loc[clauses.treat_ultra == 0, "identificad"].nunique()
print(f"  Treated firms: {n_treated:,}  |  Untreated firms: {n_untreated:,}")

# ── Build T_t (avg over treated firms per period) and T_2 (period 2 only) ────
print("Computing avg-treated reference per period...", flush=True)
treated = clauses[clauses.treat_ultra == 1]
T_t = treated.groupby("cba_period")[clause_vars].mean().reset_index()
ref_cols = [f"ref_{c}" for c in clause_vars]
T_t.columns = ["cba_period"] + ref_cols

T_2 = T_t.loc[T_t.cba_period == 2, ref_cols].copy()
if T_2.empty:
    raise RuntimeError("No treated firms with a CBA at cba_period == 2.")
T_2_vec = T_2.iloc[0].values.astype(float)
print(f"  T_2 built from {len(treated[treated.cba_period == 2]):,} treated firms",
      flush=True)

# ── Build focal panels: u_{it} and u_{i2} ────────────────────────────────────
untreated = clauses[clauses.treat_ultra == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()

u_p2 = (
    clauses.loc[(clauses.treat_ultra == 0) & (clauses.cba_period == 2),
                ["identificad"] + clause_vars]
    .rename(columns={c: f"u2_{c}" for c in clause_vars})
)
print(f"  Untreated firms with a CBA at period 2: {len(u_p2):,}", flush=True)

# ── Score 1: curr = S(u_{it}, T_t) ───────────────────────────────────────────
print("Computing curr = S(u_t, T_t)...", flush=True)
panel = untreated.merge(T_t, on="cba_period", how="left")
X = panel[clause_vars].values.astype(float)
Y = panel[ref_cols].values.astype(float)
out = compute_similarities(X, Y)
for m in MEASURES:
    panel[f"{m}_curr"] = out[m]
curr_valid = ~np.isnan(out["cosine"])
print(f"  curr valid rows: {int(curr_valid.sum()):,} / {len(panel):,}", flush=True)

# ── Score 2: uref2 = S(u_{it}, T_2) ──────────────────────────────────────────
print("Computing uref2 = S(u_t, T_2)...", flush=True)
# T_2 broadcast across rows
Y2 = np.tile(T_2_vec, (len(panel), 1))
out2 = compute_similarities(X, Y2)
for m in MEASURES:
    panel[f"{m}_uref2"] = out2[m]
uref2_valid = ~np.isnan(out2["cosine"])
print(f"  uref2 valid rows: {int(uref2_valid.sum()):,} / {len(panel):,}", flush=True)

# ── Score 3: u2ref = S(u_{i2}, T_t) ──────────────────────────────────────────
print("Computing u2ref = S(u_2, T_t)...", flush=True)
panel = panel.merge(u_p2, on="identificad", how="left")
u2_cols = [f"u2_{c}" for c in clause_vars]
X2 = panel[u2_cols].values.astype(float)
u2_avail = ~np.isnan(X2).all(axis=1)
X2 = np.where(np.isnan(X2), 0.0, X2)
Y3 = panel[ref_cols].values.astype(float)
out3 = compute_similarities(X2, Y3)
for m in MEASURES:
    vals = np.where(u2_avail, out3[m], np.nan)
    panel[f"{m}_u2ref"] = vals
print(f"  u2ref valid rows (u_2 available): {int(u2_avail.sum()):,} / "
      f"{len(panel):,}", flush=True)

# ── Keep only rows with all three score sets non-missing ─────────────────────
sim_cols = [f"{m}_{s}" for s in ("curr", "uref2", "u2ref") for m in MEASURES]
result = panel[["identificad", "cba_period"] + sim_cols].copy()
all_avail = result[sim_cols].notna().all(axis=1)
print(f"\nRows with all 12 similarity scores non-missing: "
      f"{int(all_avail.sum()):,} / {len(result):,}", flush=True)
result = result.loc[all_avail].copy()

# Diagnostics by period
print("\nFirm-period counts by cba_period (final sample):")
for p, n in result["cba_period"].value_counts().sort_index().items():
    print(f"  cba_period {int(p)}: {int(n):,}")

print(f"\nSaving {len(result):,} firm-period observations to {output_path}",
      flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_decomp_avg_prep done",
     "-d", f"Saved {len(result):,} obs to cba_similarity_decomp_avg_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
