#!/usr/bin/env python3
"""
Convert heavy DTA files used by the layer connectivity pipeline to parquet.

Run once before the pipeline (safe to re-run — skips files that already exist).

Caches:
  1. RAIS_{year}.dta            → RAIS_{year}.parquet           (raw spell data)
  2. yearly_employers_{year}.dta → yearly_employers_{year}.parquet (PIS→firm mapping)
  3. connectivity_treat_2007_2011_agg.dta → .parquet             (validation reference)
  4. cba_rais_firm (3 cols only)  → firm_status.parquet           (treat/panel flags)

Usage:
    python 00_cache_rais.py              # default: RAIS years 2007 2008
    python 00_cache_rais.py --years 2007 2008
"""

import argparse
import os
import sys
import time

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import (
    RAIS_DIR, RAIS_AUX, CBA_FIRM,
    YEARLY_EMP_TEMPLATE, YEARLY_EMP_PARQUET_TEMPLATE,
    CBA_RAIS_FIRM, FIRM_STATUS_PARQUET,
    ORIG_FIRM_CONN, ORIG_FIRM_CONN_PARQUET,
)

DEFAULT_RAIS_YEARS      = [2007, 2008]
YEARLY_EMP_YEARS        = [2007, 2008, 2009, 2010, 2011]
CHUNK_SIZE              = 500_000


# ──────────────────────────────────────────────────────────────────────────────
# 1. Raw RAIS spell data
# ──────────────────────────────────────────────────────────────────────────────

def cache_rais_year(year: int):
    dta_path     = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    parquet_path = os.path.join(RAIS_DIR, f"RAIS_{year}.parquet")

    if os.path.exists(parquet_path):
        print(f"  Already cached: {parquet_path}")
        return
    if not os.path.exists(dta_path):
        print(f"  {dta_path} not found — skipping.")
        return

    print(f"Reading {dta_path} ...")
    t0     = time.time()
    chunks = []
    reader = pd.read_stata(dta_path, chunksize=CHUNK_SIZE, convert_categoricals=False)
    for i, chunk in enumerate(reader):
        chunks.append(chunk)
        if (i + 1) % 20 == 0:
            print(f"  ... {(i+1)*CHUNK_SIZE:,} rows ({time.time()-t0:.0f}s)")

    df = pd.concat(chunks, ignore_index=True)
    print(f"  Loaded {len(df):,} rows in {time.time()-t0:.1f}s")

    print(f"Saving to {parquet_path} ...")
    t1 = time.time()
    df.to_parquet(parquet_path, index=False)
    print(f"  Saved {os.path.getsize(parquet_path)/1e9:.2f} GB in {time.time()-t1:.1f}s")


# ──────────────────────────────────────────────────────────────────────────────
# 2. Yearly employers (PIS → firm mapping)
# ──────────────────────────────────────────────────────────────────────────────

def cache_yearly_employers(year: int):
    dta_path     = YEARLY_EMP_TEMPLATE.format(year=year)
    parquet_path = YEARLY_EMP_PARQUET_TEMPLATE.format(year=year)

    if os.path.exists(parquet_path):
        print(f"  Already cached: {parquet_path}")
        return
    if not os.path.exists(dta_path):
        print(f"  {dta_path} not found — skipping.")
        return

    col_id = f"identificad_{year}"
    print(f"  Reading {dta_path} ...")
    t0 = time.time()
    df = pd.read_stata(dta_path, columns=["PIS", col_id], convert_categoricals=False)
    df = df.rename(columns={col_id: "identificad"})
    df["PIS"]         = df["PIS"].astype(str)
    df["identificad"] = df["identificad"].astype(str)
    print(f"  Loaded {len(df):,} rows in {time.time()-t0:.1f}s")

    df.to_parquet(parquet_path, index=False)
    print(f"  Saved {os.path.getsize(parquet_path)/1e6:.1f} MB → {parquet_path}")


# ──────────────────────────────────────────────────────────────────────────────
# 3. Original firm-level connectivity (validation reference)
# ──────────────────────────────────────────────────────────────────────────────

def cache_orig_firm_conn():
    if os.path.exists(ORIG_FIRM_CONN_PARQUET):
        print(f"  Already cached: {ORIG_FIRM_CONN_PARQUET}")
        return
    if not os.path.exists(ORIG_FIRM_CONN):
        print(f"  {ORIG_FIRM_CONN} not found — skipping.")
        return

    print(f"  Reading {ORIG_FIRM_CONN} ...")
    t0 = time.time()
    df = pd.read_stata(ORIG_FIRM_CONN, columns=["identificad", "totaltreat_pw_n"],
                       convert_categoricals=False)
    df["identificad"] = df["identificad"].astype(str)
    print(f"  Loaded {len(df):,} rows in {time.time()-t0:.1f}s")

    df.to_parquet(ORIG_FIRM_CONN_PARQUET, index=False)
    print(f"  Saved {os.path.getsize(ORIG_FIRM_CONN_PARQUET)/1e6:.1f} MB → {ORIG_FIRM_CONN_PARQUET}")


# ──────────────────────────────────────────────────────────────────────────────
# 4. Firm status subset of cba_rais_firm (56 GB → 3 columns only)
# ──────────────────────────────────────────────────────────────────────────────

def cache_firm_status():
    if os.path.exists(FIRM_STATUS_PARQUET):
        print(f"  Already cached: {FIRM_STATUS_PARQUET}")
        return
    if not os.path.exists(CBA_RAIS_FIRM):
        print(f"  {CBA_RAIS_FIRM} not found — skipping.")
        return

    print(f"  Reading {CBA_RAIS_FIRM} (chunked, 3 cols) ...")
    t0 = time.time()
    chunks = []
    reader = pd.read_stata(
        CBA_RAIS_FIRM,
        columns=["identificad", "treat_ultra", "in_balanced_panel"],
        chunksize=200_000,
        convert_categoricals=False,
    )
    for chunk in reader:
        chunk["identificad"] = chunk["identificad"].astype(str)
        chunks.append(chunk.drop_duplicates("identificad"))
    df = pd.concat(chunks, ignore_index=True).drop_duplicates("identificad")
    print(f"  Loaded {len(df):,} firms in {time.time()-t0:.1f}s")

    df.to_parquet(FIRM_STATUS_PARQUET, index=False)
    print(f"  Saved {os.path.getsize(FIRM_STATUS_PARQUET)/1e6:.1f} MB → {FIRM_STATUS_PARQUET}")


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--years", nargs="+", type=int, default=DEFAULT_RAIS_YEARS,
                   help="Raw RAIS years to cache (default: 2007 2008)")
    p.add_argument("--skip-rais", action="store_true",
                   help="Skip raw RAIS caching (useful when parquets already exist)")
    args = p.parse_args()

    if not args.skip_rais:
        for year in args.years:
            print(f"\n=== Raw RAIS {year} ===")
            cache_rais_year(year)

    print("\n=== Yearly employers (2007–2011) ===")
    for year in YEARLY_EMP_YEARS:
        cache_yearly_employers(year)

    print("\n=== Original firm connectivity (validation reference) ===")
    cache_orig_firm_conn()

    print("\n=== Firm status (treat_ultra, in_balanced_panel) ===")
    cache_firm_status()

    print("\nDone.")

    import subprocess
    subprocess.run(["curl", "-s", "-o", "/dev/null",
                    "-H", "Title: Cache done",
                    "-d", "Parquet cache complete (RAIS + yearly_employers + aux)",
                    "https://ntfy.sh/lgg3230-kellogg"])


if __name__ == "__main__":
    main()
