# Missing Values in Worker Transition Matrices

**Date investigated:** 2026-02-19
**Relevant files:** `05_yearly_employers.do`, `connectivity_full_lagos.m`, `totalflows_wide_2007_2011.csv`

## Summary

The file `totalflows_wide_2007_2011.csv` (16,470 rows) contains NaN values in year-pair columns for firms absent from a given year pair's transition matrix. The NaN values are preserved in the CSV (not replaced with 0), and the Stata do-files use missing-friendly averaging to handle them correctly. This document explains why NaN values exist and why the missing-friendly approach is preferred.

## Missingness pattern

| Year pair | Missing firms | Mechanism |
|-----------|--------------|-----------|
| 2007-2008 | 724 | Firm not yet in RAIS (entered after 2007) |
| 2008-2009 | 103 | Firm not yet in RAIS (entered after 2008) |
| 2009-2010 | 27 | Workforce disconnect or worker deduplication (see below) |
| 2010-2011 | 35 | Workforce disconnect or worker deduplication (see below) |

The 07-08 and 08-09 cases are straightforward: the firm didn't exist in RAIS in those years and trivially had zero flows. The 09-10 and 10-11 cases are more interesting because these firms ARE in the balanced panel (positive employment 2009-2014).

## How NaN values are produced

The pipeline works as follows:

1. **`05_yearly_employers.do`** loads raw RAIS for each year 2007-2011, filters to December-active workers with tenure > 1 month (`empem3112 * (tempempr > 1)`), then selects one spell per worker-firm (highest hours, then highest wage, then random) and one employer per worker across all firms (longest tenure, then highest wage, then random). Output: `yearly_employers_YYYY.dta`.

2. **`05_yearly_employers.do`** merges consecutive-year files on PIS, keeping only `_merge == 3` (workers present in both years). Output: `employers_YYYY_YYYY.csv`.

3. **`connectivity_full_lagos.m`** builds a transition matrix for each year pair from the employers file. `unique_estabs` is constructed only from firms whose workers appear in that pair's file (line 40). The adjacency matrix diagonal is zeroed out (line 80: self-loops removed). Output: one table per year pair.

4. **`connectivity_full_lagos.m`** merges the 4 year-pair tables via `outerjoin` with `'Type','full'` (line 155). Firms absent from a year pair get NaN. Output: `totalflows_wide_2007_2011.csv`.

A firm is absent from a year pair (and gets NaN) when **none of its workers appear in the employers file for that pair**. This happens through two distinct mechanisms.

## Mechanism 1: Complete workforce disconnect (~80% of edge cases)

The firm's qualifying workers in year *t* do not appear **anywhere** in year *t+1*'s RAIS. Not at a different firm, not at the same firm — they are completely absent from the formal labor market in the next year.

**Profile:** Very small firms (median 1-2 qualifying employees). Workers left formal employment between consecutive December snapshots (retirement, informality, emigration, death, etc.). Losing 1-2 workers means total disconnection from the transition matrix.

**Confirmed by:** Loading `rais_lagos_YYYY.dta` and checking whether PIS identifiers from year *t* appear in year *t+1*. For ~80% of missing firms, zero workers bridge.

## Mechanism 2: Worker deduplication (~20% of edge cases)

The firm's workers DO appear in year *t+1*'s RAIS, but:

- **Self-loops:** The only bridging worker stayed at the **same firm** in both years. In the `_merge == 3` step, this worker IS included. But in the MATLAB adjacency matrix, self-loops are zeroed (`M_estabs(diagonal) = 0`). However, the firm should still appear in `unique_estabs` with `totalflows = 0` — so this alone doesn't explain NaN. The missing piece is the next sub-mechanism:

- **Sibling establishment assignment:** Workers often have concurrent employment spells at multiple establishments of the same parent company. The rank_emp selection in `05_yearly_employers.do` assigns each worker to ONE employer per year. If a worker's "best" spell (longest tenure, highest wage) is at a sibling establishment rather than the firm in question, that worker is assigned elsewhere. The firm ends up with zero workers in `yearly_employers_YYYY.dta` and is absent from the transition file entirely.

**Example:** Firm `05321920000125` has 8 qualifying workers in `rais_lagos_2009`, and 7 of them also appear in 2010. But all 7 simultaneously held spells at sibling establishments (`04416923000180`, `04416935000104`, `05321987000160`). After rank_emp selection, these workers were assigned to sibling firms, leaving `05321920000125` absent from `yearly_employers_2009`.

## Why NaN -> 0 is correct

In **all cases**, the firm had zero external worker flows for that year pair:

- **Mechanism 1:** No workers bridged at all. Zero flows, trivially.
- **Mechanism 2:** After worker deduplication, the firm had zero workers assigned to it. Zero flows from/to this firm by construction.
- **07-08 / 08-09:** Firm didn't exist yet. Zero flows, trivially.

## Fix applied

1. **Source CSV:** `totalflows_wide_2007_2011.csv` — NaN values preserved (not replaced with 0). A backup copy exists as `totalflows_wide_2007_2011 copy.csv`.
2. **Stata do-files:** `Main_Results_robustness.do`, `Main_Results_robustness_ftest.do`, `Run_last4_robustness.do` — use missing-friendly averaging (sum non-missing values, divide by count of non-missing) following the pattern in `05_yearly_employers.do` lines 213-228. Firms with ALL year pairs missing get `.` for the average.
3. **Bin-level safety net:** `replace ...4 = 0 if missing(...)` retained after `egen cut` for the binned control variables. Firms with missing averages get bin 0 (reference category).

## Implications for future work

When constructing transition matrices or connectivity measures from worker-level RAIS data:

1. **Always expect firms with zero external flows.** Small firms (1-5 employees) frequently have complete workforce turnover between December snapshots. A full outer join across year pairs will produce NaN for these firms.

2. **Worker deduplication creates systematic zeros.** The one-employer-per-worker selection means firms sharing workers with sibling establishments may have zero assigned workers after deduplication. This is more common among establishments of large multi-establishment firms.

3. **Use missing-friendly averaging.** Simple division (e.g., `(totalflows_09_10 + totalflows_10_11) / 2`) propagates NaN to the average, causing sample loss. Instead, sum non-missing values and divide by the count of non-missing pairs. This preserves the distinction between "firm absent from year pair" (NaN) and "firm present with zero flows" (0).

4. **The `rais_lagos_YYYY.dta` files are pre-deduplication.** They contain all qualifying spells, including multiple spells per worker. They are NOT the same as the `yearly_employers_YYYY.dta` files, which have one employer per worker. When checking worker flows, use the yearly_employers files (or re-derive from rais_lagos with the full rank_emp logic).

5. **The local `RAIS_YYYY.dta` files are 1% debug samples** (from `sample 1` on line 20 of `011_rais_to_firm.do`). Do not use them for verification. Use `rais_lagos_YYYY.dta` for the Lagos-subset worker data, or run on the Kellogg cluster for full RAIS.
