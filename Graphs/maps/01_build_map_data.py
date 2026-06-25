"""
01_build_map_data.py
--------------------
Builds the inputs for the geographic-distribution map of the spillover sample:

  (1) estab_geo.csv   : one row per establishment
                        identificad, municipio (6-digit IBGE), treat_ultra
  (2) mun_counts.csv  : establishments per municipality, split treated/control
  (3) mun_flows.csv   : municipality-to-municipality worker-flow edges
                        (the outside-option network), reconstructed from
                        consecutive-year worker transitions in the pre-period.

Sources (all local):
  - Gui_coding/Luis_og_files/worker_panel_lagos.parquet
        worker-year panel: identificad, PIS, municipio, year (2009-2016)
  - Gui_coding/Luis_og_files/network_degree_full_rais.csv
        identificad, treat_ultra  (12,276 treated / 4,196 control)

Notes:
  - municipio is the 6-digit IBGE code (no check digit). IBGE shapefiles use
    7-digit codes; the crosswalk is handled in the plotting script.
  - The establishment-level bilateral_connectivity_2007_2011.csv is produced by
    bilateral_connectivity.m on the cluster and is NOT available locally, so the
    network is reconstructed here directly from worker transitions. We use the
    PRE-reform period (2009->2010 and 2010->2011), which is the window the
    outside-option / connectivity measure is built on.
"""
import pandas as pd
import numpy as np
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "Gui_coding").is_dir())   # project root
GUI = ROOT / "Gui_coding" / "Luis_og_files"
OUT = HERE / "data"
OUT.mkdir(parents=True, exist_ok=True)

PANEL = GUI / "worker_panel_lagos.parquet"
DEGREE = GUI / "network_degree_full_rais.csv"

PRE_YEARS = [2009, 2010, 2011]          # pre-reform window for the network

# ---------------------------------------------------------------------------
# 1. treated/control flag
# ---------------------------------------------------------------------------
print("Loading treated/control flags ...")
treat = pd.read_csv(DEGREE, dtype={"identificad": str})[["identificad", "treat_ultra"]]
treat = treat.dropna(subset=["treat_ultra"])
treat["treat_ultra"] = treat["treat_ultra"].astype(int)
print(f"  {len(treat):,} establishments  "
      f"({(treat.treat_ultra==1).sum():,} treated / {(treat.treat_ultra==0).sum():,} control)")

# ---------------------------------------------------------------------------
# 2. worker panel: identificad, PIS, municipio, year (pre-period only)
# ---------------------------------------------------------------------------
print("Loading worker panel (pre-reform years) ...")
wp = pd.read_parquet(PANEL, columns=["identificad", "PIS", "municipio", "year"])
wp["identificad"] = wp["identificad"].astype(str)
wp = wp[wp["year"].isin(PRE_YEARS)].copy()
wp["municipio"] = pd.to_numeric(wp["municipio"], errors="coerce").astype("Int64")
print(f"  {len(wp):,} worker-year rows over {PRE_YEARS}")

# ---------------------------------------------------------------------------
# 3. establishment -> municipality (modal municipio across the pre-period)
# ---------------------------------------------------------------------------
print("Assigning each establishment its modal municipality ...")
mode_mun = (wp.dropna(subset=["municipio"])
              .groupby(["identificad", "municipio"]).size()
              .reset_index(name="n")
              .sort_values(["identificad", "n"], ascending=[True, False])
              .drop_duplicates("identificad")[["identificad", "municipio"]])

estab = treat.merge(mode_mun, on="identificad", how="inner")
estab = estab.dropna(subset=["municipio"])
estab["municipio"] = estab["municipio"].astype(int)
estab.to_csv(OUT / "estab_geo.csv", index=False)
print(f"  estab_geo.csv: {len(estab):,} establishments with a municipality")

# ---------------------------------------------------------------------------
# 4. municipality-level counts (sample density + treated/control split)
# ---------------------------------------------------------------------------
mun_counts = (estab.groupby("municipio")
              .agg(n_estab=("identificad", "size"),
                   n_treated=("treat_ultra", "sum"))
              .reset_index())
mun_counts["n_control"] = mun_counts["n_estab"] - mun_counts["n_treated"]
mun_counts.to_csv(OUT / "mun_counts.csv", index=False)
print(f"  mun_counts.csv: {len(mun_counts):,} municipalities")

# ---------------------------------------------------------------------------
# 5. worker-flow network: establishment transitions -> municipality edges
#    A worker contributes a flow A->B if employed at estab A in year t and at a
#    DIFFERENT estab B in year t+1, both estabs in the sample.
# ---------------------------------------------------------------------------
print("Reconstructing worker-flow network from consecutive-year transitions ...")
est2mun = dict(zip(estab["identificad"], estab["municipio"]))
sample_ids = set(est2mun)

# one (PIS, year) -> primary establishment (the one in the sample, modal if many)
wp_s = wp[wp["identificad"].isin(sample_ids)].copy()
pe = (wp_s.groupby(["PIS", "year", "identificad"]).size().reset_index(name="n")
        .sort_values(["PIS", "year", "n"], ascending=[True, True, False])
        .drop_duplicates(["PIS", "year"]))

edges = []
for (y0, y1) in [(2009, 2010), (2010, 2011)]:
    a = pe[pe.year == y0][["PIS", "identificad"]].rename(columns={"identificad": "i"})
    b = pe[pe.year == y1][["PIS", "identificad"]].rename(columns={"identificad": "j"})
    m = a.merge(b, on="PIS")
    m = m[m["i"] != m["j"]]
    edges.append(m[["i", "j"]])
edges = pd.concat(edges, ignore_index=True)
edges["mi"] = edges["i"].map(est2mun)
edges["mj"] = edges["j"].map(est2mun)
edges = edges.dropna(subset=["mi", "mj"])
edges = edges[edges["mi"] != edges["mj"]]          # drop within-municipality flows

# undirected municipality pair
edges["a"] = edges[["mi", "mj"]].min(axis=1).astype(int)
edges["b"] = edges[["mi", "mj"]].max(axis=1).astype(int)
mun_flows = (edges.groupby(["a", "b"]).size().reset_index(name="weight")
             .sort_values("weight", ascending=False))
mun_flows.to_csv(OUT / "mun_flows.csv", index=False)
print(f"  mun_flows.csv: {len(mun_flows):,} municipality pairs, "
      f"{int(mun_flows.weight.sum()):,} total worker moves")
print("Done.")
