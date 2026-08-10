# Bilinear Decomposition — Algebra Walkthrough

Companion to [`dotprod_decomposition_proposal.md`](dotprod_decomposition_proposal.md).
Explains *why* the A/B/C/cross decomposition is an exact algebraic
identity for $u \cdot T$ (and $s_u \cdot s_T$), but not for cosine,
Bray–Curtis, total variation, or Ruzicka.

## Setup

For each untreated firm $i$ and CBA period $t$:

- $u_{i,t}$ — focal firm $i$'s clause vector at period $t$  (length $K = 139$)
- $T_{i,t}$ — flow-weighted average clause vector of $i$'s treated
  partners at period $t$ (same weights as Exercises A/B/C: uncorrected
  `bilateral_conn_pw`)

Reference is $p_2$, the last pre-Sumula CBA cycle. Define the shifts:

$$\Delta u = u_t - u_2, \qquad \Delta T = T_t - T_2.$$

## The identity

Bilinear functions distribute over addition. Substitute $u_t = u_2 + \Delta u$
and $T_t = T_2 + \Delta T$ into $u_t \cdot T_t$ and expand (just FOIL on
inner products):

$$
u_t \cdot T_t = (u_2 + \Delta u) \cdot (T_2 + \Delta T)
$$

$$
\boxed{\;u_t \cdot T_t \;=\; \underbrace{u_2 \cdot T_2}_{\text{period-2 baseline}}
   + \underbrace{u_2 \cdot \Delta T}_{\text{B-piece}}
   + \underbrace{\Delta u \cdot T_2}_{\text{C-piece}}
   + \underbrace{\Delta u \cdot \Delta T}_{\text{cross}}.\;}
$$

This is an *algebraic identity* — no assumption, no approximation. It just
restates what the inner product of two shifted vectors looks like.

## Tiny numerical example ($K = 2$ clauses)

Suppose there are only two clauses, call them A and B. At period 2:

- Focal: $u_2 = (0.6,\, 0.4)$
- Partner avg: $T_2 = (0.5,\, 0.5)$

After treatment at period $t$, treated partners shift toward clause A,
$T_t = (0.7,\, 0.3)$, so $\Delta T = (0.2,\, -0.2)$. Focal *also* drifts
toward A, $u_t = (0.7,\, 0.3)$, so $\Delta u = (0.1,\, -0.1)$.

Compute each piece:

| Quantity                | Value |
|-------------------------|-------|
| $u_t \cdot T_t$         | $0.7\cdot 0.7 + 0.3\cdot 0.3 = 0.58$ |
| $u_2 \cdot T_2$         | $0.30 + 0.20 = 0.50$  |
| $u_2 \cdot T_t$         | $0.42 + 0.12 = 0.54$  ⇒ B = $0.04$ |
| $u_t \cdot T_2$         | $0.35 + 0.15 = 0.50$  ⇒ C = $0.00$ |
| $\Delta u \cdot \Delta T$ | $(0.1)(0.2) + (-0.1)(-0.2) = 0.04$  ⇒ cross = $0.04$ |

Check: $0.50 + 0.04 + 0.00 + 0.04 = 0.58 = u_t \cdot T_t$. ✓

**Now flip the focal's direction.** Suppose the focal instead drifts
*away* from clause A: $u_t = (0.5,\, 0.5)$, so $\Delta u = (-0.1,\, 0.1)$.
Recompute:

| Quantity                  | Value |
|---------------------------|-------|
| $u_t \cdot T_t$           | $0.35 + 0.15 = 0.50$   ⇒ total change = $0.00$ |
| B  (unchanged)            | $0.04$ |
| C $= \Delta u \cdot T_2$  | $-0.05 + 0.05 = 0.00$ |
| cross $= \Delta u \cdot \Delta T$ | $(-0.1)(0.2) + (0.1)(-0.2) = -0.04$ |

Check: $0.04 + 0.00 + (-0.04) = 0.00$. ✓

The cross piece is *negative* — focal moved opposite to partner — and
exactly cancels the B-piece. So:

> The cross piece is the sign and size of co-movement. Positive means
> both sides marched into the same new clauses. Negative means they moved
> apart even as partners shifted.

## From algebra to regression

We have four candidate regression outcomes (each a deterministic function
of the four firm-period vectors $u_2, u_t, T_2, T_t$):

$$
y_A = u_t \cdot T_t,\quad
y_B = u_2 \cdot T_t,\quad
y_C = u_t \cdot T_2,\quad
y_{\text{cross}} = \Delta u \cdot \Delta T.
$$

The identity says, after a small rearrangement (each "frozen" outcome
contains a $u_2 \cdot T_2$ term):

