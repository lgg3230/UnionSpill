# Layer connectivity — dataset construction

Builds `Data/layer_connectivity/`, which the within-firm estimators
`Programs/analysis/layer_connectivity/07_within_firm/3121` and `3131` consume.
Restored from `archive/` on 2026-08-16: the estimators were in the chain while
their inputs were not, so the package could not be replicated from raw data.

Run in numeric order (2060 -> 2078). `layer_config.py` holds the shared paths and the layer
definitions (`LAYER_DEFS`) and is imported by 19 of the 19 scripts, so it must stay
beside them.

| step | does |
|---|---|
| `2060_cache_rais.py` | caches the raw RAIS columns the layer build needs |
| `2061_build_transitions.py` | worker transitions by layer |
| `2062`/`2065`/`2066_remap_*.py` | 2-bin recuts (edu2, occ2, occ2c) off `01a`'s output |
| `2063_totalflows_layer.py` | total flows per layer |
| `2064_build_demog_transitions.py` | demographic layers |
| `2067`/`2068_aggregate*.py` | aggregate transitions to the firm-layer level |
| `2069`/`2070_compute_n*.py` | normalised connectivity measures |
| `2071_validate.py`, `2072_decompose.py` | checks |
| `2073_compare_layers.py` | cross-layer comparison |
| `2074`-`2078_prep_*outcomes*.py` | firm-layer outcome panels -> `firm_layer_outcomes_{layer}.dta` |

Input: `worker_panel_lagos.parquet`. Output base: `Data/layer_connectivity/`.

## Known gap

`2061_build_transitions.py` reads `worker_panel_lagos.parquet`. **No script in this
repository writes that file.** It is a protected input, like the fullrais panel the
mincer branch needs. Conceptually it is `lagos_sample_workers.dta` (2010's output) in
parquet form, so closing the gap is likely a small export step rather than a
reconstruction, but it does not exist today.

**Do not use occupation as a layer** — employers can change occupation codes, so it
is a choice variable, not a fixed worker attribute.
