"""
cba_similarity_prep.py
Computes CBA content similarity between an untreated firm (per cba_period) and
FIVE different reference CBA vectors. The output gives 4 similarity measures
(cosine, bray_curtis, total_variation, ruzicka) for each reference, so the user
can run downstream exercises against any of them.

Reference vectors:
  A. Per-period flow-weighted average of connected treated firms' CBAs
     (varies with the focal firm's cba_period). Existing behaviour.
  B. Flow-weighted average of connected treated firms' CBAs FIXED at
     cba_period == 2 (last pre-Sumula CBA period).
  C. Equal-weighted mean of Ref A vectors at cba_period == 1 and == 2
     (fixed pre-treatment "treated" reference).
  D. Focal firm's OWN CBA at cba_period == 2 (fixed self reference).
  E. Equal-weighted mean of the focal firm's OWN CBAs at cba_periods 1 and 2
     (fixed pre-treatment self reference).

Notes:
  * All sample firms are required to have CBAs in periods 1 and 2 — Ref C, D, E
    therefore expect both pre-period observations to exist for the focal firm.
    Treated partners contribute to Ref A/B/C only for the periods in which they
    have a CBA (no fabrication of zeros at the partner level).
  * Ref B = (Ref A row at cba_period == 2), broadcast to every focal × period.
  * Ref C = equal-weighted average of (Ref A at p1) and (Ref A at p2). This
    matches "avg of two ref vectors" semantics — partners are NOT pooled
    across periods 1 and 2.
  * Connectivity weight is bilateral_conn_pw (same as the original Ref A).

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv

Outputs:
  Data/RAIS_aux/cba_similarity_panel.dta
      Backward-compat: bare-name columns cosine, bray_curtis, total_variation,
      ruzicka (= Ref A's similarities). One row per (untreated firm, cba_period)
      with a non-missing Ref A vector.
  Data/RAIS_aux/cba_similarity_panel_multi_ref.dta
      One row per (untreated firm, cba_period). Twenty similarity columns:
        <measure>_treat_t   (Ref A)   <measure>_treat_p2  (Ref B)
        <measure>_treat_p12 (Ref C)   <measure>_self_p2   (Ref D)
        <measure>_self_p12  (Ref E)
      where <measure> ∈ {cosine, bray_curtis, total_variation, ruzicka}.
      Plus an availability flag for each reference: ref_<X>_avail ∈ {0, 1}.
"""

import pandas as pd
import numpy as np
import duckdb
import subprocess
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
main     = Path("/kellogg/proj/lgg3230")
rais_aux = main / "UnionSpill/Data/RAIS_aux"

clauses_path   = rais_aux / "cba_clauses_by_period.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"

output_path_legacy = rais_aux / "cba_similarity_panel.dta"
output_path_multi  = rais_aux / "cba_similarity_panel_multi_ref.dta"

# ── Load clause data ──────────────────────────────────────────────────────────
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

treated_ids   = set(clauses.loc[clauses.treat_ultra == 1, "identificad"])
untreated_ids = set(clauses.loc[clauses.treat_ultra == 0, "identificad"])
print(f"  Treated firms: {len(treated_ids):,}  |  Untreated firms: {len(untreated_ids):,}")

