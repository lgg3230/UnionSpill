# Dataset Construction Flowchart

This maps the proposed option 1 construction path from raw RAIS/CBA files to the
analysis-ready files used by the draft. The legacy connectivity stage is
attached to `Programs/pipeline_main_data.do`, and the worker-level panel from
analysis-sample firms is now shown as an explicit upstream stage for the newer
parallel connectivity/layer pipeline.

## Main Flow

```mermaid
flowchart TD
    A[Raw RAIS yearly files<br/>$rais_raw_dir/RAIS_*.dta] --> B[Programs/1010_rais_to_firm.do]
    B --> B1[Data/RAIS_aux/worker_estab_*.dta]
    B --> B2[Data/CBA_RAIS_firm_level/rais_firm_*.dta]
    B --> B3[Data/RAIS_aux/unique_estab_*.dta]
    B --> B4[Data/RAIS_aux/rais_mode_mun_ind.dta]

    C[Raw employer association files<br/>Data/stata_emp_assoc/*.txt] --> D[Programs/1020_clean_emp_assoc.do]
    B3 --> D
    D --> D1[Data/stata_emp_assoc/emp_assoc_*.dta]
    D --> D2[Data/RAIS_aux/unique_firms_*.dta]

    E[Raw CBA coverage file<br/>Data/CBA/cnes_contracts_coverage_updated.dta] --> F[Programs/1030_clean_cba.do]
    F --> F1[Data/CBA/cba_coverage_clean.dta]
    F --> F2[Data/CBA/cba_coverage_clean_firm.dta]
    F2 --> G[Programs/1031_explode_cba_coverage_firm.py]
    G --> G1[Data/CBA/cba_firm_exploded.dta]
    G1 --> F
    F --> F3[Data/CBA/cba_estab_firm_*.dta]
    F --> F4[Data/CBA/cba_estab_firm.dta]
    F --> F5[Data/CBA/collapsed_cba_bunit_updated.dta]
    F --> F6[Data/CBA/collapsed_cba_firm_updated.dta]

    B2 --> H[Programs/1040_merge_cba_rais.do]
    F6 --> H
    I[Data/IBGE/mun_microregion_ibge.dta] --> H
    D2 --> H
    H --> H1[Data/CBA_RAIS_firm_level/cba_rais_firm_2007_2016.dta]
    H --> H2[Data/RAIS_aux/bal_pan.dta]
    H --> H3[Data/RAIS_aux/lagos_sample.csv/.dta]
    H --> H4[Data/RAIS_aux/lagos_control.csv/.dta]
    H --> H5[Data/RAIS_aux/lagos_treat.csv/.dta]
    H --> H6[Data/RAIS_aux/1_cba_treat.csv/.dta]
    H --> H7[Data/RAIS_aux/0_cba_treat.csv]

    A --> J[Programs/1050_yearly_employers.do<br/>connectivity stage]
    H1 --> J
    H3 --> J
    H4 --> J
    H5 --> J
    H6 --> J
    H7 --> J
    J --> J1[Data/RAIS_aux/yearly_employers_2007-2011.dta]
    J1 --> J2[Data/RAIS_aux/employers_2007_2008.csv<br/>...<br/>employers_2010_2011.csv]
    J2 --> K[MATLAB connectivity scripts]
    H3 --> K
    H4 --> K
    H5 --> K
    H6 --> K
    H7 --> K
    K --> K1[Data/RAIS_aux/connectivity_2007_2011.csv]
    K --> K2[Data/RAIS_aux/connectivity_treat_2007_2011.csv]
    K --> K3[Data/RAIS_aux/connectivity_control_2007_2011.csv]
    K --> K4[Data/RAIS_aux/connectivity_onecba_2007_2011.csv]
    K --> K5[Data/RAIS_aux/connectivity_zerocba_2007_2011.csv]
    K1 --> L[Aggregate connectivity in<br/>Programs/1050_yearly_employers.do]
    K2 --> L
    K3 --> L
    K4 --> L
    K5 --> L
    L --> L1[Data/RAIS_aux/connectivity_2007_2011_tcl.dta]
    L1 --> M[Merge connectivity into firm panel]
    H1 --> M
    M --> M1[Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta]
    M --> M2[Data/CBA_RAIS_firm_level/labor_analysis_sample.dta]
    M --> M3[Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta]

    A --> W[Programs/011c_worker_panel.py<br/>worker-level panel for analysis-sample firms]
    M1 --> W
    W --> W1[Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet]
    W1 --> W2[Programs/011d_worker_panel_bins.py<br/>education/race/age/tenure/contract/occupation bins]
    W2 --> W3[Programs/011e_worker_panel_bins2.py<br/>gender/disability/hours bins]
    W3 --> W4[Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet<br/>with derived worker bins]

    H1 --> N[Programs/union_treat_exp.do]
    N --> N1[Data/RAIS_aux/union_treat_exp_sep24.dta]

    W4 --> LC[Programs/layer_connectivity/00_pipeline<br/>parallel connectivity/layer measures]
    LC --> LC1[Data/layer_connectivity/final_measures/<br/>firm_layer_connectivity_*.dta/.parquet]
    LC --> LC2[Data/layer_connectivity/<br/>firm_layer_outcomes_*.dta/.parquet]

    M1 --> O[Replacement construction step<br/>partly undocumented]
    N1 --> O
    LC1 --> O
    W4 --> O
    O --> O1[Replacement for<br/>Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta]

    W4 --> P0[Derive worker wage-percentile input<br/>or update wage-percentile script to read parquet]
    P0 --> P[Current expected Stata input<br/>Data/CBA_RAIS_firm_level/worker_year_pre_new_vs_nonnew_dec26.dta]
    P --> Q[Programs/2030_get_wage_pctiles_df2.do]
    O1 --> Q
    Q --> R[Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta]

    R --> S[Draft analysis scripts]
    S --> T[Tables/, Graphs/, UnionSpill-paper/Figures/, UnionSpill-paper/Tables/]
```

