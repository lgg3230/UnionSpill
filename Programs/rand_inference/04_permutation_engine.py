#!/usr/bin/env python
"""
Randomization inference — permute the IDENTITY of the treated set.

Two modes, four outcomes each, several matching resolutions.

  --mode spillover : estimation sample = untreated balanced firms; the regressor
      is connectivity C_i to the treated set. The treated label is permuted among
      the 16,472 balanced firms (12,276 treated), the 926 non-balanced treated are
      held fixed as destinations, and connectivity is rebuilt via C_i(S)=sum W_ij.

  --mode direct : estimation sample = Panel A (treated + zero-connectivity
      untreated controls, 14,207 firms); the regressor is the treated dummy. The
      treated label is permuted among those 14,207 firms. This is a POSITIVE
      CONTROL: the direct effect is large and unambiguously caused by treatment,
      so a well-powered test must reject it; where it does not (finest match), the
      loss of power is mechanical.

Outcomes: lr_remdezr_w, lr_remdezr_h_w, l_firm_emp use year fixed effects and the
post-2012 indicator; numb_clauses uses CBA-period fixed effects and post_treat_cba.

Only the point estimate is needed per replication, so we use Frisch-Waugh
(residualize the outcome on the fixed effects once, residualize each replication's
regressor, take the slope). p = (1 + #{|b^(r)| >= |b_obs|}) / (R+1).
"""
import numpy as np, pandas as pd, argparse, time, json
from pathlib import Path
from scipy import sparse
from pyfixest.estimation.demean_ import demean

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"
TAB  = ROOT / "Tables/rand_inference"

ap = argparse.ArgumentParser()
ap.add_argument("--mode", choices=["spillover", "direct"], default="spillover")
ap.add_argument("--R", type=int, default=10000)
ap.add_argument("--batch", type=int, default=250)
ap.add_argument("--seed", type=int, default=12345)
ap.add_argument("--coarseness", choices=["none", "coarse", "medium", "fine"], default="medium")
ap.add_argument("--outcomes", nargs="+",
                default=["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"])
args = ap.parse_args()
rng = np.random.default_rng(args.seed)

def timevars(o):
    if o == "numb_clauses":
        return "cba_period", "post_treat_cba", "numb_clauses_pre4"
    return "year", "treat_year", f"{o}_pre4"

# ── frame + estimation mask by mode ─────────────────────────────────────────
df = pd.read_stata(OUT / "spill_frame.dta")
if args.mode == "spillover":
    est_mask = df.treat_ultra == 0
else:  # direct, Panel A: treated + zero-connectivity untreated
    est_mask = (df.treat_ultra == 1) | ((df.treat_ultra == 0) & (df.totaltreat_pw_n == 0))
est = df[est_mask].copy()
est = est.dropna(subset=["industry1", "mode_base_month", "microregion"]).reset_index(drop=True)
p90_panel = float(df.loc[df.treat_ultra == 0, "totaltreat_pw_n_p90"].iloc[0])

# ── firms carrying the regressor, and the observed regressor per firm ────────
reg_firms = est.identificad.unique().tolist()
reg_ix = {f: k for k, f in enumerate(reg_firms)}
NF = len(reg_firms)
firm_treat = (est.groupby("identificad").treat_ultra.first().reindex(reg_firms).values == 1)
firm_normC = (est.groupby("identificad").totaltreat_pw_norm.first().reindex(reg_firms).values)  # spillover obs

# ── CEM strata over the permutation universe ────────────────────────────────
keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})
def qbin(x, q):
    b = pd.qcut(x.rank(method="first"), q, labels=False)
    return b.where(x.notna(), q).astype(int)
