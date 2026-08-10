#!/usr/bin/env python3.8
import argparse
import time
from pathlib import Path
from importlib.machinery import SourceFileLoader

import duckdb

config = SourceFileLoader("config", str(Path(__file__).with_name("00_config.py"))).load_module()


def build_pair(year: int) -> Path:
    config.ensure_dirs()
    next_year = year + 1
    left = config.YEARLY / f"yearly_employers_{year}.parquet"
    right = config.YEARLY / f"yearly_employers_{next_year}.parquet"
    dst = config.TRANSITIONS / f"employers_{year}_{next_year}.parquet"
    csv_dst = config.TRANSITIONS / f"employers_{year}_{next_year}.csv"
    for path in [left, right]:
        if not path.exists():
            raise FileNotFoundError(path)
    for path in [dst, csv_dst]:
        if path.exists():
            path.unlink()

    print(f"[transition] {year}-{next_year}: {dst}")
    start = time.time()
    con = duckdb.connect()
    con.execute("PRAGMA threads=4")
    query = f"""
        SELECT
            a.PIS,
            '1' || a.identificad_{year} AS identificad_{year},
            '1' || b.identificad_{next_year} AS identificad_{next_year},
            '1' || a.identificad8_{year} AS identificad8_{year},
            '1' || b.identificad8_{next_year} AS identificad8_{next_year},
            a.firm_emp_{year},
            b.firm_emp_{next_year}
        FROM read_parquet('{left}') a
        INNER JOIN read_parquet('{right}') b
            USING (PIS)
    """
    con.execute(f"COPY ({query}) TO '{dst}' (FORMAT PARQUET, COMPRESSION ZSTD)")
    con.execute(f"COPY ({query}) TO '{csv_dst}' (HEADER, DELIMITER ',')")
    con.close()
    print(f"[transition] {year}-{next_year}: done in {time.time() - start:.1f}s")
    return dst


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-years", nargs="+", type=int, default=[2009])
    args = parser.parse_args()
    for year in args.start_years:
        build_pair(year)


if __name__ == "__main__":
    main()
