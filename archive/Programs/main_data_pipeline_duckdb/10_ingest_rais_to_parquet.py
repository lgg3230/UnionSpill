#!/usr/bin/env python3.8
import argparse
import time

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

from pathlib import Path
from importlib.machinery import SourceFileLoader

config = SourceFileLoader("config", str(Path(__file__).with_name("00_config.py"))).load_module()


def ingest_year(year: int, chunksize: int, force: bool) -> Path:
    config.ensure_dirs()
    src = config.RAIS_RAW / f"RAIS_{year}.dta"
    dst = config.STAGING / f"rais_selected_{year}.parquet"
    if not src.exists():
        raise FileNotFoundError(src)

    if dst.exists() and not force:
        print(f"[ingest] {year}: exists, skipping {dst}")
        return dst
    if dst.exists():
        dst.unlink()

    print(f"[ingest] {year}: {src} -> {dst}")
    start = time.time()
    writer = None
    rows = 0

    reader = pd.read_stata(
        src,
        columns=config.RAIS_COLUMNS,
        chunksize=chunksize,
        convert_categoricals=False,
    )

    try:
        for chunk in reader:
            rows += len(chunk)
            for col in ["PIS", "identificad"]:
                chunk[col] = chunk[col].astype("string")
            table = pa.Table.from_pandas(chunk, preserve_index=False)
            if writer is None:
                writer = pq.ParquetWriter(dst, table.schema, compression="zstd")
            writer.write_table(table)
            print(f"[ingest] {year}: wrote {rows:,} rows", flush=True)
    finally:
        if writer is not None:
            writer.close()

    print(f"[ingest] {year}: done {rows:,} rows in {time.time() - start:.1f}s")
    return dst


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--years", nargs="+", type=int, default=config.YEARS_DEFAULT)
    parser.add_argument("--chunksize", type=int, default=1_000_000)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    for year in args.years:
        ingest_year(year, args.chunksize, args.force)


if __name__ == "__main__":
    main()
