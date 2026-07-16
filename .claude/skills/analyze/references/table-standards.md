# Table Standards

Publication-quality tables using standard economics formatting (booktabs rules, no vertical rules). Two approaches are supported:

- **tabularray (`tblr` / `talltblr`)** -- modern key-value interface. Preferred for hand-written tables in `main.tex`.
- **`tabular` + `booktabs` + `threeparttable`** -- traditional stack. Required for R/Python/Julia-generated output (scripts export bare `tabular`).

Journal-specific conventions (significance stars, note format) adapt to the target journal -- see journal-profiles.md.

---

## No In-Table Titles or Notes

- **Never** embed titles inside the table body or as a table header row
- **Never** embed notes, sources, or footnotes inside the table itself
- Table numbering, titles, and notes are added in LaTeX via `\caption{}` and `\begin{tablenotes}` (or tabularray's `note{}` key)
- The file name and folder identify what the table contains

---

## Three-Line Format (Booktabs)

Every table uses exactly three horizontal rules and **zero vertical lines**:

**Traditional (R/Python/Julia output):**
```latex
\begin{table}[htbp]
\centering
\begin{threeparttable}
\caption{Effect of X on Y}\label{tab:main}
\begin{tabular}{lcccc}
\toprule
            & (1)     & (2)     & (3)     & (4)     \\
\midrule
...coefficients...
\bottomrule
\end{tabular}
\begin{tablenotes}\small
\item \textit{Notes:} Standard errors in parentheses.
\end{tablenotes}
\end{threeparttable}
\end{table}
```

**Modern (hand-written in main.tex):**
```latex
\begin{talltblr}[
  caption = {Effect of X on Y},
  label = {tab:main},
  note{*} = {Standard errors in parentheses.},
]{colspec = {lcccc}, rowsep = 4pt}
\toprule
            & (1)     & (2)     & (3)     & (4)     \\
\midrule
...coefficients...
\bottomrule
\end{talltblr}
```

- `\toprule` above column headers
- `\midrule` below column headers (and to separate panels)
- `\bottomrule` at the very end
- `\cmidrule(lr){2-4}` for partial rules spanning column groups
- **R/Python/Julia output:** wrap with `threeparttable` for notes via `\begin{tablenotes}`
- **Hand-written tables:** prefer `talltblr` with `note{}` keys -- unifies caption, label, and notes
- **Never** use `\hline`, `|`, or any vertical rules

---

## Coefficient Display

- Point estimates on one row, standard errors in parentheses on the row below
- Standard errors labeled in the table note (e.g., "Robust standard errors in parentheses" or "Clustered at municipality level")

**Significance reporting depends on the target journal:**

| Context | Convention |
|---------|-----------|
| **Working papers (default)** | Stars: `*` p < 0.10, `**` p < 0.05, `***` p < 0.01. Note at bottom: `\textit{Notes:} * p < 0.10, ** p < 0.05, *** p < 0.01` |
| **AEA journals** (AER, AEJ:Applied, AEJ:Policy, AER:Insights) | No significance stars. Report standard errors in parentheses. Use exact p-values or confidence intervals for key results. |
| **All other journals** | Stars acceptable. Follow journal-specific conventions in journal-profiles.md. |

Working paper default example:
```
Treatment        & 0.045**  & 0.038*   & 0.052*** \\
                 & (0.021)  & (0.020)  & (0.019)  \\
```

AEA journal example:
```
Treatment        & 0.045    & 0.038    & 0.052    \\
                 & (0.021)  & (0.020)  & (0.019)  \\
```

---

## Column and Row Structure

- **Column (1), (2), ...** headers in the first row after `\toprule`
- **Dependent variable** stated in a spanning header or the first subheader row
- **Variable names** left-aligned, human-readable (not raw R variable names)
  - `Log wages` not `ln_wage_deflated`
  - `Female` not `sex_2`
  - `Years of education` not `educ_yrs`
- **Numeric columns** right-aligned or decimal-aligned
- **N**, **R-squared**, **Fixed effects** (Yes/No), **Controls** (Yes/No) at the bottom before `\bottomrule`

---

## Panel Structure

For tables with multiple panels:

```latex
\multicolumn{5}{l}{\textit{Panel A: Full sample}} \\
\midrule
...
\\[0.5em]
\multicolumn{5}{l}{\textit{Panel B: Male workers}} \\
\midrule
...
```

- Panel labels in italics, left-aligned, spanning all columns
- `\midrule` after each panel label
- Small vertical space (`\\[0.5em]`) between panels

---

## Preferred R Packages

**Primary: `modelsummary`**

```r
library(modelsummary)

modelsummary(
  models,
  output   = "latex_tabular",  # bare tabular, no wrapper
  stars    = c("*" = 0.10, "**" = 0.05, "***" = 0.01),  # set FALSE for AEA journals
  coef_rename = c(
    "treatment"  = "Treatment",
    "log_income" = "Log income"
  ),
  gof_map = c("nobs", "r.squared", "adj.r.squared"),
  escape  = FALSE
)
```

**Alternative: `fixest::etable`**

```r
fixest::etable(
  models,
  tex      = TRUE,
  style.tex = style.tex(
    main     = "aer",
    depvar.title = "",
    fixef.title  = "",
    yesNo    = c("Yes", "No")
  ),
  se.below = TRUE,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10)  # omit for AEA journals
)
```

**For summary / descriptive tables: `kableExtra`**

```r
library(kableExtra)

kbl(df, format = "latex", booktabs = TRUE, escape = FALSE,
    align = c("l", rep("c", ncol(df) - 1))) |>
  kable_styling(latex_options = "hold_position")
```

---

## Typography

- Serif font throughout (inherits from document class -- no extra commands needed)
- `\small` or `\footnotesize` for tables that need to fit within column width
- Variable names in plain text, panel labels in `\textit{}`
- Never bold table body content; bold only for rare emphasis in headers

---

## Export

```r
# Write .tex fragment (no \begin{table} wrapper -- added in main.tex)
writeLines(tex_output, here("paper", "tables", "reg_main_specification.tex"))
```

- Output **bare `tabular` environment** (no `\begin{table}` float)
- The paper's `main.tex` wraps it with `\begin{table}`, `\caption{}`, and `\input{}`
- Write to `Tables/`

---

## File Naming

```
tables/
  descriptive/
    sumstats_main_sample.tex
    balance_treatment_control.tex
  estimation/
    reg_main_specification.tex
    reg_heterogeneity_gender.tex
    did_event_study_coefficients.tex
  robustness/
    reg_alternative_controls.tex
```

Pattern: `{table_type}_{content_description}.tex`

- `sumstats_` for summary statistics
- `balance_` for balance / pre-treatment tests
- `reg_` for regression output
- `did_` for difference-in-differences specific tables
- `first_stage_` for IV first stage

---

## Table Type Templates

Use these as defaults. Adapt columns based on the paper's needs.

**Descriptive Statistics:**
```
\toprule
                        &  Mean   &  SD     \\
\midrule
\multicolumn{3}{l}{\textit{Continuous variables}} \\
\quad Wages (USD)       &  45,230 &  12,400 \\
\quad Years of education&  13.2   &  2.8    \\
\quad Age               &  38.5   &  11.2   \\
\\[0.5em]
\multicolumn{3}{l}{\textit{Categorical variables (\%)}} \\
\quad Female            &  48.2   &         \\
\quad College degree    &  32.5   &         \\
\bottomrule
```
- Default: Mean and SD in separate columns (never stacked with parentheses)
- Categorical/binary: percentage in Mean column, SD blank
- Sample size stated once in table notes, not as a column
- Add Min/Max only when the range is substantively important

**Regression Results:**
```
\toprule
                        &  (1)    &  (2)    &  (3)    &  (4)    \\
                        &  OLS    &  OLS    &  IV     &  IV     \\
\midrule
Treatment               &  0.045**&  0.038* &  0.052**&  0.041* \\
                        & (0.021) & (0.020) & (0.025) & (0.022) \\
\midrule
Controls                &  No     &  Yes    &  No     &  Yes    \\
Fixed Effects           &  No     &  Yes    &  No     &  Yes    \\
Observations            &  10,000 &  10,000 &  10,000 &  10,000 \\
R$^2$                   &  0.05   &  0.12   &         &         \\
\bottomrule
```

**Multi-Outcome (Panel Structure):**
```
\toprule
                        &  (1)    &  (2)    &  (3)    &  (4)    \\
\midrule
\multicolumn{5}{l}{\textit{Panel A: Wages}} \\
\midrule
Treatment               &  0.045**&  0.038* &  0.052**&  0.041* \\
                        & (0.021) & (0.020) & (0.025) & (0.022) \\
\\[0.5em]
\multicolumn{5}{l}{\textit{Panel B: Employment}} \\
\midrule
Treatment               &  0.021  &  0.033* &  0.015  &  0.028  \\
                        & (0.018) & (0.017) & (0.020) & (0.019) \\
\midrule
Controls                &  No     &  Yes    &  No     &  Yes    \\
Fixed Effects           &  No     &  Yes    &  No     &  Yes    \\
Observations            &  10,000 &  10,000 &  10,000 &  10,000 \\
\bottomrule
```

**Balance Table:**
```
\toprule
Variable                &  Treatment &  Control &  Difference &  SE     &  p-value \\
\midrule
Wages (USD)             &  45,800    &  44,650  &  1,150      &  (890)  &  0.197   \\
Years of education      &  13.4      &  13.1    &  0.3        &  (0.2)  &  0.134   \\
Female (\%)             &  47.8      &  48.6    &  -0.8       &  (1.2)  &  0.505   \\
\bottomrule
```

**Robustness:**
```
\toprule
                        &  (1)        &  (2)           &  (3)          &  (4)            \\
                        &  Baseline   &  Alt. controls &  Alt. sample  &  Alt. estimator \\
\midrule
```
- Column headers describe what changes across specifications
- Same outcome variable across all columns

---

## Prohibited Patterns

| Pattern | Reason |
|---------|--------|
| Title row inside the table | Titles go in `\caption{}`, not the table body |
| Notes embedded in table body | Notes go below via `\begin{tablenotes}` |
| `\hline` | Use `\toprule` / `\midrule` / `\bottomrule` (booktabs) |
| Vertical rules (`\|` in column spec) | Never used in economics journals |
| `stargazer` package | Deprecated workflow; use `modelsummary` or `fixest::etable` |
| Raw variable names in labels | Human-readable labels required |
| `xtable` without booktabs | Produces non-journal-quality output |
| `\begin{table}` in R output | R exports bare `tabular`; float wrapper lives in `main.tex` |
