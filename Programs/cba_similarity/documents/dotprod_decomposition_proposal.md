# Exercise D — Additive Decomposition via Bilinear Outcomes

## Motivation

Exercises A/B/C use non-linear similarities (cosine, Bray–Curtis, total
variation, Ruzicka). Under each measure $S(u, T)$, the connectivity
coefficient for "both moving" (A) differs from the sum of the coefficients
for "focal frozen at $p_2$" (B) and "partner frozen at $p_2$" (C) because
$S$ has a non-trivial cross-curvature in $(u, T)$. We can recover a *clean
additive identity* by switching to a bilinear outcome.

## Algebra

Let $u_{i,t}$ and $T_{i,t}$ denote the focal firm's and weighted-treated-
partner reference clause vectors at $\text{cba\_period}\,t$, with reference
period $p_2$. Define $\Delta u = u_t - u_2$, $\Delta T = T_t - T_2$.

For the **raw inner product** $S(u, T) = u \cdot T$:

$$
u_t \cdot T_t \;=\; \underbrace{u_2 \cdot T_2}_{\text{firm-FE constant}}
\;+\; \underbrace{u_2 \cdot \Delta T}_{\text{B-piece}}
\;+\; \underbrace{\Delta u \cdot T_2}_{\text{C-piece}}
\;+\; \underbrace{\Delta u \cdot \Delta T}_{\text{cross}}.
$$

Equivalent definitions usable directly as regression outcomes (the $u_2
\cdot T_2$ term is firm-specific and absorbed by establishment fixed
effects):

| Outcome | Closed form | Interpretation |
|---|---|---|
| $y_A$    | $u_t \cdot T_t$              | both moving (Exercise A) |
| $y_B$    | $u_2 \cdot T_t$              | focal frozen at $p_2$ (Exercise B) |
| $y_C$    | $u_t \cdot T_2$              | partner frozen at $p_2$ (Exercise C) |
| $y_{\text{cross}}$ | $y_A - y_B - y_C + u_2 \cdot T_2$ | $\Delta u \cdot \Delta T$ |

OLS is linear in the outcome and the firm FE absorbs $u_2 \cdot T_2$, so
within a regression with the same RHS:

$$
\boxed{\;\beta_A \;=\; \beta_B + \beta_C + \beta_{\text{cross}}.\;}
$$

The identity holds **exactly** (numerical tolerance ~$10^{-10}$), not
approximately. This is the cleanness we lose with cosine/Bray–Curtis.

The **shares version** applies the same logic to clause-share vectors
$s_u = u / \sum_k u_k$ and $s_T = T / \sum_k T_k$. Each is a probability
vector on the simplex, so $s_u \cdot s_T \in [0, 1]$ is a *collision
probability* — the chance that random clauses drawn from $u$ and $T$
(weighted by their counts) match. The decomposition identity is identical,
just with $s$ replacing $u, T$ throughout.

## Why two versions

- **Raw $u \cdot T$**: magnitudes matter. A firm growing from 10 to 100
  clauses raises its inner product mechanically. The decomposition is
  cleanest here but interpretation is closer to "are both vectors
  *growing* in correlated directions" than "are their compositions
  becoming similar."
- **Shares $s_u \cdot s_T$**: composition-only, removes the clause-count
  magnitude channel that the user has documented as churny and
  symmetric across subgroups. Tighter to the "policy diffusion of clause
  *types*" interpretation, while preserving the exact additive identity.

Reporting both lets us see whether the decomposition story changes when
we strip clause-count growth out of the outcome.

## Decomposition pieces — what each $\beta$ measures

| Coefficient | Captures | High value means |
|---|---|---|
| $\beta_B$            | partner-side movement evaluated against fixed focal | partners' new clauses overlap with focal's frozen contract |
| $\beta_C$            | focal-side movement evaluated against fixed partner | focal adopts the *pre-Sumula* treated contract |
| $\beta_{\text{cross}}$ | covariance of focal and partner shifts | focal and partners move into the *same new* clauses together |

The sign and magnitude of $\beta_{\text{cross}}$ is the substantive payoff
of this exercise. Under a true diffusion story we expect it to be the
largest piece: high-connectivity untreated firms not only sit closer to
treated firms' fixed pre-reform contracts (B), and not only see their
*own* contract drift (C) — the two sides actually co-move into new clause
territory together.

## Sample, weights, fixed effects

All identical to Exercises A/B/C so coefficients are directly comparable:

- Sample: `lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1`,
  untreated focals with at least one treated partner sharing pre-2011
  flows AND with period-2 clauses (needed for the frozen vectors).
- Weights: uncorrected `bilateral_conn_pw` (i<j-biased per
  `bilateral_connectivity.m`).
- Connectivity regressor: `totaltreat_pw_norm` (scaled to 1 at the 90th
  percentile of the spillover sample at year 2009).
