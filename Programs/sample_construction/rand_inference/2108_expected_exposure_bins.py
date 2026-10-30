#!/usr/bin/env python
"""
Expected exposure mu_i = E_r[ regressor_i ] under the treated-set reshuffle, with
the industry x negotiation-month cells of 2098 split further by pre-treatment
size or wage bins (Referee 3):

  ind_month               industry x negotiation month (2098; replication check)
  ind_month_size{4,10,20} ... x bins of log mean employment 2009-2011
  ind_month_wage{4,10,20} ... x bins of mean log hourly wage 2009-2011

Bins come from 2107 (firm_bins_pre.csv); a firm with a missing bin gets its own
bin. Closed form as in 2098: mu_i^C = (1/p90) sum_j W_ij pi_j (spillover),
mu_i^D = pi_i (direct), pi_j the within-cell treated share.

Checks (printed, and stored in the meta JSON):
  1. W reproduces the frame's connectivity: sum_{j in T} W_ij / p90 = totaltreat_pw_norm.
  2. mu_C_ind_month / mu_D_ind_month equal expected_exposure.dta from 2098.
  3. Each scheme's closed form matches a Monte-Carlo average of N_MC reshuffles.

Output: Data/rand_inference/expected_exposure_bins.dta / .csv  (mu_C_*, mu_D_*)
        Data/rand_inference/expected_exposure_bins_meta.json   (cell counts, checks)
"""
import os, json
import numpy as np, pandas as pd
from pathlib import Path
from scipy import sparse

ROOT = Path(os.environ.get("UNIONSPILL_ROOT", "/gpfs/kellogg/proj/lgg3230/UnionSpill"))
OUT  = ROOT / "Data/rand_inference"
BINS = ["size4", "size10", "size20", "wage4", "wage10", "wage20"]
SCH  = {"ind_month": ["ind2", "mbm"], **{f"ind_month_{b}": ["ind2", "mbm", b] for b in BINS}}
N_MC = 200
rng  = np.random.default_rng(1)

frame = pd.read_stata(OUT / "spill_frame.dta")
p90 = float(frame.loc[frame.treat_ultra == 0, "totaltreat_pw_n_p90"].iloc[0])
inv = frame.groupby("identificad").agg(
    treat_ultra=("treat_ultra", "first"), totaltreat_pw_n=("totaltreat_pw_n", "first"),
    totaltreat_pw_norm=("totaltreat_pw_norm", "first"))

# ── permutation universe + cell keys (ind2, mbm verbatim from 2098) ─────────
K = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})
B = pd.read_csv(OUT / "firm_bins_pre.csv", dtype={"identificad": str})
K = K.merge(B[["identificad"] + BINS], on="identificad", how="left", validate="1:1")
_istr = K.industry1.astype("Int64").astype(str)
K["ind2"] = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)
K["mbm"]  = K.mode_base_month.astype("category").cat.codes
for b in BINS:
    K[b] = K[b].fillna(-1).astype(int)
col_id = K.identificad.values; NC = len(col_id); col_ix = {f: k for k, f in enumerate(col_id)}
treated = (K.treat_ultra.values == 1); bal = (K.in_balanced_panel.values == 1)

# spillover estimation firms (untreated) + W (rows=untreated, cols=all lagos)
sp_firms = inv.index[inv.treat_ultra == 0].tolist()
sp_ix = {f: k for k, f in enumerate(sp_firms)}; NF = len(sp_firms)
W = pd.read_parquet(OUT / "flow_weights.parquet")
w = W[W.i.isin(sp_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(sp_ix).values, w.j.map(col_ix).values)), shape=(NF, NC))
panelA = inv.index[(inv.treat_ultra == 1) | ((inv.treat_ultra == 0) & (inv.totaltreat_pw_n == 0))].tolist()
inA = np.isin(col_id, panelA)

def cells(sc):
    return K.groupby(sc, sort=True).ngroup().values

def treated_share(cell, mask):
    pi = treated.astype(float).copy()
    nt = np.bincount(cell[mask], weights=treated[mask], minlength=cell.max() + 1)
    n  = np.bincount(cell[mask], minlength=cell.max() + 1)
    pi[mask] = (nt / np.maximum(n, 1))[cell[mask]]
    return pi

def cell_stats(cell, mask):
    """Cell counts over a permutation universe. swappable = treated firms in mixed cells (2098)."""
    nt = np.bincount(cell[mask], weights=treated[mask], minlength=cell.max() + 1).astype(int)
    n  = np.bincount(cell[mask], minlength=cell.max() + 1)
    occ = n > 0; mixed = occ & (nt > 0) & (nt < n); all_t = occ & (nt == n); all_u = occ & (nt == 0)
    return dict(cells=int(occ.sum()), mixed_cells=int(mixed.sum()), swappable=int(nt[mixed].sum()),
                untreated_in_mixed=int((n - nt)[mixed].sum()),
                all_treated_cells=int(all_t.sum()), treated_fixed=int(nt[all_t].sum()),
                all_untreated_cells=int(all_u.sum()), untreated_never=int(n[all_u].sum()),
                treated_total=int(nt.sum()), firms_total=int(n.sum()))

