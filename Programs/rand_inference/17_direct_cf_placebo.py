#!/usr/bin/env python
"""
Counterfactual-connectivity placebo — a randomization-inference-style robustness
exercise for the DIRECT effect.

────────────────────────────────────────────────────────────────────────────────
DESIGN
────────────────────────────────────────────────────────────────────────────────
The direct effect grows when the control group is narrowed from all untreated
firms (Panel C, "Lorenzo-style") to untreated firms with zero observed
connectivity to the treated set (Panel A, the "pure controls"):

    Panel C  (4,196 controls)  b = 0.0178
    Panel A  (1,931 controls)  b = 0.0262      <- the inflation to be explained

If that inflation reflects TRUE spillovers -- controls connected to treated firms
are contaminated upward, so dropping them widens the treated-control gap -- then
it should be tied to the ACTUAL spillover structure. Replacing observed
connectivity with counterfactual connectivity generated from permuted treatment
assignments should generally NOT reproduce it: placebo "pure control" groups
should land nearer Panel C than Panel A.

WHAT IS HELD FIXED (this is the core rule of the design):
  * the actual treated group (12,276 firms) and the actual treatment indicator
    `treat_ultra` in the regression -- we do NOT permute the regression's treated
    group, and we do NOT re-estimate treatment assignment;
  * the outcome, fixed effects, clustering, weights and event-time structure --
    identical to Main_Results_pct_tfpw_07_11.do (lines 320-384);
  * the pool of candidate controls (the 4,196 actual untreated balanced firms).

WHAT VARIES ACROSS PERMUTATIONS:
  * ONLY the connectivity object used to CLASSIFY controls as "pure". Each draw
    permutes the treated label over the analysis sample, rebuilds counterfactual
    connectivity C_i(S) = sum_j W_ij S_j for every actual control, and reselects
    the pure-control subset from it.

TWO SELECTION RULES
  Procedure A -- counterfactual ZERO connectivity: keep actual controls with
      C_i(S_p) == 0. Mirrors the Panel A rule exactly, but the set size floats.
  Procedure B -- counterfactual BOTTOM-X%: keep the bottom X% of actual controls
      by C_i(S_p), X = the empirical pure-control share (1,931/4,196 = 46.02%),
      so the placebo control group has the SAME SIZE as the observed one.
      Ties broken at random (draw-specific).

The permutation object is the one already used for the spillover/recentering
exercise (04_permutation_engine.py, 07_placebo_diag.py): the treated label is
reshuffled within CEM strata among the 16,472 balanced firms (12,276 treated
permuted), and the 926 non-balanced treated are held fixed as always-treated
destinations ("option C"), so every draw has 13,202 destinations, as observed.
Stratification schemes are copied verbatim from 07_placebo_diag.py, INCLUDING the
correct 2-digit CNAE division (04 uses `industry1 // 100`, which is wrong -- see
041_merge_cba_rais.do:169-172, industry1 carries an artificial leading "1").

INTERPRETATION
This is a robustness / validation / placebo-style exercise, not a formally
established estimator in the literature. It asks one question: is the observed
pure-control estimate unusually large relative to the placebo distribution
induced by counterfactual connectivity? Read the reported quantiles and
randomization p-values as descriptive evidence on whether the Panel A inflation
is specific to the actual spillover structure or is a generic consequence of
selecting a low-connectivity subset of controls. The overlap diagnostics matter
as much as the p-values: if the placebo pure-control sets largely coincide with
the observed one, the exercise is mechanically underpowered and the p-value is
not informative. 18_direct_cf_placebo_report.py reports those diagnostics.

Estimation: the exact main-spec regression via pyfixest, which reproduces the
published reghdfe baselines to the printed precision (Panel C 0.01785 / 0.00318,
Panel A 0.02622 / 0.00492).

Outputs (Data/rand_inference/):
  direct_cf_placebo_<scheme>.npz    per-draw estimates, SEs, counts, overlaps
  direct_cf_placebo_<scheme>.json   observed baselines + summary statistics
"""
import numpy as np, pandas as pd, argparse, time, json, warnings
from pathlib import Path
from scipy import sparse
import pyfixest as pf

warnings.filterwarnings("ignore", message=".*singleton fixed effect.*")

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"
TAB  = ROOT / "Tables/rand_inference"

ap = argparse.ArgumentParser()
ap.add_argument("--R", type=int, default=1000)
ap.add_argument("--seed", type=int, default=12345)
ap.add_argument("--scheme", choices=["none", "intermediate", "fine_vingtile", "control_match"],
                default="intermediate")
