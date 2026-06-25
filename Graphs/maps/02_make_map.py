"""
02_make_map.py
--------------
Three-panel small-multiples map of the spillover sample's geography.

  Panel A  Sample density   : municipalities shaded by # sample establishments.
  Panel B  Treated vs control: establishment points (two colors), at municipality
                              centroids with jitter.
  Panel C  Outside-option   : worker-flow network, municipality-centroid edges,
           network            thresholded to the strongest flows.

Inputs (built by 01_build_map_data.py):
  data/estab_geo.csv, data/mun_counts.csv, data/mun_flows.csv
Shapefile:
  shapefiles/BR_Municipios_2022.shp  (IBGE 2022, CD_MUN = 7-digit, EPSG:4674)
  -> our 'municipio' is the 6-digit code = first 6 digits of CD_MUN.

Projection: reprojected to EPSG:5880 (Brazil Polyconic) for a faithful national map.
Output: Analysis/Graphs/maps/sample_geography_map.{pdf,png}
"""
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.colors import LogNorm
from matplotlib.lines import Line2D
from matplotlib.collections import LineCollection
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
SHP = HERE / "shapefiles" / "BR_Municipios_2022.shp"
OUTDIR = HERE                                   # Cluster/Graphs/maps
OUTDIR.mkdir(parents=True, exist_ok=True)

PROJ = 5880          # Brazil Polyconic (SIRGAS 2000)
TOP_EDGES = 400      # strongest municipality flows drawn in Panel C

TREAT_COLOR = "#c0392b"    # treated
CTRL_COLOR  = "#2c7fb8"    # control
EDGE_COLOR  = "#444444"

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
print("Loading shapefile + data ...")
muni = gpd.read_file(SHP)[["CD_MUN", "geometry"]]
muni["municipio"] = muni["CD_MUN"].astype(str).str[:6].astype(int)
muni = muni.to_crs(epsg=PROJ)

# state outlines (dissolve municipalities by UF prefix for a clean border layer)
uf = gpd.read_file(SHP)[["SIGLA_UF", "geometry"]].to_crs(epsg=PROJ)
uf = uf.dissolve(by="SIGLA_UF").reset_index()

counts = pd.read_csv(DATA / "mun_counts.csv")
estab  = pd.read_csv(DATA / "estab_geo.csv")
flows  = pd.read_csv(DATA / "mun_flows.csv")

# merge counts onto geometry
mg = muni.merge(counts, on="municipio", how="left")
matched = mg["n_estab"].notna().sum()
print(f"  matched {matched}/{len(counts)} sample municipalities to shapefile")

# municipality centroids (projected) for points & network
cent = muni.copy()
cent["cx"] = cent.geometry.centroid.x
cent["cy"] = cent.geometry.centroid.y
cmap_xy = cent.set_index("municipio")[["cx", "cy"]]

# ---------------------------------------------------------------------------
# Figure
# ---------------------------------------------------------------------------
mpl.rcParams.update({"font.size": 9, "axes.titlesize": 11})
fig, axes = plt.subplots(1, 3, figsize=(16.5, 7.2))

def base(ax):
    uf.boundary.plot(ax=ax, color="0.7", linewidth=0.3, zorder=1)
    ax.set_axis_off()
    ax.set_aspect("equal")

# ---- Panel A: sample density -------------------------------------------------
axA = axes[0]
mg.plot(ax=axA, color="#f0f0f0", linewidth=0, zorder=0)          # no-sample fill
norm = LogNorm(vmin=1, vmax=mg["n_estab"].max())
mg[mg["n_estab"].notna()].plot(
    ax=axA, column="n_estab", cmap="YlOrRd", norm=norm,
    linewidth=0.05, edgecolor="0.6", zorder=2)
base(axA)
axA.set_title("A. Sample density\n(establishments per municipality)")
sm = mpl.cm.ScalarMappable(cmap="YlOrRd", norm=norm)
cb = fig.colorbar(sm, ax=axA, fraction=0.035, pad=0.01, shrink=0.7)
cb.set_label("# establishments (log scale)")

# ---- Panel B: treated vs control points -------------------------------------
axB = axes[1]
mg.plot(ax=axB, color="#f7f7f7", linewidth=0, zorder=0)
base(axB)
rng = np.random.default_rng(42)
pts = estab.merge(cmap_xy, left_on="municipio", right_index=True, how="inner")
# jitter within ~12 km so co-located establishments separate visually
jit = 12000
pts["x"] = pts["cx"] + rng.uniform(-jit, jit, len(pts))
pts["y"] = pts["cy"] + rng.uniform(-jit, jit, len(pts))
for val, color, lab in [(0, CTRL_COLOR, "Control"), (1, TREAT_COLOR, "Treated")]:
    s = pts[pts["treat_ultra"] == val]
    axB.scatter(s["x"], s["y"], s=4, c=color, alpha=0.45,
                linewidths=0, label=f"{lab} (n={len(s):,})", zorder=3)
axB.set_title("B. Treated vs. control establishments")
axB.legend(loc="lower left", frameon=False, markerscale=2.5, fontsize=8)

# ---- Panel C: outside-option (worker-flow) network --------------------------
axC = axes[2]
mg.plot(ax=axC, color="#f7f7f7", linewidth=0, zorder=0)
base(axC)
fl = flows.sort_values("weight", ascending=False).head(TOP_EDGES).copy()
fl = fl.merge(cmap_xy, left_on="a", right_index=True).rename(columns={"cx": "ax", "cy": "ay"})
fl = fl.merge(cmap_xy, left_on="b", right_index=True).rename(columns={"cx": "bx", "cy": "by"})
segs = [[(r.ax, r.ay), (r.bx, r.by)] for r in fl.itertuples()]
w = fl["weight"].to_numpy(dtype=float)
wn = (w - w.min()) / (w.max() - w.min())
lw = 0.3 + 3.0 * wn
al = 0.22 + 0.55 * wn
lc = LineCollection(segs, colors=[(0.13, 0.27, 0.46, a) for a in al],
                    linewidths=lw, zorder=2)
axC.add_collection(lc)
# nodes: municipalities present in the sample
nz = cmap_xy.loc[cmap_xy.index.intersection(counts["municipio"])]
axC.scatter(nz["cx"], nz["cy"], s=2.5, c="#222222", alpha=0.6, linewidths=0, zorder=3)
axC.set_title(f"C. Outside-option network\n(top {TOP_EDGES} municipality worker-flow links)")
leg = [Line2D([0], [0], color=(0.13, 0.27, 0.46), lw=2.6, label="stronger flow"),
       Line2D([0], [0], color=(0.13, 0.27, 0.46), lw=0.5, label="weaker flow")]
axC.legend(handles=leg, loc="lower left", frameon=False, fontsize=8)

fig.suptitle("Geographic distribution of the spillover sample and the outside-option network",
             fontsize=13, y=0.99)
fig.tight_layout(rect=[0, 0, 1, 0.96])

for ext in ("pdf", "png"):
    out = OUTDIR / f"sample_geography_map.{ext}"
    fig.savefig(out, dpi=300, bbox_inches="tight")
    print(f"  saved {out}")
print("Done.")
