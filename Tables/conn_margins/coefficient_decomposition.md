# Relationship Between β (Model 1) and γ₁, γ₂ (Model 2)

## Models

**Model 1 (simple linear):**
$$\text{lr\_remdezr} = \alpha + \beta \cdot \text{conn} + \varepsilon$$

**Model 2 (decomposed):**
$$\text{lr\_remdezr} = \eta + \gamma_1 \cdot \mathbf{1}(\text{conn}>0) + \gamma_2 \cdot \text{conn} + \varepsilon_2$$

---

## Result

Model 2 nests Model 1 — running Model 1 is equivalent to running Model 2 with `1(conn > 0)` omitted. By the **omitted variable bias formula**:

$$\hat{\beta} = \hat{\gamma}_2 + \hat{\gamma}_1 \cdot \delta$$

where $\delta$ is the coefficient from the auxiliary regression:

$$\mathbf{1}(\text{conn}>0) = \delta_0 + \delta \cdot \text{conn} + \text{residual}$$

i.e.,

$$\delta = \frac{\text{Cov}(\mathbf{1}(\text{conn}>0),\, \text{conn})}{\text{Var}(\text{conn})}$$

---

## Sign of δ — Step-by-Step Derivation of the Numerator

Since `conn ≥ 0`, the indicator and the level are positively correlated. The numerator is:

$$\text{Cov}\!\left(\mathbf{1}(\text{conn}>0),\, \text{conn}\right) = E\!\left[\mathbf{1}(\text{conn}>0)\cdot\text{conn}\right] - E\!\left[\mathbf{1}(\text{conn}>0)\right]\cdot E[\text{conn}]$$

**Notation.** Let $p = P(\text{conn}>0)$ and $\mu_+ = E[\text{conn}\mid\text{conn}>0]$.

**Step 1 — Simplify $E[\mathbf{1}(\text{conn}>0)]$.**

$$E\!\left[\mathbf{1}(\text{conn}>0)\right] = P(\text{conn}>0) = p$$

**Step 2 — Simplify $E[\text{conn}]$ using the law of total expectation.**

$$E[\text{conn}] = E[\text{conn}\mid\text{conn}>0]\cdot P(\text{conn}>0) + E[\text{conn}\mid\text{conn}=0]\cdot P(\text{conn}=0) = \mu_+ \cdot p + 0 = p\mu_+$$

**Step 3 — Simplify $E[\mathbf{1}(\text{conn}>0)\cdot\text{conn}]$.**

The product equals `conn` when $\text{conn}>0$ and $0$ otherwise, so again by the law of total expectation:

$$E\!\left[\mathbf{1}(\text{conn}>0)\cdot\text{conn}\right] = E[\text{conn}\mid\text{conn}>0]\cdot P(\text{conn}>0) = \mu_+ \cdot p$$

**Step 4 — Combine.**

$$\text{Cov}\!\left(\mathbf{1}(\text{conn}>0),\,\text{conn}\right) = \mu_+ p - p \cdot p\mu_+ = \mu_+ p(1-p)$$

Substituting back $p = P(\text{conn}>0)$ and $1-p = P(\text{conn}=0)$:

$$\boxed{\text{Cov}\!\left(\mathbf{1}(\text{conn}>0),\,\text{conn}\right) = P(\text{conn}=0)\cdot P(\text{conn}>0)\cdot E[\text{conn}\mid\text{conn}>0] \;>\; 0}$$

Therefore:

$$\delta = \frac{P(\text{conn}=0)\cdot P(\text{conn}>0)\cdot E[\text{conn}\mid\text{conn}>0]}{\text{Var}(\text{conn})} > 0$$

---

## Decomposition of Var(conn) — Law of Total Variance

Let $\sigma_+^2 = \text{Var}(\text{conn}\mid\text{conn}>0)$. The law of total variance splits Var(conn) into a **within-group** and a **between-group** piece:

$$\text{Var}(\text{conn}) = \underbrace{E\!\left[\text{Var}(\text{conn}\mid G)\right]}_{\text{within}} + \underbrace{\text{Var}\!\left(E[\text{conn}\mid G]\right)}_{\text{between}}$$

where $G \in \{\text{conn}=0,\,\text{conn}>0\}$.

**Within-group term.**

Each group's conditional variance, weighted by its probability:

$$E\!\left[\text{Var}(\text{conn}\mid G)\right] = \text{Var}(\text{conn}\mid\text{conn}=0)\cdot(1-p) + \text{Var}(\text{conn}\mid\text{conn}>0)\cdot p = 0\cdot(1-p) + \sigma_+^2\cdot p = p\sigma_+^2$$

The zero group contributes nothing — all observations are exactly zero.

**Between-group term.**

The conditional mean takes two values: $0$ with probability $(1-p)$ and $\mu_+$ with probability $p$. This is a two-point distribution with variance:

$$\text{Var}\!\left(E[\text{conn}\mid G]\right) = E\!\left[(E[\text{conn}\mid G])^2\right] - \left(E[\text{conn}]\right)^2 = \left[0^2(1-p) + \mu_+^2 p\right] - (p\mu_+)^2 = p\mu_+^2 - p^2\mu_+^2 = p(1-p)\mu_+^2$$

**Combined.**

$$\boxed{\text{Var}(\text{conn}) = p\,\sigma_+^2 + p(1-p)\,\mu_+^2}$$

The first term is the variance within the connected group (weighted by their share); the second is the variance from the binary split itself (connected vs. not), which depends only on $p$ and the mean among connected firms.

**Closed-form expression for δ.**

Substituting both the numerator and denominator:

$$\delta = \frac{p(1-p)\,\mu_+}{p\,\sigma_+^2 + p(1-p)\,\mu_+^2} = \frac{(1-p)\,\mu_+}{\sigma_+^2 + (1-p)\,\mu_+^2}$$

This makes the determinants of δ transparent:
- δ is **increasing in $\mu_+$** (higher average connectivity among connected firms → indicator and level co-move more)
- δ is **decreasing in $\sigma_+^2$** (more dispersion within the connected group → level is less predictive of the indicator)
- δ is **decreasing in $p$** (more connected firms → less information in the indicator)

---

## Interpretation

β from Model 1 conflates two distinct effects:

- **γ₂** — *intensive margin*: effect of an additional unit of connectivity, conditional on being connected
- **γ₁ · δ** — *extensive margin contribution*: γ₁ is the discrete jump from zero to positive connectivity, scaled by how strongly the indicator co-moves with the level

If both γ₁ > 0 and γ₂ > 0, then β > γ₂ — the simple coefficient overstates the pure intensive-margin effect.

This motivates estimating the extensive and intensive margins separately (Panels A and B in `conn_margins_tables.tex`), rather than pooling them in a single linear specification.
