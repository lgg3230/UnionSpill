"""Central configuration for the firm × layer × year connectivity pipeline."""
import numpy as np
import pandas as pd


def _occ4_pandas(s):
    """Map ocup2002 series to 4-bin occupation layer using CBO2002 first digit.

    ocup2002 is stored as a 6-digit integer (e.g. 111220), so the first digit
    is floor(code / 100000).
    """
    first = pd.to_numeric(s, errors="coerce") // 100000
    return np.select(
        [first == 1, first.isin([2, 3]), first == 4, first >= 5],
        ["1_mgr", "23_high", "4_bur", "5p_low"],
        default="nan",  # string sentinel so load_layer_from_raw_rais can filter
    )


_OCC4_SQL = """
    CASE
        WHEN FLOOR(ocup2002 / 100000) = 1       THEN '1_mgr'
        WHEN FLOOR(ocup2002 / 100000) IN (2, 3) THEN '23_high'
        WHEN FLOOR(ocup2002 / 100000) = 4       THEN '4_bur'
        WHEN FLOOR(ocup2002 / 100000) >= 5      THEN '5p_low'
        ELSE NULL
    END"""


def _occ5_sara_pandas(s):
    """Map ocup2002 to Sara Moreira's 5-layer occupation partition.

    Source: Programs/layer_connectivity/sara_files/000_clean_rais.do
            + collapse in 010_collapse_firm.do (which merges Sara's layers 1+2
            into a single managers bin).

    Bins (using first digit d1 and second digit d2):
        '1_mgr'  : managers — d2 in {11,12,13,14}  (Sara layers 1 + 2)
        '2_pro'  : professionals — d1 == 2          (Sara layer 3)
        '3_bur'  : bureaucrats — d1 in [4,9] AND 3rd digit == 0  (Sara layer 4)
        '4_tech' : technicians — d1 == 3            (Sara layer 5)
        '5_low'  : low-skill — d1 in [4,9] AND 3rd digit != 0    (Sara layer 6)
    """
    v = pd.to_numeric(s, errors="coerce")
    d1 = (v // 100000).astype("Int64")
    d2 = (v // 10000).astype("Int64")
    d3 = ((v // 1000) % 10).astype("Int64")
    return np.select(
        [
            d2.isin([11, 12, 13, 14]),
            d1 == 2,
            d1.isin([4, 5, 6, 7, 8, 9]) & (d3 == 0),
            d1 == 3,
            d1.isin([4, 5, 6, 7, 8, 9]),
        ],
        ["1_mgr", "2_pro", "3_bur", "4_tech", "5_low"],
        default="nan",
    )


_OCC5_SARA_SQL = """
    CASE
        WHEN FLOOR(ocup2002 / 10000) IN (11, 12, 13, 14)              THEN '1_mgr'
        WHEN FLOOR(ocup2002 / 100000) = 2                              THEN '2_pro'
        WHEN FLOOR(ocup2002 / 100000) BETWEEN 4 AND 9
             AND MOD(FLOOR(ocup2002 / 1000), 10) = 0                   THEN '3_bur'
        WHEN FLOOR(ocup2002 / 100000) = 3                              THEN '4_tech'
        WHEN FLOOR(ocup2002 / 100000) BETWEEN 4 AND 9                  THEN '5_low'
        ELSE NULL
    END"""


def _ten2_pandas(s):
    """Map tempempr (tenure in months) to binary tenure layer at 12 months.

    Cutoff at 12 months based on a Lagos-sample diagnostic (May 2026): the
    pooled tenure distribution is monotonically decaying, ~23% of workers
    fall below 12 months, and firms vary widely in their share of these
    'short-tenure' workers (within-firm p10=6%, p90=48%).
    """
    v = pd.to_numeric(s, errors="coerce")
    return np.select(
        [v < 12, v >= 12],
        ["lt12mo", "ge12mo"],
        default="nan",
    )


_TEN2_SQL = """
    CASE
        WHEN tempempr <  12 THEN 'lt12mo'
        WHEN tempempr >= 12 THEN 'ge12mo'
        ELSE NULL
    END"""


LAYER_DEFS = {
    "occ3": {
        "description": "3-digit occupation (floor(ocup2002 / 10))",
        "raw_cols":    ["ocup2002"],
        "compute":     lambda df: (df["ocup2002"] // 10).astype("Int64"),
        "parquet_col": None,   # must compute from ocup2002
    },
    "occ4": {
        "description": "4-bin occupation (CBO2002 first digit: 1=mgr, 2/3=high, 4=bur, 5+=low)",
        "raw_cols":    ["ocup2002"],
        "compute":     None,
        "parquet_col": None,
        "sql_layer_expr":  _OCC4_SQL,
        "pandas_compute":  _occ4_pandas,
    },
    "edu": {
        "description": "Education bins: 0_no_hs / 1_hs / 2_higher",
        "raw_cols":    ["grinstrucao"],
        "compute":     lambda df: pd.cut(
                           df["grinstrucao"].astype(float), bins=[0, 6, 8, 11],
                           labels=["0_no_hs", "1_hs", "2_higher"]),
        "parquet_col": "educ_bin",   # pre-computed in worker_panel_lagos.parquet
    },
    "edu2": {
        "description": "Education bins: no_hs / has_hs (derived from edu via remap)",
        "raw_cols":    ["grinstrucao"],
        "compute":     None,   # derived from edu; run 01b_remap_edu2.py instead of 01
        "parquet_col": "educ_bin",
    },
    "occ2c": {
        "description": "2-bin occupation: upper_skill (mgr+high+bur) / low_skill (low) — derived from occ4",
        "raw_cols":    ["ocup2002"],
        "compute":     None,   # derived from occ4; run 01f_remap_occ2c.py
        "parquet_col": None,
    },
    "occ2": {
        "description": "2-bin occupation: high_skill (mgr+high) / low_skill (bur+low) — derived from occ4",
        "raw_cols":    ["ocup2002"],
        "compute":     None,   # derived from occ4; run 01e_remap_occ2.py instead of 01
        "parquet_col": None,
    },
    "occ5_sara": {
        "description": ("5-bin occupation following Sara Moreira's CBO2002 partition "
                        "(managers 11-14 / professionals 1d=2 / bureaucrats 4-9+3rd=0 / "
                        "technicians 1d=3 / low-skill 4-9 residual)"),
        "raw_cols":    ["ocup2002"],
        "compute":     None,
        "parquet_col": None,
        "sql_layer_expr":  _OCC5_SARA_SQL,
        "pandas_compute":  _occ5_sara_pandas,
    },
    "ten2": {
        "description": "Binary tenure: lt12mo (<1yr) / ge12mo (>=1yr), computed from tempempr",
        "raw_cols":    ["tempempr"],
        "compute":     None,
        "parquet_col": None,
        "sql_layer_expr":  _TEN2_SQL,
        "pandas_compute":  _ten2_pandas,
    },
}

YEAR_PAIRS  = [(2007, 2008), (2008, 2009), (2009, 2010), (2010, 2011)]
PAIR_LABELS = {(2007, 2008): "0708", (2008, 2009): "0809",
               (2009, 2010): "0910", (2010, 2011): "1011"}

# For origin layer: years covered by worker_panel_lagos.parquet (no raw RAIS read needed)
PARQUET_ORIGIN_YEARS = {2009, 2010}

# For destination layer: years covered by worker_panel_lagos.parquet
PARQUET_DEST_YEARS = {2009, 2010, 2011}

# IPCA deflators to December 2015 prices (2015 == 1). Must cover every year that
# appears in the outcomes panel (2009-2016), not just the transition year-pairs:
# ipca_case_sql() emits `ELSE NULL`, so a missing year silently NULLs the deflated
# wage for that year. Series copied from Programs/011_rais_to_firm.do:13, the same
# one used to build the monthly lr_remdezr in 011c_worker_panel.py.
IPCA = {
    2007: 0.607949398754109, 2008: 0.643834976197206,
    2009: 0.671594887351247, 2010: 0.711277338716318,
    2011: 0.757534213038901, 2012: 0.80176356558955,
    2013: 0.849153270408197, 2014: 0.903562518222102,
    2015: 1.0,               2016: 1.06287988213221,
    2017: 1.09420743038879,
}

# Paths
import os
_proj = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR  = "/kellogg/proj/lgg3230/RAIS/output/data/full"
RAIS_AUX  = os.path.join(_proj, "Data/RAIS_aux")
CBA_FIRM  = os.path.join(_proj, "Data/CBA_RAIS_firm_level")
OUT_BASE  = os.path.join(_proj, "Data/layer_connectivity")

YEARLY_EMP_TEMPLATE         = os.path.join(RAIS_AUX, "yearly_employers_{year}.dta")
YEARLY_EMP_PARQUET_TEMPLATE = os.path.join(RAIS_AUX, "yearly_employers_{year}.parquet")
WORKER_PANEL_PARQUET        = os.path.join(CBA_FIRM,  "worker_panel_lagos.parquet")
CBA_RAIS_FIRM               = os.path.join(CBA_FIRM,  "cba_rais_firm_2009_2016_flows_1.dta")
FIRM_STATUS_PARQUET         = os.path.join(CBA_FIRM,  "firm_status.parquet")
ORIG_FIRM_CONN              = os.path.join(RAIS_AUX,  "connectivity_treat_2007_2011_agg.dta")
ORIG_FIRM_CONN_PARQUET      = os.path.join(RAIS_AUX,  "connectivity_treat_2007_2011_agg.parquet")
