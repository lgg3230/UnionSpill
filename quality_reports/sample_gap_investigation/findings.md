# RAIS–CBA sample reconstruction gap — findings, 2026-09-22

**Update: the membership reconstruction is recovered.** Pooling upstream selected-worker municipality votes over **2007–2016**, with Stata's `minmode` tie handling, produces exactly **16,472 establishments, zero missing and zero additional**. All 12 checked CBA/date/treatment/sample fields match across all 131,776 baseline establishment-years. See [the follow-up findings](semantics_recovery/recovery_findings.md), [complete-set validation](semantics_recovery/wide_membership_validation.json), and [all 48 case explanations](semantics_recovery/case_recovery_table.md).

The sections below preserve the earlier D1–D3 investigation. Their earlier missing-artifact blocker is superseded for geographic-rule and membership recovery; the actual October execution log remains unavailable. Production code, the published-panel pin, and protected baselines were not changed.

## What was established

**[Author-confirmed]** `identificad` identifies establishments; its first eight digits, `identificad_8`, identify the CNPJ root. All membership comparisons below count establishments.

**[Artifact inspected]** The intended comparison is reproducible: **16,472 baseline versus 16,462 modal establishments; 29 missing, 19 additional, 16,443 common**. `full_membership_comparison.csv` scores against the complete baseline; `reconciliation.csv` contains one row for each of the 48 disagreements, including source status and unavailable historical fields. IDs must be read as strings to preserve leading zeroes.

**[Artifact inspected] Important stale-comparison finding:** the live `Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta` is the later 2009-carried-forward variant, with **16,476 establishments, 84 missing and 88 additional**. Its embedded save timestamp is 2026-09-11 18:04. The currently surviving CBA intermediates and annual dictionaries also date to that run. They must not be labeled the 16,462-establishment modal build. We used the protected `final_modal_firms.csv` to recover the intended complete modal membership set, then recreated its case-level diagnostic records in isolation. D1 reproduces all 48 expected memberships exactly.

## Newly recovered historical sample evidence

**[Artifact inspected + full-baseline comparison]** `Data/RAIS_aux/lagos_sample_merge_worker.dta` has an embedded save timestamp of **2025-08-15** and contains 17,826 establishments before balance restriction. Applying the current RAIS presence/balance flags gives **exactly the preserved modal set of 16,462**, with **zero symmetric difference** between them. It therefore also has the same 29 missing and 19 additional IDs relative to the published panel. The balance flags are a current input: this is a mixed-vintage comparison, not an observed August balanced export. The archived producer `archive/Programs/rais_worker_sample.do` selects `lagos_sample_avg==1` from the full sample flag file and strips the added leading ID prefix; it does not impose balance.

**[Artifact inspected]** Three older May 6, 2025 `balpan_{file,no,start}.dta` files contain all 48 cases. Their stored sample flags exclude all 29 missing IDs and include all 19 additional IDs. These are older alternative date specifications, not October flags, and must not be substituted for the unavailable October intermediates. The August and May files' hashes are checked against the preserved pre-rerun manifest in `older_input_fingerprints.json`.

**[Inference]** The reconstructed membership is consistent with a surviving pre-publication sample lineage. The gap is not evidence that the 2026 reconstruction introduced these 48 memberships for the first time. It separates earlier sample artifacts from the October published panel; exact producing code and dictionary provenance remain unresolved.

## Why the 29 establishments disappear

**[Controlled reconstruction D1]** All 29 pass positive employment and the 2009–2016 balanced-panel condition. The date requirements explain all 29 exclusions:

| Failed conditions | Establishments |
|---|---:|
| Pre-period only | 11 |
| Post-period only | 1 |
| Both pre- and post-period | 17 |

Of the 28 pre-period failures, 27 have no synthetic average filing date in 2009. `55450456000498` has a 2009 date but no qualifying second date at least one day later through 2012-01-01. These are date flags computed after establishment–union–year CBA aggregation, not simple counts of distinct raw contracts.

The formerly unexplained establishment is **`01029312000190`**. It passes `cba_pre2012_avg` but fails **`cba_post2012_avg`**. The prior `Logs/verification/churn.log` already reported 18 post-period failures but did not identify this establishment.