def mc_mu_C(cell):
    """Monte-Carlo mean of spillover connectivity over N_MC within-cell reshuffles."""
    fixed_parts = [np.where(treated & ~bal)[0]]; mixed = []
    for s in np.unique(cell[bal]):
        idx = np.where(bal & (cell == s))[0]; nt = int(treated[idx].sum())
        if nt == 0: continue
        (fixed_parts.append(idx) if nt == len(idx) else mixed.append((idx, nt)))
    fixed_cols = np.concatenate(fixed_parts); acc = np.zeros(NF)
    for _ in range(N_MC):
        S = np.zeros(NC); S[fixed_cols] = 1.0
        for idx, nt in mixed: S[rng.choice(idx, size=nt, replace=False)] = 1.0
        acc += Wm.dot(S) / p90
    return acc / N_MC

# ── check 1: W reproduces the frame's connectivity ──────────────────────────
C_rec = Wm.dot(treated.astype(float)) / p90
C_frm = inv.loc[sp_firms, "totaltreat_pw_norm"].values
ok = ~np.isnan(C_frm)
chk = dict(W_vs_frame_maxabs=float(np.abs(C_rec[ok] - C_frm[ok]).max()),
           W_vs_frame_corr=float(np.corrcoef(C_rec[ok], C_frm[ok])[0, 1]))
print(f"check 1 (W vs frame connectivity): max|diff|={chk['W_vs_frame_maxabs']:.2e} "
      f"corr={chk['W_vs_frame_corr']:.8f} -> "
      f"{'PASS' if chk['W_vs_frame_maxabs'] < 1e-5 else 'FAIL'}")
if chk["W_vs_frame_maxabs"] >= 1e-5:
    raise SystemExit("spill_frame.dta and flow_weights.parquet disagree: rerun 2091 (and 2090) first")

mu = pd.DataFrame(index=inv.index); meta = {}
for scheme, sc in SCH.items():
    cell = cells(sc)
    mu.loc[sp_firms, f"mu_C_{scheme}"] = pd.Series(Wm.dot(treated_share(cell, bal)) / p90, index=sp_firms)
    pi_dir = treated_share(cell, inA)
    mu.loc[panelA, f"mu_D_{scheme}"] = pd.Series(pi_dir[[col_ix[f] for f in panelA]], index=panelA)
    an = mu.loc[sp_firms, f"mu_C_{scheme}"].values; mc = mc_mu_C(cell)
    meta[scheme] = dict(spillover=cell_stats(cell, bal), direct=cell_stats(cell, inA),
                        mc_corr=float(np.corrcoef(an, mc)[0, 1]), mc_maxabs=float(np.abs(an - mc).max()))
    s = meta[scheme]["spillover"]
    print(f"[{scheme:18s}] cells={s['cells']:5d} mixed={s['mixed_cells']:5d} swappable={s['swappable']:5d}"
          f"/{s['treated_total']} fixed-treated={s['treated_fixed']:5d} never-treated={s['untreated_never']:4d}"
          f" | MC corr={meta[scheme]['mc_corr']:.5f}")

# ── check 2: ind_month reproduces 2098's expected_exposure.dta ──────────────
# A gap here with check 1 passing means expected_exposure.dta was built from an
# older spill_frame (other p90 or Panel A); the draft's figures used that file.
old = pd.read_stata(OUT / "expected_exposure.dta").set_index("identificad")
for c in ["mu_C_ind_month", "mu_D_ind_month"]:
    o = old[c].reindex(mu.index); ok = mu[c].notna() & o.notna(); d = (mu[c] - o)[ok].abs()
    chk[f"{c}_vs_2098_maxabs"] = float(d.max())
    chk[f"{c}_vs_2098_corr"] = float(np.corrcoef(mu[c][ok], o[ok])[0, 1])
    print(f"check 2 ({c} vs 2098): max|diff|={d.max():.2e} corr={chk[f'{c}_vs_2098_corr']:.8f} "
          f"-> {'PASS' if d.max() < 1e-6 else 'DIFFERS'}")
meta["checks"] = chk

json.dump(meta, open(OUT / "expected_exposure_bins_meta.json", "w"), indent=2)
mu = mu.reset_index()
mu.to_stata(OUT / "expected_exposure_bins.dta", write_index=False, version=118)
mu.to_csv(OUT / "expected_exposure_bins.csv", index=False)
print("saved:", OUT / "expected_exposure_bins.dta")
