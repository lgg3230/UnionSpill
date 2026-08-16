# occ4 Layer Spillover: Diagnostic Notes

**Date:** 2026-04-23

---

## Finding

The within-firm spillover specification for the **occ4 (occupation) layer** shows a **negative wage effect**: layers with higher connectivity to treated firms experience *lower* wage growth relative to less-connected layers in the same firm-year. This is the opposite of the pattern observed for education (edu2), gender, and race layers, which show either positive or null wage effects.

### Coefficient comparison: occ4 main specs

| Spec | Log wage (Post) | SE | Log emp (Post) | SE |
|------|----------------|----|---------------|----|
| (1) Within-firm FE (with layer×year FE) | −0.0053*** | (0.0021) | +0.0069** | (0.0034) |
| (2) Cross-firm FE (with layer×year FE) | −0.0048*** | (0.0017) | +0.0080** | (0.0034) |
| (1) Within-firm FE (without layer×year FE) | −0.0037* | (0.0022) | +0.0060* | (0.0035) |
| (2) Cross-firm FE (without layer×year FE) | −0.0034* | (0.0018) | +0.0074** | (0.0034) |

Removing `layer_id_num × year` FE attenuates the magnitude and significance of the negative wage coefficient but does not flip its sign. The employment effect is positive and survives both specs.

Pre-trend F-test p-value on wages: **0.121** (marginal concern — some pre-existing differential).

### Comparison with edu2/gender/race (within-firm spec)

| Layer | Log wage (Post) | Log emp (Post) |
|-------|----------------|---------------|
| edu2 | −0.0041 | −0.0200** |
| gender | −0.0006 | −0.0001 |
| race | −0.0028 | +0.0223*** |
| **occ4** | **−0.0053*** | **+0.0069** |

---

## Why the occ4 within-firm spec may be problematic

Within-firm identification compares **occupation layers within the same firm-year cell**. The estimator answers: "conditional on the firm and year, do higher-connectivity occupation layers do better?"

For occ4, the four layers are:

| Layer | Connectivity (mean) | Wage level |
|-------|--------------------|-----------| 
| Managers (1_mgr) | 0.0215 (highest) | Highest |
| High-skill (23_high) | 0.0193 | High |
| Bur. lower (4_bur) | 0.0117 | Medium |
| Low-skill (5p_low) | 0.0116 (lowest) | Lowest |

**The problem**: connectivity and wage level are nearly co-linear across occupation categories — managers have both the highest connectivity *and* the highest wages. Within a firm-year, the estimator may be picking up a differential *level* effect that was always present (managers earn more and are more connected) rather than a genuine post-reform spillover through the occupation channel.

For edu2/gender/race, the same confound exists but is less severe because:
- Within-firm wage differences across education or gender are smaller in relative terms
- Connectivity rankings across those layers are not as strongly determined by the hierarchy of the layer definition itself

---

## Three diagnostic checks to run

### Check 1 — Inspect event study graphs (already generated)

Files: `Graphs/layer_connectivity/es_lr_remdezr_layer_firm_spill_occ4_*.pdf`

Look for: does the negative coefficient emerge post-2012, or is it already present in 2009–2011? A pre-existing downward slope would confirm the confound hypothesis (not a causal effect of the reform).

### Check 2 — Within-firm connectivity rank by occupation

For each firm, rank the four occupation layers by their `layer_treat_pw_n`. Check what fraction of firms have managers as the highest-connectivity layer. If managers are consistently ranked first, the within-firm variation is essentially a manager-vs-others comparison that tracks the occupational wage hierarchy.

```python
# Pseudocode
df_conn = pd.read_stata("Data/layer_connectivity/final_measures/firm_layer_connectivity_occ4.dta")
wide = df_conn.pivot(index="identificad", columns="layer_id", values="layer_treat_pw_n")
rank_1_mgr = (wide.rank(axis=1, ascending=False)["1_mgr"] == 1).mean()
```

### Check 3 — Univariate cross-firm spec per occupation layer

Instead of pooling all four layers, run a separate cross-firm regression for each layer (e.g., restrict to `layer_id == "1_mgr"` only). This eliminates the within-firm comparison and identifies purely from cross-firm variation in connectivity. If the negative sign disappears or flips to positive, it is the within-firm cross-occupation comparison that drives the result, not a genuine negative wage spillover.

Expected result: managers (highest connectivity) should show a positive cross-firm effect if the spillover channel is real. A positive effect here alongside a negative within-firm effect would confirm that the within-firm spec is confounded by the occupational wage hierarchy.

---

## Tentative interpretation

The negative within-firm wage coefficient for occ4 is likely **not a genuine negative spillover effect**. It probably reflects that:

1. Managers are most connected to treated (high-wage) firms and also have the highest wages within any firm.
2. After Súmula 277, treated firms increase wages — their workers (disproportionately managers) flow back with higher reservation wages, but the sending firm's *relative* structure shifts: non-managerial layers may catch up more (positive employment effect) while the manager layer's *relative* position inside the firm is compressed.
3. Alternatively, the level confound described above makes the within-firm estimator unreliable for occupation layers.

**Recommendation**: Do not include the occ4 spillover as a main result. Use it only as a descriptive or robustness check, framed around the employment margin (which is positive and has a cleaner identification story).
