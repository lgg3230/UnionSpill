"""
01_build_panel_fullrais.py
==========================
Build a LEAN whole-RAIS worker panel (ALL firms, 2009-2016) for the national-
reference Mincer residualization with a firm-tenure quartic.

Difference vs. the existing Lagos panel (011c_worker_panel.py): we do NOT filter
to sample establishments, so the residual cells (race x educ x gender x year)
are later estimated over the entire national labor market.  Everything else
matches 011c / 011d exactly:
  - December-active jobs only          : empem3112 == 1
  - drop very short spells             : tempempr > 1 (or NULL)
  - one spell per (identificad, PIS)   : horascontr DESC, remdezr_h DESC, hash tb
  - wages deflated to Dec-2015 (IPCA)
  - age unified from idade / dtnascimento (011d logic, verbatim)
  - race_group from raca_cor           (011d map, verbatim)

Because `year` is part of the residual cell, residualization is fully separable
by year -> we persist ONE lean parquet part per year so the downstream step
never holds more than a single year in memory.

Output
------
Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_{year}.parquet
  columns: identificad, year, lr_remdezr, lr_hourly, age, race_group,
           genero, grinstrucao, tempempr

Run
---
  ~/.conda/envs/venv_python312/bin/python \
     Programs/mincer_tenure_fullrais/01_build_panel_fullrais.py            # all years
  ... 01_build_panel_fullrais.py --years 2009 --max-rows-per-year 3000000  # smoke test
"""

import argparse
import os
import time

import duckdb
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT  = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR = "/kellogg/proj/lgg3230/RAIS/output/data/full"
OUT_DIR  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/fullrais_panel")

ALL_YEARS = list(range(2009, 2017))

# IPCA deflators to December 2015 (verbatim from 011c_worker_panel.py)
IPCA = {
    2009: 0.671594887351247, 2010: 0.711277338716318, 2011: 0.757534213038901,
    2012: 0.80176356558955,  2013: 0.849153270408197, 2014: 0.903562518222102,
    2015: 1.0,               2016: 1.06287988213221,
}

# Columns needed for residualization inputs + selection + age reconstruction
COLS_ALWAYS = [
    "identificad", "PIS", "horascontr", "remdezr", "empem3112", "tempempr",
    "genero", "raca_cor", "grinstrucao",
    "dtadmissao",   # admission date (DDMMYYYY) — used to recover tenure where
                    # tempempr is missing (e.g. 227 firms report no tempempr in 2011)
]
# Present in some years only (011c COLS_OPTIONAL): idade absent 2009-2010,
# dtnascimento absent 2011-2013.
COLS_OPTIONAL = ["idade", "dtnascimento"]

# race_group map (verbatim from 011d_worker_panel_bins.py)
RACE_MAP = {2: "branca", 8: "parda", 4: "preta"}


def compute_age(df):
    """Unified age from idade / dtnascimento — 011d logic, robust to either
    column being absent/all-missing (idade absent 2009-2010; dtnascimento
    absent 2011-2013, filled with NaN -> must not break the .str path)."""
    idade = (pd.to_numeric(df["idade"], errors="coerce")
             if "idade" in df.columns else pd.Series(np.nan, index=df.index))
    # astype("string") turns a float-NaN placeholder column into <NA> so the
    # string accessor is always valid.
    s = (df["dtnascimento"].astype("string")
         if "dtnascimento" in df.columns
         else pd.Series(pd.NA, index=df.index, dtype="string"))
    birth_year = pd.to_numeric(s.where(s.str.len() == 8).str[4:8], errors="coerce")
    age_from_dob = df["year"] - birth_year
    return np.where(idade.notna(), idade,
                    np.where(birth_year.notna(), age_from_dob, np.nan))


