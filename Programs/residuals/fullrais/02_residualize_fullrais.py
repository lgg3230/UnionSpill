"""
02_residualize_fullrais.py
==========================
Whole-RAIS Mincer residualization. Reconstruction of the lost script that
produced mincer_residuals_firm_year_ten_fullrais.csv (the input to Tables 10
and 22 of "Replication_Wages vs Hourly").

Specification
-------------
Within each cell c = race_group x grinstrucao x genero x year, estimate by OLS

    outcome_i = a_c + sum_{k=1..4} b_ck * (age_i/50)^k
                    + sum_{k=1..4} g_ck * (tempempr_i/120)^k + e_i      (agetenure)

or without the tenure block (age). Residuals e_i are the worker-spell Mincer
residual; they are then averaged to the establishment-year level.

Cells are estimated over ALL national RAIS spells. The lagos_sample_avg==1
restriction is applied only at the very end, to the collapsed firm-year output.
Because `year` is part of the cell key, each year is an independent estimation
unit and per-part processing is exactly equivalent to pooling.

Numerical note
--------------
age and tenure MUST be rescaled before taking powers. With raw months/years the
cell design matrix has cond(X) ~ 2.4e11; np.linalg.lstsq then drops singular
values under its rcond cutoff, the intercept is not fit, and the residual mean
comes out ~0.054 instead of ~1e-14. OLS residuals are rescale-invariant in exact
arithmetic, so this is purely a conditioning fix. The per-cell residual-mean
diagnostic printed below is what catches a regression here.

Usage
-----
    python 02_residualize_fullrais.py --mode agetenure --min-obs 10
    python 02_residualize_fullrais.py --mode agetenure --min-obs 10 --years 2011 \
        --out-suffix _ten_fullrais_y2011
"""

import argparse
import os
import time
from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths  (Programs/residuals/fullrais/ -> project root is 3 levels up)
# ---------------------------------------------------------------------------
PROJECT   = Path(__file__).resolve().parents[3]
PANEL_DIR = PROJECT / "Data" / "CBA_RAIS_firm_level" / "fullrais_panel"
FIRM_DTA  = PROJECT / "Data" / "CBA_RAIS_firm_level" / "lagos_sample_sep24_pct_unionexp_ext_df2.dta"
OUT_DIR   = PROJECT / "Data" / "CBA_RAIS_firm_level"

OUTCOMES  = ["lr_remdezr", "lr_hourly"]

# Rescaling constants -- see "Numerical note" above. Do not change without
# re-running the residual-mean diagnostic.
AGE_SCALE = 50.0
TEN_SCALE = 120.0


def cell_ols_residuals(X, y, cell_ids, min_obs):
    """Cell-by-cell OLS. Returns (resid, n_skipped).

    Cells with fewer than `min_obs` rows are left as NaN. The singleton
    threshold must be at least n_regressors + 1, otherwise the within-cell
    system is underdetermined and the "residuals" are mechanically near zero.
    """
    n = len(y)
    resid = np.full(n, np.nan, dtype=np.float64)

    sort_idx     = np.argsort(cell_ids, kind="stable")
    sorted_cells = cell_ids[sort_idx]
    boundaries   = np.where(np.diff(sorted_cells))[0] + 1
    groups       = np.split(sort_idx, boundaries)

    n_skip = 0
    for idx in groups:
        if len(idx) < min_obs:
            n_skip += len(idx)
            continue
        Xi = X[idx]
        yi = y[idx]
        beta, _, _, _ = np.linalg.lstsq(Xi, yi, rcond=None)
        resid[idx] = yi - Xi @ beta

    return resid, n_skip


def build_design(df, mode, rescale=True):
    """Design matrix: intercept + quartic scaled age [+ quartic scaled tenure].

    rescale=False reproduces the ill-conditioned raw-power design. It exists
    only to diagnose historical output; never use it to produce analysis data.
    """
    n = len(df)
    cols = [np.ones(n, dtype=np.float64)]

    a_scale = AGE_SCALE if rescale else 1.0
    t_scale = TEN_SCALE if rescale else 1.0

    a = df["age"].to_numpy(dtype=np.float64) / a_scale
    for k in range(1, 5):
        cols.append(a ** k)

    if mode == "agetenure":
        t = df["tempempr"].to_numpy(dtype=np.float64) / t_scale
        for k in range(1, 5):
            cols.append(t ** k)

    return np.column_stack(cols)


def restrict_sample(df, mode):
    """Common estimation sample across both outcomes.

    Mirrors the Stata restriction (non-missing grinstrucao, genero, age; drop
    race_group in {"", "."}) and additionally requires both wage outcomes and,
    under agetenure, tenure. Requiring both outcomes jointly is what makes the
    two outcomes share one sample -- the surviving run log reports identical
    `kept` counts for lr_remdezr and lr_hourly in every year, which only holds
    under a common-sample restriction.
    """
    need = ["grinstrucao", "genero", "age"] + OUTCOMES
    if mode == "agetenure":
        need = need + ["tempempr"]

    df = df.dropna(subset=need)
    rg = df["race_group"]
    df = df[rg.notna() & (rg != "") & (rg != ".")]
    return df.reset_index(drop=True)


