# Layer Connectivity — Replication Package

Replication code for the layer connectivity exercises in Azevedo-Gomes & Neri, "Union Spillovers" (2025). All datasets required to run the regressions are bundled in `data/`. Results are written to `output/`.

---

## Setup

No editing required — every wrapper detects its own location automatically.

**Recommended: run the whole package from the shell.**

```bash
bash run_all.sh
```

This runs exercises 1–4 in one Stata process, exercise 5's two passes in their own
Stata processes, then builds every LaTeX table.

**Pure-Stata path.** Exercises 1–4 run together; exercise 5 must be launched separately:

```bash
stata-mp -b do scripts/run_all.do              # exercises 1-4
stata-mp -b do scripts/05_run_within_firm.do   # exercise 5, monthly wages
stata-mp -b do scripts/05_run_within_firm_hw.do # exercise 5, hourly wages
```

> **Exercise 5 must be its own Stata process — this is a correctness requirement, not
> a style preference.** When the within-firm estimates run after another estimation
> exercise in the same Stata session, `reghdfe` carries solver state that moves the
> `ten2` group-level coefficients in the 6th significant digit (e.g. the within-firm
> hourly tenure coefficient shifts from `-0.0032969` to `-0.0033053`). `clear all`
> between exercises is *not* sufficient. Rounded to the four decimals the tables print
> the difference is invisible, but the CSVs will not match the published estimates
> exactly. `run_all.sh` handles this for you.

---

## Data (`data/`)

Each layer ships two `.dta` files:

- **`firm_layer_outcomes_<layer>.dta`** — firm × layer × year **panel** (2009–2016). Wages, employment, and five controls aggregated within each (firm, layer, year) cell. These are the dependent variables.
- **`firm_layer_connectivity_<layer>.dta`** — firm × layer **cross-section**, computed from pre-treatment (2007–2011) worker-flow transitions. Each measure captures the share of the firm's layer-specific flows that go to / come from treated firms. These are the right-hand-side treatment-exposure variables, interacted with `Post` in the regressions.

