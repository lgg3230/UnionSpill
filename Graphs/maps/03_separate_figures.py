"""
03_separate_figures.py
----------------------
Two standalone PDF maps (one outcome each):

  sample_concentration.pdf        Municipalities shaded by # sample establishments.
  treated_control_location.pdf    Establishment points, treated vs. control.

Inputs (built by 01_build_map_data.py):
  data/estab_geo.csv, data/mun_counts.csv
Shapefile:
  shapefiles/BR_Municipios_2022.shp  (IBGE 2022, CD_MUN 7-digit, EPSG:4674)
Projection: EPSG:5880 (Brazil Polyconic).
"""
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
SHP = HERE / "shapefiles" / "BR_Municipios_2022.shp"
OUTDIR = HERE
PROJ = 5880

TREAT_COLOR = "#c0392b"
CTRL_COLOR  = "#2c7fb8"

mpl.rcParams.update({"font.size": 11})

# --- load ------------------------------------------------------------------
print("Loading shapefile + data ...")
raw = gpd.read_file(SHP)[["CD_MUN", "SIGLA_UF", "geometry"]].to_crs(epsg=PROJ)
muni = raw[["CD_MUN", "geometry"]].copy()
muni["municipio"] = muni["CD_MUN"].astype(str).str[:6].astype(int)
uf = raw[["SIGLA_UF", "geometry"]].dissolve(by="SIGLA_UF").reset_index()

counts = pd.read_csv(DATA / "mun_counts.csv")
estab = pd.read_csv(DATA / "estab_geo.csv")

mg = muni.merge(counts, on="municipio", how="left")

cent = muni.copy()
cent["cx"] = cent.geometry.centroid.x
cent["cy"] = cent.geometry.centroid.y
cmap_xy = cent.set_index("municipio")[["cx", "cy"]]


def base(ax):
    uf.boundary.plot(ax=ax, color="0.7", linewidth=0.3, zorder=1, rasterized=True)
    ax.set_axis_off()
    ax.set_aspect("equal")


# ===========================================================================
# Figure 1 — spatial concentration of the sample
# ===========================================================================
print("Figure 1: sample concentration ...")
fig, ax = plt.subplots(figsize=(7.5, 7.8))
mg.plot(ax=ax, color="#f0f0f0", linewidth=0, zorder=0, rasterized=True)  # no sample
norm = LogNorm(vmin=1, vmax=mg["n_estab"].max())
mg[mg["n_estab"].notna()].plot(
    ax=ax, column="n_estab", cmap="YlOrRd", norm=norm,
    linewidth=0.05, edgecolor="0.6", zorder=2, rasterized=True)
base(ax)
sm = mpl.cm.ScalarMappable(cmap="YlOrRd", norm=norm)
cb = fig.colorbar(sm, ax=ax, fraction=0.035, pad=0.01, shrink=0.7)
cb.set_label("Establishments per municipality (log scale)")
fig.tight_layout()
out = OUTDIR / "sample_concentration.pdf"
fig.savefig(out, dpi=300, bbox_inches="tight")
fig.savefig(out.with_suffix(".png"), dpi=300, bbox_inches="tight")
print(f"  saved {out.name} (+png)")
plt.close(fig)

# ===========================================================================
# Figure 2 — location of treated and control establishments
# ===========================================================================
print("Figure 2: treated vs. control ...")
fig, ax = plt.subplots(figsize=(7.5, 7.8))
mg.plot(ax=ax, color="#f7f7f7", linewidth=0, zorder=0, rasterized=True)
base(ax)
rng = np.random.default_rng(42)
pts = estab.merge(cmap_xy, left_on="municipio", right_index=True, how="inner")
jit = 12000
pts["x"] = pts["cx"] + rng.uniform(-jit, jit, len(pts))
pts["y"] = pts["cy"] + rng.uniform(-jit, jit, len(pts))
# plot control first so the (fewer) treated points stay visible on top
for val, color, lab in [(0, CTRL_COLOR, "Control"), (1, TREAT_COLOR, "Treated")]:
    s = pts[pts["treat_ultra"] == val]
    ax.scatter(s["x"], s["y"], s=5, c=color, alpha=0.45,
               linewidths=0, label=f"{lab} (n={len(s):,})", zorder=3, rasterized=True)
ax.legend(loc="lower left", frameon=False, markerscale=2.5, fontsize=10)
fig.tight_layout()
out = OUTDIR / "treated_control_location.pdf"
fig.savefig(out, dpi=300, bbox_inches="tight")
fig.savefig(out.with_suffix(".png"), dpi=300, bbox_inches="tight")
print(f"  saved {out.name} (+png)")
plt.close(fig)
print("Done.")