def process_year(con, year, max_rows):
    rais_file = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    print(f"\n{'='*64}\nYear {year}  ({os.path.getsize(rais_file)/1e9:.1f} GB)")

    # which optional columns exist this year?
    probe = next(iter(pd.read_stata(rais_file, chunksize=1, convert_categoricals=False)))
    avail = set(probe.columns)
    opt_present = [c for c in COLS_OPTIONAL if c in avail]
    opt_absent  = [c for c in COLS_OPTIONAL if c not in avail]
    if opt_absent:
        print(f"  optional absent: {opt_absent}")

    # ---- read (chunked; NO sample filter) -----------------------------------
    t0 = time.time()
    reader = pd.read_stata(rais_file, columns=COLS_ALWAYS + opt_present,
                           chunksize=2_000_000, convert_categoricals=False)
    chunks, n = [], 0
    for ch in reader:
        chunks.append(ch); n += len(ch)
        if max_rows and n >= max_rows:
            break
    df = pd.concat(chunks, ignore_index=True); del chunks
    if max_rows:
        df = df.iloc[:max_rows]
    for c in opt_absent:
        df[c] = np.nan
    print(f"  read : {len(df):>12,} rows in {time.time()-t0:6.1f}s")

    # ---- filter + one-spell dedup (verbatim ranking from 011c) --------------
    t1 = time.time()
    con.register("rais", df)
    res = con.execute("""
        WITH base AS (
            SELECT identificad, PIS, horascontr, remdezr, empem3112, tempempr,
                   genero, raca_cor, grinstrucao, idade, dtnascimento, dtadmissao,
                CASE WHEN remdezr IS NULL OR remdezr = 0
                          OR horascontr IS NULL OR horascontr = 0
                     THEN 0.0 ELSE remdezr / (horascontr * 4.348) END AS remdezr_h,
                hash(identificad || '|' || PIS
                     || '|' || CAST(horascontr AS VARCHAR)
                     || '|' || CAST(remdezr    AS VARCHAR)
                     || '|12345') / 1e19 AS random_tb
            FROM rais
            WHERE empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL)
        ),
        ranked AS (
            SELECT *, ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC) AS rn
            FROM base)
        SELECT identificad, horascontr, remdezr, tempempr,
               genero, raca_cor, grinstrucao, idade, dtnascimento, dtadmissao
        FROM ranked WHERE rn = 1
    """).fetch_arrow_table().to_pandas()
    con.unregister("rais"); del df
    print(f"  dedup: {len(res):>12,} spells in {time.time()-t1:6.1f}s")

    # ---- derived variables ---------------------------------------------------
    deflator = IPCA[year]
    res["year"] = year
    # log real December wage (011c) and log real hourly wage (011f/011g: *4.33)
    res["lr_remdezr"] = np.log(res["remdezr"].where(res["remdezr"] > 0) / deflator)
    res["lr_hourly"]  = np.where(
        (res["horascontr"] > 0) & (res["remdezr"] > 0),
        np.log(res["remdezr"] / (res["horascontr"] * 4.33)), np.nan)
    res["age"]        = compute_age(res)
    res["race_group"] = res["raca_cor"].map(RACE_MAP).fillna("other_missing")

    # ---- recover missing firm tenure from admission date --------------------
    # tempempr (months at current employer) == time since dtadmissao. RAIS
    # leaves tempempr blank for some establishments (227 firms report none in
    # 2011); recover it EXACTLY from the admission date. Validated on 6.2M 2011
    # workers with both fields: corr 0.9985, median |derived - tempempr| 0.07 mo.
    miss = res["tempempr"].isna()
    if miss.any():
        s   = res.loc[miss, "dtadmissao"].astype("string").str.zfill(8)  # DDMMYYYY
        adm = pd.to_datetime(s.str[4:8] + s.str[2:4] + s.str[0:2],
                             format="%Y%m%d", errors="coerce")
        derived = (pd.Timestamp(f"{year}-12-31") - adm).dt.days / 30.4375
        derived = derived.where(derived >= 0)     # guard against malformed dates
        res.loc[miss, "tempempr"] = derived.to_numpy()
        print(f"  tenure: recovered {int(derived.notna().sum()):,} missing "
              f"tempempr from dtadmissao")

    out = res[["identificad", "year", "lr_remdezr", "lr_hourly", "age",
               "race_group", "genero", "grinstrucao", "tempempr"]].copy()
    out["identificad"] = out["identificad"].astype(str).str.zfill(14)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", default=",".join(map(str, ALL_YEARS)))
    ap.add_argument("--max-rows-per-year", type=int, default=0)
    args = ap.parse_args()
    years = [int(y) for y in args.years.split(",")]

    os.makedirs(OUT_DIR, exist_ok=True)
    con = duckdb.connect()
    con.execute("PRAGMA threads=8"); con.execute("PRAGMA memory_limit='32GB'")

    t_all = time.time()
    for y in years:
        part = os.path.join(OUT_DIR, f"worker_panel_fullrais_{y}.parquet")
        if args.max_rows_per_year:
            part = part.replace(".parquet", "_SMOKE.parquet")
        elif os.path.exists(part):
            print(f"\nYear {y}: part already exists, skipping "
                  f"({os.path.getsize(part)/1e9:.2f} GB)")
            continue
        out = process_year(con, y, args.max_rows_per_year)
        out.to_parquet(part, index=False, engine="pyarrow")
        print(f"  saved: {os.path.basename(part)}  ({os.path.getsize(part)/1e9:.2f} GB, "
              f"{len(out):,} rows)")
    con.close()
    print(f"\nTotal elapsed: {(time.time()-t_all)/60:.1f} min")


if __name__ == "__main__":
    main()
