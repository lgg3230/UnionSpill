#!/usr/bin/env python
"""
Randomization inference — validate the engine end-to-end BEFORE placebo draws.

(a) pyfixest with the PANEL's totaltreat_pw_norm must reproduce reghdfe/published
    (lr_remdezr_w: 0.00507, lr_remdezr_h_w: 0.00664).
(b) The W-engine baseline connectivity  C_i = sum_{j in T} W_ij, scaled to its own
    p90 among s_spill 2009, must reproduce the same delta-hat (validates that a
    placebo draw = swap the destination set in the same machinery).

The estimand (Main_Results eq. 4):
  reghdfe y c.norm##i.treat_year if s_spill,
    absorb(identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year
           ib0.<y>_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year)
    vce(cluster identificad)
norm and treat_year main effects are absorbed (norm is time-invariant -> firm FE;
treat_year -> any #year FE), so delta-hat = coef on the single regressor norm*treat_year.
"""
import numpy as np, pandas as pd, duckdb, pyfixest as pf
from pathlib import Path

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"

FE = ["identificad", "industry1^year", "mode_base_month^year", "microregion^year",
      "l_firm_emp_pre4^year", "totalflows_pw_pre_07_114^year"]

def run_spill(df, conn_col, outcome):
    """delta-hat for one outcome; outcome-specific pre4 bin enters the FE."""
    d = df[df.treat_ultra == 0].copy()
    d["conn_post"] = d[conn_col] * d["treat_year"]
    fe = FE + [f"{outcome}_pre4^year"]
    need = [outcome, "conn_post", "identificad", "year", "industry1",
            "mode_base_month", "microregion", "l_firm_emp_pre4",
            "totalflows_pw_pre_07_114", f"{outcome}_pre4", conn_col]
    d = d.dropna(subset=[outcome, conn_col, "industry1", "mode_base_month", "microregion"])
    m = pf.feols(f"{outcome} ~ conn_post | " + " + ".join(fe),
                 data=d, vcov={"CRV1": "identificad"})
    return float(m.coef()["conn_post"]), float(m.se()["conn_post"]), int(m._N)

# ---- load frame ----
df = pd.read_stata(OUT / "spill_frame.dta")
for c in ["industry1", "mode_base_month", "microregion", "l_firm_emp_pre4",
          "totalflows_pw_pre_07_114", "lr_remdezr_w_pre4", "lr_remdezr_h_w_pre4"]:
    df[c] = df[c].astype("category")
print("frame:", df.shape, " firms:", df.identificad.nunique(),
      " untreated:", (df.treat_ultra == 0).groupby(df.identificad).first().sum())

base = pd.read_stata(OUT / "baseline_spill_coefs.dta").set_index("outcome")
print("\npublished (reghdfe):")
print(base[["bhat", "se"]].round(6))

# ---- (a) panel norm through pyfixest ----
print("\n(a) pyfixest with PANEL totaltreat_pw_norm:")
for y in ["lr_remdezr_w", "lr_remdezr_h_w"]:
    b, se, N = run_spill(df, "totaltreat_pw_norm", y)
    tgt = base.loc[y, "bhat"]
    print(f"  {y:16s} b={b:.6f} se={se:.6f} N={N}  (target {tgt:.6f}, diff {b-tgt:+.2e})")

# ---- (b) W-engine baseline connectivity ----
con = duckdb.connect()
treated = df.loc[df.treat_ultra == 1, "identificad"].unique().tolist()
tdf = pd.DataFrame({"id": treated})
W = pd.read_parquet(OUT / "flow_weights.parquet")
C = (W.merge(tdf, left_on="j", right_on="id")
       .groupby("i", as_index=False)["W"].sum()
       .rename(columns={"i": "identificad", "W": "C_w"}))
df = df.merge(C, on="identificad", how="left")
df["C_w"] = df["C_w"].fillna(0.0)

# scale to own p90 among s_spill firms in 2009 (same rule as the panel)
mask09 = (df.treat_ultra == 0) & (df.year == 2009)
p90 = np.nanpercentile(df.loc[mask09, "C_w"], 90)
df["norm_w"] = df["C_w"] / p90
print(f"\n(b) W-engine baseline connectivity (own p90={p90:.6f}):")
for y in ["lr_remdezr_w", "lr_remdezr_h_w"]:
    b, se, N = run_spill(df, "norm_w", y)
    tgt = base.loc[y, "bhat"]
    print(f"  {y:16s} b={b:.6f} se={se:.6f} N={N}  (target {tgt:.6f}, diff {b-tgt:+.2e})")