ap.add_argument("--outcomes", nargs="+", default=["lr_remdezr_w", "lr_remdezr_h_w"])
args = ap.parse_args()


def timevars(o):
    """Clause count uses CBA-period structure; the rest use calendar-year."""
    if o == "numb_clauses":
        return "cba_period", "post_treat_cba", "numb_clauses_pre4"
    return "year", "treat_year", f"{o}_pre4"


# ── regression frame: all balanced analysis-sample firms (Panel C universe) ──
df = pd.read_stata(OUT / "spill_frame.dta")
df = df.dropna(subset=["industry1", "mode_base_month", "microregion"]).reset_index(drop=True)

firm = df.groupby("identificad").agg(treat=("treat_ultra", "first"),
                                     conn=("totaltreat_pw_n", "first"))
treated_ids = set(firm.index[firm.treat == 1])                       # 12,276, NEVER permuted here
control_ids = list(firm.index[firm.treat == 0])                      # 4,196 candidate controls
obs_pure    = set(firm.index[(firm.treat == 0) & (firm.conn == 0)])  # 1,931 observed pure controls
N_PURE      = len(obs_pure)
X_SHARE     = N_PURE / len(control_ids)                              # 0.4602 -- the "46% rule"
print(f"treated={len(treated_ids)} controls={len(control_ids)} "
      f"observed pure controls={N_PURE} ({X_SHARE:.4f} of controls) PanelA firms="
      f"{len(treated_ids) + N_PURE}")

# ── permutation universe + CEM strata (verbatim from 07_placebo_diag.py) ─────
keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})


def qbin(x, q):
    b = pd.qcut(x.rank(method="first"), q, labels=False)
    return b.where(x.notna(), q).astype(int)


# industry1 = "1" + first-3-digits-of-CNAE (leading 1 preserves a dropped 0);
# the TRUE 2-digit CNAE division is the two digits after the leading 1.
_istr = keys.industry1.astype("Int64").astype(str)
keys["ind2"]     = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce").fillna(-1).astype(int)
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
sc = SCHEMES[args.scheme]
keys["stratum"] = (keys[sc].astype(str).agg("|".join, axis=1).astype("category").cat.codes
                   if sc else 0)

col_id = keys.identificad.values
col_ix = {f: k for k, f in enumerate(col_id)}
NC = len(col_id)
treated_key = keys.treat_ultra.values == 1
bal         = keys.in_balanced_panel.values == 1

# option C: permute the treated label among balanced firms; the 926 non-balanced
# treated stay treated as flow destinations, so each draw has 13,202 destinations.
in_perm     = bal
fixed_extra = np.where(treated_key & ~bal)[0]

fixed_parts, mixed_strata, mixed = ([fixed_extra] if fixed_extra.size else []), [], 0
kp = keys[in_perm]
for s, g in kp.groupby("stratum"):
    idx = g.index.values
    nt = int(treated_key[idx].sum())
    if nt == 0:        continue
    if nt == len(idx): fixed_parts.append(idx)
    else:              mixed_strata.append((idx, nt)); mixed += 1
fixed_cols = np.concatenate(fixed_parts) if fixed_parts else np.array([], int)
n_swappable = sum(nt for _, nt in mixed_strata)
print(f"[{args.scheme}] perm-universe={int(in_perm.sum())} "
      f"treated-permuted={int((treated_key & in_perm).sum())} fixed-destinations={len(fixed_cols)} "
      f"mixed-strata={mixed} swappable-treated={n_swappable}")

# ── sparse W: rows = the 4,196 actual controls, cols = all analysis-sample firms
ctrl_ix = {f: k for k, f in enumerate(control_ids)}
NF = len(control_ids)
W = pd.read_parquet(OUT / "flow_weights.parquet")
W["i"] = W.i.astype(str); W["j"] = W.j.astype(str)
w = W[W.i.isin(ctrl_ix) & W.j.isin(col_ix)]
Wm = sparse.csr_matrix((w.W.values, (w.i.map(ctrl_ix).values, w.j.map(col_ix).values)),
                       shape=(NF, NC))
ctrl_arr = np.array(control_ids)
deg = np.asarray((Wm > 0).sum(1)).ravel()          # # flow edges to any analysis-sample firm
n_isolated = int((deg == 0).sum())
print(f"W rows(controls)={NF} cols={NC} edges={Wm.nnz} | controls with NO flow edge "
      f"at all = {n_isolated} (always counterfactual-zero, in every draw)")

