"""
cba_dotprod_decomposition_prep.py

Bilinear A/B/C/cross decomposition with pretrend-aware reference.

Outcomes (computed once for raw clauses u, T and once for shares s_u, s_T):
    y_A     = u_t  dot T_t
    y_B     = u_bar dot T_t                  (focal anchored at pre-avg)
    y_C     = u_t  dot T_bar                 (partner anchored at pre-avg)
    y_cross = (u_t - u_bar) dot (T_t - T_bar)

where the anchors are firm-specific pre-treatment averages:
    u_bar_i = mean(u_{i, t in {1,2}}, ignoring missing)
    T_bar_i = mean(T_{i, t in {1,2}}, ignoring missing)

For shares: averaging is over the share vectors themselves
(not shares of averaged counts).

Bilinearity + firm FE means that, in the regression of each outcome on
(connectivity x post + FE), the identity
    beta_A = beta_B + beta_C + beta_cross
holds exactly (machine precision). u_bar . T_bar is firm-specific and
absorbed by establishment FE.

Inputs:
  Data/RAIS_aux/cba_clauses_by_period.dta
  Data/RAIS_aux/bilateral_connectivity_2007_2011.csv
  Data/RAIS_aux/cba_similarity_panel.dta            (sample-key for inner-merge)

Output:
  Data/RAIS_aux/cba_dotprod_decomposition_panel.dta
    cols: identificad, cba_period,
          dot_raw_A, dot_raw_B, dot_raw_C, dot_raw_cross,
          dot_shares_A, dot_shares_B, dot_shares_C, dot_shares_cross
"""

import subprocess
from pathlib import Path

import numpy as np
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
main         = Path("/kellogg/proj/lgg3230")
rais_aux     = main / "UnionSpill/Data/RAIS_aux"

clauses_path   = rais_aux / "cba_clauses_by_period.dta"
bilateral_path = rais_aux / "bilateral_connectivity_2007_2011.csv"
sample_path    = rais_aux / "cba_similarity_panel.dta"
output_path    = rais_aux / "cba_dotprod_decomposition_panel.dta"

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
print(f"  Treated firms: {len(treated_ids):,}  |  "
      f"Untreated firms: {len(untreated_ids):,}")

