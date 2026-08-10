#!/usr/bin/env python
"""
Composition diagnostics for the counterfactual-connectivity placebo.

Characterises WHICH control firms each selection rule keeps, so the placebo
estimates in 17_direct_cf_placebo.py can be read against the composition of the
groups that produce them. No regressions here -- only the selection step, so this
is cheap and can be run at high R.

Compares four control groups on pre-treatment characteristics:
  all controls          the 4,196 actual untreated balanced firms (Panel C)
  observed pure         the 1,931 with observed zero connectivity (Panel A)
  procedure A           controls with counterfactual zero connectivity (draw-avg)
  procedure B           bottom-46.02% of controls by counterfactual conn. (draw-avg)

Also records, per draw, the size of each placebo set and its overlap with the
observed pure-control group -- the diagnostics that determine whether the placebo
exercise is informative or mechanically degenerate.

Draw machinery (option C, CEM strata, correct 2-digit CNAE) is identical to
17_direct_cf_placebo.py.

Outputs:
  Tables/rand_inference/direct_cf_composition_<scheme>.csv
  Data/rand_inference/direct_cf_composition_<scheme>.npz
"""
import numpy as np, pandas as pd, argparse, json
from pathlib import Path
from scipy import sparse

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"
TAB  = ROOT / "Tables/rand_inference"; TAB.mkdir(exist_ok=True)

ap = argparse.ArgumentParser()
ap.add_argument("--R", type=int, default=1000)
ap.add_argument("--seed", type=int, default=12345)
ap.add_argument("--scheme", choices=["none", "intermediate", "fine_vingtile", "control_match"],
                default="intermediate")
args = ap.parse_args()

df = pd.read_stata(OUT / "spill_frame.dta")
df = df.dropna(subset=["industry1", "mode_base_month", "microregion"]).reset_index(drop=True)
firm = df.groupby("identificad").agg(treat=("treat_ultra", "first"),
                                     conn=("totaltreat_pw_n", "first"))
control_ids = list(firm.index[firm.treat == 0])
obs_pure    = set(firm.index[(firm.treat == 0) & (firm.conn == 0)])
N_PURE      = len(obs_pure)

keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})


def qbin(x, q):
    b = pd.qcut(x.rank(method="first"), q, labels=False)
    return b.where(x.notna(), q).astype(int)


_istr = keys.industry1.astype("Int64").astype(str)
keys["ind2"]     = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)
keys["size_b4"]  = qbin(keys.l_firm_emp, 4)
keys["flow_b4"]  = qbin(keys.totalflows_pw_pre_07_11, 4)
keys["size_b20"] = qbin(keys.l_firm_emp, 20)
keys["flow_b20"] = qbin(keys.totalflows_pw_pre_07_11, 20)
keys["mbm"]      = keys.mode_base_month.astype("category").cat.codes
keys["micro"]    = keys.microregion.astype(int)
SCHEMES = {"none": [], "intermediate": ["ind2", "size_b4", "flow_b4"],
           "fine_vingtile": ["ind2", "size_b20", "flow_b20"],
           "control_match": ["ind2", "micro", "mbm", "size_b4", "flow_b4"]}
sc = SCHEMES[args.scheme]
keys["stratum"] = (keys[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes
                   if sc else 0)

col_id = keys.identificad.values
col_ix = {f: k for k, f in enumerate(col_id)}
NC = len(col_id)
treated_key = keys.treat_ultra.values == 1
bal         = keys.in_balanced_panel.values == 1

fixed_parts, mixed_strata = ([np.where(treated_key & ~bal)[0]]), []
for s, g in keys[bal].groupby("stratum"):
    idx = g.index.values
    nt = int(treated_key[idx].sum())
    if nt == 0:        continue
    if nt == len(idx): fixed_parts.append(idx)
    else:              mixed_strata.append((idx, nt))
fixed_cols = np.concatenate(fixed_parts)

ctrl_ix  = {f: k for k, f in enumerate(control_ids)}
NF       = len(control_ids)
ctrl_arr = np.array(control_ids)
W = pd.read_parquet(OUT / "flow_weights.parquet")
W["i"] = W.i.astype(str); W["j"] = W.j.astype(str)
w = W[W.i.isin(ctrl_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(ctrl_ix).values, w.j.map(col_ix).values)),
                       shape=(NF, NC))

