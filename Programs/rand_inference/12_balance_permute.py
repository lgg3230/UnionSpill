#!/usr/bin/env python
"""
Balance test by permutation. For each 2011 firm characteristic X we regress X on
connectivity among the untreated (spillover) firms and report the coefficient on
connectivity at three control levels (Raw; + industry/month/microregion FE;
+ size/flow quartiles = "main"). Then, at the main-controls level, we compare the
TRUE coefficient to the distribution of coefficients obtained when connectivity is
rebuilt from a reshuffled treated set, for each stratification scheme. A high
p-value means the association is unchanged by which firms are treated (i.e. it is
the mechanical component, not identity).

Coefficient via Frisch-Waugh: residualize X and connectivity on the controls,
take the slope. p = two-sided position of the true coef in the placebo draws.

Output: Data/rand_inference/balance_permute.json
"""
import numpy as np, pandas as pd, json, time
from pathlib import Path
from scipy import sparse
from pyfixest.estimation.demean_ import demean

OUT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference")
MAIN = "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
R, BATCH, SEED = 1000, 250, 12345
SCHEMES = ["unstrat", "ind_month", "ind_month_region", "ind_month_micro"]

# ── firm-level 2011 table ────────────────────────────────────────────────────
frame = pd.read_stata(OUT / "spill_frame.dta")
p90 = float(frame.loc[frame.treat_ultra == 0, "totaltreat_pw_n_p90"].iloc[0])
o11 = (frame[frame.year == 2011].set_index("identificad")
       [["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]])
inv = frame.groupby("identificad").agg(
    industry1=("industry1", "first"), microregion=("microregion", "first"),
    mode_base_month=("mode_base_month", "first"), l_firm_emp_pre4=("l_firm_emp_pre4", "first"),
    totalflows_pw_pre_07_114=("totalflows_pw_pre_07_114", "first"),
    treat_ultra=("treat_ultra", "first"), totaltreat_pw_norm=("totaltreat_pw_norm", "first"))
demo = (pd.read_stata(MAIN, columns=["identificad", "year", "hs_c", "sup_c",
                                     "male_prop", "white_prop", "avg_tenure"])
        .query("year == 2011").set_index("identificad"))
demo["female"] = 1 - demo.male_prop; demo["nonwhite"] = 1 - demo.white_prop; demo["tenure"] = demo.avg_tenure / 12
keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str}).set_index("identificad")
age = pd.read_csv(OUT / "firm_mean_age_2011.csv", dtype={"identificad": str}).set_index("identificad")
fdf = inv.join(o11).join(demo[["hs_c", "sup_c", "female", "nonwhite", "tenure"]]) \
        .join(keys[["totalflows_pw_pre_07_11"]]).join(age[["mean_age"]])

CONF = {"lr_remdezr_w": "lr_remdezr_w", "lr_remdezr_h_w": "lr_remdezr_h_w", "l_firm_emp": "l_firm_emp",
        "numb_clauses": "numb_clauses", "flows": "totalflows_pw_pre_07_11", "hs": "hs_c", "higher": "sup_c",
        "female": "female", "nonwhite": "nonwhite", "age": "mean_age", "tenure": "tenure"}
LEVELS = {"raw": [], "fe": ["industry1", "microregion", "mode_base_month"],
          "main": ["industry1", "microregion", "mode_base_month", "l_firm_emp_pre4", "totalflows_pw_pre_07_114"]}

# estimation sample = untreated firms with the FE controls present
est = fdf[fdf.treat_ultra == 0].dropna(subset=["industry1", "microregion", "mode_base_month"]).copy()
reg_firms = est.index.tolist(); reg_ix = {f: k for k, f in enumerate(reg_firms)}; NF = len(reg_firms)
conn_true = est.totaltreat_pw_norm.values.astype(float)

# ── strata universe + W ──────────────────────────────────────────────────────
K = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str}) \
      .merge(pd.read_csv(OUT / "firm_region.csv", dtype={"identificad": str}), on="identificad", how="left")
_istr = K.industry1.astype("Int64").astype(str)
K["ind2"] = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)
K["mbm"] = K.mode_base_month.astype("category").cat.codes
K["micro"] = K.microregion.astype(int); K["region"] = K.region.fillna(-1).astype(int)
SCH = {"unstrat": [], "ind_month": ["ind2", "mbm"], "ind_month_region": ["ind2", "mbm", "region"],
       "ind_month_micro": ["ind2", "mbm", "micro"]}
col_id = K.identificad.values; NC = len(col_id); col_ix = {f: k for k, f in enumerate(col_id)}
treated = (K.treat_ultra.values == 1); bal = (K.in_balanced_panel.values == 1)
W = pd.read_parquet(OUT / "flow_weights.parquet")
w = W[W.i.isin(reg_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(reg_ix).values, w.j.map(col_ix).values)), shape=(NF, NC))

