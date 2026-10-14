# Portability work brief — run the chain from `0000_master.do` on any machine

**Written 2026-09-14, on the Mac, against `f613ea6`.** To be executed **on the Kellogg
cluster**, then pushed; the Mac pulls afterwards.

Findings below come from a static audit of `Programs/` at `f613ea6` ("Repair the chain so
it runs end to end from 0000_master.do"). Every defect listed was verified to still be
open at that commit. Line numbers are as of `f613ea6`.

---

## Goal

Make `Programs/0000_master.do` run the full chain with every tier flag set to 1, on **any**
machine with Stata 17, Python 3.12+ and MATLAB — from a **single shared version of the
code** on both the cluster and the Mac.

## Preconditions the pipeline may assume

Document these at the top of `0000_master.do`:

- Raw RAIS present in the expected folder structure.
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta` present.
- `Data/RAIS_aux/union_treat_exp_sep24.dta` present.

## Explicitly out of scope

Restoring producers for those two `.dta` files. Neither is built by any script in
`Programs/`:

- `lagos_sample_sep24.dta` — nothing writes it. `1040_yearly_employers.do:617` writes a
  `lagos_sample_sep24_test.dta` that *may* be the same construction, but that was never
  verified. **Leave the `_test` suffix alone.** Tier B reads the non-`_test` name at
  `2010_merge_lagos_worker.do:14` and `2020_get_wage_pctiles.do:358`, via
  `$lagos_firm_panel` which master sets in its tier-B block.
- `union_treat_exp_sep24.dta` — producer exists only as `archive/Programs/union_treat_exp.do`,
  not wired into master. `2030_build_pct_unionexp.do:36-42` hard-exits `601` if it is absent.

Both files currently exist on disk, so the chain runs with them in place. They are simply
not reproducible, and closing that is a separate job.

**Do not modify anything under `Data/`.** Several files there are the only copies and have
no producer. The goal is a pipeline that runs, not replaced data.

---

## Cluster environment facts

| Thing | Value |
|---|---|
| Project root | `/kellogg/proj/lgg3230/UnionSpill` |
| Stata 17 | `module load stata/17`, or `/software/Stata/stata17/stata-mp` |
| MATLAB | `/software/matlab/R2020b/bin/matlab` |
| Python 3.12 | `~/.conda/envs/venv_python312/bin/python` |
| System `python3` | **3.6 — too old, do not use** |
| Username | `lgg3230` |

Note: `rand_inference/` scripts use a `/gpfs/kellogg/...` prefix while everything else uses
`/kellogg/...`. Determine which is canonical on the cluster and standardize.

---

## Work items, in order

### 1. Machine-independent path resolution — the backbone, do it first

**61 scripts hardcode a machine path**: 27 `.do`, 29 `.py`, 5 `.m`.

The current portability mechanism is username dispatch — `if "\`c(username)'"=="lgg3230"` vs
`=="luisg"` (`0000_master.do:59-65`). It does not scale and is already rotting: 
`mincer_residuals/2083_mincer_residuals.do:38-40` still points its Mac branch at the retired
`Replication_Mar 2` directory.

Design one root-resolution mechanism and apply it everywhere. **Extend the pattern the repo
already uses** rather than inventing a new one: `1041_connectivity_full_lagos.m:7-10` does
`getenv('UNIONSPILL_AUX')` with a fallback, and `1040_yearly_employers.do:112` passes it
through the shell call. Generalize that to `UNIONSPILL_ROOT`.

- **Stata**: `global root : environment UNIONSPILL_ROOT`, with a documented fallback. Master
  must pass it through to every child process it shells out to.
- **Python**: most tier-D scripts already derive root via `Path(__file__).resolve().parents[N]`.
  Make that the standard; convert the holdouts — `rand_inference/*` (all of them),
  `4130_figure_binscatter.py`, `layers/layer_config.py`, `mincer_residuals/*`,
  `1050_corrected_turnover.py`, `2051`–`2053`.
- **MATLAB**: already env-var driven. Keep; drop the cluster fallback.

Specific defects to fix:

- **(a)** Master's `$main` on the Mac yields a doubled `UnionSpill/UnionSpill/` path:
  `$luis` (line 57) already points at the `UnionSpill` dir, while every subfolder global
  appends `/UnionSpill/Data/...`.
- **(b)** All 13 tier-C wrappers hardcode `/kellogg/proj/lgg3230` and ignore master's globals.
  They are launched as **fresh processes**, so they must still set their own globals —
  keep each standalone-runnable.
- **(c)** `/gpfs/kellogg/...` vs `/kellogg/...` inconsistency (see above).
- **(d)** `$stata_exe` / `$matlab_exe` / `$python_exe` (`0000_master.do:106-108`) are cluster
  absolute paths. Discover them per machine. **Fail loudly** with a clear message when one
  is absent rather than letting `shell` silently no-op. MATLAB in particular is often
  missing — there is none on the Mac, so tier A's connectivity stage cannot run there at all.
- **(e)** `2083_mincer_residuals.do:38-40` — retired `Replication_Mar 2` path.
- **(f)** **Paths with spaces.** `stata-mp -b do "<path>"` fails when the path contains
  spaces — Stata splits the argument regardless of shell quoting, and reports
  `file ... not found  r(601)`. Master's 15 tier-C/D shell-outs pass `$programs/...`, which
  on the Mac under OneDrive contains both `4 - PhD` and `Org_Econ BR`. Every one of those
  steps fails there. Verify the fix against a path containing spaces — a wrapper do-file or
  an equivalent indirection is the known workaround.
- **(g)** **Case sensitivity.** On the Mac the directory is `Data/CBA_rais_firm_level` while
  `$rais_firm` says `CBA_RAIS_firm_level`. Silent on macOS, fatal on Linux. Reconcile, and
  sweep for other case mismatches.

### 2. Make failures non-silent

Every tier-C/D step is `shell cd "$logs" && ...`. **Stata's `shell` does not propagate exit
codes.** A missing `$logs`, a dead estimator, or a Python traceback lets master continue and
still print `0000_master.do finished.`

Add a post-condition check per stage — expected output exists, and is newer than its input —
and abort on failure.

This is a prerequisite, not a nicety: without it item 1 **cannot be verified** on a second
machine, because a broken run and a good run are indistinguishable.

### 3. Replace the tier A side-branch stubs with real execution

`a_layers`, `a_mincer_resid` and `a_rand_inference` (`0000_master.do:187`, `:191`, `:196`)
currently only `di as error` a message telling the user to run them by hand. That is
deliberate, not a bug — but it means ~50 scripts never launch from master.

Make each run its sub-pipeline in numeric order per the directory's `README.md`:

- `sample_construction/layers/` 2060–2078
- `sample_construction/mincer_residuals/` 2080–2086
- `sample_construction/rand_inference/` 2090–2106

Follow the existing `shell cd "$logs" && $python_exe ...` convention.

Their outputs feed tier C: `3121`/`3131` need `Data/layer_connectivity/`, `3111` needs
`mincer_residuals_firm_year_age_fullrais_rb.csv`, `4130` needs the permutation inputs.

### 4. Find or write producers for the two `totalflows` CSVs

**(a) `totalflows_wide_2007_2011.csv`** — read by **14 tier-C estimators**, produced by
nothing. `Programs/TRANSITION_MATRICES_MISSING_VALUES.md:31` attributes it to
`connectivity_full_lagos.m`, but the current `1041_connectivity_full_lagos.m` has exactly
one `writetable` (line 177) and it emits `connectivity_2007_2011.csv`.

Determine whether the wide file is derivable from that output — `1041:132` builds the
`totalflows_%d_%d` columns that end up in it — or whether an older `.m` wrote it directly.
Check `archive/Programs/Old/*.m`. Reproduce it, verify against the on-disk copy, and
**preserve the NaN semantics** that doc describes: NaN, not 0, for firms absent from a year
pair.

**(b) `totalflows_panel_2009_2016.csv`** — read only by `3082_turnover.do:72`. Producer is
`archive/Programs/turnover/011b_totalflows_panel.py`. Restore it into `Programs/` under the
tier-A numbering, wire it into master, verify its output.

### 5. Fix three broken call paths that silently kill their step

- `analysis/main_results/3012_pct_tfpw.do:850` — calls `"$programs/4160_table_pct_latex.py"`;
  the file is at `$programs/analysis/main_results/4160_table_pct_latex.py`. Also uses bare
  `python3` (3.6 on the cluster) — use `$python_exe`.
- `sample_construction/mincer_residuals/2083_mincer_residuals.do:67` — calls
  `"$programs/2082_mincer_export.py"`; the file is at
  `$programs/sample_construction/mincer_residuals/2082_mincer_export.py`.
- `analysis/cba_value/3042_cba_value.do:439` — shells the `.py` with **no interpreter**, and
  the file is mode `644` in git, so this is a permission error. Use `$python_exe`.

Also convert the bare `python3` calls at `analysis/residuals/3112_mincer.do:457` and
`analysis/turnover/3082_turnover.do:562`.

Separately: `1040_yearly_employers.do:106` sets a standalone fallback `$programs` of
`.../Programs/sample_construction`, and line 112 appends `sample_construction/` again —
doubled. Harmless under master (which sets `$programs`), breaks a standalone 1040 run.

### 6. Orphaned generators — decide and record

`analysis/descriptives/4220_table_descriptives.py` and
`analysis/residuals/4230_table_resid_tenure_comparison.py` have **zero callers** anywhere.
Either wire them into master's tier D or mark them clearly as superseded. Do not leave them
ambiguous.

---

## Sync back to the Mac

`Cluster/UnionSpill` is **its own git repo** — not part of the parent `UnionSpillovers` repo
— on `github.com/lgg3230/UnionSpill`, branch `main` tracking `origin/main`. `Programs/` is
tracked. `Data/` is gitignored and moves by rsync separately. **Sync is git; do not rsync
code.**

1. **Before starting**: `git fetch && git status` on the cluster. Item 1 touches 61 files and
   will conflict messily with any uncommitted local edits. Confirm `git remote -v` points at
   the remote above — it has historically pointed at the retired `Replication-Mar-2` repo.
   Consider working on a branch given the size of the change.
2. Make the changes on the cluster. Verify there — the cluster is the **primary** verification
   machine: it has MATLAB, the real data, and the working baseline.
3. Commit and push.
4. Pull on the Mac and re-run the item-2 post-condition checks there.

**The Mac can only partially verify.** It has no MATLAB (no `/Applications/MATLAB*`, nothing
on `PATH`), so tier A's connectivity stage (1041–1045) cannot run there. Mac verification
covers path resolution, the space-in-path fix, and the non-MATLAB stages. Say so explicitly
when reporting; do not report "verified" without naming the machine and the stages covered.

**Hard constraint.** The cluster currently works *because of* the hardcoded
`/kellogg/proj/lgg3230` paths that item 1 removes. A change that makes the Mac run but
breaks the cluster is a regression. If the portable mechanism cannot be made to work on the
cluster, stop and report rather than leaving the cluster worse than it started.

**Commit hangs**: this repo used to hang on git's stat-scan of the large gitignored `Data/`
dir. Fixed on the Mac via `core.untrackedCache` + `core.fsmonitor`. Verify the same config
exists on the cluster checkout, or commits there may hang. Plumbing fallback:

```bash
tree=$(git write-tree)
commit=$(echo "$msg" | git commit-tree "$tree" -p HEAD)
git update-ref refs/heads/main "$commit"
```

---

## Repo rules that apply while editingi

**`cap drop`: one variable per line, no exceptions.** `cap drop x y z` silently drops only
`x` in Stata. This has caused real bugs in this repo — `cap drop totalflows_pw outflows_pw
inflows_pw` silently kept `totalflows_pw`, producing R²=1.0000 instead of ≈0.44.

**Do not collapse the tier-C `shell` calls into plain `do` calls.** `reghdfe` carries session
state; running two exercises in one Stata process shifts coefficients in the sixth digit, and
`clear all` does not reset it. Each estimator needs a fresh process. This is why item 1(f)
must be solved *without* removing the shell-out.

**Never write a `/*` glob literally in a `*` comment line in a do-file.** Stata honours the
block-comment opener inside `*` comments. This exact bug silently swallowed every tier flag
and every `do` call in master until 2026-09-06 — it parsed fine, printed
`0000_master.do finished.`, and ran nothing.

---

## What is already correct — do not "fix" these

Verified sound at `f613ea6`:

- Master parses cleanly end to end; all flag blocks are reachable (the 2026-09-06
  comment-swallowing bug is genuinely fixed).
- Tier A internals 1010 → 1011 → 1020 → 1030 → 1040 plus the five MATLAB scripts: filenames
  and year ranges (2007–2016, 2007–2011) all line up. The treat/control/one/zero `_agg.dta`
  files **are** built, in the loop at `1040:326`.
- Tier B order 2010 → 2020 (`stop_after_pct`) → 2030 → 2040 → 2050 correctly respects the
  circularity guard and produces `lagos_sample_sep24_pct_unionexp_ext_df2.dta`, which all 13
  estimators read.
- Tier C → tier D filenames match across `Tables/pct_tfpw_cc/`,
  `Tables/currentconn_full/<pipeline>/` and `Tables/conn_margins/`.
- All five generators master passes `--with-mean` to actually accept it.
- Tier-D Python derives paths from `__file__`, so `cd $logs` does not break them — except
  `4130`, which hardcodes `/gpfs` (see item 1).
- `lagos_sample_sep24_pct_unionexp_ext.dta` (no `_df2`) is written by `2020:392` and read by
  nothing. Dead end, harmless, not a missing link.
