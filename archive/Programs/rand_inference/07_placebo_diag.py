#!/usr/bin/env python
"""
Placebo-diagnostics engine — spillover permutation under four named
stratifications, with balance diagnostics (Test 1A) on the treated set.

For each stratification scheme we:
  * reshuffle the treated label within strata (same cardinality as observed),
  * rebuild placebo connectivity C_i(S) = sum_j W_ij S_j and re-estimate the
    spillover slope for the wage outcomes (randomization-inference p-value),
  * on the SAME draws, record the standardized-mean-difference imbalance of the
    treated set on the key stratification variables (log size, flow intensity)
    and the treated-set share in each 2-digit industry division.

Schemes (destination-firm stratification cells):
  none          : single stratum (i.i.d. reshuffle)
  intermediate  : 2-digit industry x size-quartile x flow-quartile
  fine_vingtile : 2-digit industry x size-vingtile x flow-vingtile
  control_match : 2-digit industry x microregion x negotiation-month
                  x size-quartile x flow-quartile   (matches the control spec)

Outputs (Data/rand_inference/):
  placebo_diag_<scheme>.npz   arrays for the report script
  placebo_diag_summary.json   p-values + firm counts for all schemes

Estimation sample, W engine and option-C (hold 926 non-balanced treated fixed)
are identical to 04_permutation_engine.py.
"""
import numpy as np, pandas as pd, argparse, time, json
from pathlib import Path
from scipy import sparse
from pyfixest.estimation.demean_ import demean

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"

ap = argparse.ArgumentParser()
ap.add_argument("--R", type=int, default=1000)
ap.add_argument("--batch", type=int, default=250)
ap.add_argument("--seed", type=int, default=12345)
ap.add_argument("--outcomes", nargs="+",
                default=["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"])
args = ap.parse_args()

def timevars(o):
    """Clause count uses CBA-period structure; the rest use calendar-year."""
    if o == "numb_clauses":
        return "cba_period", "post_treat_cba", "numb_clauses_pre4"
    return "year", "treat_year", f"{o}_pre4"

# ── frame + estimation sample (spillover: untreated balanced firms) ──────────
df = pd.read_stata(OUT / "spill_frame.dta")
est_mask = df.treat_ultra == 0
est = df[est_mask].copy()
est = est.dropna(subset=["industry1", "mode_base_month", "microregion"]).reset_index(drop=True)
p90_panel = float(df.loc[df.treat_ultra == 0, "totaltreat_pw_n_p90"].iloc[0])

reg_firms = est.identificad.unique().tolist()
reg_ix = {f: k for k, f in enumerate(reg_firms)}
NF = len(reg_firms)
firm_normC = est.groupby("identificad").totaltreat_pw_norm.first().reindex(reg_firms).values

# ── permutation universe: all lagos firms with their stratification keys ─────
keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})

def qbin(x, q):
    b = pd.qcut(x.rank(method="first"), q, labels=False)
    return b.where(x.notna(), q).astype(int)

# industry1 = "1" + first-3-digits-of-CNAE (leading 1 preserves a dropped 0);
# the TRUE 2-digit CNAE division is the two digits after the leading 1 (041:169-218).
_istr = keys.industry1.astype("Int64").astype(str)
keys["ind2"] = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)

def broad_industry(b):
    """results.do 18-category grouping of the 2-digit CNAE division."""
    if b in (1, 2, 3):                 return 1
    if 5 <= b <= 9:                    return 2
    if 10 <= b <= 33:                  return 3
    if 35 <= b <= 39:                  return 4
    if 41 <= b <= 43:                  return 5
    if 45 <= b <= 47:                  return 6
    if 49 <= b <= 53:                  return 7
    if 55 <= b <= 56:                  return 8
    if 58 <= b <= 63:                  return 9
    if 64 <= b <= 66:                  return 10
    if b == 68:                        return 11
    if (69 <= b <= 75) or (77 <= b <= 79): return 12
    if 80 <= b <= 82:                  return 13
    if b == 84:                        return 14
    if b == 85:                        return 15
    if 86 <= b <= 88:                  return 16
    if 90 <= b <= 91:                  return 17
    if 92 <= b <= 99:                  return 18
    return -1
