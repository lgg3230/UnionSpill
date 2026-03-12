"""
01_prep_data.py — Worker-Level Wage Regressions: Data Preparation
================================================================
Merges worker_estab_lagos.parquet with firm-level DTA to produce
worker_wages_panel.dta for use in 02_regressions.do.

Outputs:
  Data/worker_wages/worker_wages_panel.dta
"""

import numpy as np
import pandas as pd
import subprocess
from pathlib import Path

ROOT     = Path(__file__).resolve().parent.parent.parent
parquet  = ROOT / "Data/RAIS_aux/worker_estab_lagos.parquet"
firm_dta = ROOT / "Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
tf_csv   = ROOT / "Data/RAIS_aux/totalflows_wide_2007_2011.csv"
out_dir  = ROOT / "Data/worker_wages"
out_dir.mkdir(exist_ok=True)

# ── 1. Load worker parquet ────────────────────────────────────────────────────
print("Loading worker parquet...")
keep_parquet = [
    "identificad", "year", "PIS_w",
    "lr_remdezr_h",          # firm-level log hourly Dec wage
    "r_remdezr_h_w",         # individual real hourly Dec wage (raw, for log)
    "lr_remdezr_w",          # individual log Dec wage (cross-check)
    "avg_ftreat_pf_n",       # pre-treatment proportion to treated (firm-constant)
    "totalflows_n_pw_2009",  # pre-treatment per-worker flows (cross-check)
    "totaltreat_pw_n",       # main connectivity (time-invariant)
    "l_firm_emp",
    "in_balanced_panel", "lagos_sample_avg", "treat_ultra",
    "industry1", "mode_base_month", "microregion",
    "grinstrucao_w", "genero_w", "raca_cor_w", "ocup2002_w", "idade_w",
]
df = pd.read_parquet(parquet, columns=keep_parquet)
df = df[df["year"].between(2009, 2016)].copy()
print(f"  Parquet rows (2009-2016): {len(df):,}")

# ── 2. Compute lr_remdezr_h_w (individual worker log hourly Dec wage) ─────────
# r_remdezr_h_w is the real (deflated) hourly December wage at worker level
df["lr_remdezr_h_w"] = np.where(
    df["r_remdezr_h_w"] > 0,
    np.log(df["r_remdezr_h_w"]),
    np.nan
)

# ── 3. Merge firm DTA for totaltreat_pw_norm, firm_emp ──────────────────────
print("Loading firm DTA...")
firm_cols = ["identificad", "year", "totaltreat_pw_norm", "totaltreat_pw_n",
             "firm_emp", "l_firm_emp"]
firm = pd.read_stata(firm_dta, columns=firm_cols)
firm = firm.rename(columns={
    "l_firm_emp": "l_firm_emp_firm",   # rename to avoid collision
})

df = df.merge(firm[["identificad", "year", "totaltreat_pw_norm",
                     "firm_emp", "l_firm_emp_firm"]],
              on=["identificad", "year"], how="left")

# Use firm DTA l_firm_emp where parquet one is missing
df["l_firm_emp"] = df["l_firm_emp"].fillna(df["l_firm_emp_firm"])
df.drop(columns=["l_firm_emp_firm"], inplace=True)

print(f"  After merge: {len(df):,} rows, {df['identificad'].nunique():,} firms")

# ── 4. Load totalflows_wide_2007_2011.csv for totalflows_pw_pre_07_11 ─────────
print("Loading totalflows wide CSV...")
tf = pd.read_csv(tf_csv)
tf["identificad"] = tf["identificad"].astype(str).str.zfill(14)

# Compute average per-worker pairwise flows 2007-2011 (missing-safe)
yp_cols = ["totalflows_pw_07_08", "totalflows_pw_08_09",
           "totalflows_pw_09_10", "totalflows_pw_10_11"]
yp_cols_present = [c for c in yp_cols if c in tf.columns]
tf["totalflows_pw_pre_07_11"] = tf[yp_cols_present].mean(axis=1, skipna=True)
# If all year-pairs are missing, leave as NaN
all_na = tf[yp_cols_present].isna().all(axis=1)
tf.loc[all_na, "totalflows_pw_pre_07_11"] = np.nan

tf_merge = tf[["identificad", "totalflows_pw_pre_07_11"]].drop_duplicates("identificad")
df = df.merge(tf_merge, on="identificad", how="left")
print(f"  totalflows_pw_pre_07_11 non-missing: {df['totalflows_pw_pre_07_11'].notna().sum():,}")

# ── 5. Inverse employment weight ──────────────────────────────────────────────
df["inv_firm_emp"] = 1.0 / df["firm_emp"].clip(lower=1)

# ── 6. Normalize avg_ftreat_pf_n (for firm×year FE spec) ─────────────────────
s = (df.lagos_sample_avg == 1) & (df.in_balanced_panel == 1) & (df.treat_ultra == 0)
p90_pf = df.loc[s & (df.year == 2009), "avg_ftreat_pf_n"].quantile(0.9)
df["totaltreat_pf_norm"] = df["avg_ftreat_pf_n"] / p90_pf
print(f"  avg_ftreat_pf_n p90 (spillover sample, 2009): {p90_pf:.6f}")

