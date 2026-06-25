"""
direction_convergence_geometry.py

Positive characterization of the "joint convergence to a NOVEL region" claim that the
existing fixed-benchmark pipeline (direction_convergence_*.do) cannot deliver on its own.

The fixed-benchmark regressions only test whether a firm moves toward its connected
counterpart's *period-2 (2011)* clause vector. A null there says "not converging to the
other group's old position" — necessary but NOT sufficient for "both move to a new common
region." This script supplies the missing pieces, all from the main firm-year panel:

  #1  Displacement-vector geometry (group centroids):
        dT = Tpost - Tpre ,  dU = Upost - Upre
        |dT|, |dU|, angle(dT,dU)              -> do both groups move the SAME direction?
        sim(Upost,Tpre) vs sim(Upre,Tpre)     -> is U approaching T's 2011 state? (claim: no)
        sim(Tpost,Upre) vs sim(Tpre,Upre)     -> is T approaching U's 2011 state? (claim: no)
        sim(Tpost,Upost) vs sim(Tpre,Upre)    -> do the two groups converge to each other?
        sim(Upost,Upre), sim(Tpost,Tpre)      -> how far each moved from its own baseline
      all in the project's four similarity measures.

  #4  Clause-group decomposition (10 Sistema-Mediador groups, leading digit of cl_ code):
        group shares in Tpre/Tpost/Upre/Upost, dShareT_g, dShareU_g, sign agreement.

  trajectory: centroid similarity to the two fixed anchors (Tpre2, Upre2) by cba_period.

  #2/#3 (local proxy) connectivity-graded firm-level regression:
        per-firm similarity to the FIXED treated period-2 centroid (old region) and to the
        FIXED treated POST centroid (new region), on connectivity x post, firm+period FE,
        with and without a mode_union x post control. (True partner-weighted benchmarks and a
        federation/CUT control need the bilateral file / a federation variable -> cluster.)

Outputs (Tables/direction_convergence/geometry/):
  geometry_centroid_metrics.csv
  geometry_group_decomposition.csv
  geometry_centroid_trajectory.csv
  geometry_connectivity_graded.csv
  geometry_summary.md           (human-readable, all panels)
"""

import os
import getpass
from pathlib import Path
import numpy as np
import pandas as pd

# ── paths (machine-detect, mirror the .do wrapper) ────────────────────────────
user = getpass.getuser()
if user == "lgg3230":
    ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
else:
    ROOT = Path("/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/"
                "4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill")

PANEL = ROOT / "Data/CBA_rais_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
if not PANEL.exists():  # cluster uses upper-case dir
    PANEL = ROOT / "Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
OUT = ROOT / "Tables/direction_convergence/geometry"
OUT.mkdir(parents=True, exist_ok=True)

CONN_VAR = "totaltreat_pw_n"   # firm->treated connectivity (panel's own pre measure)

GROUP_LABELS = {
    "0": "Unclassified",
    "1": "Pay / Remuneration",
    "2": "Bonuses & Allowances",
    "3": "Employment / Job security",
    "4": "Work relations & Equality",
    "5": "Workday / Hours",
    "6": "Health & Safety",
    "7": "Vacation & Leave",
    "8": "Union relations",
    "9": "General / Enforcement",
}

# ── 1. load only what we need ─────────────────────────────────────────────────
print("Reading panel (selected columns)...")
itr = pd.read_stata(PANEL, chunksize=20, convert_categoricals=False)
allcols = list(next(itr).columns)
cl_cols = [c for c in allcols if c.startswith("cl_")]
need = ["identificad", "treat_ultra", "cba_period", "in_balanced_panel", "year",
        "mode_union", CONN_VAR] + cl_cols
need = [c for c in need if c in allcols]
df = pd.read_stata(PANEL, columns=need, convert_categoricals=False)
print(f"  raw rows: {len(df):,}; cl vars: {len(cl_cols)}")

# same restrictions as the pipeline
df = df[(df["in_balanced_panel"] == 1) & (df["year"] >= 2009)
        & df["cba_period"].notna() & df["mode_union"].notna()
        & df["treat_ultra"].notna()].copy()
print(f"  after filters: {len(df):,} rows")
print("  cba_period dist:\n", df["cba_period"].value_counts().sort_index())
print("  treat_ultra dist:\n", df["treat_ultra"].value_counts())

