#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: CONNECTIVITY MEASURE ILLUSTRATION

Creates a conceptual figure illustrating the connectivity measure:
  - Blue circles  = untreated firms
  - Red squares   = treated firms
  - Arrows        = worker flows in both directions (widths ∝ flow size)

Connectivity (firm i) = (flows between i and treated firms) / avg employment_i
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import matplotlib.patches as mpatches
from pathlib import Path

# ─── FONT ──────────────────────────────────────────────────────────────────────
import matplotlib.font_manager as fm
font_dir = Path("/kellogg/proj/lgg3230/UnionSpill/fonts")
for fp in font_dir.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))
mpl.rcParams["font.family"] = "Libertinus Serif"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42

# ─── PATHS ─────────────────────────────────────────────────────────────────────
GRAPHS_DIR = Path("/kellogg/proj/lgg3230/UnionSpill/Graphs/connectivity_diagram")
GRAPHS_DIR.mkdir(parents=True, exist_ok=True)

# ─── COLORS ────────────────────────────────────────────────────────────────────
UNTREATED_FACE = "#AEC6E8"
UNTREATED_EDGE = "#2166AC"
TREATED_FACE   = "#F4A582"
TREATED_EDGE   = "#B2182B"
FOCAL_FACE     = "#D0E8FF"
FOCAL_EDGE     = "#08519C"

ARROW_TREATED   = "#B2182B"
ARROW_UNTREATED = "#4393C3"
ARROW_BG        = "#AAAAAA"

FIRM_R = 0.42

# ─── FIRM POSITIONS ────────────────────────────────────────────────────────────
firms = {
    "F":  dict(xy=(1.5, 3.3),  kind="untreated",    focal=True),
    "U1": dict(xy=(4.2, 5.0),  kind="untreated",    focal=False),
    "U2": dict(xy=(4.6, 1.5),  kind="untreated",    focal=False),
    "U3": dict(xy=(0.3, 5.5),  kind="untreated",    focal=False),
    "U4": dict(xy=(0.2, 1.0),  kind="untreated",    focal=False),
    "T1": dict(xy=(6.8, 4.2),  kind="treated",      focal=False),
    "T2": dict(xy=(6.5, 1.8),  kind="treated",      focal=False),
    "T3": dict(xy=(4.2, 6.8),  kind="treated",      focal=False),
    # Out-of-sample firms (gray dashed)
    "X1": dict(xy=(7.9, 6.0),  kind="out_of_sample", focal=False),
    "X2": dict(xy=(7.6, 0.3),  kind="out_of_sample", focal=False),
    "X3": dict(xy=(2.8, 7.5),  kind="out_of_sample", focal=False),
}

# Flows FROM focal firm i → j
FOCAL_AVG_EMP = 50
focal_out = [
    dict(dst="T1", n=15, treated=True),
    dict(dst="T2", n=11, treated=True),
    dict(dst="T3", n=3,  treated=True),
    dict(dst="U1", n=12, treated=False),
    dict(dst="U2", n=8,  treated=False),
]

# Flows INTO focal firm j → i
focal_in = [
    dict(src="T1", n=9,  treated=True),
    dict(src="T2", n=7,  treated=True),
    dict(src="T3", n=2,  treated=True),
    dict(src="U1", n=6,  treated=False),
    dict(src="U2", n=5,  treated=False),
]

# Flows to/from out-of-sample firms (shown in gray, don't count)
oos_flows = [
    dict(src="F",  dst="X1", n=4),
    dict(src="X1", dst="F",  n=2),
    dict(src="F",  dst="X2", n=6),
    dict(src="X2", dst="F",  n=3),
]

# Background flows (non-focal, faded)
bg_flows = [
    ("U3", "T3"), ("U3", "U1"),
    ("U4", "T2"), ("U4", "U2"),
    ("U1", "T1"), ("U2", "T2"),
    ("T1", "T3"),
]

# ─── HELPERS ───────────────────────────────────────────────────────────────────
def boundary(src_xy, dst_xy, r=FIRM_R, gap=0.1):
    vec  = np.array(dst_xy) - np.array(src_xy)
    dist = np.linalg.norm(vec)
    unit = vec / dist
    return (np.array(src_xy) + unit * (r + gap),
            np.array(dst_xy) - unit * (r + gap))

def perp_unit(src_xy, dst_xy):
    vec  = np.array(dst_xy) - np.array(src_xy)
    unit = vec / np.linalg.norm(vec)
    return np.array([-unit[1], unit[0]])

