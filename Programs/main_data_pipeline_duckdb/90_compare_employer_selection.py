#!/usr/bin/env python3.8
import argparse
import json
from pathlib import Path
from importlib.machinery import SourceFileLoader

import duckdb
import pandas as pd

config = SourceFileLoader("config", str(Path(__file__).with_name("00_config.py"))).load_module()


def read_stata_year(year: int) -> pd.DataFrame:
    path = config.RAIS_AUX / f"yearly_employers_{year}.dta"
    cols = [f"PIS", f"identificad_{year}", f"identificad8_{year}", f"firm_emp_{year}"]
    df = pd.read_stata(path, columns=cols, convert_categoricals=False)
    df["PIS"] = df["PIS"].astype("string")
    df[f"identificad_{year}"] = df[f"identificad_{year}"].astype("string")
    df[f"identificad8_{year}"] = df[f"identificad8_{year}"].astype("string")
    return df


def write_stata_year_parquet(year: int) -> Path:
    out = config.REPORTS / f"stata_yearly_employers_{year}.parquet"
    df = read_stata_year(year)
    df.to_parquet(out, index=False)
    return out


def compare_year(year: int) -> dict:
    stata_pq = write_stata_year_parquet(year)
    duck_pq = config.YEARLY / f"yearly_employers_{year}.parquet"
    con = duckdb.connect()
    con.execute("PRAGMA threads=4")
    res = con.execute(
        f"""
        WITH
        s AS (
            SELECT
                CAST(PIS AS VARCHAR) AS PIS,
                CAST(identificad_{year} AS VARCHAR) AS id_s,
                CAST(firm_emp_{year} AS BIGINT) AS emp_s
            FROM read_parquet('{stata_pq}')
        ),
        d AS (
            SELECT
                CAST(PIS AS VARCHAR) AS PIS,
                CAST(identificad_{year} AS VARCHAR) AS id_d,
                CAST(firm_emp_{year} AS BIGINT) AS emp_d
            FROM read_parquet('{duck_pq}')
        ),
        m AS (
            SELECT *
            FROM s FULL OUTER JOIN d USING (PIS)
        )
        SELECT
            (SELECT count(*) FROM s) AS stata_rows,
            (SELECT count(*) FROM d) AS duck_rows,
            sum((id_s IS NOT NULL AND id_d IS NOT NULL)::INTEGER) AS pis_both,
            sum((id_s IS NOT NULL AND id_d IS NULL)::INTEGER) AS pis_stata_only,
            sum((id_s IS NULL AND id_d IS NOT NULL)::INTEGER) AS pis_duck_only,
            sum((id_s IS NOT NULL AND id_d IS NOT NULL AND id_s = id_d)::INTEGER) AS same_identificad,
            sum((id_s IS NOT NULL AND id_d IS NOT NULL AND id_s != id_d)::INTEGER) AS different_identificad,
            sum((id_s IS NOT NULL AND id_d IS NOT NULL AND emp_s = emp_d)::INTEGER) AS same_firm_emp,
            sum((id_s IS NOT NULL AND id_d IS NOT NULL AND emp_s != emp_d)::INTEGER) AS different_firm_emp
        FROM m
        """
    ).fetchone()
    con.close()
    keys = [
        "stata_rows", "duck_rows", "pis_both", "pis_stata_only", "pis_duck_only",
        "same_identificad", "different_identificad", "same_firm_emp", "different_firm_emp",
    ]
    return {"year": year, **{k: int(v or 0) for k, v in zip(keys, res)}}


def compare_transition(year: int) -> dict:
    next_year = year + 1
    stata_path = config.RAIS_AUX / f"employers_{year}_{next_year}.csv"
    duck_path = config.TRANSITIONS / f"employers_{year}_{next_year}.parquet"
    con = duckdb.connect()
    con.execute("PRAGMA threads=4")
    res = con.execute(
        f"""
        WITH
        s AS (
            SELECT
                CAST(PIS AS VARCHAR) AS PIS,
                CAST(identificad_{year} AS VARCHAR) AS origin_s,
                CAST(identificad_{next_year} AS VARCHAR) AS dest_s
            FROM read_csv_auto('{stata_path}', header=true, all_varchar=true)
        ),
        d AS (
            SELECT
                CAST(PIS AS VARCHAR) AS PIS,
                CAST(identificad_{year} AS VARCHAR) AS origin_d,
                CAST(identificad_{next_year} AS VARCHAR) AS dest_d
            FROM read_parquet('{duck_path}')
        ),
        m AS (
            SELECT *
            FROM s FULL OUTER JOIN d USING (PIS)
        )
        SELECT
            (SELECT count(*) FROM s) AS stata_rows,
            (SELECT count(*) FROM d) AS duck_rows,
            sum((origin_s IS NOT NULL AND origin_d IS NOT NULL)::INTEGER) AS pis_both,
            sum((origin_s IS NOT NULL AND origin_d IS NULL)::INTEGER) AS pis_stata_only,
            sum((origin_s IS NULL AND origin_d IS NOT NULL)::INTEGER) AS pis_duck_only,
            sum((origin_s IS NOT NULL AND origin_d IS NOT NULL AND origin_s = origin_d)::INTEGER) AS same_origin,
            sum((origin_s IS NOT NULL AND origin_d IS NOT NULL AND origin_s != origin_d)::INTEGER) AS different_origin,
            sum((origin_s IS NOT NULL AND origin_d IS NOT NULL AND dest_s = dest_d)::INTEGER) AS same_destination,
            sum((origin_s IS NOT NULL AND origin_d IS NOT NULL AND dest_s != dest_d)::INTEGER) AS different_destination
        FROM m
        """
    ).fetchone()
    con.close()
    keys = [
        "stata_rows", "duck_rows", "pis_both", "pis_stata_only", "pis_duck_only",
        "same_origin", "different_origin", "same_destination", "different_destination",
    ]
    return {"pair": f"{year}_{next_year}", **{k: int(v or 0) for k, v in zip(keys, res)}}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--years", nargs="+", type=int, default=[2009, 2010])
    parser.add_argument("--transition-start", type=int, default=2009)
    args = parser.parse_args()

    config.ensure_dirs()
    report = {
        "yearly": [compare_year(year) for year in args.years],
        "transition": compare_transition(args.transition_start),
    }
    out = config.REPORTS / f"comparison_{args.transition_start}_{args.transition_start + 1}.json"
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print(f"[compare] wrote {out}")


if __name__ == "__main__":
    main()