- FE structure:
  - Establishment
  - industry × cba_period
  - mode_base_month × cba_period
  - microregion × cba_period
  - Panel B (union variant): adds mode_union × cba_period
- Pre-treatment quartile bins of (outcome, log employment, total flows) ×
  cba_period.
- Cluster SEs at the establishment level.

## Files to add

```
Programs/cba_similarity/cba_dotprod_decomposition_prep.py       # Python prep
Programs/cba_similarity/cba_dotprod_decomposition.do            # Stata
Programs/cba_similarity/_run_cba_dotprod_decomposition.do       # wrapper
Programs/cba_similarity/generate_dotprod_raw_decomposition_latex.py
Programs/cba_similarity/generate_dotprod_shares_decomposition_latex.py
```

No edits to any existing file.

### Python prep responsibilities

For each $(i, t)$ with $i$ untreated and at least one treated partner:

1. Build $u_{i,t}$, $u_{i,2}$ (untreated focal clauses at $t$ and at 2).
2. Build $T_{i,t}$, $T_{i,2}$ using uncorrected `bilateral_conn_pw` weights
   (already implemented in `cba_similarity_focal_frozen_prep.py` — port
   that block).
3. For both **raw** and **shares** versions, compute:
   - `y_A    = u_t · T_t`
   - `y_B    = u_2 · T_t`
   - `y_C    = u_t · T_2`
   - `y_cross= (u_t - u_2) · (T_t - T_2)`
4. Inner-merge with `cba_similarity_panel.dta` on `(identificad, cba_period)`
   to enforce the same regression sample.

Output: `Data/RAIS_aux/cba_dotprod_decomposition_panel.dta` with columns
`identificad, cba_period, dot_raw_{A,B,C,cross}, dot_shares_{A,B,C,cross}`.

### Stata responsibilities

For each version $v \in \{raw, shares\}$ and each FE variant $\in
\{base, union\}$, run four regressions (A, B, C, cross). Sixteen total.

Same construction as `cba_similarity_focal_frozen.do`:
- `post_treat_cba` main + `pre_treat_cba` placebo regressions.
- Write rows to two CSVs:
  - `Tables/cba_similarity/results_spill_dotprod_raw.csv`
  - `Tables/cba_similarity/results_spill_dotprod_shares.csv`

After regressions, verify the identity programmatically: read back the
four CSVs in the wrapping LaTeX script and assert
$|\beta_A - (\beta_B + \beta_C + \beta_{\text{cross}})| < 10^{-8}$ for
each FE variant. Fail loud if it doesn't.

### LaTeX tables

Two tables, one per version:
- Columns: A, B, C, cross, $B+C+\text{cross}$ (= A check)
- Rows: Panel A (base FE) and Panel B (union FE), each with
  `Connectivity × Post`, SE, `Connectivity × Pre`, SE, baseline mean,
  observations, establishments, pre-trend $p$-value.

### Outputs

```
Data/RAIS_aux/cba_dotprod_decomposition_panel.dta
Tables/cba_similarity/results_spill_dotprod_raw.csv
Tables/cba_similarity/results_spill_dotprod_shares.csv
Tables/cba_similarity/dotprod_raw_decomposition_table.tex
Tables/cba_similarity/dotprod_shares_decomposition_table.tex
Logs/cba_similarity/cba_dotprod_decomposition_<date>_<time>.log
```

## Sanity checks

1. **Numerical identity**: $\beta_A - (\beta_B + \beta_C + \beta_{\text{cross}})$
   should be machine-zero (verified in the LaTeX generator).
2. **Period-2 baseline mean**: $y_A = y_B = y_C$ at $t = 2$ since $u_2 = u_t$
   and $T_2 = T_t$ there; $y_{\text{cross}} = 0$ at $t = 2$ by construction.
3. **Sign sanity**: under the diffusion story, $\beta_B, \beta_C, \beta_{\text{cross}} \geq 0$
   (or at least not strongly negative); $\beta_{\text{cross}}$ expected to
   carry most of the headline effect.
4. **Shares vs raw**: if $\beta_B, \beta_C$ in raw are dominated by
   clause-count growth, expect them to shrink (relative to A) in shares;
   if the *composition* story is real, $\beta_{\text{cross}}$ should
   survive in shares.

## Comparability with A/B/C cosine results

The three previous exercises and this one use the *same* sample, weights,
connectivity scaling, FE structure, and reference period — only the
outcome function changes. So the cosine table's $\beta_A^{\cos} \approx
0.013$ is comparable in *qualitative* sign and significance to
$\beta_A^{\text{dot,raw}}$ here, even though magnitudes are not directly
on the same scale (cosine is in $[0,1]$ per observation; raw inner
product scales with clause-count). The collision-probability shares
version is bounded in $[0, 1]$ like cosine, so its magnitudes are the
ones to compare across tables.
