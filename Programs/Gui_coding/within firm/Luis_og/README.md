# Layer Connectivity — Replication Package

Replication code for the layer connectivity exercises in Azevedo-Gomes & Neri, "Union Spillovers" (2025). All datasets required to run the regressions are bundled in `data/`. Results are written to `output/`.

---

## Setup

No editing required — the wrapper detects its own location automatically. Run from within Stata:

```stata
do "scripts/run_all.do"
```

Or from the terminal (from any directory):

```bash
stata-mp -b do /path/to/layer_connectivity_standalone/scripts/run_all.do
```

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

## Requirements

**Stata 17** with:
```stata
ssc install reghdfe
ssc install ftools
ssc install coefplot
```

**Python 3.9+** with `pandas` (only needed for the LaTeX table generators, `0?b_make_table_*.py`):
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