# ── 2. collapse to firm x cba_period (mean of cl_) ────────────────────────────
def _modal(s):
    s = s.dropna()
    return s.mode().iloc[0] if len(s) else np.nan

agg = {c: "mean" for c in cl_cols}
agg["treat_ultra"] = "max"
agg["mode_union"] = _modal
agg[CONN_VAR] = "mean"
fp = df.groupby(["identificad", "cba_period"], as_index=False).agg(agg)
print(f"  firm x cba_period rows: {len(fp):,}; firms: {fp['identificad'].nunique():,}")

fp["bucket"] = np.where(fp["cba_period"] >= 3, "post",
                np.where(fp["cba_period"] == 2, "pre", "early"))  # pre = period 2 (2011)

# ── 3. similarity helpers (same 4 measures as the pipeline) ───────────────────
def _shares(v):
    s = v.sum()
    return v / s if s > 0 else v * 0.0

def sim_all(a, b):
    a = np.asarray(a, float); b = np.asarray(b, float)
    sa, sb = _shares(a), _shares(b)
    out = {}
    na, nb = np.linalg.norm(sa), np.linalg.norm(sb)
    out["cosine_shares"] = float(sa @ sb / (na * nb)) if na > 0 and nb > 0 else np.nan
    out["tv_shares"] = float(1 - 0.5 * np.abs(sa - sb).sum())
    mx = np.maximum(a, b).sum()
    out["ruzicka_counts"] = float(np.minimum(a, b).sum() / mx) if mx > 0 else np.nan
    den = (a + b).sum()
    out["bc_counts"] = float(1 - np.abs(a - b).sum() / den) if den > 0 else np.nan
    return out

def disp_angle(d1, d2):
    n1, n2 = np.linalg.norm(d1), np.linalg.norm(d2)
    return float(d1 @ d2 / (n1 * n2)) if n1 > 0 and n2 > 0 else np.nan

# ── 4. group centroids (mean count vector across firms) ───────────────────────
def centroid(mask):
    return fp.loc[mask, cl_cols].mean().to_numpy(float)

T_pre  = centroid((fp.treat_ultra == 1) & (fp.bucket == "pre"))
T_post = centroid((fp.treat_ultra == 1) & (fp.bucket == "post"))
U_pre  = centroid((fp.treat_ultra == 0) & (fp.bucket == "pre"))
U_post = centroid((fp.treat_ultra == 0) & (fp.bucket == "post"))

# ── #1 centroid geometry table ────────────────────────────────────────────────
rows = []
def add(label, a, b):
    r = {"comparison": label, **sim_all(a, b)}
    rows.append(r)

add("U_post vs T_pre  (U approaching T's 2011?)", U_post, T_pre)
add("U_pre  vs T_pre  (baseline U-to-T2011)",     U_pre,  T_pre)
add("T_post vs U_pre  (T approaching U's 2011?)", T_post, U_pre)
add("T_pre  vs U_pre  (baseline T-to-U2011)",     T_pre,  U_pre)
add("T_post vs U_post (mutual: groups converge?)", T_post, U_post)
add("T_pre  vs U_pre  (baseline between-group)",   T_pre,  U_pre)
add("U_post vs U_pre  (U self-movement)",          U_post, U_pre)
add("T_post vs T_pre  (T self-movement)",          T_post, T_pre)
geo = pd.DataFrame(rows)

# displacement magnitudes & angle (counts and shares)
dT_c, dU_c = T_post - T_pre, U_post - U_pre
dT_s, dU_s = _shares(T_post) - _shares(T_pre), _shares(U_post) - _shares(U_pre)
disp = pd.DataFrame([
    {"quantity": "|dT| counts", "value": float(np.linalg.norm(dT_c))},
    {"quantity": "|dU| counts", "value": float(np.linalg.norm(dU_c))},
    {"quantity": "angle(dT,dU) counts [cos]", "value": disp_angle(dT_c, dU_c)},
    {"quantity": "|dT| shares", "value": float(np.linalg.norm(dT_s))},
    {"quantity": "|dU| shares", "value": float(np.linalg.norm(dU_s))},
    {"quantity": "angle(dT,dU) shares [cos]", "value": disp_angle(dT_s, dU_s)},
    {"quantity": "total clauses T_pre",  "value": float(T_pre.sum())},
    {"quantity": "total clauses T_post", "value": float(T_post.sum())},
    {"quantity": "total clauses U_pre",  "value": float(U_pre.sum())},
    {"quantity": "total clauses U_post", "value": float(U_post.sum())},
])
geo.to_csv(OUT / "geometry_centroid_metrics.csv", index=False)
disp.to_csv(OUT / "geometry_displacement.csv", index=False)

