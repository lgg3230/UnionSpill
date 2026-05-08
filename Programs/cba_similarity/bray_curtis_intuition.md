# Similarity Measures: Intuition

Notes on similarity measures for compositional vectors (counts or proportions across categories — species, clauses, occupations, etc.). Built around Bray-Curtis as the primary tool, with comparisons to total variation, Euclidean, Jaccard, and Ruzicka.

---

## Bray-Curtis Similarity

### Formula

Similarity form, between 0 and 1:

$$BC_{sim}(A, B) = \frac{2 \sum_i \min(A_i, B_i)}{\sum_i A_i + \sum_i B_i}$$

The dissimilarity version is just $1 - BC_{sim}$, or equivalently:

$$BC_{diss}(A, B) = \frac{\sum_i |A_i - B_i|}{\sum_i A_i + \sum_i B_i}$$

### Intuition

Think of two CBAs as bundles of clauses. For each clause type, $\min(A_i, B_i)$ is how much of that clause they *both* have — the shared portion. Sum that across all clause types and you get total overlap. Divide by the average total size $(|A| + |B|)/2$ and you get the share of the "average bundle" that is common to both.

### Key Properties

- **Bounded [0, 1]**: 1 means identical compositions, 0 means no shared categories at all.
- **Asymmetric in size**: If A is a strict subset of B with half the volume, $BC_{sim} = 2|A| / (|A| + |B|) = 2/3$, not 1. So it penalizes size differences, not just compositional ones — unlike cosine similarity, which ignores magnitude.
- **Ignores joint absences**: A category where both A and B have zero contributes nothing to numerator or denominator. This is why it's popular in ecology — two ponds aren't "similar" because they both lack penguins.
- **Linear in differences**: Built on L1 (absolute) distance, so it's less sensitive to outliers than Euclidean-based measures.

### When to Use It vs Alternatives

- **vs Jaccard**: Jaccard is the binary (presence/absence) version. Bray-Curtis uses the actual counts/weights.
- **vs cosine**: Cosine measures angle only — it says A and 10·A are identical. Bray-Curtis says they're not, because magnitudes differ.
- **vs Euclidean**: Euclidean treats joint zeros as "agreement," which inflates similarity for sparse data. Bray-Curtis doesn't.

For CBA clause vectors, this matters: two agreements that both omit obscure clauses shouldn't be called similar *because* of those omissions — Bray-Curtis correctly ignores them.

---

## Total Variation Similarity

The compositional sister of Bray-Curtis — same idea, but it first **normalizes each vector into a probability distribution** before measuring the gap.

### Formula

Convert each vector into shares: $\tilde{x}_k = x_k / \sum_k x_k$, $\tilde{y}_k = y_k / \sum_k y_k$. Then:

$$TV_{sim}(\mathbf{x}, \mathbf{y}) = 1 - \tfrac{1}{2} \sum_k |\tilde{y}_k - \tilde{x}_k|$$

The dissimilarity, $TV_{diss} = \tfrac{1}{2} \sum_k |\tilde{y}_k - \tilde{x}_k|$, is the **total variation distance** — a workhorse metric in probability theory for comparing distributions.

### Intuition

Treat each CBA's clause counts as describing a **probability distribution over clause types** ("if I randomly grabbed a clause from this CBA, what's the probability it's of type $k$?"). Then the question becomes: how different are the two distributions?

The factor of $\tfrac{1}{2}$ is the convention that bounds the answer in $[0, 1]$. Without it, $\sum_k |\tilde{y}_k - \tilde{x}_k|$ could reach 2 (two disjoint distributions on different supports). The half makes the natural reading clean: $TV_{diss}$ is the **probability mass that must be moved** to convert one distribution into the other.

Equivalently — and this is the most useful formulation — total variation distance is:

$$TV_{diss} = \max_A |P(A) - Q(A)|$$

over all subsets $A$ of clause types. So it's the **single category-bundle on which the two distributions disagree most**. If $TV_{diss} = 0.30$, there exists some subset of clause types whose total share differs by 30 percentage points between the two CBAs.

### Why It's Different from Bray-Curtis

Same shape, different normalization choice:

| | Bray-Curtis | Total Variation |
|---|---|---|
| Numerator | $\sum_k \|y_k - x_k\|$ | $\sum_k \|\tilde{y}_k - \tilde{x}_k\|$ |
| Denominator | $\sum_k (x_k + y_k)$ | always $2$ (built into the $\tfrac{1}{2}$) |
| Scale-sensitive? | Yes — bigger CBAs penalised more by absolute differences | No — only shape matters |
| What it measures | Volume + composition agreement | Pure compositional agreement |

