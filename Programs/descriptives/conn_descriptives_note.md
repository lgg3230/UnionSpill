# Connectivity descriptives — how the continuous regressor relates to observables

Connectivity = `totaltreat_pw_n` (raw per-worker pre-reform 2007–2011 flows to treated
firms). Characteristics are pre-treatment (2009–2011) firm means.

**Samples (separate sets, not overlaid).**
- **Control (spillover) sample = the spillover estimation sample.** Restricted to the
  `e(sample)` of the headline spillover log-wage event study
  (`4012_pct_tfpw.do`): **n = 4,084**, matching the ~4,085 firms the main
  spillover estimates use. (Reproduced by re-running that exact regression in
  `firm_conn_scatter_prep.do` and tagging `e(sample)`; the one upstream control built
  from an external flows merge is omitted, costing ≤1 firm.)
- **Treated firms** = treated balanced-panel Lagos firms, **n = 12,274**.

Within each set a uniform sample is used (listwise-complete on connectivity + the 8
characteristics). The heavy-tailed rate variables (separation, hiring, churn) are
winsorized at p99.

## Characteristics (8) and definitions
`lr_remdezr_w` log wages · `l_firm_emp` log employment · **separation rate** `turnover_u`
(= separations/avg emp) · **hiring rate** `hiring_rate_u` · **churn rate** =
(hires+seps)/avg emp · **retention** `retention_u` · share female (= 1−`male_prop`) ·
share non-white (= 1−`white_prop`). The hiring rate was added because the separation and
churn panels look near-identical (both dominated by separations); hiring is the distinct
inflow margin.

## Distribution of connectivity
- Control: **46.1% at exactly zero**; median 0.0026, mean 0.0123, p90 0.029, heavy tail.
- Treated: only 18.4% at zero; median 0.037, mean 0.138 — far more connected.
- Figures: `hist_connectivity.pdf` (control) and `hist_connectivity_treated.pdf`
  (treated), each with median & mean lines + legend.

## Univariate OLS slopes: y(2011) on connectivity
Each cell reports the slope $\beta$ from regressing the 2011 characteristic on raw
connectivity (`totaltreat_pw_n`), HC1-robust SE in parentheses (one obs per firm).
Y-variables are **2011 values** (not 2009–2011 means). Plots trim the top 1% of
connectivity for display.

**Control (spillover) estimation sample, n = 4,032:**
| Characteristic | β (SE) |
|---|---|
| Log wages | 1.363 (0.539)** |
| Log employment | 14.951 (1.844)*** |
| Separation rate | 2.900 (0.613)*** |
| Hiring rate | 2.914 (0.508)*** |
| Churn rate (hires+seps) | 5.855 (0.939)*** |
| Retention rate | −1.146 (0.184)*** |
| Share female | −2.182 (0.270)*** |
| Share non-white | −0.497 (0.285)* |

**Treated firms, n = 12,128 (for contrast):** log wages 2.161 (0.029), log employment
−2.017 (0.062), separation −0.584 (0.022), hiring −0.488 (0.020), churn −1.079 (0.038),
retention 0.277 (0.008), share female 0.172 (0.012), non-white −0.202 (0.013) — all
highly significant.

## Verdict
On the spillover estimation sample the slopes are **statistically significant for nearly
every characteristic** — but this reflects the large sample (n≈4,000): the underlying
*correlations* are weak (|r| ≤ 0.15), so connectivity explains little of the variation in
observables. Economically, over the connectivity range that actually identifies the
spillover (0 to ≈0.13 at p99) the implied differences are modest for most outcomes
(e.g. log wages: 1.36 × 0.13 ≈ 0.18 log points), with the clear exception of **firm
size**: the log-employment slope (≈15) implies a large gap, but the binscatter shows this
is essentially an *extensive-margin* jump — zero-connectivity firms are much smaller, with
a flat gradient among positive-connectivity firms — not a smooth size gradient. So the
honest read is: connectivity is **detectably but weakly** related to observables, with the
strongest tie to firm size at the zero-vs-positive margin. This characterizes the
continuous regressor on the sample that identifies the spillover and complements the
treated-vs-control balance table. Treated firms, by contrast, show strong, monotone
connectivity gradients (wages ↑, turnover/churn ↓, retention ↑) reflecting their embedding
in the treated network — structure absent in the control sample.

## Files
- prep: `Programs/descriptives/firm_conn_scatter_prep.do` (reproduces the spillover
  e(sample); adds `hiring`; tags `in_spill`/`in_treat`) → `Tables/descriptives/firm_conn_scatter.csv`
- binscatters (recommended): `Programs/descriptives/firm_conn_binscatter.py` →
  `Graphs/descriptives/binscatter_conn_*.pdf` + `_combined.pdf` (control),
  `binscatter_conn_*_treated.pdf` + `_combined_treated.pdf` (treated)
- raw scatters (reference): `Programs/descriptives/firm_conn_scatter.py` → `scatter_conn_*` (+ `_treated`)
- histograms: `Programs/conn_descriptives/5140_figure_conn_hist.py` →
  `hist_connectivity.pdf` (control), `hist_connectivity_treated.pdf` (treated)
- slopes: `Tables/descriptives/firm_conn_slopes.csv` (β, HC1 SE, t, n per characteristic and set)

(The earlier overlaid control-vs-treated `*_full.pdf` figures were removed in favour of
the separate sets.)
