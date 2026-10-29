#!/usr/bin/env python3
"""
Continuous-treatment DiD (Zhang 2026) for the spillover effect: ATT(d) at each
level d of connectivity to treated firms, among untreated establishments, with
zero-connectivity establishments as the comparison group.

Input:  Data/RAIS_aux/drdid_firm_wide.dta (written by 3252_drdid.do)
Output: Tables/drdid/zhang_cdid_att.csv      ATT(d), SE, pointwise and uniform 95% bands
        Tables/drdid/zhang_cdid_support.csv  sample before / after the support screen

Design
  - 2x2 as in 3252: Y1 = mean 2012-16 (CBA periods 3-6 for clauses), Y0 = mean
    2009-11 (periods 1-2). Treatment D = connectivity scaled to its 2009 p90.
  - Support screen (Zhang's Assumption 2.3: kappa < P(D=0|X) < 1-kappa and
    f(d|X) > kappa over the dose range). Cells are the levels of the paper's
    absorbed controls: own-outcome 2009-11 quartile, employment quartile,
    2007-11 flows quartile, CBA base month, microregion, industry1. A level is
    kept if it holds at least one zero-connectivity firm and at least one exposed
    firm in each tercile of positive connectivity; repeated until stable.
  - Kernel on log connectivity: zero-connectivity firms get exactly zero kernel
    weight (no leakage of the D=0 mass point into low doses), and the bandwidth
    adapts to the skewed dose. ATT(d) is unchanged; only the smoothing scale is.
  - The author's bandwidth rule (1.06 sd N^-1/4 on the smoothed dose), grid
    (100 points over the 2.5-97.5 percentiles of positive dose), 5-fold
    cross-fitting, random-forest nuisances and 1,000 Gaussian multipliers.

Usage: python 3261_zhang_cdid.py [--outcomes lr_remdezr_h_w ...] [--grid 100] [--B 1000]
"""

import argparse
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE / "Zhang"))
from zhang_cdid import cdid_panel, default_estimators, multipliers, uniform_band  # noqa: E402

OUTCOMES = {  # outcome: (slot tag in drdid_firm_wide, own-outcome quartile)
    "lr_remdezr_w":   ("w",   "lr_remdezr_w_pre4"),
    "lr_remdezr_h_w": ("hw",  "lr_remdezr_h_w_pre4"),
    "l_firm_emp":     ("emp", "l_firm_emp_pre4"),
    "numb_clauses":   ("cl",  "numb_clauses_pre4"),
}
COMMON_CELLS = ["l_firm_emp_pre4", "totalflows_pw_pre_07_114", "month0", "mreg0", "ind4"]
SEED = 923   # the author's random_state, reused for the multipliers


def support_screen(df, dims, n_bins=3, min_ctrl=1, min_exposed=1):
    """Keep levels of every cell dimension holding zero-connectivity firms and exposed firms in each dose bin."""
    keep = pd.Series(True, index=df.index)
    while True:
        changed = False
        for v in dims:
            cur = df[keep]
            ok = cur[cur.nD == 1].groupby(v).size() >= min_ctrl
            for b in range(n_bins):
                ne = cur[cur.dose_bin == b].groupby(v).size()
                ok &= ne.reindex(ok.index).fillna(0) >= min_exposed
            drop = keep & ~df[v].isin(set(ok[ok].index))
            if drop.any():
                keep &= ~drop
                changed = True
        if not changed:
            return keep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outcomes", nargs="+", default=list(OUTCOMES))
    ap.add_argument("--grid", type=int, default=100)
    ap.add_argument("--B", type=int, default=1000)
    args = ap.parse_args()

    firm = pd.read_stata(ROOT / "Data" / "RAIS_aux" / "drdid_firm_wide.dta")
    missing = [c for c in COMMON_CELLS if c not in firm.columns]
    if missing:
        sys.exit(f"drdid_firm_wide.dta lacks {missing}: rerun 3251_drdid.do")

    out_dir = ROOT / "Tables" / "drdid"
    rows, support = [], []
    for y in args.outcomes:
        tag, own = OUTCOMES[y]
        cells = ([own] if own != "l_firm_emp_pre4" else []) + COMMON_CELLS
        df = firm[firm.treat_ultra == 0].copy()
        df["Y0"], df["Y1"] = df[f"y_{tag}_2"], df[f"y_{tag}_3"]
        df = df.dropna(subset=["Y0", "Y1", "connn0"] + cells).reset_index(drop=True)
        df["nD"] = (df.connn0 == 0).astype(int)
        df["dose_bin"] = np.nan
        pos = df.nD == 0
        df.loc[pos, "dose_bin"] = pd.qcut(df.loc[pos, "connn0"], 3, labels=False)
        n_in = (int((df.nD == 1).sum()), int(pos.sum()))

        keep = support_screen(df, cells)
        df = df[keep].reset_index(drop=True)
        n_ctrl, n_exp = int((df.nD == 1).sum()), int((df.nD == 0).sum())

        # Smoothed dose: log connectivity; controls at -inf, where the Gaussian kernel is exactly 0.
        L = np.where(df.nD == 0, np.log(df.connn0.where(df.connn0 > 0, 1.0)), -np.inf)
        Lpos = L[df.nD == 0]
        n = len(df)
        h = 1.06 * np.std(Lpos) * n ** (-1 / 4)
        lgrid = np.linspace(np.percentile(Lpos, 2.5), np.percentile(Lpos, 97.5), args.grid)

        X = df[cells].astype(float)
        Y1, Y0, nD = df.Y1.to_numpy(), df.Y0.to_numpy(), df.nD.to_numpy()
        mp = multipliers(n, args.B, SEED)
        est = default_estimators()
        cache = {}

        t0 = time.time()
        att, sd, attb = [], [], []
        for l in lgrid:
            a, v, ab = cdid_panel(Y1, Y0, L, nD, X, l, 5, h, args.B, est, mp, cache)
            att.append(a)
            sd.append((v / n) ** 0.5)
            attb.append(ab)
        crit = uniform_band(att, sd, attb)
        print(f"{y}: controls {n_ctrl}/{n_in[0]}, exposed {n_exp}/{n_in[1]}, h={h:.3f} (log dose), "
              f"uniform crit {crit:.2f}, {time.time() - t0:.0f}s")

        support.append(dict(outcome=y, ctrl_in=n_in[0], exposed_in=n_in[1], ctrl=n_ctrl, exposed=n_exp,
                            cells=" ".join(cells), h_log=h, crit_uniform=crit))
        for l, a, s in zip(lgrid, att, sd):
            rows.append(dict(outcome=y, dose=np.exp(l), log_dose=l, att=a, se=s,
                             lo=a - 1.96 * s, hi=a + 1.96 * s,
                             lo_unif=a - crit * s, hi_unif=a + crit * s))

    pd.DataFrame(rows).to_csv(out_dir / "zhang_cdid_att.csv", index=False)
    pd.DataFrame(support).to_csv(out_dir / "zhang_cdid_support.csv", index=False)
    print(f"Wrote {out_dir / 'zhang_cdid_att.csv'} and {out_dir / 'zhang_cdid_support.csv'}")


if __name__ == "__main__":
    main()