$$
y_A \;=\; y_B + y_C - (u_2 \cdot T_2) + y_{\text{cross}}.
$$

Now run four separate regressions of these outcomes on the **same** RHS
(connectivity × post + FEs + controls), each with **firm fixed effects**.
The firm FE absorbs any constant within firm $i$ — including
$u_2 \cdot T_2$, which is a firm-specific number (the period-2 baseline
inner product). The projection of $(u_2 \cdot T_2)$ onto the
within-firm-demeaned connectivity regressor is therefore zero by
construction.

OLS is linear in the dependent variable, so:

$$
\hat\beta_A \;=\; \hat\beta_B + \hat\beta_C - \underbrace{\hat\beta_{u_2 \cdot T_2}}_{=\,0\text{ under firm FE}} + \hat\beta_{\text{cross}}.
$$

Therefore:

$$
\boxed{\;\hat\beta_A \;=\; \hat\beta_B + \hat\beta_C + \hat\beta_{\text{cross}}\;}
$$

holds **exactly** — to machine precision, not approximately. (The LaTeX
generator checks $|\hat\beta_A - (\hat\beta_B + \hat\beta_C + \hat\beta_{\text{cross}})| < 10^{-8}$
and fails loud otherwise.)

## Why cosine doesn't admit this trick

$$
\cos(u_t, T_t) \;=\; \frac{u_t \cdot T_t}{\lVert u_t\rVert\,\lVert T_t\rVert}.
$$

The numerator decomposes cleanly — we just did that. The denominator does
not: $\lVert u_t\rVert = \sqrt{u_t \cdot u_t}$ is **non-linear** in $u_t$.
So you can't write

$$
\cos(u_t, T_t) \;=\; \cos(u_2, T_t) + \cos(u_t, T_2) + (\text{cross})
$$

as a clean algebraic identity. The non-linearity of the norm destroys it.
Same for Bray–Curtis (denominator is $L_1$-norm), Ruzicka, and total
variation — each normalizes by something non-linear in $(u, T)$.

This is why our earlier cosine-based A/B/C table left a residual:
$\hat\beta_A^{\cos} \approx 0.013$ while $\hat\beta_B^{\cos} + \hat\beta_C^{\cos} \approx 0.005$,
with the missing $\sim 0.008$ being the part of the headline effect that
the cross-curvature of cosine absorbs but can't be allocated to either
single-side piece. The bilinear exercise allocates it.

**Cost of switching to $u \cdot T$:** it is not bounded in $[0, 1]$ and
scales with clause counts (a firm with 100 clauses has a much larger
$\lVert u\rVert$ than one with 10). The shares version below restores
boundedness while preserving the exact identity.

## Shares version

Define share vectors on the simplex:

$$
s_{u,t} = \frac{u_t}{\sum_k u_{k,t}}, \qquad s_{T,t} = \frac{T_t}{\sum_k T_{k,t}}.
$$

Apply the identical algebra to $s_u \cdot s_T$:

$$
s_{u,t} \cdot s_{T,t} \;=\; s_{u,2} \cdot s_{T,2} + s_{u,2} \cdot \Delta s_T + \Delta s_u \cdot s_{T,2} + \Delta s_u \cdot \Delta s_T.
$$

Same decomposition, same exact regression identity, but now
$s_u \cdot s_T \in [0, 1]$ is the **collision probability**: pick a clause
from $u$ at random, weighted by $u$'s share vector, and a clause from $T$
at random, weighted by $T$'s share vector — the probability they're the
same clause is $s_u \cdot s_T$.

So the shares version answers "does CBA *composition* converge?" rather
than "do both vectors *grow into the same place* together?" — and is on
the same magnitude scale as cosine for comparison across tables.

## How to read the eventual results

| Coefficient                  | What it captures                                         | Story it tells                                                                 |
|------------------------------|----------------------------------------------------------|---------------------------------------------------------------------------------|
| $\hat\beta_C$                 | focal moves while partner is held at pre-reform           | "Untreated firms' new clauses look more like *old* treated contracts."        |
| $\hat\beta_B$                 | partner moves while focal is held at pre-reform           | "Treated partners' *new* clauses look more like the untreated firm's old."   |
| $\hat\beta_{\text{cross}}$    | both sides move correlatedly                              | "High-connectivity firms and their treated partners march into the same new clauses together." |
| $\hat\beta_A$                 | total                                                     | sum of the three (exact identity).                                            |

Under a diffusion-of-ideas story we expect $\hat\beta_{\text{cross}}$ to
be the dominant piece — and the cosine result already hinted at this:
$\hat\beta_A \approx 0.013$, $\hat\beta_B + \hat\beta_C \approx 0.005$,
leaving ~$0.008$ for the cross-like residual that bilinear decomposition
will make explicit.
