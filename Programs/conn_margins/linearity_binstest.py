#!/usr/bin/env python3
"""
Formal Cattaneo et al. (2024) linearity test via binstest.

H0: E[raw_did | conn_firm, w] is a degree-1 polynomial (linear) in conn_firm.

Uses the same data, outcome, predictor, and control matrix as
linearity_fig3_binsreg_corrected.py.  The test statistic is a sup-norm
(L-inf) distance between the nonparametric binsreg fit and the linear fit,
with a p-value computed by Gaussian-process simulation (nsims=2000).

Reference: Cattaneo, Crump, Farrell, Feng (2024) "On Binscatter," AER 114(5).

Output:
  Tables/conn_margins/linearity_binstest.csv   — machine-readable results
"""

import warnings
import numpy as np
import pandas as pd
from binsreg import binstest
from pathlib import Path
import subprocess

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
tables_dir.mkdir(parents=True, exist_ok=True)

# ── Load data (same as linearity_fig3_binsreg_corrected.py) ──────────────────

df = pd.read_csv(tables_dir / "scatter_raw_controls.csv")
df = df.dropna(subset=["conn_firm", "raw_did"])
print(f"Firms: {len(df):,}")

cat_cols = ["industry1", "mode_base_month", "microregion",
            "lr_remdezr_w_pre4", "l_firm_emp_pre4", "totalflows_pw_pre_07_114"]
for col in cat_cols:
    df[col] = df[col].astype("category")

W = pd.get_dummies(df[cat_cols], drop_first=True, dtype=float)
print(f"Control matrix: {W.shape[1]} dummies")

# Slight jitter on x to break exact ties (same as corrected figure)
np.random.seed(42)
x_jitter = df["conn_firm"].values.astype(float) + np.random.uniform(0, 1e-8, len(df))

df_bs = pd.DataFrame({"y": df["raw_did"].values.astype(float), "x": x_jitter})
df_bs = pd.concat([df_bs, W.reset_index(drop=True)], axis=1)
w_cols = W.columns.tolist()

# ── Linearity test ────────────────────────────────────────────────────────────
# testmodelpoly=1  : H0 is that the CEF is linear in x (degree-1 polynomial)
# lp=inf (default) : sup-norm statistic — most conservative, standard choice
# nsims=2000       : publication-quality simulation precision
# simsgrid=50      : evaluation grid density per bin (default 20)

print("\nRunning binstest (testmodelpoly=1, nsims=2000, simsgrid=50) ...")
print("This may take 1–3 minutes.\n")

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binstest("y", "x", w=w_cols, data=df_bs,
                   testmodelpoly=1,
                   nsims=2000, simsgrid=50,
                   simsseed=42)

# ── Extract results ───────────────────────────────────────────────────────────

tp    = res.testpoly        # test_str object with attrs: val, stat, pval
nbins = res.options.nbins

stat = float(tp.stat[0])
pval = float(tp.pval[0])

print("=" * 55)
print("Linearity test (Cattaneo et al. 2024)")
print("H0: E[y|x,w] is linear in x")
print("-" * 55)
print(f"  Bins (data-driven DPI):  {nbins}")
print(f"  Test statistic (sup-t):  {stat:.4f}")
print(f"  P-value (2000 sims):     {pval:.4f}")
print("=" * 55)
if pval < 0.01:
    conclusion = "Reject linearity at 1%"
elif pval < 0.05:
    conclusion = "Reject linearity at 5%"
elif pval < 0.10:
    conclusion = "Reject linearity at 10%"
else:
    conclusion = "Cannot reject linearity"
print(f"  Conclusion: {conclusion}")
print("=" * 55)

# ── Save to CSV ───────────────────────────────────────────────────────────────

out_df = pd.DataFrame({
    "test":       ["linearity (testmodelpoly=1)"],
    "outcome":    ["raw_did"],
    "predictor":  ["conn_firm"],
    "nbins":      [nbins],
    "stat_supt":  [stat],
    "pval":       [pval],
    "nsims":      [2000],
    "simsgrid":   [50],
    "lp":         ["inf"],
    "conclusion": [conclusion],
})
out_path = tables_dir / "linearity_binstest.csv"
out_df.to_csv(out_path, index=False)
print(f"\nSaved: {out_path}")

# ── Notify ────────────────────────────────────────────────────────────────────

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: binstest done",
     "-d", f"linearity test: stat={stat:.4f}, p={pval:.4f}, {conclusion}",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False
)