**[Artifact inspected + controlled reconstruction]** Its published panel selects union `46.058.160/0001-92`, with synthetic filing dates 2009-10-22, 2011-11-18, and 2013-07-03; the last agreement ends 2014-04-30. Modal matching uses municipality **410180**, selects union `81.398.794/0001-95`, and retains only earlier agreements, with the latest end date 2012-05-31. Contract **`2013_031457`**, union `46.058.160/0001-92`, covers municipality **353650**, is filed 2013-07-03, and ends 2014-04-30. It therefore fails the modal geographic join. This contract is an observed current source record; its correspondence to the published synthetic date/union is supported, but the actual historical join key is unavailable. See `priority_case_chronology.csv` and `cba_join_outcomes.csv`.

This establishment is also the one with within-year municipality multiplicity among the missing cases in 2011: **six municipalities in the preserved worker panel**. Over 2009–2016, its raw collapsed annual rows retain only 353650 and 354990, while worker records also contain 410180. There is no contradiction: a first-nonmissing annual value is not a full worker municipality history. The worker panel supplements, rather than replaces, the protected annual raw backup. The old 0.03% statistic in `withinyear.log` concerns **798 / 3,100,515 establishments in 2011**, not a pooled all-year frequency.

## Controlled recovery using the published municipality field (D3)

**[Controlled comparison]** Every missing establishment has one constant observed municipality in the published panel, and all 29 differ from the current worker-weighted mode. Substituting that **observed published output field** as the matching key, holding the D1 inputs and code fixed, restores **all 29** to the sample.

The check goes beyond selected failures: across **278 published establishments in the 42 roots and 2,717 establishment–years**, D3 reproduces the published union, average/minimum/maximum filing dates, start/end dates, treatment, pre/post eligibility, sample and balance flags **exactly, including missingness**. See `published_control_summary.json`; the difference table is empty. This is strong evidence that the missing establishments' CBA divergence can be explained by their municipality assignment, without changing CBA coverage or aggregation code. It does not establish that the output field was the historical input key or recover the rule that produced it. Additional establishments lack this published field, so D3 is not a complete candidate procedure or full-baseline reconstruction.

Two cases, `03380763000101` and `29167442000109`, have their published municipality only in **2007**, not in any protected annual row during 2009–2016. All 29 missing cases' published municipalities match the first available raw annual value since 2007. However, this apparent rule **fails for 46 of 278 published root peers**. It was rejected as a sufficient historical explanation before any full candidate run. No unsupported early-year rule search was performed.

## Why the 19 additional establishments enter — and what remains unknown

**[Controlled reconstruction D1]** Every additional establishment passes all rebuilt conditions. Each has linked CBA records, dates, selected-union information, and positive-employment/balance flags in the detail files. **All 19 are entirely absent from the filtered published panel.** Their historical pre/post flags, unions, and join keys are therefore unavailable; absence cannot be translated into a particular historical date failure. Those cells are blank and explicitly labeled in `reconciliation.csv`.

**[Controlled comparison D2]** Holding the cleaned CBA source, RAIS records, 1020 aggregation, and 1030 filters fixed, changing only annual matching municipality/state from modal to raw-per-year:

- makes **16 of 29 missing** establishments eligible;
- makes **17 of 19 additional** establishments ineligible;
- leaves **13 missing and 2 additional** membership discrepancies unchanged.

Thus municipality-dependent linkage has a demonstrated causal effect on membership for **33 of these 48 establishments**. It does not establish which keys the historical build used. The other 15 are individually labeled for this D2 contrast; D3 subsequently explains all 13 missing members of that group using their observed published municipality. “Unchanged” refers to final membership; intermediate unions or date flags can still change. For the priority case, raw matching restores the later union/agreement but loses the 2009 condition, so final inclusion remains zero.

The 15 unchanged IDs are:

`00233342000151`, `01029312000190`, `03380763000101`, `04060243000176`, `04270071000165`, `04861051000169`, `05508838000619`, `07831987000135`, `08370059000183`, `10249238000109`, `29167442000109`, `44215952000106`, `45024551000204`, `55450456000498`, `61079232000252`.

D2 is a causal diagnostic, **not a proposed replacement procedure or a full-sample score**. The prior raw rule's full-baseline error of 153 remains an inherited result. No new rule search or full-baseline candidate reconstruction was run.