# ── VALIDATION: the W engine, evaluated AT THE OBSERVED treated set, must
#    reproduce the Panel A pure-control set that the panel variable defines.
obs_S = np.zeros(NC); obs_S[[col_ix[f] for f in col_id if treated_key[col_ix[f]]]] = 1.0
C_obs_W = Wm.dot(obs_S)
w_pure = set(ctrl_arr[C_obs_W == 0])
inter, union = len(w_pure & obs_pure), len(w_pure | obs_pure)
print(f"VALIDATION W-reconstructed pure controls={len(w_pure)} vs panel-defined={N_PURE} | "
      f"agree={inter} jaccard={inter/union:.4f}")

# ── observed baselines + per-outcome regression scaffolding ──────────────────
FE_BASES = ["industry1", "mode_base_month", "microregion", "l_firm_emp_pre4",
            "totalflows_pw_pre_07_114"]


def build(outcome):
    T, post_col, pre4 = timevars(outcome)
    d = df[df[outcome].notna()].copy()
    if outcome == "numb_clauses":
        d = d[d.cba_period.notna()].copy()
    fe_cols = ["identificad"]
    for b in FE_BASES + [pre4]:
        c = f"{b}__T"; d[c] = d[b].astype(str) + "_" + d[T].astype(str); fe_cols.append(c)
    # the treated MAIN effect is absorbed by the firm FE and the post main effect by
    # the year-interacted FEs, so the interaction is the only surviving regressor:
    # this reproduces `treat_ultra##i.treat_year` exactly.
    d["x_direct"] = (d.treat_ultra == 1).astype(float) * d[post_col].astype(float)
    return d.reset_index(drop=True), " + ".join(fe_cols)


def fit(d, fe, outcome):
    m = pf.feols(f"{outcome} ~ x_direct | {fe}", data=d, vcov={"CRV1": "identificad"})
    return (float(m.coef()["x_direct"]), float(m.se()["x_direct"]),
            int(m._N), int(d.identificad.nunique()))


OC, base = {}, {}
for outcome in args.outcomes:
    d, fe = build(outcome)
    OC[outcome] = (d, fe)
    bC = fit(d, fe, outcome)                                              # Panel C: all controls
    dA = d[d.identificad.isin(treated_ids | obs_pure)]
    bA = fit(dA, fe, outcome)                                             # Panel A: observed pure
    base[outcome] = dict(panelC=bC, panelA=bA)
    print(f"  [{outcome:15s}] PanelC b={bC[0]:+.5f} se={bC[1]:.5f} N={bC[2]:,} firms={bC[3]:,} | "
          f"PanelA b={bA[0]:+.5f} se={bA[1]:.5f} N={bA[2]:,} firms={bA[3]:,} | "
          f"inflation={bA[0]-bC[0]:+.5f}")

# ── permutation loop ────────────────────────────────────────────────────────
rng = np.random.default_rng(args.seed)
R = args.R
res = {o: {p: dict(b=np.full(R, np.nan), se=np.full(R, np.nan),
                   n_obs=np.zeros(R, int), n_ctrl=np.zeros(R, int),
                   overlap=np.full(R, np.nan))
           for p in ("A", "B")} for o in args.outcomes}

t0 = time.time()
for r in range(R):
    # 1. draw a counterfactual treated set S_p of the observed cardinality
    S = np.zeros(NC)
    if fixed_cols.size:
        S[fixed_cols] = 1.0
    for idx, nt in mixed_strata:
        S[rng.choice(idx, size=nt, replace=False)] = 1.0
    # 2. counterfactual connectivity for every ACTUAL control firm
    C = Wm.dot(S)
    # 3. reselect the pure-control set two ways (actual treated group untouched)
    selA = ctrl_arr[C == 0]
    order = np.lexsort((rng.random(NF), C))                # random tie-break within C
    selB = ctrl_arr[order[:N_PURE]]
    for tag, sel in (("A", selA), ("B", selB)):
        keep_ids = treated_ids | set(sel)
        for outcome in args.outcomes:
            d, fe = OC[outcome]
            b, se, n_obs, n_firm = fit(d[d.identificad.isin(keep_ids)], fe, outcome)
            R_ = res[outcome][tag]
            R_["b"][r], R_["se"][r] = b, se
            R_["n_obs"][r], R_["n_ctrl"][r] = n_obs, len(sel)
            R_["overlap"][r] = len(set(sel) & obs_pure) / len(sel) if len(sel) else np.nan
    if r < 3 or (r + 1) % 50 == 0:
        el = time.time() - t0
        print(f"  draw {r+1}/{R} | A: n_ctrl={len(selA):5d} b={res[args.outcomes[0]]['A']['b'][r]:+.5f} "
              f"| B: n_ctrl={len(selB):5d} b={res[args.outcomes[0]]['B']['b'][r]:+.5f} "
              f"| {el:.0f}s ({el/(r+1):.2f}s/draw)", flush=True)