# ── #4 clause-group decomposition ─────────────────────────────────────────────
def grp(c):
    rest = c[3:]                      # after 'cl_'
    return rest[0] if rest[:1].isdigit() else "0"
groups = {g: [c for c in cl_cols if grp(c) == g] for g in GROUP_LABELS}

def grp_share(centroid_vec, cols_by_g):
    tot = centroid_vec.sum()
    out = {}
    cmap = {c: i for i, c in enumerate(cl_cols)}
    for g, cols in cols_by_g.items():
        idx = [cmap[c] for c in cols]
        out[g] = float(centroid_vec[idx].sum() / tot) if tot > 0 else np.nan
    return out

sT2, sTp = grp_share(T_pre, groups), grp_share(T_post, groups)
sU2, sUp = grp_share(U_pre, groups), grp_share(U_post, groups)
gd = []
for g, lab in GROUP_LABELS.items():
    dT = sTp[g] - sT2[g]; dU = sUp[g] - sU2[g]
    gd.append({"group": g, "label": lab, "n_clausetypes": len(groups[g]),
               "share_T_pre": sT2[g], "share_T_post": sTp[g], "dShare_T": dT,
               "share_U_pre": sU2[g], "share_U_post": sUp[g], "dShare_U": dU,
               "same_direction": "yes" if (dT * dU) > 0 else ("flat" if dT == 0 or dU == 0 else "no")})
gdf = pd.DataFrame(gd).sort_values("group")
gdf.to_csv(OUT / "geometry_group_decomposition.csv", index=False)

# ── trajectory: centroid sim to fixed anchors by cba_period ───────────────────
traj = []
for t in sorted(fp.cba_period.unique()):
    for grp_name, tv in [("treated", 1), ("untreated", 0)]:
        m = (fp.treat_ultra == tv) & (fp.cba_period == t)
        if m.sum() == 0:
            continue
        c = centroid(m)
        sT = sim_all(c, T_pre); sU = sim_all(c, U_pre)
        traj.append({"cba_period": int(t), "group": grp_name, "n_firms": int(m.sum()),
                     "sim_to_Tpre_cosine": sT["cosine_shares"],
                     "sim_to_Tpre_tv": sT["tv_shares"],
                     "sim_to_Upre_cosine": sU["cosine_shares"],
                     "sim_to_Upre_tv": sU["tv_shares"]})
tdf = pd.DataFrame(traj)
tdf.to_csv(OUT / "geometry_centroid_trajectory.csv", index=False)

# ── #2/#3 local proxy: connectivity-graded firm-level regression ──────────────
# per-firm similarity to FIXED treated period-2 centroid (old region) and to FIXED
# treated POST centroid (new region); on connectivity x post, firm + period FE,
# +/- mode_union x post control. Untreated firms only.
import pyfixest as pf
u = fp[fp.treat_ultra == 0].copy()
Xc = u[cl_cols].to_numpy(float)
def per_firm_sim(anchor):                       # vectorized: all rows vs one anchor vector
    a = np.asarray(anchor, float)
    xs = Xc.sum(1); asum = a.sum()
    S = np.divide(Xc, xs[:, None], out=np.zeros_like(Xc), where=xs[:, None] > 0)
    qa = a / asum if asum > 0 else a * 0.0
    nS = np.linalg.norm(S, axis=1); nq = np.linalg.norm(qa)
    cos = np.where((nS > 0) & (nq > 0), (S @ qa) / (nS * nq), np.nan)
    tv = np.where(nS > 0, 1 - 0.5 * np.abs(S - qa).sum(1), np.nan)
    mx = np.maximum(Xc, a).sum(1)
    ruz = np.where(mx > 0, np.minimum(Xc, a).sum(1) / mx, np.nan)
    den = (Xc + a).sum(1)
    bc = np.where(den > 0, 1 - np.abs(Xc - a).sum(1) / den, np.nan)
    return {"cosine_shares": cos, "tv_shares": tv, "ruzicka_counts": ruz, "bc_counts": bc}