# ── Bilateral pairs (uncorrected weights, same as Exercises A/B/C) ────────────
print("Loading bilateral connectivity (uncorrected weights)...", flush=True)
bilateral = pd.read_csv(str(bilateral_path))
bilateral["id_i"] = bilateral["identificad_i"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["id_j"] = bilateral["identificad_j"].astype("int64").astype(str).str.zfill(15).str[1:]
bilateral["weight"] = pd.to_numeric(bilateral["bilateral_conn_pw"], errors="coerce").fillna(0)
bilateral = bilateral[bilateral["weight"] > 0][["id_i", "id_j", "weight"]].copy()
print(f"  {len(bilateral):,} bilateral pairs with positive weight")

fwd = bilateral[
    bilateral["id_i"].isin(untreated_ids) & bilateral["id_j"].isin(treated_ids)
].rename(columns={"id_i": "focal", "id_j": "partner"})
rev = bilateral[
    bilateral["id_j"].isin(untreated_ids) & bilateral["id_i"].isin(treated_ids)
].rename(columns={"id_j": "focal", "id_i": "partner"})
pairs = pd.concat([fwd, rev], ignore_index=True).drop_duplicates(
    subset=["focal", "partner"]
)[["focal", "partner", "weight"]]
print(f"  Untreated-to-treated pairs: {len(pairs):,}", flush=True)
print(f"  Untreated focals with >=1 treated partner: "
      f"{pairs['focal'].nunique():,}", flush=True)

# ── Build moving partner reference T_{i,t} per (focal, period) ────────────────
# T_{i,t} = sum_k w_{ik} * x_{k,t} / sum_k w_{ik}, k partners with CBA at t.
print("Building per-period treated reference vectors T_{i,t}...", flush=True)

treated_clauses = clauses[clauses["treat_ultra"] == 1][
    ["identificad", "cba_period"] + clause_vars
].rename(columns={"identificad": "partner"})

merged_pairs = pairs.merge(treated_clauses, on="partner", how="inner")
print(f"  (focal, partner, period) triples: {len(merged_pairs):,}", flush=True)

w_totals = (merged_pairs.groupby(["focal", "cba_period"])["weight"]
            .sum().reset_index().rename(columns={"weight": "w_total"}))

weighted = merged_pairs[clause_vars].multiply(merged_pairs["weight"], axis=0)
weighted["focal"]      = merged_pairs["focal"].values
weighted["cba_period"] = merged_pairs["cba_period"].values
T_ref = weighted.groupby(["focal", "cba_period"]).sum().reset_index()
T_ref = T_ref.merge(w_totals, on=["focal", "cba_period"], how="inner")
for c in clause_vars:
    T_ref[c] = T_ref[c] / T_ref["w_total"]
T_ref = T_ref.drop(columns=["w_total"])
T_ref = T_ref.rename(columns={"focal": "identificad"})
print(f"  Per-(focal, period) T_{{i,t}} rows: {len(T_ref):,}", flush=True)

# ── Build focal vector u_{i,t} for untreated only ─────────────────────────────
u_panel = clauses[clauses["treat_ultra"] == 0][
    ["identificad", "cba_period"] + clause_vars
].copy()
print(f"  Untreated focal (i, t) rows: {len(u_panel):,}", flush=True)

# ── Pre-treatment averages u_bar_i, T_bar_i ───────────────────────────────────
# Average over t in {1, 2}, ignoring missing periods (so a firm with only
# period-1 or only period-2 still gets a reference).
print("Computing pre-treatment-average anchors u_bar_i, T_bar_i...", flush=True)
u_pre = u_panel[u_panel["cba_period"].isin([1, 2])]
u_bar = u_pre.groupby("identificad")[clause_vars].mean().reset_index()
u_bar = u_bar.rename(columns={c: f"ubar_{c}" for c in clause_vars})
print(f"  u_bar built for {len(u_bar):,} untreated firms", flush=True)

T_pre = T_ref[T_ref["cba_period"].isin([1, 2])]
T_bar = T_pre.groupby("identificad")[clause_vars].mean().reset_index()
T_bar = T_bar.rename(columns={c: f"Tbar_{c}" for c in clause_vars})
print(f"  T_bar built for {len(T_bar):,} untreated focals", flush=True)

# Diagnostics: how many firms have only period 1, only period 2, both
u_per_count = u_pre.groupby("identificad")["cba_period"].nunique()
print(f"  Untreated focals with both p1 and p2 clauses: "
      f"{(u_per_count == 2).sum():,}", flush=True)
print(f"  Only p1: {(u_per_count == 1).sum():,}", flush=True)
T_per_count = T_pre.groupby("identificad")["cba_period"].nunique()
print(f"  Focals with both p1 and p2 partner refs: "
      f"{(T_per_count == 2).sum():,}", flush=True)
print(f"  Only one pre-period partner ref: {(T_per_count == 1).sum():,}", flush=True)

# ── Cross-join u_panel x T_ref, inner with anchors ────────────────────────────
# We want, per (focal i, period t), to attach both u_t and T_t and the anchors.
print("Merging u_panel + T_ref + anchors...", flush=True)
ut = u_panel.rename(columns={c: f"u_{c}" for c in clause_vars})
Tt = T_ref.rename(columns={c: f"T_{c}" for c in clause_vars})
m = ut.merge(Tt, on=["identificad", "cba_period"], how="inner")
m = m.merge(u_bar, on="identificad", how="inner")
m = m.merge(T_bar, on="identificad", how="inner")
print(f"  (i, t) rows with u_t, T_t, u_bar, T_bar all present: {len(m):,}",
      flush=True)

# ── Build raw outcomes ────────────────────────────────────────────────────────
U  = m[[f"u_{c}"     for c in clause_vars]].values.astype(float)   # u_{i,t}
TM = m[[f"T_{c}"     for c in clause_vars]].values.astype(float)   # T_{i,t}
Ub = m[[f"ubar_{c}"  for c in clause_vars]].values.astype(float)   # u_bar_i
Tb = m[[f"Tbar_{c}"  for c in clause_vars]].values.astype(float)   # T_bar_i

dot_raw_A     = (U  * TM).sum(axis=1)             # u_t . T_t
dot_raw_B     = (Ub * TM).sum(axis=1)             # u_bar . T_t
dot_raw_C     = (U  * Tb).sum(axis=1)             # u_t . T_bar
dot_raw_cross = ((U - Ub) * (TM - Tb)).sum(axis=1)
dot_raw_anchor = (Ub * Tb).sum(axis=1)            # u_bar . T_bar (FE-absorbed)

# Algebraic check (per row): A = anchor + B-anchor + C-anchor + cross
# i.e., A = B + C - anchor + cross
identity_resid_raw = dot_raw_A - (dot_raw_B + dot_raw_C - dot_raw_anchor + dot_raw_cross)
print(f"  raw per-row identity max |resid|: "
      f"{np.abs(identity_resid_raw).max():.3e}", flush=True)

# ── Build shares outcomes ─────────────────────────────────────────────────────
# Per-row total counts for u_t, T_t; per-firm pre-avg totals separately for u_bar, T_bar.
def shares(arr):
    tot = arr.sum(axis=1, keepdims=True)
    with np.errstate(divide="ignore", invalid="ignore"):
        s = np.where(tot > 0, arr / np.maximum(tot, 1e-15), 0.0)
    return s

# For u_bar and T_bar in shares form, average the SHARES of periods 1 and 2,
# not the shares of the averaged counts. So rebuild from u_panel and T_ref.
print("Building share-average anchors s_u_bar, s_T_bar...", flush=True)

u_pre_arr = u_pre[clause_vars].values.astype(float)
u_pre_shares = shares(u_pre_arr)
u_pre_shares_df = pd.DataFrame(u_pre_shares, columns=clause_vars)
u_pre_shares_df["identificad"] = u_pre["identificad"].values
s_u_bar = u_pre_shares_df.groupby("identificad")[clause_vars].mean().reset_index()
s_u_bar = s_u_bar.rename(columns={c: f"subar_{c}" for c in clause_vars})

T_pre_arr = T_pre[clause_vars].values.astype(float)
T_pre_shares = shares(T_pre_arr)
T_pre_shares_df = pd.DataFrame(T_pre_shares, columns=clause_vars)
T_pre_shares_df["identificad"] = T_pre["identificad"].values
s_T_bar = T_pre_shares_df.groupby("identificad")[clause_vars].mean().reset_index()
s_T_bar = s_T_bar.rename(columns={c: f"sTbar_{c}" for c in clause_vars})

# Attach share-anchors to merged panel
m = m.merge(s_u_bar, on="identificad", how="inner")
m = m.merge(s_T_bar, on="identificad", how="inner")
print(f"  (i, t) rows after share-anchor merge: {len(m):,}", flush=True)

# Recompute U, TM, Ub, Tb to align with possibly-shrunk index
U  = m[[f"u_{c}"     for c in clause_vars]].values.astype(float)
TM = m[[f"T_{c}"     for c in clause_vars]].values.astype(float)
sUb = m[[f"subar_{c}" for c in clause_vars]].values.astype(float)
sTb = m[[f"sTbar_{c}" for c in clause_vars]].values.astype(float)

sU  = shares(U)
sTM = shares(TM)

dot_shares_A     = (sU  * sTM).sum(axis=1)
dot_shares_B     = (sUb * sTM).sum(axis=1)
dot_shares_C     = (sU  * sTb).sum(axis=1)
dot_shares_cross = ((sU - sUb) * (sTM - sTb)).sum(axis=1)
dot_shares_anchor = (sUb * sTb).sum(axis=1)

identity_resid_sh = dot_shares_A - (dot_shares_B + dot_shares_C - dot_shares_anchor + dot_shares_cross)
print(f"  shares per-row identity max |resid|: "
      f"{np.abs(identity_resid_sh).max():.3e}", flush=True)

# ── Assemble output panel ─────────────────────────────────────────────────────
# Recompute the raw outcomes from the now-aligned U, TM, Ub, Tb (post share-merge)
Ub = m[[f"ubar_{c}"  for c in clause_vars]].values.astype(float)
Tb = m[[f"Tbar_{c}"  for c in clause_vars]].values.astype(float)
dot_raw_A     = (U  * TM).sum(axis=1)
dot_raw_B     = (Ub * TM).sum(axis=1)
dot_raw_C     = (U  * Tb).sum(axis=1)
dot_raw_cross = ((U - Ub) * (TM - Tb)).sum(axis=1)
dot_raw_anchor = (Ub * Tb).sum(axis=1)

result = pd.DataFrame({
    "identificad":       m["identificad"].values,
    "cba_period":        m["cba_period"].values,
    "dot_raw_A":         dot_raw_A,
    "dot_raw_B":         dot_raw_B,
    "dot_raw_C":         dot_raw_C,
    "dot_raw_cross":     dot_raw_cross,
    "dot_raw_anchor":    dot_raw_anchor,
    "dot_shares_A":      dot_shares_A,
    "dot_shares_B":      dot_shares_B,
    "dot_shares_C":      dot_shares_C,
    "dot_shares_cross":  dot_shares_cross,
    "dot_shares_anchor": dot_shares_anchor,
})

# ── Cosine with pretrend-corrected anchors ────────────────────────────────────
# cos_A = cos(u_t, T_t); cos_B = cos(u_bar, T_t); cos_C = cos(u_t, T_bar).
# These are NOT bilinear, so we get no exact A = B + C + cross identity.
# Reported alongside the bilinear results to allow comparison against the
# previously-reported cosine A/B/C exercises (which used period-2 anchors).
print("Computing cosine outcomes (pretrend-corrected anchors)...", flush=True)

def cos(X, Y):
    nx = np.linalg.norm(X, axis=1)
    ny = np.linalg.norm(Y, axis=1)
    denom = np.maximum(nx * ny, 1e-15)
    return np.where((nx > 0) & (ny > 0), (X * Y).sum(axis=1) / denom, 0.0)

result["cos_A"] = cos(U,  TM)
result["cos_B"] = cos(Ub, TM)
result["cos_C"] = cos(U,  Tb)
print(f"  cos_A range: [{result['cos_A'].min():.4f}, {result['cos_A'].max():.4f}]",
      flush=True)

# ── Ruzicka (weighted Jaccard) with pretrend-corrected anchors ────────────────
# ruz(u, T) = sum_k min(u_k, T_k) / sum_k max(u_k, T_k).
# Magnitude-sensitive: a firm with 100 clauses vs 10 has small Ruzicka with a
# similar-shape but 10x smaller partner, while cosine would still be ~1.
# Stricter than Bray-Curtis (uses max in denominator, not sum). Non-linear, so
# no exact identity.
print("Computing Ruzicka outcomes (pretrend-corrected anchors)...", flush=True)

def ruz(X, Y):
    mins = np.minimum(X, Y).sum(axis=1)
    maxs = np.maximum(X, Y).sum(axis=1)
    denom = np.maximum(maxs, 1e-15)
    return np.where(maxs > 0, mins / denom, 0.0)

result["ruz_A"] = ruz(U,  TM)
result["ruz_B"] = ruz(Ub, TM)
result["ruz_C"] = ruz(U,  Tb)
print(f"  ruz_A range: [{result['ruz_A'].min():.4f}, {result['ruz_A'].max():.4f}]",
      flush=True)

# ── Inner-merge with cba_similarity_panel sample ──────────────────────────────
print("Inner-merging with cba_similarity_panel.dta on (identificad, cba_period)...",
      flush=True)
sample_keys = pd.read_stata(str(sample_path),
                            columns=["identificad", "cba_period"],
                            convert_categoricals=False)
sample_keys["identificad"] = (sample_keys["identificad"].astype(str)
                              .str.strip().str.zfill(14))
sample_keys = sample_keys.drop_duplicates(subset=["identificad", "cba_period"])

n_before = len(result)
result = result.merge(sample_keys, on=["identificad", "cba_period"], how="inner")
print(f"  Firm-period obs: {n_before:,} -> {len(result):,} after sample-merge",
      flush=True)

# ── Period-2 sanity ───────────────────────────────────────────────────────────
# At t=2: u_t = u_2 and T_t = T_2. u_bar is the avg of periods 1 and 2.
# If a firm has BOTH p1 and p2, then u_bar = (u_1 + u_2)/2, and (u_t - u_bar) =
# (u_2 - u_bar) = (u_2 - u_1)/2, which is NOT zero in general. So cross at p2
# is not zero by construction (unlike the focal_frozen setup where u_bar = u_2).
# That's the whole point.
for c in ["dot_raw_A", "dot_shares_A", "dot_raw_cross", "dot_shares_cross"]:
    p2_mean = result.loc[result["cba_period"] == 2, c].mean()
    print(f"  Period-2 mean {c}: {p2_mean:.6f}", flush=True)

# ── Save ──────────────────────────────────────────────────────────────────────
print(f"Saving {len(result):,} firm-period obs to {output_path}", flush=True)
result.to_stata(str(output_path), write_index=False, version=118)

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_dotprod_decomposition_prep done",
     "-d", f"Saved {len(result):,} obs",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