keys["ind2"]   = (keys.industry1 // 100).fillna(-1).astype(int)
keys["size_b"] = qbin(keys.l_firm_emp, 4)
keys["flow_b"] = qbin(keys.totalflows_pw_pre_07_11, 4)
keys["mbm"]    = keys.mode_base_month.astype("category").cat.codes
keys["micro"]  = keys.microregion.astype(int)
RES = {"none": [], "coarse": ["ind2", "size_b", "flow_b"],
       "medium": ["ind2", "micro", "size_b", "flow_b"],
       "fine": ["ind2", "micro", "mbm", "size_b", "flow_b"]}
sc = RES[args.coarseness]
keys["stratum"] = (keys[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes
                   if sc else 0)

col_id = keys.identificad.values
col_ix = {f: k for k, f in enumerate(col_id)}
NC = len(col_id)
treated = keys.treat_ultra.values == 1
bal     = keys.in_balanced_panel.values == 1

if args.mode == "spillover":
    # permute among balanced firms; hold non-balanced treated fixed as destinations
    in_perm = bal
    fixed_extra = np.where(treated & ~bal)[0]                 # 926 always-treated destinations
else:
    # permute among Panel A firms (= estimation firms); no fixed extras
    panelA = np.array([col_ix[f] for f in reg_firms])
    in_perm = np.zeros(NC, bool); in_perm[panelA] = True
    fixed_extra = np.array([], int)

fixed_parts, mixed_strata, mixed = ([fixed_extra] if fixed_extra.size else []), [], 0
kp = keys[in_perm]
for s, g in kp.groupby("stratum"):
    idx = g.index.values
    nt = int(treated[idx].sum())
    if nt == 0:            continue
    if nt == len(idx):     fixed_parts.append(idx)
    else:                  mixed_strata.append((idx, nt)); mixed += 1
fixed_cols = np.concatenate(fixed_parts) if fixed_parts else np.array([], int)
n_perm = sum(nt for _, nt in mixed_strata)
print(f"[{args.mode}/{args.coarseness}] perm-universe={int(in_perm.sum())} "
      f"treated-permuted={int((treated & in_perm).sum())} fixed={len(fixed_cols)} "
      f"mixed-strata={mixed} in-mixed={n_perm}")

# ── sparse W (spillover only): rows = reg_firms, cols = all lagos firms ──────
if args.mode == "spillover":
    W = pd.read_parquet(OUT / "flow_weights.parquet")
    w = W[W.i.isin(reg_ix) & W.j.isin(col_ix)]
    Wm = sparse.csr_matrix((w.W.values, (w.i.map(reg_ix).values, w.j.map(col_ix).values)),
                           shape=(NF, NC))
# map keys column-order firm -> reg_firms row (for direct: indicator lookup)
key_to_reg = np.array([reg_ix.get(f, -1) for f in col_id])

def firm_reg_batch(B):
    """(NF, B) firm-level regressor (pre-post) for B placebo draws."""
    S = np.zeros((NC, B))
    if fixed_cols.size:
        S[fixed_cols, :] = 1.0
    for col in range(B):
        for idx, nt in mixed_strata:
            S[rng.choice(idx, size=nt, replace=False), col] = 1.0
    if args.mode == "spillover":
        return Wm.dot(S) / p90_panel                          # connectivity per reg firm
    # direct: map selected columns to reg-firm indicator
    out = np.zeros((NF, B))
    rows = np.where(key_to_reg >= 0)[0]
    out[key_to_reg[rows], :] = S[rows, :]
    return out

obs_firm_reg_batch  = firm_reg_batch
firm_reg_observed = (firm_normC if args.mode == "spillover" else firm_treat.astype(float))

# ── FE machinery ────────────────────────────────────────────────────────────
def demean_vec(x2d, flist):
    res, ok = demean(np.ascontiguousarray(x2d, np.float64),
                     np.ascontiguousarray(flist, np.int64), np.ones(x2d.shape[0]))
    assert ok; return res
def keep_nonsingleton(flist):
    keep = np.ones(flist.shape[0], bool)
    while True:
        dropped = False
        for j in range(flist.shape[1]):
            col = flist[keep, j]; cnt = np.bincount(col)
            sing = np.isin(col, np.where(cnt == 1)[0])
            if sing.any():
                keep[np.where(keep)[0][sing]] = False; dropped = True
        if not dropped:
            return keep

results = {}
for outcome in args.outcomes:
    T, post_col, pre4 = timevars(outcome)
    eo = est[est[outcome].notna()].copy()
    if outcome == "numb_clauses":
        eo = eo[eo.cba_period.notna()].copy()
    eo = eo.reset_index(drop=True)
    # interacted FE columns for this outcome's time dimension
    fe_bases = ["industry1", "mode_base_month", "microregion", "l_firm_emp_pre4",
                pre4, "totalflows_pw_pre_07_114"]
    fe_cols = ["identificad"]
    for b in fe_bases:
        c = f"{b}__T"; eo[c] = eo[b].astype(str) + "_" + eo[T].astype(str); fe_cols.append(c)
    flist_full = np.column_stack([eo[c].astype("category").cat.codes.values.astype(np.int64)
                                  for c in fe_cols])
    keep = keep_nonsingleton(flist_full)
    flist = np.ascontiguousarray(flist_full[keep])
    My = demean_vec(eo[[outcome]].values[keep], flist)[:, 0]

    post = eo[post_col].values.astype(float)
    obs_regrow = eo.identificad.map(reg_ix).values.astype(int)   # firm -> reg row

    def slopes(firm_reg):                       # firm_reg: (NF, B)
        CP = firm_reg[obs_regrow, :] * post[:, None]
        Mx = demean_vec(CP[keep, :], flist)
        return (Mx.T @ My) / np.einsum("ij,ij->j", Mx, Mx)

    d_obs = float(slopes(firm_reg_observed[:, None])[0])
    t0 = time.time()
    dr = np.empty(args.R)
    for s0 in range(0, args.R, args.batch):
        b = min(args.batch, args.R - s0)
        dr[s0:s0 + b] = slopes(firm_reg_batch(b))
    p_two = float((np.sum(np.abs(dr) >= abs(d_obs)) + 1) / (args.R + 1))
    p_up  = float((np.sum(dr >= d_obs) + 1) / (args.R + 1))
    print(f"  [{outcome:15s}] obs={d_obs:+.5f} placebo mean={dr.mean():+.5f} sd={dr.std():.5f} "
          f"p_two={p_two:.4f} p_up={p_up:.4f} ({time.time()-t0:.0f}s)")
    results[outcome] = dict(mode=args.mode, delta_obs=d_obs, p_two_sided=p_two, p_upper=p_up,
                            R=args.R, placebo_mean=float(dr.mean()), placebo_sd=float(dr.std()),
                            coarseness=args.coarseness)
    np.save(OUT / f"placebo_{args.mode}_{outcome}_{args.coarseness}.npy", dr)

TAB.mkdir(exist_ok=True)
with open(TAB / f"perm_{args.mode}_{args.coarseness}.json", "w") as f:
    json.dump(results, f, indent=2)
print("saved:", TAB / f"perm_{args.mode}_{args.coarseness}.json")
