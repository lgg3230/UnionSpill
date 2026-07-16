# Figure Standards

Publication-quality figures for economics papers. All figures must be directly includable in the LaTeX manuscript without manual editing.

---

## Core Rules

- **Never add titles or subtitles inside ggplot** -- use `labs(title = NULL, subtitle = NULL)`
- **Figure information goes in two places:**
  1. **File name** -- descriptive, e.g., `fig1_hispanic_enrollment_ascm.pdf`
  2. **LaTeX `\caption{}`** -- the authoritative title, numbered and editable without re-running R
- **Panel labels are the exception** -- "Panel A: Employment" inside multi-panel figures (via `patchwork`, `cowplot`, etc.) is fine since they identify sub-panels, not the whole figure
- **Axis labels must be publication-quality** -- "Employment Rate" not "emp_rate". Clean labels stay in the figure; titles and context go in the caption
- **Use serif fonts** -- figures should match the paper's body text
- **Output PDF for figures** -- vector graphics for LaTeX. Use `ggsave("fig.pdf")`. PNG only for raster content (maps, photos)

---

## Font and Theme

Set serif fonts to match the paper's body text:

```r
theme_paper <- theme_minimal(base_family = "serif", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position  = "bottom",
    plot.title       = element_blank(),  # No titles -- INV-12
    plot.subtitle    = element_blank()
  )

theme_set(theme_paper)
```

For Python (matplotlib):
```python
import matplotlib.pyplot as plt
plt.rcParams.update({
    "font.family": "serif",
    "font.size": 11,
    "axes.grid": True,
    "grid.alpha": 0.3,
})
```

---

## Axis Labels

- **Show all years on the x-axis** when the panel spans ~20 years or fewer:
  ```r
  scale_x_continuous(breaks = min_year:max_year)
  ```
  Only thin out labels when they overlap (roughly >20 ticks).

- **Human-readable labels:**
  - "Log Wages (2010 USD)" not "ln_wage_deflated"
  - "Share of Female Workers" not "pct_female"
  - Include units where applicable

---

## Color

- **Colorblind-friendly palettes** -- use `scale_color_brewer(palette = "Set2")`, `viridis`, or similar
- **Never rely on red/green contrast alone**
- **Color-independent design** -- figures must be readable in grayscale:
  - Combine color with shape (`shape` aesthetic)
  - Combine color with linetype (`linetype` aesthetic)
  - Series remain distinguishable without color

Recommended palettes:
```r
# Option 1: ColorBrewer
scale_color_brewer(palette = "Set2")

# Option 2: Viridis (perceptually uniform)
scale_color_viridis_d()

# Option 3: Manual (maximum control)
scale_color_manual(values = c("#1b9e77", "#d95f02", "#7570b3"))
```

---

## Figure Width

- **Single-panel:** `width=0.8\textwidth` in LaTeX, `width = 6, height = 4` in ggsave
- **Side-by-side panels:** `width=0.48\textwidth` each in LaTeX
- **Full-width landscape:** use `\begin{landscape}` environment

In R:
```r
ggsave(
  here("paper", "figures", "fig_event_study.pdf"),
  plot = p,
  width = 6,
  height = 4,
  device = cairo_pdf  # Better font embedding
)
```

---

## Common Figure Types

### Event Study Plot
```r
ggplot(es_data, aes(x = relative_time, y = estimate)) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray50") +
  labs(x = "Periods Relative to Treatment", y = "Estimated Effect") +
  theme_paper
```

### Coefficient Plot
```r
library(modelsummary)
modelplot(models, coef_omit = "Intercept") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  theme_paper
```

### RDD Plot
```r
rdplot(y = df$outcome, x = df$running_var, c = cutoff,
       x.label = "Running Variable", y.label = "Outcome")
```

---

## Export

```r
# PDF for LaTeX inclusion (vector graphics)
ggsave(
  here("paper", "figures", "fig_main.pdf"),
  plot = p,
  width = 6, height = 4
)

# PNG only for raster content
ggsave(
  here("paper", "figures", "map_treatment.png"),
  plot = p_map,
  width = 8, height = 6, dpi = 300
)
```

---

## File Naming

```
figures/
  descriptive/
    fig_histogram_outcome.pdf
    fig_time_series_treatment.pdf
  estimation/
    fig_event_study_main.pdf
    fig_coefplot_heterogeneity.pdf
    fig_rdd_main.pdf
  robustness/
    fig_placebo_test.pdf
    fig_sensitivity_bandwidth.pdf
```

Pattern: `fig_{description}.pdf`

---

## LaTeX Inclusion

```latex
\begin{figure}[htbp]
\centering
\includegraphics[width=0.8\textwidth]{figures/estimation/fig_event_study_main.pdf}
\caption{Event study estimates of treatment effect. The figure plots point estimates
and 95\% confidence intervals for each period relative to treatment. The dashed
vertical line marks treatment onset. Pre-treatment coefficients are not statistically
different from zero, consistent with parallel trends. Source: [data source].}
\label{fig:event_study}
\end{figure}
```

Key elements of figure captions (INV-2):
- What is shown
- How to read it
- Data source

---

## Prohibited Patterns

| Pattern | Reason |
|---------|--------|
| `ggtitle()` or `labs(title = "...")` | Titles go in LaTeX `\caption{}` (INV-12) |
| `plt.title()` in matplotlib | Same reason |
| Default ggplot theme (gray background) | Use `theme_minimal` or custom theme |
| Red/green only color schemes | Not colorblind-friendly |
| JPG format | Lossy compression; use PDF for vector, PNG for raster |
| Axis labels with underscores | Human-readable labels required |
| Legend inside plot area (overlapping data) | Use `legend.position = "bottom"` |
