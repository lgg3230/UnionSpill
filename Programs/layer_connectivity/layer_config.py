"""Central configuration for the firm × layer × year connectivity pipeline."""
import pandas as pd

LAYER_DEFS = {
    "occ3": {
        "description": "3-digit occupation (floor(ocup2002 / 10))",
        "raw_cols":    ["ocup2002"],
        "compute":     lambda df: (df["ocup2002"] // 10).astype("Int64"),
        "parquet_col": None,   # must compute from ocup2002
    },
    "edu": {
        "description": "Education bins: 0_no_hs / 1_hs / 2_higher",
        "raw_cols":    ["grinstrucao"],
        "compute":     lambda df: pd.cut(
                           df["grinstrucao"].astype(float), bins=[0, 6, 8, 11],
                           labels=["0_no_hs", "1_hs", "2_higher"]),
        "parquet_col": "educ_bin",   # pre-computed in worker_panel_lagos.parquet
    },
}

YEAR_PAIRS  = [(2007, 2008), (2008, 2009), (2009, 2010), (2010, 2011)]
PAIR_LABELS = {(2007, 2008): "0708", (2008, 2009): "0809",
               (2009, 2010): "0910", (2010, 2011): "1011"}

# For origin layer: years covered by worker_panel_lagos.parquet (no raw RAIS read needed)
PARQUET_ORIGIN_YEARS = {2009, 2010}

# For destination layer: years covered by worker_panel_lagos.parquet
PARQUET_DEST_YEARS = {2009, 2010, 2011}

IPCA = {
    2007: 0.607949398754109, 2008: 0.643834976197206,
    2009: 0.671594887351247, 2010: 0.711277338716318,
    2011: 0.757534213038901,
}

# Paths
import os
_proj = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR  = "/kellogg/proj/lgg3230/RAIS/output/data/full"
RAIS_AUX  = os.path.join(_proj, "Data/RAIS_aux")
CBA_FIRM  = os.path.join(_proj, "Data/CBA_RAIS_firm_level")
OUT_BASE  = os.path.join(_proj, "Data/layer_connectivity")

YEARLY_EMP_TEMPLATE  = os.path.join(RAIS_AUX, "yearly_employers_{year}.dta")
WORKER_PANEL_PARQUET = os.path.join(CBA_FIRM,  "worker_panel_lagos.parquet")
CBA_RAIS_FIRM        = os.path.join(CBA_FIRM,  "cba_rais_firm_2009_2016_flows_1.dta")
ORIG_FIRM_CONN       = os.path.join(RAIS_AUX,  "connectivity_treat_2007_2011_agg.dta")