# ── characteristics of the control pool, aligned to ctrl_arr ────────────────
K = keys.set_index("identificad")
CH = pd.DataFrame(index=pd.Index(ctrl_arr, name="identificad"))
CH["l_firm_emp"]   = K.l_firm_emp.reindex(ctrl_arr).values
CH["firm_emp"]     = K.firm_emp.reindex(ctrl_arr).values
CH["totalflows"]   = K.totalflows_pw_pre_07_11.reindex(ctrl_arr).values
CH["turnover"]     = K.turnover.reindex(ctrl_arr).values
CH["true_conn"]    = firm.conn.reindex(ctrl_arr).values
CH["n_edges"]      = np.asarray((Wm > 0).sum(1)).ravel()
CH["is_obs_pure"]  = np.isin(ctrl_arr, list(obs_pure)).astype(float)
VARS = ["l_firm_emp", "firm_emp", "totalflows", "turnover", "true_conn", "n_edges", "is_obs_pure"]

rng = np.random.default_rng(args.seed)
R = args.R
accA = {v: np.zeros(R) for v in VARS}
accB = {v: np.zeros(R) for v in VARS}
nA, nB = np.zeros(R, int), np.zeros(R, int)
ovA, ovB = np.zeros(R), np.zeros(R)
recA, recB = np.zeros(R), np.zeros(R)     # recall: share of the observed pure set captured

for r in range(R):
    S = np.zeros(NC); S[fixed_cols] = 1.0
    for idx, nt in mixed_strata:
        S[rng.choice(idx, size=nt, replace=False)] = 1.0
    C = Wm.dot(S)
    mA = C == 0
    order = np.lexsort((rng.random(NF), C))
    mB = np.zeros(NF, bool); mB[order[:N_PURE]] = True
    for m, acc, n, ov, rec in ((mA, accA, nA, ovA, recA), (mB, accB, nB, ovB, recB)):
        sub = CH[m]
        for v in VARS:
            acc[v][r] = np.nanmean(sub[v].values)
        n[r] = int(m.sum())
        ov[r] = sub.is_obs_pure.mean() if m.sum() else np.nan
        rec[r] = sub.is_obs_pure.sum() / N_PURE

# ── composition table ───────────────────────────────────────────────────────
rows = []
allc = CH
pure = CH[CH.is_obs_pure == 1]
for lab, d in (("All controls (Panel C)", allc), ("Observed pure (Panel A)", pure)):
    rows.append(dict(group=lab, n_controls=len(d),
                     **{v: float(np.nanmean(d[v].values)) for v in VARS}))
rows.append(dict(group="Procedure A (cf. zero conn.)", n_controls=float(nA.mean()),
                 **{v: float(accA[v].mean()) for v in VARS}))
rows.append(dict(group="Procedure B (cf. bottom 46%)", n_controls=float(nB.mean()),
                 **{v: float(accB[v].mean()) for v in VARS}))
comp = pd.DataFrame(rows)
comp.to_csv(TAB / f"direct_cf_composition_{args.scheme}.csv", index=False)
print(comp.to_string(index=False, float_format=lambda x: f"{x:,.4f}"))

print(f"\nProcedure A set size: mean={nA.mean():.0f} min={nA.min()} max={nA.max()} "
      f"(observed pure = {N_PURE}); empty draws={(nA == 0).sum()}; "
      f"draws with <100 controls={(nA < 100).sum()}")
print(f"Procedure A overlap (share of placebo set inside observed pure): "
      f"mean={np.nanmean(ovA):.4f} min={np.nanmin(ovA):.4f} max={np.nanmax(ovA):.4f}")
print(f"Procedure A recall (share of the 1,931 observed pure captured): mean={recA.mean():.4f}")
print(f"Procedure B overlap: mean={np.nanmean(ovB):.4f} min={np.nanmin(ovB):.4f} "
      f"max={np.nanmax(ovB):.4f} | recall mean={recB.mean():.4f}")

np.savez(OUT / f"direct_cf_composition_{args.scheme}.npz",
         nA=nA, nB=nB, ovA=ovA, ovB=ovB, recA=recA, recB=recB,
         **{f"A_{v}": accA[v] for v in VARS}, **{f"B_{v}": accB[v] for v in VARS})
print("saved:", TAB / f"direct_cf_composition_{args.scheme}.csv")
