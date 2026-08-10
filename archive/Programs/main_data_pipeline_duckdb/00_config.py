from pathlib import Path

PROJECT = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_RAW = Path("/kellogg/proj/lgg3230/RAIS/output/data/full")

DATA = PROJECT / "Data"
RAIS_AUX = DATA / "RAIS_aux"
OUT = DATA / "main_pipeline_duckdb"
STAGING = OUT / "staging"
YEARLY = OUT / "yearly_employers"
TRANSITIONS = OUT / "transitions"
REPORTS = OUT / "reports"

YEARS_DEFAULT = [2009, 2010]
RAIS_COLUMNS = ["PIS", "identificad", "empem3112", "tempempr", "horascontr", "remdezr"]


def ensure_dirs() -> None:
    for path in [OUT, STAGING, YEARLY, TRANSITIONS, REPORTS]:
        path.mkdir(parents=True, exist_ok=True)
