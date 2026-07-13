#!/usr/bin/env python
"""
Expected exposure mu_i = E_r[ regressor_i ] under the treated-set reshuffle, for
four stratification schemes that reproduce the treatment-assignment logic
(industry and negotiation month, plus geography at two granularities):

  unstrat            no strata
  ind_month          industry x negotiation month
  ind_month_region   industry x month x region (1st digit of municipio, macro-region)
  ind_month_micro    industry x month x microregion   (finest / base)

Because the regressor is linear in the treated set, the average across
permutations is closed form: mu_i^C = (1/p90) sum_j W_ij pi_j (spillover),
mu_i^D = pi_i (direct), with pi_j the within-stratum treated share. Validated
against a small Monte-Carlo average.

Output: Data/rand_inference/expected_exposure.dta / .csv  (mu_C_*, mu_D_*)
        Data/rand_inference/expected_exposure_meta.json    (swappable counts)
"""
import numpy as np, pandas as pd, json
from pathlib import Path
from scipy import sparse

OUT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference")
SCHEMES = ["unstrat", "ind_month", "ind_month_region", "ind_month_micro"]

frame = pd.read_stata(OUT / "spill_frame.dta")
p90 = float(frame.loc[frame.treat_ultra == 0, "totaltreat_pw_n_p90"].iloc[0])
inv = frame.groupby("identificad").agg(
    treat_ultra=("treat_ultra", "first"), totaltreat_pw_n=("totaltreat_pw_n", "first"))

# ── permutation universe + strata keys ───────────────────────────────────────
K = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})
reg = pd.read_csv(OUT / "firm_region.csv", dtype={"identificad": str})
K = K.merge(reg, on="identificad", how="left")
_istr = K.industry1.astype("Int64").astype(str)
K["ind2"]   = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)
K["mbm"]    = K.mode_base_month.astype("category").cat.codes
K["micro"]  = K.microregion.astype(int)
K["region"] = K.region.fillna(-1).astype(int)
SCH = {"unstrat": [], "ind_month": ["ind2", "mbm"],
       "ind_month_region": ["ind2", "mbm", "region"],
       "ind_month_micro": ["ind2", "mbm", "micro"]}
col_id = K.identificad.values; NC = len(col_id); col_ix = {f: k for k, f in enumerate(col_id)}
treated = (K.treat_ultra.values == 1); bal = (K.in_balanced_panel.values == 1)

# spillover estimation firms (untreated) + W (rows=untreated, cols=all lagos)
sp_firms = inv.index[inv.treat_ultra == 0].tolist()
sp_ix = {f: k for k, f in enumerate(sp_firms)}; NF = len(sp_firms)
W = pd.read_parquet(OUT / "flow_weights.parquet")
w = W[W.i.isin(sp_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(sp_ix).values, w.j.map(col_ix).values)), shape=(NF, NC))
panelA = inv.index[(inv.treat_ultra == 1) | ((inv.treat_ultra == 0) & (inv.totaltreat_pw_n == 0))].tolist()
inA = np.array([f in set(panelA) for f in col_id])

def stratum_share(mask_rows, sc):
    K["stratum"] = (K[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes if sc else 0)
    pi = treated.astype(float).copy()
    share = K[mask_rows].groupby("stratum")["treat_ultra"].transform(lambda s: (s == 1).mean()).values
    pi[np.where(mask_rows)[0]] = share
    return pi

def swap_count(mask_rows, sc):
    K["stratum"] = (K[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes if sc else 0)
    g = K[mask_rows].groupby("stratum")["treat_ultra"].agg(nt=lambda s: (s == 1).sum(), n="size")
    return int(g[(g.nt > 0) & (g.nt < g.n)].nt.sum())

mu = pd.DataFrame(index=inv.index); meta = {}
for scheme in SCHEMES:
    sc = SCH[scheme]
    mu.loc[sp_firms, f"mu_C_{scheme}"] = pd.Series(Wm.dot(stratum_share(bal, sc)) / p90, index=sp_firms)
    pi_dir = stratum_share(inA, sc)
    mu.loc[panelA, f"mu_D_{scheme}"] = pd.Series(pi_dir[[col_ix[f] for f in panelA]], index=panelA)
    meta[scheme] = dict(swap_spillover=swap_count(bal, sc), swap_direct=swap_count(inA, sc))

# validate mu_C (ind_month) vs Monte-Carlo
sc = SCH["ind_month"]; K["stratum"] = K[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes
fixed = np.where(treated & ~bal)[0]; mixed = []; fixed_parts = [fixed]
for s, g in K[bal].groupby("stratum"):
    idx = g.index.values; nt = int(treated[idx].sum())
    if nt == 0: continue
    (fixed_parts.append(idx) if nt == len(idx) else mixed.append((idx, nt)))
fixed_cols = np.concatenate(fixed_parts); rng = np.random.default_rng(1); acc = np.zeros(NF)
for _ in range(1000):
    S = np.zeros(NC); S[fixed_cols] = 1.0
    for idx, nt in mixed: S[rng.choice(idx, size=nt, replace=False)] = 1.0
    acc += Wm.dot(S) / p90
an = mu.loc[sp_firms, "mu_C_ind_month"].values
print(f"validation (ind_month): corr(analytic,MC)={np.corrcoef(an, acc/1000)[0,1]:.5f}")

json.dump(meta, open(OUT / "expected_exposure_meta.json", "w"), indent=2)
mu = mu.reset_index()
mu.to_stata(OUT / "expected_exposure.dta", write_index=False, version=118)
mu.to_csv(OUT / "expected_exposure.csv", index=False)
print("swappable:", {k: v["swap_spillover"] for k, v in meta.items()})
print("saved:", OUT / "expected_exposure.dta")