## Option 1 Runner Skeleton

```mermaid
flowchart LR
    A[Programs/pipeline_main_data.do] --> B[1010_rais_to_firm.do]
    A --> C[1030_clean_cba.do]
    A --> D[1040_merge_cba_rais.do]
    A --> E[1050_yearly_employers.do<br/>with MATLAB connectivity]
    E --> H[cba_rais_firm_2009_2016_flows_1.dta]
    H --> W[011c_worker_panel.py]
    W --> X[011d/011e worker bins]
    X --> Y[worker_panel_lagos.parquet]
    Y --> Z[layer_connectivity/00_pipeline<br/>parallel connectivity/layer measures]
    A --> F[union_treat_exp.do]
    F --> I[union_treat_exp_sep24.dta]
    H --> J[Replacement step:<br/>new lagos_sample_sep24_pct_unionexp.dta base]
    I --> J
    Z --> J
    J --> G
    A --> G[2030_get_wage_pctiles_df2.do]
    G --> K[lagos_sample_sep24_pct_unionexp_ext_df2.dta]
```

## Known Gaps Before This Is Fully Replicable

1. `lagos_sample_sep24_pct_unionexp.dta` is the legacy missing upstream link.
   The intended option 1 path should replace this with the new parallel
   connectivity construction, but the exact script that writes the replacement
   firm-level file is still not identified in this map. The observed replacement
   output is `Data/CBA_RAIS_firm_level_currentconn_overlay/lagos_sample_sep24_pct_unionexp_ext_df2.dta`.

2. `Programs/1040_merge_cba_rais.do` appears to have a legacy typo in the
   zero-CBA treatment block: it saves `zero_cba_treat` to
   `Data/RAIS_aux/1_cba_treat.dta` before exporting `0_cba_treat.csv`.

3. The connectivity stage currently depends on MATLAB scripts run from
   `Programs/1050_yearly_employers.do`. Any canonical option 1 runner must call
   this stage or a verified replacement that reproduces:
   `totaltreat_pw_n`, `totaltreat_pf_n`, and `avg_ftreat_pf_n`.

4. Analysis scripts generally do not reconstruct connectivity. They use
   `totaltreat_pw_n` from the analysis-ready panel and create
   `totaltreat_pw_norm` by scaling it to the 2009 p90 among untreated
   spillover-sample firms.

5. The worker-level panel from analysis-sample firms should be part of option 1.
   The cleaner path is `Programs/011c_worker_panel.py` from raw RAIS plus
   `cba_rais_firm_2009_2016_flows_1.dta`, followed by
   `Programs/011d_worker_panel_bins.py` and
   `Programs/011e_worker_panel_bins2.py`. Older alternatives exist
   (`Programs/1060_rais_worker_panel.do`, `_run_012_worker_panel.do`,
   `2010_merge_lagos_worker.do`, `merge_lagos_worker_all.do`,
   `Programs/Python/create_lagos_workers.py`), but they produce broad
   worker-establishment panels or Lagos-worker merges rather than the cleaner
   analysis-sample worker panel.