| File | Contents |
|------|----------|
| `firm_layer_outcomes_edu2.dta` | Firm × layer (no\_hs / has\_hs) × year — wages, employment, controls |
| `firm_layer_outcomes_gender.dta` | Firm × layer (female / male) × year — wages, employment, controls |
| `firm_layer_outcomes_race.dta` | Firm × layer (white / nonwhite) × year — wages, employment, controls |
| `firm_layer_outcomes_occ4.dta` | Firm × layer (1\_mgr / 23\_high / 4\_bur / 5p\_low) × year — wages, employment, controls |
| `firm_layer_outcomes_occ5_sara.dta` | Firm × layer (1\_mgr / 2\_pro / 3\_bur / 4\_tech / 5\_low) × year — Sara Moreira's 5-layer occupation partition |
| `firm_layer_outcomes_ten2.dta` | Firm × layer (lt12mo / ge12mo) × year — binary tenure split at 12 months |
| `firm_layer_connectivity_edu2.dta` | Firm × layer connectivity to treated firms (education) |
| `firm_layer_connectivity_gender.dta` | Firm × layer connectivity to treated firms (gender) |
| `firm_layer_connectivity_race.dta` | Firm × layer connectivity to treated firms (race) |
| `firm_layer_connectivity_occ4.dta` | Firm × layer connectivity to treated firms (occupation, 4-bin) |
| `firm_layer_connectivity_occ5_sara.dta` | Firm × layer connectivity to treated firms (Sara's 5-bin occupation) |
| `firm_layer_connectivity_ten2.dta` | Firm × layer connectivity to treated firms (binary tenure) |
| `lagos_sample_sep24_pct_unionexp_ext_df2.dta` | Firm panel: treatment status, balanced panel flag, size, union exposure |
| `currentconn_overlay_totaltreat.dta` | Current-connectivity overlay: recomputed `totaltreat_pw_n` per firm × year, plus the frozen legacy value it replaces |
| `totalflows_wide_2007_2011.csv` | Firm-level total worker flows 2007–2011 (pre-trend controls) |

### Layer-level controls (in every `firm_layer_outcomes_*.dta`)

Aggregated within each (firm, layer, year) cell. Available as right-hand-side controls
in any layer-level spec; the variable mechanically degenerate within a given layer is
omitted (e.g. `share_higher_ed` is not produced for the `edu2` outcomes).

| Variable | Definition |
|----------|------------|
| `mean_horas` | Mean contracted weekly hours (`horascontr`) |
| `mean_age` | Mean worker age |
| `share_female` | Share female (`genero == 0`) |
| `share_higher_ed` | Share with higher education (`educ_bin == "2_higher"`) |
| `share_fixed_term` | Share on fixed-term contracts (`d_fixed_term == 1`) |

### Layer definitions

| Layer | Bins | Source |
|---|---|---|
| `edu2` | `no_hs` / `has_hs` | `educ_bin` collapsed to high-school-or-more vs. none |
| `gender` | `female` / `male` | `genero` |
| `race` | `nonwhite` (parda/preta) / `white` (branca) | `race_group` |
| `occ4` | `1_mgr` / `23_high` / `4_bur` / `5p_low` | CBO2002 first digit (1, 2-3, 4, 5+) |
| `occ5_sara` | `1_mgr` / `2_pro` / `3_bur` / `4_tech` / `5_low` | Sara Moreira's CBO2002 partition: managers (d2 ∈ 11-14), professionals (d1=2), bureaucrats (d1 ∈ 4-9 ∧ 3rd digit=0), technicians (d1=3), low-skill (d1 ∈ 4-9 residual). Differs from `occ4` by splitting professionals from technicians and isolating the bureaucratic mid-level. |
| `ten2` | `lt12mo` (<1yr) / `ge12mo` (≥1yr) | `tempempr`; cutoff at 12 months chosen after a pooled+within-firm diagnostic showing ~23% of workers below the cutoff and substantial within-firm variation in the short-tenure share (p10=6%, p90=48%) |

---

## Two corrections in this build

Both matter for exercise 5; neither changes exercises 1–4.

**1. Current connectivity.** The Lagos firm panel ships a *frozen* `totaltreat_pw_n`.
Exercise 5 replaces it with the current recomputable measure from
`currentconn_overlay_totaltreat.dta`. Note the trap: the panel's `totaltreat_pw_norm`
is normalized by the **legacy** p90, so swapping the level variable alone silently
leaves the regressor on the old scale. `05a_within_firm_estimates.do` rebuilds
`totaltreat_pw_norm` from the current measure (p90 = 0.02926) rather than reading it.

**2. Corrected log hourly wages.** `firm_layer_outcomes_*.dta` now carries

```
lr_remdezr_h_layer = ln((remdezr / (horascontr * 4.348)) / IPCA_year)
```

The May 2026 build of this package computed it with DuckDB's `LOG()`, which is **base
10, not natural log**. Every hourly group-level magnitude was therefore a factor of
ln(10) ≈ 2.303 too small. Because the bug scaled coefficients and standard errors
identically, all t-statistics and stars in the old output were already correct — only
the magnitudes were wrong. The monthly wage and employment columns are unaffected.

## Exercises

### Exercise 1 — Layer-level spillover (`01a_layer_spillover.do`)

For each layer definition (education, gender, race), tests whether firms with higher connectivity to treated firms through that layer experience larger post-reform wage and employment effects.

**Three specifications per layer:**
1. Within-firm FE (`firm × year`) — main spec
2. Cross-firm FE (`microregion × year`, `industry × year`, `mode × year`)
3. Firm-level restricted sample

**Sample:** untreated firms in the balanced panel, above median pre-treatment employment.

**Outputs** → `output/`:
- `results_spill_layer_{edu2,gender,race}_abvmed_firm_layer_spill.csv`
- `results_spill_layer_cross_{edu2,gender,race}_abvmed_firm_layer_spill.csv`
- `results_spill_firmrestr_{edu2,gender,race}_abvmed_firm_layer_spill.csv`
- `es_*.pdf` — event study graphs

```bash
stata-mp -b do scripts/01a_layer_spillover.do
python scripts/01b_make_table_spillover.py
# → output/table_layer_specs_abvmed_firm_{edu,demog}.tex
```

---

### Exercise 2 — Horse race (`02a_horse_race_edu2.do`)

Includes both education-layer connectivity variables (`c_no_hs` and `c_has_hs`) simultaneously in the same regression. Each coefficient is thus conditional on the other, identifying which education channel survives when both compete.

**Education layer (edu2) only.** The regression at the layer level is:

```
outcome ~ c_no_hs × Post + c_has_hs × Post + FE
```

Outcomes: log wages and log employment, at both the layer level and firm level.

**Outputs** → `output/`:
- `results_horse_race_edu2.csv`

```bash
stata-mp -b do scripts/02a_horse_race_edu2.do
python scripts/02b_make_table_horse_race.py
# → output/table_horse_race_edu2.tex
```

---

### Exercise 3 — Occupation layer spillover (`03a_layer_spillover_occ4.do`)

Same as Exercise 1 but for the occ4 (occupation) layer partition: Managers / High-skill / Bureaucrat lower / Low-skill, following CBO 2002 first digit.

**Sample:** untreated firms in the balanced panel, above median pre-treatment employment.

**Outputs** → `output/`:
- `results_spill_layer_occ4_abvmed_firm_layer_spill.csv`
- `results_spill_layer_cross_occ4_abvmed_firm_layer_spill.csv`
- `results_spill_firmrestr_occ4_abvmed_firm_layer_spill.csv`
- `es_*.pdf` — event study graphs

```bash
stata-mp -b do scripts/03a_layer_spillover_occ4.do
python scripts/03b_make_table_spillover_occ4.py
# → output/table_layer_specs_abvmed_firm_occ4.tex
```

---

### Exercise 4 — Occupation horse race (`04a_horse_race_occ4.do`)

Includes all four occupation-layer connectivity variables (`c_1_mgr`, `c_23_high`, `c_4_bur`, `c_5p_low`) simultaneously. Each coefficient is conditional on the others, identifying which occupation channel survives when all compete.

**Sample:** untreated firms in the balanced panel (no size cut).

**Outputs** → `output/`:
- `results_horse_race_occ4.csv`

```bash
stata-mp -b do scripts/04a_horse_race_occ4.do
python scripts/04b_make_table_horse_race_occ4.py
# → output/table_horse_race_occ4.tex
```

---

### Exercise 5 — Within-firm group-level exhibits (`05_run_within_firm{,_hw}.do`)

Reproduces **Tables 10, 11, 12, 22, 23 and 24** of *Replication: Wages vs Hourly Wages*.

Workers are partitioned three ways — education (no HS / HS+), gender (female / male),
and tenure (<12mo / ≥12mo) — and group-specific connectivity is compared against the
firm-level measure. Both wage definitions are estimated: log monthly wages (Tables 10–12)
and corrected log hourly wages (Tables 22–24).

**Three estimation blocks per partition:**

1. **A6 — descriptives.** Group employment, wage, per-worker flows and connectivity over
   2009–2011, plus a within/between-firm variance decomposition of group connectivity.
2. **A7 — group-level spillovers.** Three columns per outcome: the firm-level benchmark,
   a *within firms* spec (firm × year FE, so identification is across groups inside the
   same firm-year), and an *overall* spec (microregion × year, industry × year,
   negotiation-month × year FE). Each with a pre-treatment placebo.
3. **A8 — horse race.** Both group-specific connectivity measures entered jointly on
   firm-level outcomes, with an equality test. Estimated under three scalings
   (`own` group p90, common `firm` p90, per-SD); the tables print the `firm` scaling.

**Sample:** untreated establishments in the balanced panel. Connectivity is scaled so
that 1 equals the 90th percentile of the firm-level distribution.

**Outputs** → `output/`:

| File | Feeds |
|------|-------|
| `a6_group{,_hw}.csv`, `a6_partition{,_hw}.csv` | Tables 10, 22 |
| `a7{,_hw}.csv` | Tables 11, 23 |
| `a8{,_hw}.csv` | Tables 12, 24 |
| `t_layerdesc{,_hw}.tex` | Table 10, Table 22 |
| `t_groupspecs{,_hw}.tex` | Table 11, Table 23 |
| `t_horserace{,_hw}.tex` | Table 12, Table 24 |

Each `.tex` is a complete `table` float, ready to `\input`. Tables 12 and 24 use
`siunitx` `S` columns and `\makecell`, so the host document needs `siunitx`,
`makecell` and `booktabs`.

```bash
stata-mp -b do scripts/05_run_within_firm.do      # -> a6/a7/a8 .csv
stata-mp -b do scripts/05_run_within_firm_hw.do   # -> a6/a7/a8 _hw.csv
python scripts/05b_make_tables_within_firm.py     # -> the six .tex files
```

**Previewing the tables.** To eyeball the six tables without pasting them into the paper:

```bash
module load texlive/2026        # or ensure pdflatex is on PATH
python scripts/05c_preview_tables.py
```

This writes `output/preview/` — one cropped PDF per table, numbered as in the replication
document, plus `tables_within_firm_all.pdf` with all six. Optional; `run_all.sh` does not
call it. Needs `pdflatex`, and PyMuPDF for the cropping (without PyMuPDF the PDFs are
still produced, just uncropped).

`05a_within_firm_estimates.do` is the shared engine; the two `05_run_*` files just set
`wf_wage_firm` / `wf_wage_layer` / `wf_suffix` and call it. It is a port of
`Programs/layer_connectivity/07_within_firm/01_within_firm_estimates{,_hw}.do`, itself a
Stata port of the original R package, and reproduces those estimates to ~1e-12.

**Known discrepancy against the PDF.** Of the 564 numbers printed across the six tables,
562 reproduce exactly. The two exceptions are the same cell in Tables 12 and 24 — Panel B,
Male Connectivity, pre-trend log employment standard error — where the PDF prints
`0.0058` but the underlying estimate is `0.00574397`, i.e. `0.0057`. The value in the PDF
does not match its own source CSV; this package prints the value the regression produces.

---

## Requirements

**Stata 17** with:
```stata
ssc install reghdfe
ssc install ftools
ssc install coefplot
```

**Python 3.9+** for the LaTeX table generators. `01b`–`04b` need `pandas`; `05b_make_tables_within_firm.py` uses only the standard library:
```
pip install pandas
```

The end-to-end wrapper `run_all.sh` defaults to `stata-mp` and `python3` on the user's `PATH`. Both can be overridden:

```bash
STATA=/path/to/stata17/stata-mp \
PYTHON=/path/to/python3 \
bash run_all.sh
```

If `python3` resolves to an older interpreter (e.g. 3.6), pass an explicit Python 3.9+ path via `PYTHON=...` rather than installing globally.
