#!/usr/bin/env python3
"""
Figure 5 — Polynomial augmentation test (job suburbanization / REStat 2023 approach).
Overlays linear, quadratic, and cubic fits on the residualized DiD scatter.
If the quadratic and cubic fits are visually indistinguishable from the linear fit,
this supports the linear specification. Reports joint F-tests for higher-order terms.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/linearity_fig5_poly.pdf
"""

import warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import statsmodels.api as sm
import binsreg
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"
RED    = "#B2182B"
BLUE   = "#2166AC"
GREEN  = "#1A9850"

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel and build firm-level DiD (same as Figures 2 & 3) ───────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages_panel.csv")
df = df.dropna(subset=["e_conn", "e_lr_remdezr_w"])

pre   = df[df["year"] < 2012].groupby("identificad")[["e_conn", "e_lr_remdezr_w"]].mean()
post  = df[df["year"] >= 2012].groupby("identificad")[["e_lr_remdezr_w"]].mean()
firms = pre.join(post, lsuffix="_pre", rsuffix="_post", how="inner")
firms["did"] = firms["e_lr_remdezr_w_post"] - firms["e_lr_remdezr_w_pre"]
firms = firms[["e_conn", "did"]].dropna()
print(f"Firms: {len(firms):,}")

x = firms["e_conn"].values.astype(float)
y = firms["did"].values.astype(float)

x_lo, x_hi = np.quantile(x, 0.01), np.quantile(x, 0.99)
x_grid = np.linspace(x_lo, x_hi, 300)

# ── Fit linear, quadratic, cubic ─────────────────────────────────────────────

def poly_fit_ci(x, y, deg, xg):
    Xp  = np.column_stack([x**d for d in range(1, deg + 1)])
    mod = sm.OLS(y, sm.add_constant(Xp)).fit(cov_type="HC1")
    Xg  = np.column_stack([xg**d for d in range(1, deg + 1)])
    pr  = mod.get_prediction(sm.add_constant(Xg))
    ci  = pr.conf_int()
    return pr.predicted_mean, ci[:, 0], ci[:, 1], mod

_, _, _, mod_lin  = poly_fit_ci(x, y, 1, x_grid)
_, _, _, mod_quad = poly_fit_ci(x, y, 2, x_grid)
_, _, _, mod_cub  = poly_fit_ci(x, y, 3, x_grid)

y_lin,  ci_lin_lo,  ci_lin_hi,  _ = poly_fit_ci(x, y, 1, x_grid)
y_quad, ci_quad_lo, ci_quad_hi, _ = poly_fit_ci(x, y, 2, x_grid)
y_cub,  ci_cub_lo,  ci_cub_hi,  _ = poly_fit_ci(x, y, 3, x_grid)

# F-tests: quadratic (H0: β2=0) and cubic (H0: β2=β3=0)
f_quad = mod_quad.f_test("x2 = 0")
f_cub  = mod_cub.f_test(["x2 = 0", "x3 = 0"])
fv_quad = float(np.atleast_1d(f_quad.fvalue).flat[0])
fv_cub  = float(np.atleast_1d(f_cub.fvalue).flat[0])
print(f"F-test quadratic term:    F={fv_quad:.3f}, p={f_quad.pvalue:.3f}")
print(f"F-test cubic terms joint: F={fv_cub:.3f},  p={f_cub.pvalue:.3f}")

# ── binsreg dots ──────────────────────────────────────────────────────────────

np.random.seed(42)
x_jitter = x + np.random.uniform(0, 1e-8, len(x))
df_bs = pd.DataFrame({"y": y, "x": x_jitter})
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binsreg.binsreg("y", "x", data=df_bs, noplot=True, nbins=100)
d = res.data_plot[0]

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

ax.scatter(d.dots["x"], d.dots["fit"],
           s=20, color="#888888", zorder=3, linewidths=0,
           label="Bin means (100 optimal bins)")

ax.fill_between(x_grid, ci_lin_lo,  ci_lin_hi,  color=RED,   alpha=0.10, zorder=1)
ax.fill_between(x_grid, ci_quad_lo, ci_quad_hi, color=BLUE,  alpha=0.10, zorder=1)
ax.fill_between(x_grid, ci_cub_lo,  ci_cub_hi,  color=GREEN, alpha=0.10, zorder=1)

ax.plot(x_grid, y_lin,  color=RED,   linewidth=1.8, linestyle="-",
        zorder=6, label=f"Linear  (slope: {mod_lin.params[1]:.4f})")
ax.plot(x_grid, y_quad, color=BLUE,  linewidth=1.8, linestyle="--",
        zorder=5, label=f"Quadratic  (F-test $\\beta_2=0$: p={f_quad.pvalue:.3f})")
ax.plot(x_grid, y_cub,  color=GREEN, linewidth=1.8, linestyle=":",
        zorder=4, label=f"Cubic  (F-test $\\beta_2=\\beta_3=0$: p={f_cub.pvalue:.3f})")

ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.set_xlim(x_lo, x_hi)

ax.set_xlabel("Residualized connectivity to treated firms", fontsize=11)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=9.5,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig5_poly.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
