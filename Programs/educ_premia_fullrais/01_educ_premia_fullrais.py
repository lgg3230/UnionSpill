"""
01_educ_premia_fullrais.py
==========================
National education premia from the WHOLE RAIS (all firms, not just the Lagos
analysis sample), 2009-2016.

Motivation
----------
In Heterogeneity_within_firm.R the education "premia" are group-mean log wage
differences.  Gui's version takes those means over the Lagos analysis sample
only (worker_panel_lagos.parquet).  Here the reference means are recomputed
over ALL selected RAIS workers, so the premium of an education level is its
mean wage relative to the national mean (and relative to the no-HS group),
rather than relative to the sample.

Same worker restrictions as the Lagos panel builder (011c_worker_panel.py):
  - December-active jobs only         : empem3112 == 1
  - drop very short spells            : tempempr > 1 (or NULL)
  - one spell per (identificad, PIS)  : rank by horascontr DESC,
                                        remdezr_h DESC, hash tiebreaker (salt 12345)
The ONLY difference vs. 011c is that we do NOT filter to sample establishments.

Wages deflated to Dec-2015 (IPCA), lr_remdezr = log(remdezr / deflator).

Education groups (grinstrucao), matching the R script:
  nohs        = 1:6
  hs          = 7:8
  collegeplus = 9:11
  hsplus      = 7:11

Output (full run)
-----------------
Tables/educ_premia_fullrais/educ_premia_national.csv
  year, group, n_workers, mean_lw, edprem_vs_nohs, edprem_vs_overall

BENCHMARK MODE
--------------
This script is written so it can be run on a reduced slice to estimate the
completion time of the full 8-year job:

  # tiny smoke test: first 3M rows of 2009 only
  python 01_educ_premia_fullrais.py --years 2009 --max-rows-per-year 3000000

  # full job (all years, all rows)
  python 01_educ_premia_fullrais.py

It times the read / dedup / aggregate stages separately, then extrapolates the
read stage (the bottleneck) to the full 2009-2016 file footprint and prints an
estimated total wall time.

Run with the conda py312 interpreter:
  ~/.conda/envs/venv_python312/bin/python \
      Programs/educ_premia_fullrais/01_educ_premia_fullrais.py --years 2009 --max-rows-per-year 3000000
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
PROJECT   = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR  = "/kellogg/proj/lgg3230/RAIS/output/data/full"
OUT_DIR   = os.path.join(PROJECT, "Tables/educ_premia_fullrais")
OUT_CSV   = os.path.join(OUT_DIR, "educ_premia_national.csv")

ALL_YEARS = list(range(2009, 2017))

# IPCA deflators to December 2015 (copied verbatim from 011c_worker_panel.py)
IPCA = {
    2009: 0.671594887351247,
    2010: 0.711277338716318,
    2011: 0.757534213038901,
    2012: 0.80176356558955,
    2013: 0.849153270408197,
    2014: 0.903562518222102,
    2015: 1.0,
    2016: 1.06287988213221,
}

# Minimal column set: selection keys + wage + education
COLS = [
    "identificad", "PIS", "horascontr", "remdezr",
    "empem3112", "tempempr", "grinstrucao",
]

# Education group definition (grinstrucao ranges), matching the R script
def educ_group(g):
    # vectorized elsewhere; kept here for reference
    if 1 <= g <= 6:
        return "nohs"
    if 7 <= g <= 8:
        return "hs"
    if 9 <= g <= 11:
        return "collegeplus"
    return None


# ---------------------------------------------------------------------------
# Read one year, apply restrictions + one-spell dedup, return firm-worker rows
# ---------------------------------------------------------------------------
def process_year(con, year, max_rows, timings):
    rais_file = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    print(f"\n{'='*64}\nYear {year}  ({os.path.getsize(rais_file)/1e9:.1f} GB)  {rais_file}")

    # ---- READ (chunked, optionally truncated) --------------------------------
    t_read = time.time()
    reader = pd.read_stata(
        rais_file, columns=COLS, chunksize=2_000_000, convert_categoricals=False,
    )
    chunks, n_read = [], 0
    for chunk in reader:
        chunks.append(chunk)
        n_read += len(chunk)
        if max_rows and n_read >= max_rows:
            break
    df = pd.concat(chunks, ignore_index=True)
    del chunks
    if max_rows:
        df = df.iloc[:max_rows]
        n_read = len(df)
    read_s = time.time() - t_read
    timings["read_rows"] += n_read
    timings["read_s"]    += read_s
    print(f"  read : {n_read:>12,} rows  in {read_s:8.1f}s  "
          f"({n_read/read_s/1e6:.2f} M rows/s)")

    # ---- FILTER + ONE-SPELL DEDUP (DuckDB, same logic as 011c) ---------------
    t_dd = time.time()
    con.register("rais", df)
    result = con.execute("""
        WITH base AS (
            SELECT identificad, PIS, remdezr, grinstrucao,
                CASE WHEN remdezr IS NULL OR remdezr = 0
                          OR horascontr IS NULL OR horascontr = 0
                     THEN 0.0 ELSE remdezr / (horascontr * 4.348) END AS remdezr_h,
                hash(identificad || '|' || PIS
                     || '|' || CAST(horascontr AS VARCHAR)
                     || '|' || CAST(remdezr    AS VARCHAR)
                     || '|12345') / 1e19 AS random_tb,
                horascontr
            FROM rais
            WHERE empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL)
        ),
        ranked AS (
            SELECT *, ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
            ) AS rn
            FROM base
        )
        SELECT identificad, remdezr, grinstrucao
        FROM ranked WHERE rn = 1
    """).fetch_arrow_table().to_pandas()
    con.unregister("rais")
    del df
    dd_s = time.time() - t_dd
    timings["dedup_s"]   += dd_s
    timings["dedup_rows"] += len(result)
    print(f"  dedup: {len(result):>12,} spells in {dd_s:7.1f}s")

    # ---- WAGE + EDUCATION GROUP ---------------------------------------------
    deflator = IPCA[year]
    w = result["remdezr"].where(result["remdezr"] > 0)
    result["lr_remdezr"] = np.log(w / deflator)

    g = result["grinstrucao"]
    result["group"] = np.select(
        [g.between(1, 6), g.between(7, 8), g.between(9, 11)],
        ["nohs", "hs", "collegeplus"], default=None,
    )
    result = result.dropna(subset=["lr_remdezr"])

    # Summarize THIS year in place, then release the worker frame so peak memory
    # is bounded by one year (~40M spells), never the full 8-year panel.
    summary = summarize_year(result, year)
    del result
    return summary


# ---------------------------------------------------------------------------
# National year x group means + premia for a single year's worker frame
# ---------------------------------------------------------------------------
def summarize_year(gy, year):
    # group means (+ hsplus = union of hs and collegeplus)
    overall = gy["lr_remdezr"].mean()
    means = gy.groupby("group")["lr_remdezr"].agg(["mean", "count"])
    nohs = means.loc["nohs", "mean"] if "nohs" in means.index else np.nan
    hsplus = gy[gy["group"].isin(["hs", "collegeplus"])]["lr_remdezr"]
    entries = {g: (means.loc[g, "mean"], int(means.loc[g, "count"]))
               for g in means.index}
    entries["hsplus"] = (hsplus.mean(), len(hsplus))
    entries["overall"] = (overall, len(gy))
    rows = [dict(year=int(year), group=grp, n_workers=n, mean_lw=m,
                 edprem_vs_nohs=m - nohs, edprem_vs_overall=m - overall)
            for grp, (m, n) in entries.items()]
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", default=",".join(map(str, ALL_YEARS)),
                    help="comma-separated years (default all 2009-2016)")
    ap.add_argument("--max-rows-per-year", type=int, default=0,
                    help="cap rows read per year (0 = all). Use for benchmarking.")
    ap.add_argument("--out", default=OUT_CSV)
    args = ap.parse_args()

    years = [int(y) for y in args.years.split(",")]
    max_rows = args.max_rows_per_year
    benchmark = bool(max_rows) or years != ALL_YEARS

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    timings = dict(read_rows=0, read_s=0.0, dedup_rows=0, dedup_s=0.0)
    t0 = time.time()
    # Each element is a small per-year summary (~5 rows); no worker-level panel
    # is ever concatenated, so peak memory stays at one year.
    parts = [process_year(con, y, max_rows, timings) for y in years]
    out = (pd.concat(parts, ignore_index=True)
             .sort_values(["year", "group"]).reset_index(drop=True))
    total_s = time.time() - t0
    # summarize + wage/group construction = whatever isn't read or dedup
    agg_s = total_s - timings["read_s"] - timings["dedup_s"]

    print(f"\n{'='*64}\nRESULT (year x group means)\n{'='*64}")
    with pd.option_context("display.max_rows", None, "display.width", 120):
        print(out.to_string(index=False))

    # ---- timing summary + extrapolation -------------------------------------
    read_tp = timings["read_rows"] / timings["read_s"] if timings["read_s"] else 0
    print(f"\n{'='*64}\nTIMING\n{'='*64}")
    print(f"  read : {timings['read_rows']:,} rows in {timings['read_s']:.1f}s "
          f"({read_tp/1e6:.2f} M rows/s)")
    print(f"  dedup: {timings['dedup_rows']:,} spells in {timings['dedup_s']:.1f}s")
    print(f"  agg  : {agg_s:.1f}s")
    print(f"  TOTAL: {total_s:.1f}s ({total_s/60:.1f} min)")

    if benchmark:
        # bytes/row observed on the sampled year(s) -> rows in full 8-year set
        sampled_bytes = sum(os.path.getsize(os.path.join(RAIS_DIR, f"RAIS_{y}.dta"))
                            for y in years)
        full_bytes = sum(os.path.getsize(os.path.join(RAIS_DIR, f"RAIS_{y}.dta"))
                         for y in ALL_YEARS)
        # rows read may be truncated; scale by the fraction of sampled bytes read
        frac_read = min(1.0, (timings["read_rows"] /
                              (timings["read_rows"] if not max_rows else max_rows * len(years))))
        est_full_rows = timings["read_rows"] / max(frac_read, 1e-9) * (full_bytes / sampled_bytes)
        est_read_s = est_full_rows / read_tp if read_tp else float("nan")
        # dedup+agg scale ~linearly with rows read; add proportionally
        scale = est_full_rows / max(timings["read_rows"], 1)
        est_total_s = est_read_s + timings["dedup_s"] * scale + agg_s * scale
        print(f"\n{'='*64}\nEXTRAPOLATION to full 2009-2016 ({full_bytes/1e9:.0f} GB)\n{'='*64}")
        print(f"  sampled footprint : {sampled_bytes/1e9:.1f} GB "
              f"({'truncated' if max_rows else 'full'} read)")
        print(f"  est. total rows   : {est_full_rows/1e6:,.0f} M")
        print(f"  est. read time    : {est_read_s/60:.1f} min")
        print(f"  est. TOTAL time   : {est_total_s/60:.1f} min "
              f"({est_total_s/3600:.1f} h)")
        print("\n  (BENCHMARK run - results NOT written to CSV)")
    else:
        os.makedirs(OUT_DIR, exist_ok=True)
        out.to_csv(args.out, index=False)
        print(f"\nSaved: {args.out}")

    con.close()


if __name__ == "__main__":
    main()