# ── Load bilateral connectivity ───────────────────────────────────────────────
print("Loading bilateral connectivity...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]

bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()
print(f"  {len(bilateral):,} bilateral pairs with positive weight")

# ── (untreated firm i) → (treated firm j) directed pairs ──────────────────────
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

# ── Ref A: per-period flow-weighted avg of connected treated CBAs ─────────────
print("Computing Ref A (per-period treated weighted avg)...", flush=True)

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

ref_a_long = con.execute(f"""
    SELECT
        b.firm_i       AS identificad,
        t.cba_period,
        {clause_agg_sql}
    FROM bilateral_ut b
    JOIN treated_clauses t ON b.firm_j = t.firm_j
    GROUP BY b.firm_i, t.cba_period
""").fetch_arrow_table().to_pandas()

ref_clause_vars = [f"ref_{c}" for c in clause_vars]  # column names produced by SQL
print(f"  Ref A rows: {len(ref_a_long):,}  "
      f"({ref_a_long['identificad'].nunique():,} unique focal firms)", flush=True)

# ── Ref B: Ref A's vector at cba_period == 2, broadcast across all periods ────
print("Building Ref B (treated weighted avg, fixed at p2)...", flush=True)
ref_b = (
    ref_a_long.loc[ref_a_long.cba_period == 2, ["identificad"] + ref_clause_vars]
    .rename(columns={f"ref_{c}": f"refB_{c}" for c in clause_vars})
    .reset_index(drop=True)
)
print(f"  Ref B rows: {len(ref_b):,}")

# ── Ref C: equal-weighted mean of Ref A at p1 and p2 ──────────────────────────
print("Building Ref C (treated weighted avg, mean of p1 & p2)...", flush=True)
ref_a_p1 = (
    ref_a_long.loc[ref_a_long.cba_period == 1, ["identificad"] + ref_clause_vars]
    .set_index("identificad")
)
ref_a_p2 = (
    ref_a_long.loc[ref_a_long.cba_period == 2, ["identificad"] + ref_clause_vars]
    .set_index("identificad")
)
common_c = ref_a_p1.index.intersection(ref_a_p2.index)
ref_c = ((ref_a_p1.loc[common_c] + ref_a_p2.loc[common_c]) / 2.0).reset_index()
ref_c.columns = ["identificad"] + [f"refC_{c}" for c in clause_vars]
print(f"  Ref C rows: {len(ref_c):,}  "
      f"(focal firms with Ref A at both p1 and p2)", flush=True)

# ── Ref D: focal firm's own clause vector at cba_period == 2 ──────────────────
print("Building Ref D (focal own p2 self)...", flush=True)
ref_d = (
    clauses.loc[(clauses.treat_ultra == 0) & (clauses.cba_period == 2),
                ["identificad"] + clause_vars]
    .rename(columns={c: f"refD_{c}" for c in clause_vars})
    .reset_index(drop=True)
)
print(f"  Ref D rows: {len(ref_d):,}")

# ── Ref E: focal firm's own avg of cba_periods 1 and 2 ────────────────────────
print("Building Ref E (focal own avg p1 & p2)...", flush=True)
self_p1 = (
    clauses.loc[(clauses.treat_ultra == 0) & (clauses.cba_period == 1),
                ["identificad"] + clause_vars]
    .set_index("identificad")
)
self_p2 = (
    clauses.loc[(clauses.treat_ultra == 0) & (clauses.cba_period == 2),
                ["identificad"] + clause_vars]
    .set_index("identificad")
)
common_e = self_p1.index.intersection(self_p2.index)
ref_e = ((self_p1.loc[common_e] + self_p2.loc[common_e]) / 2.0).reset_index()
ref_e.columns = ["identificad"] + [f"refE_{c}" for c in clause_vars]
print(f"  Ref E rows: {len(ref_e):,}", flush=True)

# ── Build the focal panel (X = focal firm's own clause vector at row's period) ─
print("Building focal panel and merging all references...", flush=True)
panel = clauses.loc[clauses.treat_ultra == 0,
                    ["identificad", "cba_period"] + clause_vars].copy()

# Ref A varies with cba_period
ref_a_for_merge = ref_a_long.rename(
    columns={f"ref_{c}": f"refA_{c}" for c in clause_vars}
)
panel = panel.merge(ref_a_for_merge, on=["identificad", "cba_period"], how="left")

# Ref B/C/D/E are firm-level constants (broadcast across cba_period)
for ref_df in (ref_b, ref_c, ref_d, ref_e):
    panel = panel.merge(ref_df, on="identificad", how="left")

print(f"  Panel rows: {len(panel):,}  "
      f"({panel['identificad'].nunique():,} unique focal firms)", flush=True)

# ── Similarity helper ─────────────────────────────────────────────────────────
def compute_similarities(X: np.ndarray, Y_raw: np.ndarray, suffix: str) -> dict:
    """
    Compute cosine, bray_curtis, total_variation, ruzicka between focal vectors X
    and reference vectors Y_raw. NaN rows in Y are treated as 'reference missing'
    and produce NaN for all four measures.

    Returns: dict of column-name -> 1d np.ndarray.
    """
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

    return {
        f"cosine_{suffix}":          cosine,
        f"bray_curtis_{suffix}":     bray_curtis,
        f"total_variation_{suffix}": total_variation,
        f"ruzicka_{suffix}":         ruzicka,
        f"ref_{suffix}_avail":       ref_ok.astype("int8"),
    }

# ── Compute all 5 × 4 similarity columns ──────────────────────────────────────
print("Computing similarity measures...", flush=True)
X = panel[clause_vars].values.astype(float)

ref_specs = [
    ("treat_t",   "refA_"),
    ("treat_p2",  "refB_"),
    ("treat_p12", "refC_"),
    ("self_p2",   "refD_"),
    ("self_p12",  "refE_"),
]

for suffix, prefix in ref_specs:
    Y_cols = [f"{prefix}{c}" for c in clause_vars]
    Y_raw  = panel[Y_cols].values.astype(float)
    out    = compute_similarities(X, Y_raw, suffix)
    for k, v in out.items():
        panel[k] = v
    n_avail = int(out[f"ref_{suffix}_avail"].sum())
    print(f"  Ref {suffix:<10}  available rows: {n_avail:,} / {len(panel):,}",
          flush=True)

# ── Multi-ref output ──────────────────────────────────────────────────────────
sim_measures = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
sim_cols = [f"{m}_{s}" for s, _ in ref_specs for m in sim_measures]
avail_cols = [f"ref_{s}_avail" for s, _ in ref_specs]

multi_out = panel[
    ["identificad", "cba_period"] + sim_cols + avail_cols
].copy()

# Drop rows with no reference available at all (all 5 missing)
keep = (multi_out[avail_cols].sum(axis=1) > 0)
multi_out = multi_out.loc[keep].copy()
print(f"\nMulti-ref panel: {len(multi_out):,} rows  "
      f"({multi_out['identificad'].nunique():,} firms)", flush=True)
print(f"Saving multi-ref panel to {output_path_multi}", flush=True)
multi_out.to_stata(str(output_path_multi), write_index=False, version=118)

# ── Backward-compat output (Ref A only, bare names) ───────────────────────────
legacy = panel.loc[
    panel["ref_treat_t_avail"] == 1,
    ["identificad", "cba_period",
     "cosine_treat_t", "bray_curtis_treat_t",
     "total_variation_treat_t", "ruzicka_treat_t"],
].rename(columns={
    "cosine_treat_t":          "cosine",
    "bray_curtis_treat_t":     "bray_curtis",
    "total_variation_treat_t": "total_variation",
    "ruzicka_treat_t":         "ruzicka",
})
print(f"Saving legacy Ref-A panel ({len(legacy):,} rows) to {output_path_legacy}",
      flush=True)
legacy.to_stata(str(output_path_legacy), write_index=False, version=118)

print("Done.", flush=True)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_prep done",
     "-d", (f"Multi-ref: {len(multi_out):,} rows. "
            f"Legacy Ref-A: {len(legacy):,} rows."),
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
