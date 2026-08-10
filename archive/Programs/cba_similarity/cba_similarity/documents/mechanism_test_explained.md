# Mechanism test: research question → regression

## The research question

If the spillover from treated to untreated firms operates through **CBA content
diffusing along worker flows** — workers carrying knowledge of clauses between
firms — then the same mechanism should run in the **other direction** too:
when treated firms renegotiate their CBAs post-Súmula-277, they should learn
most from connected partners about clauses *they were missing*.

So: **do treated firms add the most clauses in exactly the dimensions where
their connected (untreated) partners already had more?**

## How the question becomes a regression

The translation is a 3-step build.

### Step 1 — Build a "gap" for each (treated firm × clause type) pair (`mechanism_gap_prep.py`)

Pre-treatment only (`cba_period ∈ {1, 2}`):

For a treated firm $i$ and clause type $c$:

$$\text{gap}_{ic} = \max\!\Big(0,\; \underbrace{\sum_j w_{ij}\, c^{\text{pre}}_{jc}}_{\text{conn-weighted avg of partners}} - \underbrace{c^{\text{pre}}_{ic}}_{\text{own pre count}}\Big)$$

Where partners $j$ are *untreated* firms with positive worker flow to $i$ in
2007–2011, and $w_{ij}$ is the average year-pair flow ratio (`ratio_0708`,
`ratio_0809`, `ratio_0910`, `ratio_1011`). The `max(0, ·)` keeps only clause
types where **partners had more than you**.

The mirror quantity:

$$\text{surplus}_{ic} = \max\!\Big(0,\; c^{\text{pre}}_{ic} - \sum_j w_{ij}\, c^{\text{pre}}_{jc}\Big)$$

— clause types where **you had more than partners**.

Both are **time-invariant** (a single number per firm × clause type, computed
once from pre-treatment data).

### Step 2 — Reshape the treated panel long over clause types (`mechanism_test.do`)

Treated balanced-panel firms, years 2009+. The dataset goes from one row per
(firm × year) with 139 `cl_*` columns to one row per (firm × year × clause
type) with one `cl_count` outcome. The long panel has dimensions: ~17k treated
firms × ~8 years × 139 clause types.

Merge in `gap_ic` and `surplus_ic` (both time-invariant).

### Step 3 — The regression

$$c^{\text{count}}_{ict} = \beta\,(\text{gap}_{ic} \times \text{post}_t) + \alpha_{ic} + \alpha_t + \varepsilon_{ict}$$

- `post_t = 1{cba_period ≥ 3}` (post-Súmula-277 CBA renegotiation)
- $\alpha_{ic}$: firm × clause-type FE — absorbs the **level** of `gap_ic`
  (time-invariant) and the firm's baseline count for that clause type
- $\alpha_t$: year FE — common time trends in clause counts
- SE clustered at firm (`identificad`)

The FE structure leaves only the **interaction** `gap × post` identified.
Identification comes from comparing, **within a single (firm $i$, clause-type
$c$) cell**, how its post-period count changed *relative to the same firm's
other clause types*. A firm-clause cell where the firm was "behind its
partners" pre-reform is being compared against the same firm's other cells
where it wasn't behind.

**Interpretation of $\hat\beta > 0$:** treated firms' clause counts grew more
in the post period **specifically for the clause types where their connected
untreated partners had more pre-treatment** — relative to clause types where
they weren't behind. That's the diffusion footprint.

### Step 4 — Falsification (same do-file, second regression)

Re-run the exact same regression with `surplus_ic × post` instead. The
diffusion story predicts $\beta_{\text{surplus}} \approx 0$: partners can't
teach you about clauses *they* have fewer of. If this regression **also**
returns a positive coefficient, the gap result isn't really about diffusion —
it's about treated firms uniformly growing on under-represented clause types
regardless of what partners had.

## Why this is the natural mirror to the similarity exercises

| | `cba_similarity` | `mechanism_test` |
|---|---|---|
| Whose CBA is the outcome? | Untreated firm's | Treated firm's |
| Reference | Connected treated firms | Connected untreated firms |
| Aggregation level | Firm × period (one similarity scalar) | Firm × clause-type × year (long panel) |
| Connectivity weight | `bilateral_conn_pw` / `totaltreat_pw_norm` | `mean(ratio_0708..1011)` |
| Diffusion prediction | More-connected untreated firms ⇒ smaller post-shift in CBA content (closer to treated content) | Treated firms expand most in clause types where their partners had more |

Both are testing the **same content-diffusion mechanism**, from opposite sides.

## Outputs

- `Tables/cba_similarity/mechanism_test_results_all.csv` — master: 30 rows covering all 24 specs (4 RHS × 3 FE × 2 samples)
- `Tables/cba_similarity/mechanism_test_gap.csv` — legacy: `gap × post`, year FE, main sample
- `Tables/cba_similarity/mechanism_test_gap_clausexyear.csv` — legacy: `gap × post`, clause × year FE
- `Tables/cba_similarity/mechanism_test_surplus.csv` — legacy: `surplus × post`, year FE
- `Tables/cba_similarity/mechanism_test_surplus_clausexyear.csv` — legacy: `surplus × post`, clause × year FE
- `Data/CBA_RAIS_firm_level/mechanism_gaps.dta` — long: identificad × clause_num with `gap` and `surplus`
- `Data/CBA_RAIS_firm_level/mechanism_clause_map.csv` — clause_num → clause_name lookup

## Additional specifications

Beyond the original `gap × post` (main) and `surplus × post` (falsification), the master CSV includes:

### Raw signed gap

$$\text{raw\_gap}_{ic} = \text{gap}_{ic} - \text{surplus}_{ic} = \overline{\text{partner}}_c - \text{own}_{ic}^{\text{pre}}$$

A single linear slope `cl_count = β × (raw_gap × post)`. Forces β_gap = −β_surplus. Useful as a single-coefficient summary; deviates from the asymmetric ReLU split when the data show different slopes on the two sides.

### Joint regression

`cl_count = β_g (gap × post) + β_s (surplus × post) + α_ic + α_t + ε`

Because gap and surplus are mutually exclusive at the cell level (only one is positive in any firm-clause cell), β_g and β_s in the joint match the alone-spec coefficients. The joint adds the symmetry test `β_g = −β_s`. If that test rejects, the response is asymmetric across regimes.

### Mode-union × year FE

Replaces `year` FE with `i.mode_union × i.year`. Absorbs union-specific secular trends in clause counts, so β is identified from cross-firm variation in gap *within the same union × year cell*. Tighter control given that CBAs are negotiated by unions.

### Placebo

Restricts to pre-period only (`cba_period ∈ {1, 2}`) and replaces `post` with `placebo_post = 1{cba_period == 2}`. β ≈ 0 expected if the gap × post effect is genuinely driven by Súmula 277 rather than by pre-existing clause-count divergence between gap and non-gap cells.