old = per_firm_sim(T_pre); new = per_firm_sim(T_post)
for k in old:
    u[f"simOld_{k}"] = old[k]
    u[f"simNew_{k}"] = new[k]
u["post"] = (u.cba_period >= 3).astype(int)
u["firm_id"] = u.groupby("identificad").ngroup()
u["c_x_post"] = u[CONN_VAR].fillna(0) * u["post"]
u["munion"] = u["mode_union"].astype("Int64").astype(str)

reg_rows = []
# Two FE specs that stay cheap on the small local sample:
#   base  = firm + period FE (within-firm; effect off the post interaction)
#   union = union + period FE (within-union; do more-connected firms in the SAME union
#           converge more?). The full partner-level union control (same_union_wshare) is in
#           direction_convergence_currentbench_prep.py (cluster).
for region, pre in [("old(T_pre)", "simOld_"), ("new(T_post)", "simNew_")]:
    for meas in ["cosine_shares", "tv_shares", "ruzicka_counts", "bc_counts"]:
        y = f"{pre}{meas}"
        d = u[[y, "c_x_post", "firm_id", "cba_period", "munion", "identificad"]].dropna()
        for spec, fe in [("base", "firm_id + cba_period")]:
            try:
                m = pf.feols(f"{y} ~ c_x_post | {fe}", data=d, vcov={"CRV1": "identificad"})
                b = float(m.coef()["c_x_post"]); se = float(m.se()["c_x_post"])
                reg_rows.append({"region": region, "measure": meas, "spec": spec,
                                 "coef": b, "se": se, "t": b / se if se else np.nan,
                                 "N": int(m._N)})
            except Exception as e:
                reg_rows.append({"region": region, "measure": meas, "spec": spec,
                                 "coef": np.nan, "se": np.nan, "t": np.nan, "N": 0,
                                 "err": str(e)[:60]})
rdf = pd.DataFrame(reg_rows)
rdf.to_csv(OUT / "geometry_connectivity_graded.csv", index=False)

# ── human-readable summary ────────────────────────────────────────────────────
def md_table(df_, floats=4):
    d = df_.copy()
    for c in d.columns:
        if d[c].dtype.kind in "fc":
            d[c] = d[c].map(lambda x: "" if pd.isna(x) else f"{x:.{floats}f}")
    return d.to_markdown(index=False)

lines = []
lines.append("# Direction-of-convergence: geometry & decomposition\n")
lines.append(f"Panel: `{PANEL.name}`  |  firms (firm x period): {fp['identificad'].nunique():,}  "
             f"|  pre = cba_period==2, post = cba_period>=3\n")
lines.append("## #1 Centroid similarity (4 measures). Higher = closer.\n")
lines.append(md_table(geo) + "\n")
lines.append("## #1 Displacement vectors (do both groups move the same way?)\n")
lines.append(md_table(disp) + "\n")
lines.append("## #4 Clause-group decomposition (share of total clauses; dShare in pct points)\n")
lines.append(md_table(gdf) + "\n")
lines.append("## Centroid trajectory vs fixed anchors (cosine & TV on shares)\n")
lines.append(md_table(tdf) + "\n")
lines.append("## #2/#3 Connectivity-graded firm-level reg (untreated; coef on connectivity x post)\n")
lines.append("old(T_pre) = moving toward treated's 2011 bundle; new(T_post) = toward treated's post bundle.\n")
lines.append(md_table(rdf) + "\n")
(OUT / "geometry_summary.md").write_text("\n".join(lines))

print("\n=== WROTE ===")
for f in ["geometry_centroid_metrics.csv", "geometry_displacement.csv",
          "geometry_group_decomposition.csv", "geometry_centroid_trajectory.csv",
          "geometry_connectivity_graded.csv", "geometry_summary.md"]:
    print("  ", OUT / f)
print("\n----- SUMMARY -----\n")
print((OUT / "geometry_summary.md").read_text())
