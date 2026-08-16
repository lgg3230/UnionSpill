# Archive restore recipe

**Built 2026-08-10.** Every archived exercise and the exact command that puts it back. `archive/` mirrors the project layout, so restoring is a move.

Archived: **759 scripts** and **32 output directories**. `Programs/` went from 830 scripts to 71.

Rows marked **mixed** are directories that still hold chain scripts: restore their *contents*, not the directory, or `git mv` fails because the target exists.

| Pipeline | Scripts | Kind | Restore |
|---|---|---|---|
| `(root)` | 92 | root | `git mv archive/Programs/<file> Programs/` |
| `Gui_coding` | 42 | whole | `git mv archive/Programs/Gui_coding Programs/Gui_coding` |
| `Old` | 51 | whole | `git mv archive/Programs/Old Programs/Old` |
| `Python` | 2 | whole | `git mv archive/Programs/Python Programs/Python` |
| `aipw_robust` | 2 | whole | `git mv archive/Programs/aipw_robust Programs/aipw_robust` + `git mv archive/Tables/aipw_robust Tables/aipw_robust`, `git mv archive/Graphs/aipw_robust Graphs/aipw_robust`, `git mv archive/Logs/aipw_robust Logs/aipw_robust` |
| `avg_within_firm_cdf` | 2 | whole | `git mv archive/Programs/avg_within_firm_cdf Programs/avg_within_firm_cdf` + `git mv archive/Tables/avg_within_firm_cdf Tables/avg_within_firm_cdf`, `git mv archive/Graphs/avg_within_firm_cdf Graphs/avg_within_firm_cdf` |
| `cba_similarity` | 124 | whole | `git mv archive/Programs/cba_similarity Programs/cba_similarity` + `git mv archive/Tables/cba_similarity Tables/cba_similarity`, `git mv archive/Graphs/cba_similarity Graphs/cba_similarity`, `git mv archive/Logs/cba_similarity Logs/cba_similarity` |
| `cba_value` | 7 | **mixed** | `git mv archive/Programs/cba_value/* Programs/cba_value/` |
| `clause_types` | 11 | **mixed** | `git mv archive/Programs/clause_types/* Programs/clause_types/` |
| `composition` | 8 | **mixed** | `git mv archive/Programs/composition/* Programs/composition/` |
| `conn_descriptives` | 22 | **mixed** | `git mv archive/Programs/conn_descriptives/* Programs/conn_descriptives/` |
| `conn_margins` | 50 | **mixed** | `git mv archive/Programs/conn_margins/* Programs/conn_margins/` |
| `connectivity_diagram` | 1 | whole | `git mv archive/Programs/connectivity_diagram Programs/connectivity_diagram` + `git mv archive/Graphs/connectivity_diagram Graphs/connectivity_diagram` |
| `descriptives` | 10 | **mixed** | `git mv archive/Programs/descriptives/* Programs/descriptives/` |
| `direction_convergence` | 11 | whole | `git mv archive/Programs/direction_convergence Programs/direction_convergence` + `git mv archive/Tables/direction_convergence Tables/direction_convergence`, `git mv archive/Graphs/direction_convergence Graphs/direction_convergence`, `git mv archive/Logs/direction_convergence Logs/direction_convergence` |
| `educ_premia_fullrais` | 1 | whole | `git mv archive/Programs/educ_premia_fullrais Programs/educ_premia_fullrais` |
| `entry_exit` | 20 | whole | `git mv archive/Programs/entry_exit Programs/entry_exit` + `git mv archive/Tables/entry_exit Tables/entry_exit`, `git mv archive/Graphs/entry_exit Graphs/entry_exit`, `git mv archive/Logs/entry_exit Logs/entry_exit` |
| `exit` | 3 | whole | `git mv archive/Programs/exit Programs/exit` + `git mv archive/Tables/exit Tables/exit`, `git mv archive/Logs/exit Logs/exit` |
| `honest_did` | 14 | whole | `git mv archive/Programs/honest_did Programs/honest_did` + `git mv archive/Tables/honest_did Tables/honest_did`, `git mv archive/Graphs/honest_did Graphs/honest_did`, `git mv archive/Logs/honest_did Logs/honest_did` |
| `iv_late_conn_early_conn` | 3 | whole | `git mv archive/Programs/iv_late_conn_early_conn Programs/iv_late_conn_early_conn` + `git mv archive/Tables/iv_late_conn_early_conn Tables/iv_late_conn_early_conn`, `git mv archive/Logs/iv_late_conn_early_conn Logs/iv_late_conn_early_conn` |
| `layer_connectivity` | 111 | **mixed** | `git mv archive/Programs/layer_connectivity/* Programs/layer_connectivity/` |
| `main_data_pipeline` | 8 | whole | `git mv archive/Programs/main_data_pipeline Programs/main_data_pipeline` + `git mv archive/Logs/main_data_pipeline Logs/main_data_pipeline` |
| `main_data_pipeline_duckdb` | 6 | whole | `git mv archive/Programs/main_data_pipeline_duckdb Programs/main_data_pipeline_duckdb` |
| `main_results` | 16 | **mixed** | `git mv archive/Programs/main_results/* Programs/main_results/` |
| `max_clause_row` | 17 | whole | `git mv archive/Programs/max_clause_row Programs/max_clause_row` + `git mv archive/Tables/max_clause_row Tables/max_clause_row`, `git mv archive/Logs/max_clause_row Logs/max_clause_row` |
| `numb_clauses_outliers` | 13 | whole | `git mv archive/Programs/numb_clauses_outliers Programs/numb_clauses_outliers` + `git mv archive/Tables/numb_clauses_outliers Tables/numb_clauses_outliers`, `git mv archive/Logs/numb_clauses_outliers Logs/numb_clauses_outliers` |
| `rand_inference` | 17 | **mixed** | `git mv archive/Programs/rand_inference/* Programs/rand_inference/` |
| `residuals` | 18 | **mixed** | `git mv archive/Programs/residuals/* Programs/residuals/` |
| `results` | 14 | whole | `git mv archive/Programs/results Programs/results` |
| `robustness` | 21 | **mixed** | `git mv archive/Programs/robustness/* Programs/robustness/` |
| `sample_nesting` | 5 | whole | `git mv archive/Programs/sample_nesting Programs/sample_nesting` + `git mv archive/Tables/sample_nesting Tables/sample_nesting`, `git mv archive/Logs/sample_nesting Logs/sample_nesting` |
| `turnover` | 25 | **mixed** | `git mv archive/Programs/turnover/* Programs/turnover/` |
| `within_firm_final` | 9 | whole | `git mv archive/Programs/within_firm_final Programs/within_firm_final` |
| `worker_wages` | 3 | whole | `git mv archive/Programs/worker_wages Programs/worker_wages` + `git mv archive/Tables/worker_wages Tables/worker_wages`, `git mv archive/Graphs/worker_wages Graphs/worker_wages`, `git mv archive/Logs/worker_wages Logs/worker_wages` |

## Output directories

An output directory moved only when its pipeline had no chain script left **and** none of its filenames appears in `Draft.tex` or the replication doc. Nothing was blocked by that second test.

One case to know about: the replication doc displays honest-DiD figures, but through renamed copies in `UnionSpill-paper/Replication/Figures/`. Those copies were not touched, so the document still compiles — but the pipeline that regenerates them is now in `archive/Programs/honest_did/` with outputs in `archive/Graphs/honest_did/`. Restore both before rebuilding those figures.

## Known breakage on reactivation

Archived scripts calling OTHER archived scripts via `$programs/...` will not resolve until the callee is restored or the path is repointed at `archive/Programs/`. Archived scripts calling CHAIN scripts still work, because the chain did not move.

## Verified after the move

- every call target in the remaining scripts resolves
- `0000_master.do` runs clean
- no remaining script references `archive/`