def process_part(path, mode, min_obs, verbose=True, rescale=True):
    """Residualize one year-part, return the collapsed firm-year frame."""
    cols = ["identificad", "year", "age", "race_group",
            "genero", "grinstrucao", "tempempr"] + OUTCOMES
    df = pd.read_parquet(path, columns=cols)
    n_raw = len(df)
    df = restrict_sample(df, mode)

    cell_key = (
        df["race_group"].astype(str) + "_" +
        df["grinstrucao"].astype(str) + "_" +
        df["genero"].astype(str) + "_" +
        df["year"].astype(str)
    )
    cell_ids = pd.factorize(cell_key)[0]

    X = build_design(df, mode, rescale=rescale)
    if verbose:
        print(f"  part: {path.name}  (raw={n_raw:,})")

    out = None
    for outcome in OUTCOMES:
        y = df[outcome].to_numpy(dtype=np.float64)
        resid, n_skip = cell_ols_residuals(X, y, cell_ids, min_obs)

        kept = np.isfinite(resid)
        if verbose:
            print(f"    {outcome}: kept={int(kept.sum()):,} "
                  f"skip_singleton={n_skip:,} "
                  f"resid_mean={resid[kept].mean():.2e}")

        sub = pd.DataFrame({
            "identificad": df["identificad"].values[kept],
            "year":        df["year"].values[kept],
            "resid":       resid[kept],
            "raw":         y[kept],
        })
        fy = (sub.groupby(["identificad", "year"], observed=True)
                 .agg(**{f"{outcome}_resid":     ("resid", "mean"),
                         f"{outcome}_mean":      ("raw",   "mean"),
                         f"n_workers_{outcome}": ("raw",   "count")})
                 .reset_index())

        out = fy if out is None else out.merge(fy, on=["identificad", "year"], how="outer")

    return out


def lagos_firm_years():
    """(identificad, year) pairs with lagos_sample_avg == 1, read independently
    from the firm-level panel -- not from any existing residual file."""
    it = pd.read_stata(FIRM_DTA,
                       columns=["identificad", "year", "lagos_sample_avg"],
                       iterator=True)
    d = it.read()
    d = d[d["lagos_sample_avg"] == 1][["identificad", "year"]]
    d["identificad"] = d["identificad"].astype(str)
    d["year"] = d["year"].astype("int64")
    return d.drop_duplicates()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["age", "agetenure"], default="agetenure")
    ap.add_argument("--min-obs", type=int, default=None,
                    help="Singleton threshold. Default = n_regressors + 1.")
    ap.add_argument("--years", type=int, nargs="*", default=None,
                    help="Restrict to these years (cells are within-year, so "
                         "this is exactly separable from a full run).")
    ap.add_argument("--no-rescale", action="store_true",
                    help="DIAGNOSTIC ONLY: use raw age/tenure powers. Reproduces "
                         "ill-conditioned historical output; not for analysis.")
    ap.add_argument("--out-suffix", default="_ten_fullrais",
                    help="Suffix on mincer_residuals_firm_year{suffix}.csv")
    args = ap.parse_args()

    n_reg = 9 if args.mode == "agetenure" else 5
    min_obs = args.min_obs if args.min_obs is not None else n_reg + 1

    t0 = time.time()
    print(f"panel=fullrais mode={args.mode} regressors={n_reg} min_obs={min_obs}")

    parts = sorted(PANEL_DIR.glob("worker_panel_fullrais_*.parquet"))
    if args.years:
        keep = {str(y) for y in args.years}
        parts = [p for p in parts if p.stem.split("_")[-1] in keep]
    if not parts:
        raise SystemExit(f"No panel parts found under {PANEL_DIR}")

    frames = [process_part(p, args.mode, min_obs, rescale=not args.no_rescale)
              for p in parts]
    national = pd.concat(frames, ignore_index=True)

    lagos = lagos_firm_years()
    national["identificad"] = national["identificad"].astype(str)
    national["year"] = national["year"].astype("int64")
    filtered = national.merge(lagos, on=["identificad", "year"], how="inner")
    print(f"  filtered to lagos_sample_avg==1: {len(national):,} -> "
          f"{len(filtered):,} firm-years")

    ordered = ["identificad", "year"]
    for outcome in OUTCOMES:
        ordered += [f"{outcome}_resid", f"{outcome}_mean", f"n_workers_{outcome}"]
    filtered = filtered[ordered].sort_values(["identificad", "year"]).reset_index(drop=True)

    out_csv = OUT_DIR / f"mincer_residuals_firm_year{args.out_suffix}.csv"
    filtered.to_csv(out_csv, index=False)
    print(f"\nSaved: {out_csv}  ({len(filtered):,} firm-years)")
    print(f"Elapsed: {(time.time()-t0)/60:.1f} min")


if __name__ == "__main__":
    main()