# totaltreat_pw_norm verification (already merged from firm DTA)
p90_check = df.loc[s & (df.year == 2009), "totaltreat_pw_n"].quantile(0.9)
print(f"  totaltreat_pw_n p90 (spillover sample, 2009): {p90_check:.6f}")
print(f"  totaltreat_pw_norm p90: {df.loc[s & (df.year==2009), 'totaltreat_pw_norm'].quantile(0.9):.4f} (should be ~1.0)")

# ── 7. totalflows_pw_pre_07_114: 4-bin of pre-treatment avg totalflows/worker ──
# Bin at year==2009 obs, then broadcast to all years within firm
yr2009_mask = df["year"] == 2009
tf_vals = df.loc[yr2009_mask & df["in_balanced_panel"].eq(1), "totalflows_pw_pre_07_11"].fillna(0)
bins = pd.qcut(tf_vals, q=4, labels=False, duplicates="drop")
bin_map = dict(zip(df.loc[yr2009_mask & df["in_balanced_panel"].eq(1), "identificad"], bins))
df["totalflows_pw_pre_07_114"] = df["identificad"].map(bin_map)
df["totalflows_pw_pre_07_114"] = df.groupby("identificad")["totalflows_pw_pre_07_114"].transform("min")
df["totalflows_pw_pre_07_114"] = df["totalflows_pw_pre_07_114"].fillna(0).astype(float)

# ── 8. outcome_pre4 bins for both outcomes ────────────────────────────────────
for out_var in ["lr_remdezr_h", "lr_remdezr_h_w"]:
    # Pre-treatment mean (2009-2011)
    pre_mean = (df[df.year.between(2009, 2011)]
                .groupby("identificad")[out_var].mean())
    df[f"{out_var}_pre"] = df["identificad"].map(pre_mean)

    # 4-bin from year==2009 cross-section (in_balanced_panel==1)
    pre_vals_2009 = df.loc[yr2009_mask & df["in_balanced_panel"].eq(1),
                           f"{out_var}_pre"]
    pre_bins = pd.qcut(pre_vals_2009, q=4, labels=False, duplicates="drop")
    bin_map_pre = dict(zip(
        df.loc[yr2009_mask & df["in_balanced_panel"].eq(1), "identificad"],
        pre_bins
    ))
    df[f"{out_var}_pre4"] = df["identificad"].map(bin_map_pre)
    df[f"{out_var}_pre4"] = df.groupby("identificad")[f"{out_var}_pre4"].transform("min")
    df[f"{out_var}_pre4"] = df[f"{out_var}_pre4"].fillna(0).astype(float)

# ── 9. l_firm_emp_pre4: 4-bin of pre-treatment log employment ─────────────────
pre_emp = (df[df.year.between(2009, 2011)]
           .groupby("identificad")["l_firm_emp"].mean())
df["l_firm_emp_pre"] = df["identificad"].map(pre_emp)

lfe_vals_2009 = df.loc[yr2009_mask & df["in_balanced_panel"].eq(1), "l_firm_emp_pre"]
lfe_bins = pd.qcut(lfe_vals_2009, q=4, labels=False, duplicates="drop")
lfe_bin_map = dict(zip(
    df.loc[yr2009_mask & df["in_balanced_panel"].eq(1), "identificad"],
    lfe_bins
))
df["l_firm_emp_pre4"] = df["identificad"].map(lfe_bin_map)
df["l_firm_emp_pre4"] = df.groupby("identificad")["l_firm_emp_pre4"].transform("min")
df["l_firm_emp_pre4"] = df["l_firm_emp_pre4"].fillna(0).astype(float)

# ── 10. Period indicators ──────────────────────────────────────────────────────
df["treat_year"]   = (df["year"] >= 2012).astype("int8")
df["placebo_year"] = (df["year"] <  2011).astype("int8")

# ── 11. Save ──────────────────────────────────────────────────────────────────
# Drop helper columns not needed in Stata
drop_cols = ["r_remdezr_h_w", "lr_remdezr_w",
             "lr_remdezr_h_pre", "lr_remdezr_h_w_pre",
             "l_firm_emp_pre"]
df.drop(columns=[c for c in drop_cols if c in df.columns], inplace=True)

out_path = str(out_dir / "worker_wages_panel.dta")
print(f"Saving to {out_path} ...")
df.to_stata(out_path, write_index=False, version=118)
print(f"Done. {len(df):,} rows saved.")

# ── Summary stats ─────────────────────────────────────────────────────────────
spill = df[(df.lagos_sample_avg == 1) & (df.treat_ultra == 0) & (df.in_balanced_panel == 1)]
print(f"\nSpillover sample rows: {len(spill):,}")
print(f"Unique firms (spillover): {spill['identificad'].nunique():,}")
print(f"Years: {sorted(df.year.unique())}")
print(f"totaltreat_pw_norm describe:\n{spill.loc[spill.year==2009,'totaltreat_pw_norm'].describe()}")

subprocess.run(["curl", "-s", "-o", "/dev/null",
                "-H", "Title: Done",
                "-d", "01_prep_data.py complete — worker_wages pipeline",
                "https://ntfy.sh/lgg3230-kellogg"])
