# Ordered Decomposition of CBA Similarity Changes — Implementation Plan

## Goal

Decompose the headline similarity result into two interpretable counterfactuals,
using the four similarity measures already in the paper (cosine, total variation,
Bray–Curtis, Ruzicka). No new measure is introduced.

The headline regression estimates the effect of connectivity-to-treated on
$S(u_{it}, T_{it})$, where both the focal vector $u_{it}$ and the treated
reference $T_{it}$ move with $t$. The decomposition asks who is moving, by
freezing one side at its last pre-reform value (CBA period 2):

- **UntreatedMove**: $S(u_{it}, T_{i2}) - S(u_{i2}, T_{i2})$. Treated reference
  frozen at period 2; does the focal move toward it?
- **TreatedMove**: $S(u_{i2}, T_{it}) - S(u_{i2}, T_{i2})$. Focal frozen at
  period 2; does the treated reference move toward it?

These are the two main objects. Together with two "additional" residual terms
they exactly decompose $\Delta S_{it} = S(u_{it}, T_{it}) - S(u_{i2}, T_{i2})$.

## Notation

For untreated focal firm $i$, CBA period $t \in \{1,\ldots,6\}$, and any
similarity measure $S$:

- $u_{it}$: focal clause vector at $t$; $u_{i2}$: focal at period 2.
- $T_{it}$: treated reference at $t$; $T_{i2}$: same reference at period 2.
- $T$ is either the connectivity-weighted partner reference (firm-specific) or
  the simple-average treated reference (period-specific only).

## Three Similarity Scores per Observation

Per $(i,t)$ and per measure, compute:

| Score | Definition | Reused from |
|-------|-----------|-------------|
| $S^{\text{curr}}_{it}$ | $S(u_{it}, T_{it})$ | headline (existing) |
| $S^{u}_{it}$ | $S(u_{it}, T_{i2})$ | analog of `pretreat_ref` |
| $S^{T}_{it}$ | $S(u_{i2}, T_{it})$ | **new** |

The fourth quantity $S(u_{i2}, T_{i2})$ is constant in $t$ within $i$ and is
absorbed by firm FE in every regression; it is not stored.

## Five Outcomes per Measure × Reference Type

All five are linear combinations of the three scores above:

| Outcome | Construction | Role |
|---------|--------------|------|
| $\Delta S_{it}$ | $S^{\text{curr}}_{it}$ (firm FE absorbs the baseline) | headline, existing |
| UntreatedMove$_{it}$ | $S^{u}_{it}$ | **main, body** |
| TreatedMove$_{it}$ | $S^{T}_{it}$ | **main, body** |
| TreatedAdditional$_{it}$ | $S^{\text{curr}}_{it} - S^{u}_{it}$ | appendix |
| UntreatedAdditional$_{it}$ | $S^{\text{curr}}_{it} - S^{T}_{it}$ | appendix |

## Coefficient Identity

Because OLS is linear and all five regressions share the same panel, the same
firm + FE structure, and the same controls,

$$
\hat\beta_{\Delta S}
= \hat\beta_{\text{UntreatedMove}} + \hat\beta_{\text{TreatedAdditional}}
= \hat\beta_{\text{TreatedMove}}    + \hat\beta_{\text{UntreatedAdditional}}
$$

holds at machine precision. The prep pipeline must produce one panel per
reference type used by all five regressions; never run them on different
subsamples.

## Reference Types

### Connectivity-weighted partner reference

$T_{it}$ is the flow-weighted average of clause vectors of $i$'s treated
partners with a CBA in period $t$. Existing infrastructure in
`cba_similarity_prep.py` builds this; we need to evaluate the same construction
at $t = 2$ to obtain $T_{i2}$.

Sample restriction: focal must have $u_{i2}$ and at least one treated partner
with a CBA in period 2 (for $T_{i2}$ to exist).

### Average treated reference

$T_t$ is the simple mean over treated firms with a CBA at $t$. Existing
infrastructure in `cba_similarity_avg_prep.py` builds this.

Caveat: $T_t$ does not depend on $i$, so the conn × post coefficient on
$S(u_{i2}, T_t)$ identifies whether the universal treated drift happens to
align with high-connectivity firms' period-2 profiles. This is typically near
zero by construction; report it, but flag it as a sanity check rather than as
evidence on treated movement.

## File Layout

Replace the 10-file `pretreat_ref` pipeline in
`/home/lgg3230/.claude/plans/graceful-cuddling-hedgehog.md` with eight files
total:

```
Programs/cba_similarity/
    cba_similarity_decomp_prep.py              # weighted reference
    cba_similarity_decomp.do
    _run_cba_similarity_decomp.do
    generate_cba_similarity_decomp_latex.py

    cba_similarity_decomp_avg_prep.py          # average reference
    cba_similarity_decomp_avg.do
    _run_cba_similarity_decomp_avg.do
    generate_cba_similarity_decomp_avg_latex.py
```

Each prep script outputs one Stata file with the three similarity columns per
measure (12 columns + IDs):

```
Data/RAIS_aux/cba_similarity_decomp_panel.dta
Data/RAIS_aux/cba_similarity_decomp_avg_panel.dta
```

Each `.do` derives the five outcomes per measure from those columns inside
Stata and runs, sharing one regression sample:

- pooled post-period DiD on each of the five outcomes
- event study (`c.conn##ib2.cba_period`, period 2 omitted) on each

## Output Paths

```
Tables/cba_similarity/
    results_decomp_cba_similarity.csv
    results_decomp_cba_similarity_avg.csv
    cba_similarity_decomp_table.tex         # body, two-panel
    cba_similarity_decomp_avg_table.tex     # body, two-panel
    cba_similarity_decomp_full_table.tex    # appendix, all five outcomes + identity

Graphs/cba_similarity/
    es_untreatedmove.pdf
    es_treatedmove.pdf
    es_untreatedmove_avg.pdf
    es_treatedmove_avg.pdf

Logs/cba_similarity/
    cba_similarity_decomp_<date>_<time>.log
    cba_similarity_decomp_avg_<date>_<time>.log
```

## Main-Text Table Format

Same structure as `cba_similarity_table.tex`:

- 4 columns: Cosine, Bray–Curtis, Total Variation, Ruzicka.
- Panel A: UntreatedMove. Panel B: TreatedMove.
- Rows: $\hat\beta$ on $\text{Connectivity} \times \text{Post}$, robust SE,
  baseline period-2 similarity mean, pre-trend $p$-value over $t \leq 2$,
  $N$ observations, $N$ establishments, FE row.

The appendix `*_decomp_full_table.tex` reports all five outcomes side by side
and the coefficient identity residual.

## Event-Study Figures

One PDF per main outcome (UntreatedMove, TreatedMove) × reference type. Each
PDF has four sub-panels (one similarity measure each). Period 2 is the
omitted category. Y-axis is the same across the two PDFs within a reference
type for visual comparison.

## Verification Checklist

1. **Algebraic identity** per measure × reference type. Print
   $\max_{i,t} |\Delta S_{it} - \text{UntreatedMove}_{it} - \text{TreatedAdditional}_{it}|$
   and the analog for decomposition 2. Should be $< 10^{-12}$.
2. **Coefficient identity**. Print
   $\hat\beta_{\Delta S} - \hat\beta_{\text{UntreatedMove}} - \hat\beta_{\text{TreatedAdditional}}$.
   Should be within rounding ($\sim 10^{-8}$).
3. **Sample identity**. $N$ and $N_{\text{estab}}$ must be identical across
   the five regressions inside a reference type. If not, merge or missingness
   has broken the panel — fix before reading results.
4. **Mechanical zero at $t=2$**. UntreatedMove$_{i2}$ and TreatedMove$_{i2}$
   are 0 by construction. Period 2 is the omitted event-study category and
   stays in the pooled-post sample (so firm FE has full identification).

## Relationship to Existing Work

- The headline $\Delta S$ regression is the existing exercise; coefficients
  already in `cba_similarity_table.tex` and the headline coefplot.
- The bilinear dotprod decomposition
  (`cba_dotprod_decomposition.do`, `documents/session_bilinear_decomposition.md`,
  `documents/dotprod_decomposition_proposal.md`) covers the same conceptual
  ground via the bilinear form $u_t \cdot T_t$. It moves to the appendix:
  same answer through a different geometry reinforces the conclusion, but the
  main text uses the ordered decomposition because each piece is in a measure
  the reader already knows.
- The pre-treat-ref plan (`/plans/graceful-cuddling-hedgehog.md`) is
  superseded by this plan. The UntreatedMove regression on the weighted
  reference is what that plan called "pretreat_ref"; it is reused but
  rebuilt inside the unified decomposition prep so all five outcomes share
  one panel, ensuring the coefficient identity.
