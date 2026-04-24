# Cross-Layer Connectivity: Derivation

## Setup

Let:
- $n_{i,A}$ = number of workers in layer $A$ of firm $i$
- $n_i = \sum_A n_{i,A}$ = total employment of firm $i$
- $s_{i,A} = n_{i,A} / n_i$ = share of firm $i$'s workforce in layer $A$
- $\text{layer\_treat\_n}_{i,A}$ = total worker flows from layer $A$ of firm $i$ to treated firms
- $\text{layer\_treat\_pw}_{i,A} = \text{layer\_treat\_n}_{i,A} / n_{i,A}$ = flows to treated per worker in layer $A$
- $\text{totaltreat\_n}_i = \sum_A \text{layer\_treat\_n}_{i,A}$ = total flows to treated from firm $i$ (all layers)
- $\text{totaltreat\_pw}_i = \text{totaltreat\_n}_i / n_i$ = total flows to treated per worker in firm $i$

---

## Step 1: Firm-level connectivity as a weighted average of layer connectivities

$$\text{totaltreat\_pw}_i = \frac{\text{totaltreat\_n}_i}{n_i} = \frac{\sum_A \text{layer\_treat\_n}_{i,A}}{n_i} = \sum_A \frac{n_{i,A}}{n_i} \times \frac{\text{layer\_treat\_n}_{i,A}}{n_{i,A}} = \sum_A s_{i,A} \times \text{layer\_treat\_pw}_{i,A}$$

Firm-level per-worker connectivity is the **employment-share-weighted average** of layer-level per-worker connectivities.

---

## Step 2: Decompose into own-layer and cross-layer components

For a given outcome layer $B$, split the sum:

$$\text{totaltreat\_pw}_i = s_{i,B} \times \text{layer\_treat\_pw}_{i,B} + \sum_{A \neq B} s_{i,A} \times \text{layer\_treat\_pw}_{i,A}$$

Rearranging:

$$\underbrace{\sum_{A \neq B} s_{i,A} \times \text{layer\_treat\_pw}_{i,A}}_{\equiv\ \text{cross\_conn}_{i,B}} = \text{totaltreat\_pw}_i - s_{i,B} \times \text{layer\_treat\_pw}_{i,B}$$

---

## Step 3: Simplify

$$\text{cross\_conn}_{i,B} = \frac{\text{totaltreat\_n}_i - \text{layer\_treat\_n}_{i,B}}{n_i}$$

**Derivation:**

$$\text{totaltreat\_pw}_i - s_{i,B} \times \text{layer\_treat\_pw}_{i,B} = \frac{\text{totaltreat\_n}_i}{n_i} - \frac{n_{i,B}}{n_i} \times \frac{\text{layer\_treat\_n}_{i,B}}{n_{i,B}} = \frac{\text{totaltreat\_n}_i - \text{layer\_treat\_n}_{i,B}}{n_i}$$

---

## Interpretation

$\text{cross\_conn}_{i,B}$ is the **total flows to treated from all layers other than $B$, divided by total firm employment $n_i$.**

- The weights $s_{i,A} = n_{i,A}/n_i$ are not imposed — they come directly from the algebra of aggregating layer flows to firm-level flows.
- The denominator is $n_i$ (total firm workers), not $n_{i,B}$ or $n_i - n_{i,B}$.
- Equivalently: $\text{cross\_conn}_{i,B} = \text{totaltreat\_pw}_i - s_{i,B} \times \text{layer\_treat\_pw}_{i,B}$, i.e., firm-level connectivity minus own-layer $B$'s contribution to it.

---

## What to compute in practice

For each firm $\times$ layer $\times$ year observation $(i, B, t)$:

| Quantity | Source | Formula |
|----------|--------|---------|
| $\text{totaltreat\_n}_{i,t}$ | firm-level data | `totaltreat_pw_n` $\times$ `firm_emp` |
| $\text{layer\_treat\_n}_{i,B,t}$ | layer data | `layer_treat_pw_n` $\times$ `layer_emp` |
| $n_{i,t}$ | firm-level data | `firm_emp` |
| $\text{cross\_conn}_{i,B,t}$ | computed | $(\text{totaltreat\_n}_{i,t} - \text{layer\_treat\_n}_{i,B,t})\ /\ n_{i,t}$ |

Note: $\text{cross\_conn}_{i,B,t}$ is **time-varying** (like `layer_treat_pw_n`) but pre-treatment values should be used in the regression, analogously to how `layer_treat_pw_n` is a pre-treatment measure.
