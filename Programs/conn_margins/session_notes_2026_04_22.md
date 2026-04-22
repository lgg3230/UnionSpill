# Session Notes — Linearity Defense Pipeline
**Date:** 2026-04-22  
**Pipeline:** `Programs/conn_margins/`

---

## Overview

This document records two consecutive Claude Code sessions building and refining the linearity defense for the UnionSpill paper. The goal is to defend the linear dose–response specification used in the main spillover regressions.

---

## Session 1 Summary (earlier context, recovered from compaction)

### What was built

#### Figure 3a — LOWESS with bootstrap CIs (`linearity_fig3_lowess.py`)
- LOWESS (locally weighted regression) with `frac=0.5` bandwidth, plotted over x ∈ [p1, p99]
- Bootstrap CIs: B=300 resamples, pointwise 2.5/97.5 percentiles
- Motivation: "least functionally impositive" nonparametric smoother
- The LOWESS shows a dip at medium connectivity levels — consistent with the quartile table showing non-monotonic effects — but the CI is wide enough to encompass the OLS line

#### Figure 3b — binsreg with uniform confidence band (`linearity_fig3_binsreg.py`)
- 50-bin binscatter, Cattaneo et al. (2024) methodology
- **Key fix (Cattaneo Problem 2):** switched from `ci=(3,3)` (pointwise) to `cb=(3,3)` (uniform confidence band), which is required for testing whether the linear fit is globally consistent with the data
- OLS overlay (slope ≈ 0.005)
- Input: `Tables/conn_margins/scatter_resid_wages_panel.csv` (residualized variables)

#### Figure 3c — corrected covariate-adjusted binsreg (`linearity_fig3_binsreg_corrected.py`)
- **Fixes Cattaneo Problem 1:** instead of pre-residualizing x and y (valid only under linearity), passes raw variables + control matrix `w` to binsreg, implementing the semi-linear partial-mean estimator (Cattaneo et al. 2024, eq. 3)
- Stata do-file `conn_margins_scatter_controls.do` exports `scatter_raw_controls.csv` with raw DiD, raw connectivity, and 6 categorical controls
- Python builds W = 583 dummies (industry, mode, microregion, 3 quartile sets), passes to `binsreg(..., w=w_cols)`
- OLS slope: **0.0051** (vs 0.0050 residualized) — validates residualized approximation
- Axis limits: x ∈ [−0.15, 2.5], y ∈ [0, 0.25]

#### TeX wrappers
- `Graphs/conn_margins/fig_linearity_binsreg.tex` — residualized figure
- `Graphs/conn_margins/fig_linearity_binsreg_corrected.tex` — corrected figure (journal-quality notes)

#### bib entry added to `UnionSpill-paper/bib.bib`
```bibtex
@article{Cattaneo2024,
  author  = {Cattaneo, Matias D. and Crump, Richard K. and Farrell, Max H. and Feng, Yingjie},
  title   = {On Binscatter},
  journal = {American Economic Review},
  year    = {2024},
  volume  = {114},
  number  = {5},
  pages   = {1488--1514},
  doi     = {10.1257/aer.20221576}
}
```
Note: `UnionSpill-paper/` is gitignored in the main repo — the bib entry lives only locally and in Overleaf.

### Key technical decisions

**Why uniform confidence band, not pointwise CIs?**  
For testing whether the linear OLS fit is globally consistent with the data, you need the 95% band to cover the *entire* function simultaneously. Pointwise CIs are too narrow and would reject a correct linear model at many evaluation points by chance.

**Why internal covariate adjustment (Problem 1)?**  
Cattaneo et al. (2024, Section I.A) show that pre-residualizing x and y before binscatter is only valid under linearity. For nonlinear true functions it distorts both the shape and the support of the estimated conditional mean. The correct approach is to let binsreg implement the partial-mean estimator internally via `w=`.

**Why does the residualized approach give almost the same slope?**  
The two slopes (0.0050 vs 0.0051) are nearly identical because the true relationship is close to linear in this dataset — the residualized approximation happens to work well here.

---

## Session 2 — Current session (2026-04-22)

### 1. Added formal linearity test (Cattaneo et al. 2024 sup-norm test)

**Motivation:** Several top journals (e.g., Morales et al. on NCA enforceability) report the formal `binstest` p-value alongside the figure.