keys["broad"]    = keys["ind2"].map(broad_industry).astype(int)
keys["size_b4"]  = qbin(keys.l_firm_emp, 4)
keys["flow_b4"]  = qbin(keys.totalflows_pw_pre_07_11, 4)
keys["size_b20"] = qbin(keys.l_firm_emp, 20)
keys["flow_b20"] = qbin(keys.totalflows_pw_pre_07_11, 20)
keys["mbm"]      = keys.mode_base_month.astype("category").cat.codes
keys["micro"]    = keys.microregion.astype(int)

SCHEMES = {
    "none":          [],
    "intermediate":  ["ind2", "size_b4", "flow_b4"],
    "fine_vingtile": ["ind2", "size_b20", "flow_b20"],
    "control_match": ["ind2", "micro", "mbm", "size_b4", "flow_b4"],
}

col_id = keys.identificad.values
NC = len(col_id)
treated = keys.treat_ultra.values == 1
bal     = keys.in_balanced_panel.values == 1

# ── sparse W: rows = estimation firms, cols = all lagos firms ────────────────
col_ix = {f: k for k, f in enumerate(col_id)}
W = pd.read_parquet(OUT / "flow_weights.parquet")
w = W[W.i.isin(reg_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(reg_ix).values, w.j.map(col_ix).values)),
                       shape=(NF, NC))

# ── balanced-pool arrays for the imbalance statistics ────────────────────────
pool = np.where(bal)[0]                       # rows of the reshuffle universe
NP = pool.size
x_size = keys.l_firm_emp.values[pool]
x_flow = keys.totalflows_pw_pre_07_11.values[pool]
sd_size = np.nanstd(x_size)
sd_flow = np.nanstd(x_flow)
grp_pool = keys.broad.values[pool]                          # broad_industry (results.do 18-cat)
groups = sorted([g for g in np.unique(grp_pool) if g >= 1])
grp_ind = {g: (grp_pool == g).astype(float) for g in groups}
obs_treat_pool = treated[pool].astype(float)  # real treated indicator over pool

def smd(treat_col, x, sd):
    """(B,) standardized mean diff of x: treated vs untreated, common sd.
    NaN-safe: entries with missing x are excluded from both group means."""
    m  = (~np.isnan(x)).astype(float)[:, None]
    xf = np.where(np.isnan(x), 0.0, x)[:, None]
    tsum = (treat_col * m).sum(0); usum = ((1 - treat_col) * m).sum(0)
    mt = (treat_col * xf).sum(0) / tsum
    mu = ((1 - treat_col) * xf).sum(0) / usum
    return (mt - mu) / sd

def shares(treat_col):
    """(len(groups), B) treated-set share in each broad_industry group."""
    tsum = treat_col.sum(0)
    return np.vstack([(treat_col * grp_ind[g][:, None]).sum(0) / tsum for g in groups])

# observed imbalance + shares
obs_smd_size = float(smd(obs_treat_pool[:, None], x_size, sd_size)[0])
obs_smd_flow = float(smd(obs_treat_pool[:, None], x_flow, sd_flow)[0])
obs_shares   = shares(obs_treat_pool[:, None])[:, 0]

# ── FE machinery (identical to 04) ───────────────────────────────────────────
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

# pre-build per-outcome demeaned outcome + FE list + firm->reg-row map
OC = {}
for outcome in args.outcomes:
    T, post_col, pre4 = timevars(outcome)
    eo = est[est[outcome].notna()].copy()
    if outcome == "numb_clauses":
        eo = eo[eo.cba_period.notna()].copy()
    eo = eo.reset_index(drop=True)
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
    obs_regrow = eo.identificad.map(reg_ix).values.astype(int)
    n_firms = eo.loc[keep, "identificad"].nunique()
    OC[outcome] = dict(eo=eo, keep=keep, flist=flist, My=My, post=post,
                       obs_regrow=obs_regrow, n_obs=int(keep.sum()), n_firms=int(n_firms))

def slopes(firm_conn, oc):                    # firm_conn: (NF, B)
    CP = firm_conn[oc["obs_regrow"], :] * oc["post"][:, None]
    Mx = demean_vec(CP[oc["keep"], :], oc["flist"])
    return (Mx.T @ oc["My"]) / np.einsum("ij,ij->j", Mx, Mx)

