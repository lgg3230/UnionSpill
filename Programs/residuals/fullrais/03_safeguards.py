"""
03_safeguards.py
================
Validation checks for the reconstructed whole-RAIS Mincer residualization.

  S4  per-cell residual mean ~ 0. This is the check that catches the
      age^4/tenure^4 conditioning failure (residual mean 0.054 instead of
      ~1e-14) described in 02_residualize_fullrais.py.

  REF exact comparison of a rebuilt residual file against a reference file,
      restricted to the years present in the rebuild. Because the cell key
      includes `year`, a single-year rebuild is directly comparable to the
      corresponding slice of a full-panel reference.

Usage
-----
    python 03_safeguards.py ref \
        --new mincer_residuals_firm_year_ten_fullrais_y2011.csv \
        --ref mincer_residuals_firm_year_ten_fullrais.csv \
        --tol 1e-10

    python 03_safeguards.py s4 --years 2011 --mode agetenure --min-obs 10
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

PROJECT = Path(__file__).resolve().parents[3]
DATA    = PROJECT / "Data" / "CBA_RAIS_firm_level"

RESID_COLS = ["lr_remdezr_resid", "lr_hourly_resid"]
MEAN_COLS  = ["lr_remdezr_mean", "lr_hourly_mean"]
N_COLS     = ["n_workers_lr_remdezr", "n_workers_lr_hourly"]


def load(name):
    path = name if Path(name).is_absolute() else DATA / name
    return pd.read_csv(path, dtype={"identificad": str})


def check_ref(args):
    new = load(args.new)
    ref = load(args.ref)

    years = sorted(new["year"].unique())
    ref = ref[ref["year"].isin(years)].copy()
    print(f"Comparing years {years}:  new={len(new):,} rows   ref={len(ref):,} rows")

    key = ["identificad", "year"]
    new_k = set(map(tuple, new[key].values))
    ref_k = set(map(tuple, ref[key].values))

    only_new = new_k - ref_k
    only_ref = ref_k - new_k
    print(f"  keys only in new: {len(only_new):,}")
    print(f"  keys only in ref: {len(only_ref):,}")

    merged = new.merge(ref, on=key, how="inner", suffixes=("_new", "_ref"))
    print(f"  matched keys    : {len(merged):,}")

    ok = (len(only_new) == 0) and (len(only_ref) == 0)

    for col in N_COLS:
        diff = (merged[f"{col}_new"] != merged[f"{col}_ref"]).sum()
        print(f"  {col:24s} mismatched counts: {diff:,}")
        ok = ok and diff == 0

    for col in RESID_COLS + MEAN_COLS:
        d = np.abs(merged[f"{col}_new"] - merged[f"{col}_ref"])
        mx = np.nanmax(d) if len(d) else 0.0
        print(f"  {col:24s} max |diff| = {mx:.3e}")
        ok = ok and mx < args.tol

    print("\nCHECKPOINT 1: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def check_s4(args):
    # "02_residualize_fullrais" is not a valid module name, so load it by path.
    # run_name is not "__main__", so the module's main() does not fire.
    import runpy
    mod = runpy.run_path(str(Path(__file__).resolve().parent / "02_residualize_fullrais.py"),
                         run_name="__safeguards__")

    panel_dir = PROJECT / "Data" / "CBA_RAIS_firm_level" / "fullrais_panel"
    n_reg = 9 if args.mode == "agetenure" else 5
    min_obs = args.min_obs if args.min_obs is not None else n_reg + 1

    worst = 0.0
    for year in args.years:
        path = panel_dir / f"worker_panel_fullrais_{year}.parquet"
        cols = ["identificad", "year", "age", "race_group", "genero",
                "grinstrucao", "tempempr", "lr_remdezr", "lr_hourly"]
        df = pd.read_parquet(path, columns=cols)
        df = mod["restrict_sample"](df, args.mode)

        cell_key = (df["race_group"].astype(str) + "_" +
                    df["grinstrucao"].astype(str) + "_" +
                    df["genero"].astype(str) + "_" +
                    df["year"].astype(str))
        cell_ids = pd.factorize(cell_key)[0]
        X = mod["build_design"](df, args.mode)

        for outcome in ["lr_remdezr", "lr_hourly"]:
            y = df[outcome].to_numpy(dtype=np.float64)
            resid, _ = mod["cell_ols_residuals"](X, y, cell_ids, min_obs)
            kept = np.isfinite(resid)
            per_cell = pd.Series(resid[kept]).groupby(cell_ids[kept]).mean()
            mx = float(np.abs(per_cell).max())
            worst = max(worst, mx)
            print(f"  {year} {outcome:12s} max |per-cell resid mean| = {mx:.3e}")

    ok = worst < 1e-8
    print(f"\nS4: " + ("PASS" if ok else f"FAIL (worst {worst:.3e})"))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("ref")
    r.add_argument("--new", required=True)
    r.add_argument("--ref", required=True)
    r.add_argument("--tol", type=float, default=1e-10)
    r.set_defaults(func=check_ref)

    s = sub.add_parser("s4")
    s.add_argument("--years", type=int, nargs="+", required=True)
    s.add_argument("--mode", choices=["age", "agetenure"], default="agetenure")
    s.add_argument("--min-obs", type=int, default=None)
    s.set_defaults(func=check_s4)

    args = ap.parse_args()
    raise SystemExit(args.func(args))


if __name__ == "__main__":
    main()