def demean_cols(x2d, codes):
    if codes.shape[1] == 0:
        return x2d - x2d.mean(0, keepdims=True)
    res, ok = demean(np.ascontiguousarray(x2d, np.float64),
                     np.ascontiguousarray(codes, np.int64), np.ones(x2d.shape[0])); assert ok; return res

def codes_for(sub, level):
    cols = LEVELS[level]
    if not cols: return np.zeros((len(sub), 0), np.int64)
    return np.column_stack([sub[c].astype("category").cat.codes.values.astype(np.int64) for c in cols])

def slope(rx, rc):
    d = rc @ rc; return float((rx @ rc) / d) if d > 0 else np.nan

def slope_se(rx, rc):
    """FWL slope of rx on rc (both residualized) + HC0 robust SE."""
    d = rc @ rc
    if d <= 0: return np.nan, np.nan
    g = (rx @ rc) / d
    e = rx - g * rc
    v = np.sum(rc ** 2 * e ** 2) / d ** 2
    return float(g), float(np.sqrt(v))

# ── true coefficient at 3 levels + placebo dist (main level) per scheme ──────
rng = np.random.default_rng(SEED)
res = {}
# per-scheme strata (fixed cols + mixed) over balanced pool
strata = {}
for scheme in SCHEMES:
    sc = SCH[scheme]
    K["stratum"] = (K[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes if sc else 0)
    fixed_parts = [np.where(treated & ~bal)[0]]; mixed = []
    for s, g in K[bal].groupby("stratum"):
        idx = g.index.values; nt = int(treated[idx].sum())
        if nt == 0: continue
        (fixed_parts.append(idx) if nt == len(idx) else mixed.append((idx, nt)))
    strata[scheme] = (np.concatenate(fixed_parts), mixed)

def conn_batch(scheme, B):
    fixed_cols, mixed = strata[scheme]
    S = np.zeros((NC, B)); S[fixed_cols, :] = 1.0
    for c in range(B):
        for idx, nt in mixed:
            S[rng.choice(idx, size=nt, replace=False), c] = 1.0
    return Wm.dot(S) / p90

for ck, xcol in CONF.items():
    x = est[xcol].values.astype(float); m = np.isfinite(x) & np.isfinite(conn_true)
    sub = est[m]; xv = x[m]; ct = conn_true[m]
    row = dict(n=int(m.sum()))
    # true coefficient at each control level
    for lv in LEVELS:
        cds = codes_for(sub, lv)
        rx = demean_cols(xv[:, None], cds)[:, 0]; rc = demean_cols(ct[:, None], cds)[:, 0]
        g, se = slope_se(rx, rc)
        row[f"true_{lv}"] = g; row[f"true_{lv}_se"] = se
        if lv == "main": rx_main, cds_main = rx, cds
        if lv == "raw":  rx_raw = rx
    # placebo distribution at main level, per scheme
    t0 = time.time()
    for scheme in SCHEMES:
        g = np.empty(R); gu = np.empty(R)                 # main-controls and univariate
        for s0 in range(0, R, BATCH):
            B = min(BATCH, R - s0)
            Cb = conn_batch(scheme, B)[m, :]
            rcb = demean_cols(Cb, cds_main)
            denom = np.einsum("ij,ij->j", rcb, rcb); denom[denom == 0] = np.nan
            g[s0:s0 + B] = (rx_main @ rcb) / denom
            Cc = Cb - Cb.mean(0, keepdims=True)           # centered (no controls)
            du = np.einsum("ij,ij->j", Cc, Cc); du[du == 0] = np.nan
            gu[s0:s0 + B] = (rx_raw @ Cc) / du
        gobs, gobs_u = row["true_main"], row["true_raw"]
        lo = (np.sum(g <= gobs) + 1) / (R + 1); hi = (np.sum(g >= gobs) + 1) / (R + 1)
        lou = (np.sum(gu <= gobs_u) + 1) / (R + 1); hiu = (np.sum(gu >= gobs_u) + 1) / (R + 1)
        row[f"pl_{scheme}_mean"] = float(np.nanmean(g)); row[f"pl_{scheme}_p"] = float(min(1.0, 2 * min(lo, hi)))
        row[f"pl_{scheme}_mean_uni"] = float(np.nanmean(gu)); row[f"pl_{scheme}_p_uni"] = float(min(1.0, 2 * min(lou, hiu)))
    res[ck] = row
    print(f"[{ck:14s}] true main={row['true_main']:+.4f} "
          + " ".join(f"{s.split('_')[-1]}:p={row[f'pl_{s}_p']:.2f}" for s in SCHEMES)
          + f" ({time.time()-t0:.0f}s)")

json.dump(res, open(OUT / "balance_permute.json", "w"), indent=2)
print("saved:", OUT / "balance_permute.json")