Bray-Curtis says a CBA with 10 clauses and one with 20 clauses (otherwise identical mix) are *not* perfectly similar. Total variation says they *are* — the **profile** is the same.

### Key Properties

- **Bounded $[0, 1]$**: 0 when the two clause-type distributions don't overlap at all; 1 when they're identical proportions.
- **Ignores total volume**: doubling all $x_k$ doesn't change $\tilde{x}_k$, so it doesn't change the similarity. Pure compositional measure.
- **Joint absences**: ignored — categories where both distributions have zero share contribute nothing. Same logic as Bray-Curtis and Jaccard.
- **Triangle inequality holds**: $TV_{diss}$ is a proper metric on the simplex, useful for clustering or theoretical bounds.
- **Bounded by KL divergence**: Pinsker's inequality gives $TV_{diss} \leq \sqrt{\tfrac{1}{2} D_{KL}}$ — so TV is the "robust cousin" of KL when you don't want to assume strict positivity.

### What It Captures in CBA Terms

If two CBAs cover the same clause topics in the same proportions but one is a fatter document with twice as much text per topic, total variation says they're identical. **Total variation is the right measure when you want to ask: "do these two CBAs allocate their bargaining attention the same way?"** — irrespective of how heavily they bargain overall.

That's a cleaner question than Bray-Curtis answers, but it also throws away potentially relevant information: a CBA that doubles every clause is doing *more* of the same union work, and Bray-Curtis registers that, while total variation calls it a wash. Which behaviour is "right" depends on whether you care about intensity or composition.

### When to Use It (vs Alternatives) for the Spillover Story

The connectivity-driven mechanism in this project is "untreated firms shift their CBAs to look like the treated firms they're connected to." Two interpretations:

- **Composition story**: untreated firms re-prioritize *which* topics get bargained → total variation captures this cleanly.
- **Intensity story**: untreated firms *amplify* what they were already bargaining on the topics treated firms emphasize → Bray-Curtis or Ruzicka registers this; total variation does not.

Reporting both lets the reader see whether the spillover is about reshuffling topic shares (TV moves) or about volume on already-shared topics (BC and Ruzicka move more than TV does). In the tables: if TV moves but Ruzicka doesn't, the effect is purely compositional; if Ruzicka moves more than TV, there's an intensive-margin component.

---

## Euclidean-Based Similarity

Euclidean distance is unbounded $[0, \infty)$, so converting it to a bounded $[0, 1]$ similarity requires a transformation. There's no single canonical version.

### Common Conversions

1. **Reciprocal**: $sim = \frac{1}{1 + d(A, B)}$
   - Bounded in $(0, 1]$, equals 1 when identical, decays as distance grows.
   - Smooth, but the rate of decay depends on the scale of your data.

2. **Exponential (Gaussian kernel)**: $sim = \exp(-d(A,B)^2 / 2\sigma^2)$
   - Same idea, but with a tunable bandwidth $\sigma$. Used in kernel methods (SVMs, spectral clustering).
   - Falls off faster than reciprocal — more aggressive penalty for distant points.

3. **Normalized by maximum**: $sim = 1 - d(A,B) / d_{max}$
   - Where $d_{max}$ is the maximum observed distance. Maps to $[0, 1]$ exactly.
   - But $d_{max}$ is sample-dependent, so similarities aren't comparable across datasets.

4. **Negative distance** (the proximity convention used in the bilateral analysis): $sim = -d(A, B)$
   - Not bounded, but monotonically inverse to distance — fine if you only need a relative ranking, e.g., as a regressor in a fixed-effects model where levels don't matter.
   - This is exactly what `size_proximity = -abs(...)` does in the project.

### Why Euclidean Is Often Avoided for Compositional Data

- **Treats joint zeros as agreement**: two firms with zero clauses in 100 different categories look "close" even if they share nothing.
- **Sensitive to scale**: doubling all counts changes distance even though the composition is identical.
- **Penalizes large categories disproportionately**: a difference of 5 in a clause that ranges 0–1000 dominates over a difference of 1 in a clause that ranges 0–2.

That's why Bray-Curtis, cosine, and Jaccard are preferred for compositional/sparse data. Euclidean similarity is more natural when variables are already on comparable continuous scales (e.g., standardized log-employment, log-wage), which is why the `*_proximity` measures use it for size/wage but not for clause counts.

### Practical Takeaway

If a Euclidean-based similarity in $[0, 1]$ is needed, the reciprocal $1/(1+d)$ is the simplest choice. For clause-count vectors specifically, Bray-Curtis (or Ruzicka) is the better tool.

---

## Jaccard Similarity

Jaccard is the **binary cousin** of Bray-Curtis — it cares only about *which* categories are present, not *how much* of each.

