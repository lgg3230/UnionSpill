#!/usr/bin/env python3.8
import argparse
import time
from pathlib import Path
from importlib.machinery import SourceFileLoader

import duckdb

config = SourceFileLoader("config", str(Path(__file__).with_name("00_config.py"))).load_module()


def select_year(year: int) -> Path:
    config.ensure_dirs()
    src = config.STAGING / f"rais_selected_{year}.parquet"
    dst = config.YEARLY / f"yearly_employers_{year}.parquet"
    if not src.exists():
        raise FileNotFoundError(f"Missing staging parquet: {src}")
    if dst.exists():
        dst.unlink()

    print(f"[select] {year}: {src} -> {dst}")
    start = time.time()
    con = duckdb.connect()
    con.execute("PRAGMA threads=4")
    con.execute(
        f"""
        COPY (
            WITH base AS (
                SELECT
                    CAST(PIS AS VARCHAR) AS PIS,
                    CAST(identificad AS VARCHAR) AS identificad,
                    substr(CAST(identificad AS VARCHAR), 1, 8) AS identificad8,
                    CAST(tempempr AS DOUBLE) AS tempempr,
                    CAST(horascontr AS DOUBLE) AS horascontr,
                    CASE
                        WHEN CAST(remdezr AS DOUBLE) > 0 AND CAST(horascontr AS DOUBLE) > 0
                        THEN ln(CAST(remdezr AS DOUBLE) / (CAST(horascontr AS DOUBLE) * 4.348))
                        ELSE NULL
                    END AS l_remdezr_h
                FROM read_parquet('{src}')
                WHERE CAST(empem3112 AS DOUBLE) * (CAST(tempempr AS DOUBLE) > 1)::INTEGER = 1
            ),
            estab_ranked AS (
                SELECT
                    *,
                    row_number() OVER (
                        PARTITION BY identificad, PIS
                        ORDER BY horascontr DESC NULLS LAST,
                                 l_remdezr_h DESC NULLS LAST,
                                 hash(PIS, identificad, tempempr, horascontr, l_remdezr_h) DESC
                    ) AS estab_rn
                FROM base
            ),
            estab_selected AS (
                SELECT
                    *,
                    count(*) OVER (PARTITION BY identificad) AS firm_emp
                FROM estab_ranked
                WHERE estab_rn = 1
            ),
            worker_ranked AS (
                SELECT
                    *,
                    row_number() OVER (
                        PARTITION BY PIS
                        ORDER BY tempempr DESC NULLS LAST,
                                 l_remdezr_h DESC NULLS LAST,
                                 hash(PIS, identificad, tempempr, horascontr, l_remdezr_h, 'worker') DESC
                    ) AS worker_rn
                FROM estab_selected
            )
            SELECT
                PIS,
                identificad AS identificad_{year},
                identificad8 AS identificad8_{year},
                CAST(firm_emp AS BIGINT) AS firm_emp_{year}
            FROM worker_ranked
            WHERE worker_rn = 1
        ) TO '{dst}' (FORMAT PARQUET, COMPRESSION ZSTD)
        """
    )
    con.close()
    print(f"[select] {year}: done in {time.time() - start:.1f}s")
    return dst


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--years", nargs="+", type=int, default=config.YEARS_DEFAULT)
    args = parser.parse_args()
    for year in args.years:
        select_year(year)


if __name__ == "__main__":
    main()