# ── summarize + save ────────────────────────────────────────────────────────
summary = dict(scheme=args.scheme, R=R, seed=args.seed,
               n_treated=len(treated_ids), n_controls=len(control_ids),
               n_obs_pure=N_PURE, pure_share=X_SHARE,
               n_isolated_controls=n_isolated,
               w_validation=dict(n_w_pure=len(w_pure), n_panel_pure=N_PURE,
                                 agree=inter, jaccard=inter / union),
               swappable_treated=int(n_swappable), mixed_strata=int(mixed),
               outcomes={})

for outcome in args.outcomes:
    bC, bA = base[outcome]["panelC"], base[outcome]["panelA"]
    o_sum = dict(panelC=dict(b=bC[0], se=bC[1], n_obs=bC[2], n_firms=bC[3]),
                 panelA=dict(b=bA[0], se=bA[1], n_obs=bA[2], n_firms=bA[3]),
                 inflation=bA[0] - bC[0])
    for tag in ("A", "B"):
        b = res[outcome][tag]["b"]
        ok = ~np.isnan(b)
        bb = b[ok]
        # Randomization p-values. The reference point is the OBSERVED pure-control
        # estimate: how extreme is it against placebo control selections?
        p_up  = float((np.sum(bb >= bA[0]) + 1) / (bb.size + 1))
        p_two = float((np.sum(np.abs(bb - bC[0]) >= abs(bA[0] - bC[0])) + 1) / (bb.size + 1))
        o_sum[f"proc{tag}"] = dict(
            mean=float(bb.mean()), median=float(np.median(bb)), sd=float(bb.std(ddof=1)),
            q = {q: float(np.quantile(bb, q/100)) for q in (1, 5, 10, 25, 50, 75, 90, 95, 99)},
            mean_se=float(np.nanmean(res[outcome][tag]["se"][ok])),
            pct_of_obs_pure=float((bb < bA[0]).mean() * 100),   # percentile of Panel A in placebos
            p_upper=p_up, p_two_sided_vs_panelC=p_two,
            n_valid=int(ok.sum()),
            mean_n_ctrl=float(res[outcome][tag]["n_ctrl"][ok].mean()),
            min_n_ctrl=int(res[outcome][tag]["n_ctrl"][ok].min()),
            max_n_ctrl=int(res[outcome][tag]["n_ctrl"][ok].max()),
            mean_overlap=float(np.nanmean(res[outcome][tag]["overlap"][ok])),
        )
        s = o_sum[f"proc{tag}"]
        print(f"  [{outcome:15s}/{tag}] placebo mean={s['mean']:+.5f} sd={s['sd']:.5f} "
              f"| PanelC={bC[0]:+.5f} PanelA={bA[0]:+.5f} | PanelA percentile={s['pct_of_obs_pure']:.1f} "
              f"p_up={s['p_upper']:.4f} | mean n_ctrl={s['mean_n_ctrl']:.0f} "
              f"overlap={s['mean_overlap']:.3f}")
    summary["outcomes"][outcome] = o_sum

np.savez(OUT / f"direct_cf_placebo_{args.scheme}.npz",
         **{f"{o}_{t}_{k}": res[o][t][k]
            for o in args.outcomes for t in ("A", "B") for k in ("b", "se", "n_obs", "n_ctrl", "overlap")},
         **{f"base_{o}_{p}": np.array(base[o][p][:2]) for o in args.outcomes for p in ("panelC", "panelA")})
TAB.mkdir(exist_ok=True)
with open(TAB / f"direct_cf_placebo_{args.scheme}.json", "w") as f:
    json.dump(summary, f, indent=2)
print("saved:", TAB / f"direct_cf_placebo_{args.scheme}.json", f"({time.time()-t0:.0f}s)")