### Formula

For two sets $A$ and $B$ (or binary indicator vectors):

$$J(A, B) = \frac{|A \cap B|}{|A \cup B|} = \frac{\text{shared categories}}{\text{categories in either}}$$

The dissimilarity version is $1 - J$.

### Intuition

Two CBAs share clause types $\{1, 3, 5, 7\}$ and $\{1, 3, 8\}$. Intersection has 2 elements ($\{1, 3\}$), union has 5 ($\{1, 3, 5, 7, 8\}$), so $J = 2/5 = 0.4$. The numerator counts agreements, the denominator counts everything that *could* have been an agreement. Joint zeros are excluded from both — same logic as Bray-Curtis.

### Key Properties

- **Bounded [0, 1]**: 1 if identical, 0 if disjoint.
- **Ignores joint absences**: same as Bray-Curtis. Co-absent rare clauses don't inflate similarity.
- **Insensitive to magnitude when binary**: a CBA with one mention of a clause and one with twenty mentions are "the same" if you only encode presence. This is the main reason to switch to Bray-Curtis (or Ruzicka) when frequencies matter.
- **Metric**: $1 - J$ satisfies the triangle inequality (Bray-Curtis dissimilarity does *not*, which can matter for clustering).

### When to Use It

- **Categorical/binary data**: clause types coded as present/absent, industry overlap, geographic overlap of operating municipalities.
- **Sparse, high-dimensional sets**: text n-grams, bag-of-words. Standard for near-duplicate detection (MinHash, LSH).
- **When magnitude is misleading or unreliable**: e.g., if clause counts are noisy parser estimates but presence is robust.

### When *Not* to Use It

- **When intensity matters**: a CBA mentioning "wages" once vs. negotiating wage scales across 12 occupations are not equally similar to a third CBA. Use Bray-Curtis or Ruzicka.
- **When data is dense**: most categories present in everything → Jaccard saturates near 1 and loses discriminating power.

---

## Ruzicka Similarity (Weighted Jaccard)

Ruzicka generalizes Jaccard to non-negative count/weight vectors. **The CBA similarity analysis is switching from binary Jaccard to Ruzicka** so that clause-count intensity (not just presence) drives the measure.

### Formula

$$R(A, B) = \frac{\sum_i \min(A_i, B_i)}{\sum_i \max(A_i, B_i)}$$

### Intuition

Same numerator as Bray-Curtis (the shared portion across categories), but the denominator is the *union* of the two bundles rather than the average. Every unit in either bundle that isn't matched is a full penalty — making Ruzicka stricter than Bray-Curtis.

### Relationship to Other Measures

- **Reduces to Jaccard** when $A$ and $B$ are binary indicator vectors.
- **Sister of Bray-Curtis**: same numerator $\sum \min$, but Bray-Curtis divides by $\frac{1}{2}(|A| + |B|)$ (average) while Ruzicka divides by $\sum \max$ (union).
- **Always**: $R \leq BC_{sim}$ for the same vectors.
- **$1 - R$ is a metric** (satisfies triangle inequality), unlike $1 - BC_{sim}$ — useful for clustering.

### Comparison Table

| Measure | Numerator | Denominator | Sensitive to magnitude? | Joint zeros? | Metric? |
|---|---|---|---|---|---|
| **Jaccard (binary)** | shared types | union of types | No | Ignored | Yes |
| **Ruzicka (weighted Jaccard)** | $\sum \min$ | $\sum \max$ | Yes (strict) | Ignored | Yes |
| **Bray-Curtis** | $2 \sum \min$ | $\sum A + \sum B$ | Yes (lenient) | Ignored | No |
| **Total variation** | $\sum \|\tilde A - \tilde B\|$ on shares | $2$ (fixed) | No (compositional only) | Ignored | Yes |
| **Cosine** | $A \cdot B$ | $\|A\| \|B\|$ | No (angle only) | Counted as 0 contribution | No |
| **Euclidean (reciprocal)** | — | $1 + \|A - B\|_2$ | Yes | Counted as agreement | No |

### Why Ruzicka Over Jaccard for the CBA Analysis

- **Uses clause-count intensity**: a CBA that bargains a topic heavily is differentiated from one that mentions it once. Binary Jaccard treats them the same.
- **Drops dense-data saturation**: when most CBAs cover most clause types (high density), binary Jaccard collapses near 1. Ruzicka uses counts to keep discriminating.
- **Preserves the "shared topics" intuition**: still ignores joint absences, still bounded $[0, 1]$, and still a proper metric (unlike Bray-Curtis).
- **Reports cleanly alongside Bray-Curtis**: same numerator, different denominator, so any divergence is informative about whether penalties on size mismatches matter.