def draw_firm(ax, name, info):
    x, y  = info["xy"]
    focal = info.get("focal", False)
    kind  = info["kind"]

    if kind == "out_of_sample":
        # Gray dashed circle
        circ = plt.Circle((x, y), FIRM_R, facecolor="#E8E8E8", edgecolor="#888888",
                           linewidth=1.4, linestyle="--", zorder=4)
        ax.add_patch(circ)
        ax.text(x, y, name, ha="center", va="center", fontsize=9,
                color="#666666", fontweight="bold", zorder=5)
        return

    if kind == "untreated":
        face = FOCAL_FACE if focal else UNTREATED_FACE
        edge = FOCAL_EDGE if focal else UNTREATED_EDGE
        lw   = 2.5 if focal else 1.8
        ax.add_patch(plt.Circle((x, y), FIRM_R,
                                facecolor=face, edgecolor=edge,
                                linewidth=lw, zorder=4))
    else:
        ax.add_patch(mpatches.FancyBboxPatch(
            (x - FIRM_R, y - FIRM_R), 2*FIRM_R, 2*FIRM_R,
            boxstyle="square,pad=0",
            facecolor=TREATED_FACE, edgecolor=TREATED_EDGE,
            linewidth=1.8, zorder=4))

    label_color = FOCAL_EDGE if focal else (TREATED_EDGE if kind == "treated" else UNTREATED_EDGE)
    ax.text(x, y, name if not focal else "$i$",
            ha="center", va="center", fontsize=9,
            color=label_color, fontweight="bold", zorder=5)

# ─── FIGURE ────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(9, 6.5))
ax.set_xlim(-0.6, 8.5)
ax.set_ylim(-1.8, 8.0)
ax.set_aspect("equal")
ax.axis("off")

# Arrow width parameters (used for all focal/oos flows)
max_n    = max(fl["n"] for fl in focal_out + focal_in + oos_flows)
lw_scale = 11.0
RAD_OUT  =  0.18
RAD_IN   = -0.18
PERP_OUT =  0.30
PERP_IN  = -0.30

# ── Background flows ──────────────────────────────────────────────────────────
for src_n, dst_n in bg_flows:
    start, end = boundary(firms[src_n]["xy"], firms[dst_n]["xy"])
    ax.annotate("", xy=end, xytext=start,
                arrowprops=dict(arrowstyle="-|>", color=ARROW_BG,
                                lw=0.8, alpha=0.3, mutation_scale=9))

# ── Out-of-sample flows (gray, curved, don't count toward connectivity) ───────
for fl in oos_flows:
    s = firms[fl["src"]]["xy"]
    d = firms[fl["dst"]]["xy"]
    start, end = boundary(s, d)
    lw = max(0.6, (fl["n"] / max_n) * lw_scale * 0.6)
    ax.annotate("", xy=end, xytext=start,
                arrowprops=dict(arrowstyle="-|>", color="#999999", lw=lw,
                                alpha=0.55, mutation_scale=8 + lw,
                                connectionstyle="arc3,rad=0.18"))

# ── Focal outflows (i → j), curved upward ────────────────────────────────────
for fl in focal_out:
    s = firms["F"]["xy"]
    d = firms[fl["dst"]]["xy"]
    start, end = boundary(s, d)
    color = ARROW_TREATED if fl["treated"] else ARROW_UNTREATED
    lw    = max(0.8, (fl["n"] / max_n) * lw_scale)

    ax.annotate("", xy=end, xytext=start,
                arrowprops=dict(arrowstyle="-|>", color=color, lw=lw,
                                alpha=0.85, mutation_scale=10 + lw,
                                connectionstyle=f"arc3,rad={RAD_OUT}"))

    pv  = perp_unit(s, d)
    mid = (np.array(start) + np.array(end)) / 2 + pv * PERP_OUT
    ax.text(mid[0], mid[1], f"{fl['n']}",
            ha="center", va="center", fontsize=7.5, color=color,
            fontweight="bold", zorder=6,
            bbox=dict(boxstyle="round,pad=0.12", fc="white", ec="none", alpha=0.85))

# ── Focal inflows (j → i), curved opposite ────────────────────────────────────
for fl in focal_in:
    s = firms[fl["src"]]["xy"]
    d = firms["F"]["xy"]
    start, end = boundary(s, d)
    color = ARROW_TREATED if fl["treated"] else ARROW_UNTREATED
    lw    = max(0.8, (fl["n"] / max_n) * lw_scale)

    ax.annotate("", xy=end, xytext=start,
                arrowprops=dict(arrowstyle="-|>", color=color, lw=lw,
                                alpha=0.55, mutation_scale=10 + lw,
                                connectionstyle=f"arc3,rad={RAD_IN}"))

    pv  = perp_unit(s, d)
    mid = (np.array(start) + np.array(end)) / 2 + pv * PERP_IN
    ax.text(mid[0], mid[1], f"{fl['n']}",
            ha="center", va="center", fontsize=7.5, color=color,
            fontweight="bold", zorder=6,
            bbox=dict(boxstyle="round,pad=0.12", fc="white", ec="none", alpha=0.85))