**[Artifact inspected]** Raw annual histories confirm movers in 27/29 missing and 19/19 additional cases; establishment-weighted mean employment over 2009–2016 is 187.98 and 71.39 respectively. Missing cases span 28 roots and additional cases 15, with `97191902` shared. Root peers were retained throughout D1/D2; all establishments within the 42 roots were extracted before any grouping. All 48 membership outcomes, including the shared-root cases, were individually checked. D3 additionally checks the published CBA histories of root peers.

## Where the divergence can be located

**[Artifact inspected]** Preserved and rebuilt exploded firm-CBA inputs agree on all seven substantive columns for the 42 roots: 144,449 rows and 128,380 distinct records on each side, with zero distinct-record differences. Different binary hashes therefore do not establish different relevant coverage content. See `exploded_comparison.json`; the preserved file's hash matches the pre-rerun manifest.

**[Code inspected]** The actual path is:

1. **1010:** worker–establishment rows for 2009–2016 supply establishment-level municipality modes, weighted by retained worker-year rows. `mode(...), minmode` excludes missing values and selects the smallest tied numeric municipality. This is not a mode of eight annual establishment observations. The complete-population dictionary was reused, so subset selection did not alter modes.
2. **1011:** merges employer associations by full establishment ID and writes annual `unique_firms`. Using-only association rows lack a CNPJ root/municipality and cannot join the nonempty roots in this diagnostic. Sectoral CBA code is inactive.
3. **1020:** municipal coverage joins on `(identificad_8, municipio)`, state coverage on `(identificad_8, state)`, national coverage on `identificad_8`, using the CBA's **start_year** to select the annual dictionary. It deduplicates, computes the main union per establishment, expands active years, and constructs synthetic establishment–union–year dates. These operations can change eligibility even where some raw contracts match.
4. **1030:** merges by establishment and active year and computes date flags across establishment records. Positive employment covers 2009–2014; balance covers 2009–2016. The second pre-period date must be at least earliest-2009-date + 1 and no later than **2012-01-01 inclusive**. Post-period requires nonmissing average filing date >= 2012-01-01 and end date >= 2012-12-31. Literal Stata missing-value ordering is preserved by running the original code; an independent calculation agrees for all available case panels.
5. **1040:** adds connectivity, retains using-only RAIS panel rows, and restricts its test output to `lagos_sample_avg==1`; no later balance/date restriction is needed for this membership definition. Prior 1030 modal logs and the post-1040 export each report 16,462. The preserved full modal list supplies set-level scoring; the old temporary pre/post lists needed to newly verify their exact historical set equality do not survive.

**Earliest supported attribution:** the eligibility divergence is already present in the **CBA information feeding 1030**. D2 isolates a municipality/state join-key effect through **1020** for 33 cases; D3 restores all 29 losses and reproduces all inspected published CBA fields for 278 establishments using their observed published municipalities. **An exact first historical divergence at 1010 or 1011 has not been observed.** Matching exploded coverage agrees, but the actual published annual dictionaries, joined CBA outputs, and full historical date/union intermediates are missing. The unresolved interval includes historical establishment-dictionary construction and CBA attribute/aggregation choices through 1020. Agreement in coverage alone does not prove agreement in all historical CBA attributes or code.

## Reference and run audit

**[Artifact inspected]** Repository revision: `f613ea6084a57d91236cfa98cc778e8d6c1f771c`. Relevant production scripts have no working-tree diff. Preexisting `.gitignore` modifications and deleted pipeline documents were left untouched. Resolved root: `/gpfs/kellogg/proj/lgg3230/UnionSpill`.

- Published preserved panel and pinned live copy both have MD5 `232e8af202087211d276af84bb22cd6c`.
- The reported 2025-10-06 date is both the filesystem modification date and embedded Stata save timestamp (06:53). This supports its vintage, but is not an independently documented production event. First git commit has author date 2025-10-15; no code-to-binary producer provenance follows merely from that ordering.
- Baseline worker parquet contains 19,598,473 worker rows. Membership extraction applies **no additional row restriction**: take distinct `identificad` over its actual 2009–2016 window. Its 131,776 unique establishment–year pairs equal the published panel restricted to `lagos_sample_avg==1 & in_balanced_panel==1 & inrange(year,2009,2016)`. There is **no `treat_ultra==0` restriction** in the 16,472 count; this is broader than the spillover-only sample.
- Both inspected establishment panels have unique `(identificad, year)` keys. The 162,472 common rows consist of 15,106 in 2007, 15,822 in 2008, and 16,443 in each year 2009–2016. The earlier row count is a longer-window comparison, not duplicate establishment-years.
- `Programs/verification/run_variant_to_1030.do` is absent. Its echoed source survives in logs and used shared production output paths. It was not rerun. All new outputs are under `Data/sample_gap_investigation/` and this report directory. The new 1020 suffix begins after the coverage producer; only explicitly read-only inputs are symlinked. Stata logs terminate normally with no `r(...)` errors.