**Implementation:**  
Added `binsreg.binstest(..., testmodelpoly=1, nsims=2000, simsseed=42, simsgrid=50)` to both binsreg scripts. This tests H₀: E[y|x] (or the partial mean E[y − w'γ̂ | x]) is a global degree-1 polynomial (linear) against a nonparametric alternative, using the sup-norm of the t-statistic.

```python
tst = binsreg.binstest("y", "x", w=w_cols, data=df_bs,
                       testmodelpoly=1, nsims=2000, simsseed=42, simsgrid=50)
p_val = float(tst.testpoly.pval[0])
t_stat = float(tst.testpoly.stat[0])
```

**Results:**
| Figure | Test stat | p-value |
|--------|-----------|---------|
| Corrected (covariate-adjusted) | 1.17 | **0.422** |
| Residualized | 2.44 | **0.468** |

Both are strong non-rejections of linearity.

**Figure annotation:**  
```python
p_str = f"$p = {p_val:.3f}$" if p_val >= 0.001 else "$p < 0.001$"
ax.text(0.98, 0.97, f"Linearity test: {p_str}",
        transform=ax.transAxes, ha="right", va="top",
        fontsize=9, style="italic")
```

**TeX wrapper language (corrected figure):**
> To formally assess linearity, the figure reports in its upper-right corner the $p$-value from the sup-norm specification test of \citet{Cattaneo2024}, which tests the null hypothesis that the partial-mean function $\mu(x) \equiv E[y_i - w_i'\hat{\gamma} \mid x_i = x]$ is a global linear polynomial against a nonparametric alternative. The test fails to reject linearity ($p = 0.422$), consistent with the visual evidence.

### 2. Trimmed x-axis upper limit to 2.5

Changed `ax.set_xlim(-0.15, 3)` → `ax.set_xlim(-0.15, 2.5)` in `linearity_fig3_binsreg_corrected.py`.

### 3. Synced to paper (Overleaf)

- Copied PDF: `Graphs/conn_margins/linearity_fig3_binsreg_corrected.pdf` → `UnionSpill-paper/Figures/Main/`
- Updated `Main_Results.tex` figure notes (lines ~2650–2654):
  - Added sample description (balanced panel 2009–2016, zero prior coverage)
  - Explained internal covariate adjustment and why it matters (cites Cattaneo eq. 3)
  - Added linearity test paragraph with p = 0.422
- Pushed to Overleaf (`git.overleaf.com/68365c9cece9fb72f3cb58c1`), branch `master`

---

## File inventory

| File | Purpose |
|------|---------|
| `Programs/conn_margins/conn_margins_scatter.do` | Exports residualized scatter data |
| `Programs/conn_margins/conn_margins_scatter_controls.do` | Exports raw DiD + controls (for corrected figure) |
| `Programs/conn_margins/linearity_fig3_lowess.py` | LOWESS + bootstrap CI figure |
| `Programs/conn_margins/linearity_fig3_binsreg.py` | Residualized binsreg (50 bins, uniform CB, linearity test) |
| `Programs/conn_margins/linearity_fig3_binsreg_corrected.py` | Corrected covariate-adjusted binsreg + linearity test |
| `Tables/conn_margins/scatter_resid_wages_panel.csv` | Input for residualized figure |
| `Tables/conn_margins/scatter_raw_controls.csv` | Input for corrected figure (4,188 firms) |
| `Graphs/conn_margins/linearity_fig3_binsreg_corrected.pdf` | Main output — canonical linearity defense figure |
| `Graphs/conn_margins/fig_linearity_binsreg.tex` | TeX wrapper (residualized) |
| `Graphs/conn_margins/fig_linearity_binsreg_corrected.tex` | TeX wrapper (corrected, canonical) |

---

## Commits

| Hash | Message |
|------|---------|
| `8420fa5` | Add conn_margins linearity defense: binsreg figures, Cattaneo corrected covariate adjustment, TeX wrappers |
| `3daf599` | Add Cattaneo (2024) linearity test to binsreg figures |
| `703ae1b` | Trim x-axis upper limit to 2.5 on corrected binsreg figure |

---

## How to reproduce

```bash
# Step 1: export raw controls from Stata
module load stata/17
stata-mp -b do Programs/conn_margins/conn_margins_scatter_controls.do

# Step 2: generate corrected figure (takes ~3 min due to binstest nsims=2000)
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/linearity_fig3_binsreg_corrected.py

# Step 3: copy to paper
cp Graphs/conn_margins/linearity_fig3_binsreg_corrected.pdf \
   UnionSpill-paper/Figures/Main/
```