# ── Draw firms on top ─────────────────────────────────────────────────────────
for name, info in firms.items():
    draw_firm(ax, name, info)

fx, fy = firms["F"]["xy"]
ax.text(fx, fy - FIRM_R - 0.2,
        f"Focal firm $i$\nAvg. emp. $= {FOCAL_AVG_EMP}$",
        ha="center", va="top", fontsize=8.5, color=FOCAL_EDGE, style="italic")

# ─── CONNECTIVITY CALLOUT ─────────────────────────────────────────────────────
treated_out = sum(f["n"] for f in focal_out if f["treated"])
treated_in  = sum(f["n"] for f in focal_in  if f["treated"])
total_flows = treated_out + treated_in
conn_val    = total_flows / FOCAL_AVG_EMP

cx, cy = 6.2, -1.0
formula_str = (
    r"Connectivity$_i$  $=$  "
    r"$\dfrac{\sum_{j\in\,\mathcal{T}}\,(\mathrm{flows}_{ij} + \mathrm{flows}_{ji})}{\overline{L}_{i}}$"
    r"  $= \dfrac{" + str(total_flows) + r"}{" + str(FOCAL_AVG_EMP) + r"}$"
    f"  $= {conn_val:.2f}$"
)
ax.text(cx, cy + 0.62, formula_str,
        ha="center", va="bottom", fontsize=10.0,
        bbox=dict(boxstyle="round,pad=0.5", fc="#F5F5F5", ec="0.65", lw=1.1),
        zorder=7)

ax.annotate("", xy=(fx + 0.2, fy - FIRM_R - 0.1),
            xytext=(cx - 1.3, cy + 0.55),
            arrowprops=dict(arrowstyle="-", color="0.5",
                            lw=0.8, linestyle="dashed",
                            connectionstyle="arc3,rad=0.15"),
            zorder=3)

# ─── LEGEND ───────────────────────────────────────────────────────────────────
# Two-row legend: firm types (top row), flow types (bottom row)
from matplotlib.lines import Line2D

firm_handles = [
    mpatches.Patch(facecolor=FOCAL_FACE,     edgecolor=FOCAL_EDGE,     linewidth=2.0,
                   label="Untreated firm (focal)"),
    mpatches.Patch(facecolor=UNTREATED_FACE, edgecolor=UNTREATED_EDGE, linewidth=1.6,
                   label="Untreated firm"),
    mpatches.Patch(facecolor=TREATED_FACE,   edgecolor=TREATED_EDGE,   linewidth=1.6,
                   label="Treated firm"),
    mpatches.Patch(facecolor="#E8E8E8",      edgecolor="#888888",      linewidth=1.4,
                   linestyle="--", label="Firm not in sample"),
]
flow_handles = [
    Line2D([0], [0], color=ARROW_TREATED,   linewidth=2.5, label="Flow ↔ treated firm"),
    Line2D([0], [0], color=ARROW_UNTREATED, linewidth=2.5, label="Flow ↔ untreated firm"),
    Line2D([0], [0], color="#999999",       linewidth=1.5, alpha=0.7,
           label="Flow ↔ out-of-sample firm"),
    Line2D([0], [0], color=ARROW_BG,        linewidth=1.5, alpha=0.4,
           label="Other worker flows"),
]

ax.legend(handles=firm_handles + flow_handles,
          loc="upper center", bbox_to_anchor=(0.5, -0.17),
          ncol=4, frameon=False, fontsize=8.5,
          handlelength=1.4, handleheight=1.0,
          columnspacing=1.0, handletextpad=0.6)

fig.tight_layout(pad=0.2)

# ─── SAVE ──────────────────────────────────────────────────────────────────────
out_pdf = GRAPHS_DIR / "connectivity_diagram.pdf"
out_png = GRAPHS_DIR / "connectivity_diagram.png"
fig.savefig(out_pdf, bbox_inches="tight", dpi=150)
fig.savefig(out_png, bbox_inches="tight", dpi=150)
print(f"Saved: {out_pdf}")
print(f"Saved: {out_png}")