## Exact blocker and next action

**[Artifact inspected / search scope]** The September 2025 candidate dictionaries in `Data_may2025/rais_aux_sep24/` are real, with an embedded September 18 timestamp for the 2009 file. Their source and downstream use are unestablished. They contain records for only 39/48 disputed IDs and completely omit **six published missing establishments** across all eight years. They cannot alone supply the complete annual matching path required to explain the published panel. The old `Data_may2025/{rais_aux,rais_firm,CBA,emp_assoc}` reconstruction outputs have been removed; these candidate dictionaries are a different tree.

Needed evidence, in order:

1. **The actual annual `unique_estab_{2009..2016}.dta` / `unique_firms_{2009..2016}.dta` consumed by the October 2025 build, together with provenance**, or the corresponding pooled dictionary if that build used one. These would test historical geographic matching directly, including the additional IDs.
2. **The historical `cba_estab_firm.dta`, `collapsed_cba_firm_updated.dta`, or unfiltered `cba_rais_firm_2007_2016.dta` / flows panel**, to observe lost historical dates, main unions, and exclusion flags for the 19 additional establishments and identify the historical reason for excluding the two additional cases unchanged in D2 (`04060243000176`, `04861051000169`). All 29 missing cases now have a controlled geographic explanation from D3.
3. The producing code/input versions, to distinguish dictionary differences from later CBA cleaning/union selection/synthetic-date differences and establish historical provenance.

Searches covered accessible project trees, tracked code and history, archives, deletion inventories, and surviving logs; see `searches.md`. Apparent archived full intermediates are broken symlinks, not historical copies. The pooled `rais_unique_estab_09_16.dta` is recorded as deleted. The author's Mac is not mounted and no reachable Mac endpoint is documented. Recovery should target that copy or backups, rather than testing unsupported municipality rules.

## Separate analysis-variable track

**[Artifact-inspected log; causal attribution unresolved]** `Logs/verification/vartest.log` verifies the prior 162,472-row comparison's definition and tolerance. It is not a comparison changing A7 alone. No claim is made that A7 explains every flow, exposure, or wage difference, nor that current deterministic selection reproduces historical selected spells. No regressions or A7 rebuilds were run.

## Reproducibility and details

See `run_manifest.json`, `experiments.md`, and `README.md` for commands and limits. Relevant detail files are `raw_municipality_history.csv`, `modal_dictionary.csv`, `available_dictionary_records.csv`, `baseline_worker_municipality_counts.csv`, the three case panels, both matched-CBA tables, and `cba_join_outcomes.csv` (248,953 candidate establishment–coverage rows with dates and explicit modal/raw join outcomes). Historical observations and reconstructed values are labeled separately. No reconstructed join key is presented as an observed historical key.

## Additional searches after the initial reconciliation

The broadened wildcard search for establishment/firm dictionaries, collapsed CBA outputs, and program archives is recorded in `extended_artifact_search.txt`. It found no additional complete historical dictionary. The April 23, 2025 `Data/CBA/collapsed_cba_firm.dta` contains 46/48 cases, including all 19 additions. Its schema and archived producer differ materially: the old producer uses `merge m:m`, aggregates at establishment–year rather than establishment–union–year, and uses another treatment threshold. It is not the October main-union intermediate and was not passed off as such.

The preserved 60 GB `worker_estab_all_years.dta` is a September 7, 2026 reconstruction, not an October 2025 dictionary. The `worker_estab_BASELINE_feb2026.dta` is a September 14 conversion of the filtered baseline worker sample, so it cannot supply the 19 additional IDs. A November 2025 `worker_estab_all_years.parquet` is a one-million-row excerpt, ends at establishment `00005275000118`, and contains none of the 48 cases. Historical full-RAIS residual-worker parquet files do not contain municipality. These checks close potentially misleading surviving-artifact leads without recomputing unsupported rules.
