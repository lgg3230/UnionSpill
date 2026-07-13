#!/usr/bin/env python
"""
Rebuild connectivity-to-CONTROL-firms independently from the flow weights, as the
mirror of totaltreat_pw_n: totalcontrol_pw_n_i = sum_{j in C} W_ij, with the
control set C = all untreated Lagos firms (treat_ultra==0), paralleling the
treated set (all treated). Uses flow_weights.parquet (the same W that reproduces
totaltreat_pw_n). Validated against connectivity_control_2007_2011_agg.dta.

Normalized by its own 90th percentile in the spillover sample (untreated balanced
firms), so a unit is the 90th percentile of the control measure, comparable to
totaltreat_pw_norm.

Output: Data/rand_inference/control_connectivity.dta / .csv
        (identificad, totalcontrol_pw_n, totalcontrol_pw_norm)
"""
import numpy as np, pandas as pd
from pathlib import Path

OUT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference")
AUX = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux")

K = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})
control = set(K.loc[K.treat_ultra == 0, "identificad"])      # all untreated Lagos firms

W = pd.read_parquet(OUT / "flow_weights.parquet")
W["j"] = W.j.astype(str); W["i"] = W.i.astype(str)
tc = W[W.j.isin(control)].groupby("i")["W"].sum().rename("totalcontrol_pw_n")

# every focal firm that appears in the flow network; firms with no control edges -> 0
focal = pd.Index(sorted(set(W.i)), name="identificad")
tc = tc.reindex(focal).fillna(0.0).reset_index()

# ── validate vs the existing MATLAB-built measure ────────────────────────────
agg = (pd.read_stata(AUX / "connectivity_control_2007_2011_agg.dta",
                     columns=["identificad", "totalcontrol_pw_n"])
       .set_index("identificad")["totalcontrol_pw_n"])
chk = tc.set_index("identificad").join(agg.rename("ref"), how="inner").dropna()
chk = chk[chk.index.isin(control)]           # compare on the untreated focal set
d = (chk.totalcontrol_pw_n - chk["ref"]).abs()
print(f"validation vs connectivity_control_agg: n={len(chk)} corr={chk.totalcontrol_pw_n.corr(chk["ref"]):.6f} "
      f"maxdiff={d.max():.6f} frac<1e-6={np.mean(d < 1e-6):.3f}")

# ── normalize by own p90 in the spillover sample (untreated balanced) ────────
sp = set(K.loc[(K.treat_ultra == 0) & (K.in_balanced_panel == 1), "identificad"])
p90 = float(np.percentile(tc.loc[tc.identificad.isin(sp), "totalcontrol_pw_n"], 90))
tc["totalcontrol_pw_norm"] = tc.totalcontrol_pw_n / p90
print(f"control p90 (spillover sample) = {p90:.5f}; "
      f"norm mean={tc.totalcontrol_pw_norm.mean():.3f} max={tc.totalcontrol_pw_norm.max():.2f}")

tc.to_stata(OUT / "control_connectivity.dta", write_index=False, version=118)
tc.to_csv(OUT / "control_connectivity.csv", index=False)
print("saved:", OUT / "control_connectivity.dta", "| firms:", len(tc))
