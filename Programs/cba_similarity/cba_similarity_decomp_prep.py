"""
cba_similarity_decomp_prep.py

Ordered decomposition of the CBA similarity change, weighted-reference branch.

For each untreated focal firm i and CBA period t we need three similarity
scores per measure S in {cosine, bray_curtis, total_variation, ruzicka}:

  curr  : S(u_{it}, T_{it})    — both sides move (the headline outcome)
  uref2 : S(u_{it}, T_{i2})    — focal moves, treated reference frozen at p2
  u2ref : S(u_{i2}, T_{it})    — focal frozen at p2, treated reference moves

These three columns are then combined inside Stata into the five regression
outcomes (DeltaS, UntreatedMove, TreatedMove, TreatedAdditional,
UntreatedAdditional) per measure. With firm FE the algebraic
baseline S(u_{i2}, T_{i2}) is absorbed, so it is not stored.

T_{it} is the bilateral-conn-weighted partner reference — same weights as the
headline cba_similarity_prep.py (bilateral_conn_pw, uncorrected). All three
similarity scores must use this single weight definition for the coefficient
identity

    beta_DeltaS = beta_UntreatedMove + beta_TreatedAdditional
                = beta_TreatedMove   + beta_UntreatedAdditional

to hold to machine precision.

Inputs (already produced by upstream scripts):
  Data/RAIS_aux/cba_similarity_panel.dta
      → S(u_{it}, T_{it}) per measure, columns: cosine, bray_curtis,
        total_variation, ruzicka.
  Data/RAIS_aux/cba_similarity_pretreat_ref_uncorr_w_panel.dta
      → S(u_{it}, T_{i2}).  Same weights as the legacy panel.
  Data/RAIS_aux/cba_similarity_focal_frozen_panel.dta
      → S(u_{i2}, T_{it}).  Same weights as the legacy panel.

All three upstream prep scripts already inner-merge their output with
cba_similarity_panel.dta on (identificad, cba_period), so the samples are
already aligned. This script intersects them once more for safety and
reports the final row count.

Output:
  Data/RAIS_aux/cba_similarity_decomp_panel.dta
      one row per (identificad, cba_period); 12 similarity columns plus
      identificad, cba_period.
"""

from pathlib import Path
import subprocess

import pandas as pd

main     = Path("/kellogg/proj/lgg3230")
rais_aux = main / "UnionSpill/Data/RAIS_aux"

curr_path  = rais_aux / "cba_similarity_panel.dta"
uref2_path = rais_aux / "cba_similarity_pretreat_ref_uncorr_w_panel.dta"
u2ref_path = rais_aux / "cba_similarity_focal_frozen_panel.dta"
out_path   = rais_aux / "cba_similarity_decomp_panel.dta"

MEASURES = ["cosine", "bray_curtis", "total_variation", "ruzicka"]


def load_and_rename(path: Path, suffix: str) -> pd.DataFrame:
    print(f"Loading {path.name} ...", flush=True)
    df = pd.read_stata(str(path), convert_categoricals=False)
    df["identificad"] = df["identificad"].astype(str).str.strip().str.zfill(14)
    df = df[["identificad", "cba_period"] + MEASURES].copy()
    df = df.rename(columns={m: f"{m}_{suffix}" for m in MEASURES})
    print(f"  {len(df):,} rows", flush=True)
    return df


curr  = load_and_rename(curr_path,  "curr")
uref2 = load_and_rename(uref2_path, "uref2")
u2ref = load_and_rename(u2ref_path, "u2ref")

print("Inner-merging the three panels on (identificad, cba_period) ...",
      flush=True)
merged = curr.merge(uref2, on=["identificad", "cba_period"], how="inner")
merged = merged.merge(u2ref, on=["identificad", "cba_period"], how="inner")
print(f"  curr  rows:  {len(curr):,}", flush=True)
print(f"  uref2 rows:  {len(uref2):,}", flush=True)
print(f"  u2ref rows:  {len(u2ref):,}", flush=True)
print(f"  merged rows: {len(merged):,}  "
      f"({merged['identificad'].nunique():,} firms)", flush=True)

# Sanity check: every measure column non-missing on the merged sample.
sim_cols = [f"{m}_{s}" for s in ("curr", "uref2", "u2ref") for m in MEASURES]
nonmiss_counts = merged[sim_cols].notna().sum()
print("Non-missing counts per similarity column:", flush=True)
for col in sim_cols:
    print(f"  {col:<32} {int(nonmiss_counts[col]):,}", flush=True)

print(f"Saving {len(merged):,} firm-period observations to {out_path}",
      flush=True)
merged.to_stata(str(out_path), write_index=False, version=118)

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: cba_similarity_decomp_prep done",
     "-d", f"Saved {len(merged):,} obs to cba_similarity_decomp_panel.dta",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
