# Permutation-Placebo Test — Reference Note

*What this analysis is, and how to read the balance diagnostic (Test 1A).*

This note explains the placebo/randomization-inference exercise for the union
spillover estimate, and in particular **how we check that the reshuffling
preserves the structure of the treated set** along the characteristics we worry
about. It is the reference document for the `rand_inference` placebo-diagnostics
pipeline.

---

## The design in one paragraph

The spillover regression (see `Programs/Main_Results_pct_tfpw_07_11.do`, line
~568) estimates, on **untreated** firms only,

```
outcome_it = beta * (Connectivity_i x Post_t) + FE + controls
Connectivity_i = sum_j W_ij * treated_j      (pre-period, held fixed)
```

`Connectivity_i` is how exposed firm *i* is, through pre-reform worker flows
`W_ij`, to firms `j` that were **treated** by Súmula 277 (`treated_j`). The
placebo test asks: is it the *identity* of the treated firms that drives
`beta`, or just the *kind of firms* connected firms happen to sit near? We
answer it by **reassigning `treated_j` at random** to other firms, recomputing
placebo connectivity, and re-estimating `beta` many times.

Treatment here is a **timing lottery**: a firm is "treated" if its collective
bargaining agreement happened to be active on the Súmula-277 cutoff date. Since
these firms renegotiate on rolling schedules, which side of the line they land
on is close to random — *conditional on* the observable imbalances between the
groups. The stratified reshuffling is how we encode "as-good-as-random within
these cells," and the balance diagnostic below is how we verify it.

---

## What the reshuffle implicitly claims

- The placebo draws define a set of **counterfactual worlds**: "treatment could
  just as well have landed on *these* firms instead."
- The method is valid only if the **real world is a typical member of that
  set** — i.e., the real treated assignment is exchangeable with the draws.
- "Keeping the structure of the sample" means exactly this: in every
  counterfactual world, the treated group must **look like the real treated
  group** along everything that matters for connectivity and outcomes (same size
  profile, same industry mix, same flow intensity, etc.). Only the *identities*
  differ.
- If a draw makes the treated group look different (say, smaller firms on
  average), that world was *not* equally likely, and placebo connectivity built
  from it is not a valid stand-in for real connectivity.

---

## What Test 1A does, mechanically

Think of it as asking, one covariate at a time: *"is the real assignment a
typical draw from my own reshuffling scheme, along X?"*

1. Define an imbalance statistic as a **function of the assignment vector**:
   `T(g)` = standardized mean difference of X between firms with `g_j = 1`
   (treated) and `g_j = 0` (untreated).
2. Compute it once with the **real** assignment: `T(g_real)` — the real-world
   imbalance (which we know exists).
3. Compute it for **every placebo draw**: `T(g^(1)), ..., T(g^(S))`.
4. Look at **where `T(g_real)` falls inside the distribution of the `T(g^(s))`**.

The reading is the *reverse* of a normal placebo test, and this is the part that
trips people up:

- **You do NOT want the placebo distribution centered at zero.** You want it
  centered **at the real value.**
- **Preserved structure** = every counterfactual treated group reproduces the
  same imbalance the real treated group has. The `T(g^(s))` cluster tightly
  around `T(g_real)`, and the real value sits in the middle. The imbalance still
  exists, but it is now **held fixed by design** — baked into every world, so it
  cancels when you recenter or compare real vs. placebo `beta`.
- **Broken structure** = the reshuffle ignores X, so placebo treated groups mix
  X freely. The `T(g^(s))` collapse toward 0 while `T(g_real)` sits far out in
  the tail. Now the real world is *atypical* among your counterfactuals along X:
  real connectivity loads on "flows to high-X firms," placebo connectivity does
  not. The comparison is contaminated.

So the per-covariate diagnostic number is simply the **position (z-score or
quantile) of the real imbalance within the placebo imbalance distribution**.
Near the center → structure preserved along X. In the tail → the scheme fails
along X → stratify on X (or control for it) and re-run.

---

## Tiny example

- 10 destination firms, 5 treated. Treated mean size 100, untreated mean 20.
  Real imbalance: large and positive.
- **Unstratified reshuffle** (any 5 of 10): draws often make the "treated" group
  small-firm-heavy. Placebo imbalances scatter around 0. The real imbalance
  lands at the ~99th percentile. **Fail**: the counterfactual worlds have
  treatment landing on small firms, which never happens in reality.
- **Size-stratified reshuffle** (reshuffle within size bins, each bin keeping its
  own treated count): every draw's treated group has (almost) the same size
  profile as the real one. Placebo imbalances pile up right at the real value.
  **Pass**: size imbalance is now part of the design, not a contaminant.
- Mechanics: within-cell reshuffling *exactly* preserves any variable that is
  constant within cells, and *approximately* preserves variables the cells proxy
  well. Coarse bins → the placebo distribution has some spread around the real
  value, which is fine as long as the real value is in the central mass.

---

## One refinement specific to this design

- The structure that matters is not the raw covariate distribution of
  destination firms — it is their distribution **as seen through the flow
  weights `W_ij`**, because `Connectivity_i = sum_j W_ij * treated_j`.
- A treated firm that receives flows from thousands of origin firms matters
  enormously; a treated firm nobody flows to matters not at all. An unweighted
  balance test treats them the same.
- So run each covariate's test twice:
  - **Unweighted** `T(g)`: plain treated-vs-untreated difference across
    destination firms.
  - **Flow-weighted** `T(g)`: the same difference, weighting each destination
    firm *j* by its total inflow `sum_i W_ij`.
- The flow-weighted version is the one that directly governs whether placebo
  connectivity is distributed like real connectivity. A scheme can pass
  unweighted and fail flow-weighted (e.g., if the few high-inflow treated firms
  are systematically different). If they disagree, trust the weighted one.

---

## Summary — one line per piece

- **Claim being tested:** the real treated set is a typical draw from the
  reshuffling scheme.
- **Statistic:** imbalance `T(g)` per covariate, computed on the real assignment
  and on every draw.
- **Pass:** real `T` sits in the center of the placebo `T` distribution
  (imbalance reproduced by design).
- **Fail:** placebo `T`'s center on 0, real `T` in the tail (scheme creates
  worlds that do not resemble reality).
- **Fix on fail:** add that covariate to the strata (or as a control), redraw,
  retest.
- **Extra for this design:** do it flow-weighted, since connectivity only sees
  destinations through `W_ij`.

Then **Test 1B** (regress the recentered connectivity `z_i = Connectivity_i -
mu_i` on all covariates jointly, permutation p-values) is the omnibus
certificate that nothing important slipped through: Test 1A tells you *which*
variable to fix, Test 1B tells you *whether you are done*.
