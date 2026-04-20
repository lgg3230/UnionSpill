# CBA Similarity Measures: Pre- vs. Post-Reform Content

## Setup

For each establishment $i$, define two CBA content vectors based on clause counts across $K$ subgroups (24 subgroups or 137 clause types):

$$\mathbf{x}_i^{\text{pre}} = (c_1^{\text{pre}}, c_2^{\text{pre}}, \ldots, c_K^{\text{pre}}) \quad \text{and} \quad \mathbf{x}_i^{\text{post}} = (c_1^{\text{post}}, c_2^{\text{post}}, \ldots, c_K^{\text{post}})$$

The goal is to compute a scalar similarity $s_i = \text{sim}(\mathbf{x}_i^{\text{pre}}, \mathbf{x}_i^{\text{post}})$ for each establishment, then test whether $s_i$ is increasing in connectivity to treatment:

$$s_i = \alpha + \beta \cdot C_i + \gamma' \mathbf{W}_i + \varepsilon_i$$

where $C_i$ is the pre-treatment worker-flow connectivity measure (normalized to 1 at the 90th percentile) and $\mathbf{W}_i$ are controls (industry × region, CBA size, employment). A positive $\hat{\beta}$ means more connected firms experienced *smaller* CBA content changes — consistent with a content-diffusion spillover mechanism.

---

## Similarity Measures

### 1. Cosine Similarity

$$s_i^{\cos} = \frac{\mathbf{x}_i^{\text{pre}} \cdot \mathbf{x}_i^{\text{post}}}{\|\mathbf{x}_i^{\text{pre}}\| \cdot \|\mathbf{x}_i^{\text{post}}\|}$$

**Interpretation:** Measures the angular alignment between the two clause vectors, independent of their magnitudes. A firm that expands its total CBA post-reform but keeps the same relative composition across subgroups scores high. This isolates *compositional* change from *scale* change.

**Reference:** Salton & McGill (1983), *Introduction to Modern Information Retrieval*. Applied to economics by Hoberg & Phillips (2016, *JPE*), who use cosine similarity of 10-K product descriptions to measure industry relatedness.

---

### 2. Bray-Curtis Similarity

$$s_i^{BC} = 1 - \frac{\sum_k |c_k^{\text{post}} - c_k^{\text{pre}}|}{\sum_k (c_k^{\text{post}} + c_k^{\text{pre}})}$$

**Interpretation:** Originally developed for comparing species abundance vectors in ecology, it is well-suited for non-negative count data. Unlike cosine similarity, it is sensitive to both the presence/absence of clause types *and* their absolute magnitudes. The denominator normalizes by total clause content, so it remains comparable across CBAs of different sizes.

**Reference:** Bray & Curtis (1957, *Ecological Monographs*). Widely adopted for count data with magnitude in ecological and biological sciences; used analogously in economics for count-like composition data.

---

### 3. Total Variation Similarity (Normalized $\ell_1$)

First normalize each CBA vector into a share distribution:

$$\tilde{c}_k^t = \frac{c_k^t}{\sum_k c_k^t}$$

Then compute:

$$s_i^{TV} = 1 - \frac{1}{2} \sum_k \left| \tilde{c}_k^{\text{post}} - \tilde{c}_k^{\text{pre}} \right|$$

**Interpretation:** This is the complement of the total variation distance between the pre- and post-reform clause *share distributions*. By normalizing to shares first, it completely removes any effect of total CBA length — isolating whether the *profile* (fraction of clauses allocated to wage, employment, or other amenities) shifted. Ranges from 0 (maximally different compositions) to 1 (identical compositions).

**Reference:** Related to the $L^1$/Wasserstein metrics standard in statistics. In economics, Gentzkow & Shapiro (2010, *QJE*) use a closely related normalized difference in word frequencies to measure partisan divergence in Congressional speech.

---

### 4. Jaccard Similarity (Presence/Absence)

Let $\mathcal{A}_i^t = \{k : c_k^t > 0\}$ be the set of subgroups with at least one clause in period $t$. Then:

$$s_i^{J} = \frac{|\mathcal{A}_i^{\text{pre}} \cap \mathcal{A}_i^{\text{post}}|}{|\mathcal{A}_i^{\text{pre}} \cup \mathcal{A}_i^{\text{post}}|}$$

**Interpretation:** Answers "what fraction of all subgroups ever covered in either period were covered in both periods?" Ignores how many clauses appear within each subgroup — only whether the topic is present at all. Particularly appropriate at the 24-subgroup level where the dimensionality is tractable. Robust to outlier clause counts.

**Reference:** Jaccard (1901, *Bulletin de la Société Vaudoise des Sciences Naturelles*). Applied in economics by Bloom et al. (2013, *AER*), who use Jaccard-type product similarity to measure technology spillovers.

---

## Summary

| Measure | What it captures | Sensitive to magnitudes | Normalizes for CBA size | Best used for |
|---|---|---|---|---|
| **Cosine** | Angle between count vectors | Yes | Implicitly | Composition shifts net of scale |
| **Bray-Curtis** | Absolute count differences | Yes | Yes (sum denominator) | Count data with magnitude |
| **Total Variation** | Share/profile differences | After normalization | Explicitly | Compositional profile only |
| **Jaccard** | Presence/absence overlap | No | Yes | Coarse binary topic coverage |

---

## Recommended Strategy

Lead with **cosine similarity** as the main specification (cleanest interpretation, most familiar to economics audiences), and present **Bray-Curtis** and **total variation** as robustness columns. **Jaccard** serves as a binary-coverage check at the 24-subgroup level. Presenting all four in a single table with one column per measure allows readers to assess whether findings are robust to the choice of similarity metric.

---

## References

- Bray, J.R. & Curtis, J.T. (1957). An ordination of the upland forest communities of southern Wisconsin. *Ecological Monographs*, 27(4), 325–349.
- Bloom, N., Schankerman, M. & Van Reenen, J. (2013). Identifying technology spillovers and product market rivalry. *Econometrica*, 81(4), 1347–1393.
- Gentzkow, M. & Shapiro, J.M. (2010). What drives media slant? Evidence from U.S. daily newspapers. *Econometrica*, 78(1), 35–71.
- Hoberg, G. & Phillips, G. (2016). Text-based network industries and endogenous product differentiation. *Journal of Political Economy*, 124(5), 1423–1465.
- Jaccard, P. (1901). Étude comparative de la distribution florale dans une portion des Alpes et des Jura. *Bulletin de la Société Vaudoise des Sciences Naturelles*, 37, 547–579.
- Salton, G. & McGill, M.J. (1983). *Introduction to Modern Information Retrieval*. McGraw-Hill.