# ── run each scheme ──────────────────────────────────────────────────────────
summary = {}
for scheme, sc in SCHEMES.items():
    rng = np.random.default_rng(args.seed)
    keys["stratum"] = (keys[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes
                       if sc else 0)

    in_perm = bal
    fixed_extra = np.where(treated & ~bal)[0]           # 926 always-treated destinations
    fixed_parts, mixed_strata, mixed = ([fixed_extra] if fixed_extra.size else []), [], 0
    kp = keys[in_perm]
    for s, g in kp.groupby("stratum"):
        idx = g.index.values
        nt = int(treated[idx].sum())
        if nt == 0:            continue
        if nt == len(idx):     fixed_parts.append(idx)
        else:                  mixed_strata.append((idx, nt)); mixed += 1
    fixed_cols = np.concatenate(fixed_parts) if fixed_parts else np.array([], int)
    n_swap = sum(nt for _, nt in mixed_strata)          # treated that can actually move

    # position of each pool row inside the pool-array (for the imbalance stat)
    pool_pos = -np.ones(NC, int); pool_pos[pool] = np.arange(NP)

    def draw_batch(B):
        """Return (S_pool (NP,B) treated indicator over the balanced pool,
                   conn (NF,B) placebo connectivity per estimation firm)."""
        S = np.zeros((NC, B))
        if fixed_cols.size:
            S[fixed_cols, :] = 1.0
        for col in range(B):
            for idx, nt in mixed_strata:
                S[rng.choice(idx, size=nt, replace=False), col] = 1.0
        conn = Wm.dot(S) / p90_panel
        return S[pool, :], conn

    dr = {o: np.empty(args.R) for o in args.outcomes}
    smd_s = np.empty(args.R); smd_f = np.empty(args.R)
    shr = np.empty((len(groups), args.R))
    t0 = time.time()
    for s0 in range(0, args.R, args.batch):
        B = min(args.batch, args.R - s0)
        Spool, conn = draw_batch(B)
        for o in args.outcomes:
            dr[o][s0:s0 + B] = slopes(conn, OC[o])
        smd_s[s0:s0 + B] = smd(Spool, x_size, sd_size)
        smd_f[s0:s0 + B] = smd(Spool, x_flow, sd_flow)
        shr[:, s0:s0 + B] = shares(Spool)

    # observed slopes use the PANEL connectivity so they equal the main-table estimate
    res = {}
    for o in args.outcomes:
        d_obs = float(slopes(firm_normC[:, None], OC[o])[0])
        p_two = float((np.sum(np.abs(dr[o]) >= abs(d_obs)) + 1) / (args.R + 1))
        res[o] = dict(delta_obs=d_obs, p_two=p_two,
                      placebo_mean=float(dr[o].mean()), placebo_sd=float(dr[o].std()),
                      n_obs=OC[o]["n_obs"], n_firms=OC[o]["n_firms"])
    summary[scheme] = dict(
        strata=sc, n_mixed_strata=mixed, n_swappable=int(n_swap),
        n_treated_permuted=int((treated & in_perm).sum()), n_fixed=int(fixed_cols.size),
        n_est_firms=OC[args.outcomes[0]]["n_firms"], n_est_obs=OC[args.outcomes[0]]["n_obs"],
        outcomes=res)
    np.savez(OUT / f"placebo_diag_{scheme}.npz",
             **{f"delta_{o}": dr[o] for o in args.outcomes},
             smd_size=smd_s, smd_flow=smd_f, shares=shr,
             obs_smd_size=obs_smd_size, obs_smd_flow=obs_smd_flow,
             obs_shares=obs_shares, groups=np.array(groups),
             **{f"delta_obs_{o}": res[o]["delta_obs"] for o in args.outcomes})
    print(f"[{scheme:14s}] swap={n_swap:6d} mixed={mixed:4d} "
          + " ".join(f"{o}:d={res[o]['delta_obs']:+.4f} p={res[o]['p_two']:.3f}" for o in args.outcomes)
          + f"  smd_size_obs={obs_smd_size:+.2f} smd_flow_obs={obs_smd_flow:+.2f} ({time.time()-t0:.0f}s)")

# observed pool-level facts for the report
summary["_meta"] = dict(R=args.R, p90_panel=p90_panel, n_pool=int(NP),
                        obs_smd_size=obs_smd_size, obs_smd_flow=obs_smd_flow,
                        groups=[int(g) for g in groups],
                        obs_shares=[float(v) for v in obs_shares])
with open(OUT / "placebo_diag_summary.json", "w") as f:
    json.dump(summary, f, indent=2)
print("saved:", OUT / "placebo_diag_summary.json")
