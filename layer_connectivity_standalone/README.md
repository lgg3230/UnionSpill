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

| File | Size | Contents |
|------|------|----------|
| `firm_layer_outcomes_edu2.dta` | 11 MB | Firm × layer (no\_hs / has\_hs) × year wages and employment |
| `firm_layer_outcomes_gender.dta` | 13 MB | Firm × layer (female / male) × year wages and employment |
| `firm_layer_outcomes_race.dta` | 12 MB | Firm × layer (white / nonwhite) × year wages and employment |
| `firm_layer_connectivity_edu2.dta` | 5.9 MB | Firm × layer connectivity to treated firms (education) |
| `firm_layer_connectivity_gender.dta` | 6.4 MB | Firm × layer connectivity to treated firms (gender) |
| `firm_layer_connectivity_race.dta` | 6.2 MB | Firm × layer connectivity to treated firms (race) |
| `firm_layer_outcomes_occ4.dta` | 19 MB | Firm × layer (1\_mgr / 23\_high / 4\_bur / 5p\_low) × year wages and employment |
| `firm_layer_connectivity_occ4.dta` | 9.7 MB | Firm × layer connectivity to treated firms (occupation) |
| `lagos_sample_sep24_pct_unionexp_ext_df2.dta` | 186 MB | Firm panel: treatment status, balanced panel flag, size, union exposure |
| `totalflows_wide_2007_2011.csv` | 1.1 MB | Firm-level total worker flows 2007–2011 (pre-trend controls) |

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

**Python 3.9+** with:
```
pip install pandas
```
