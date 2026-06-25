# Direction-of-convergence: geometry & decomposition

Panel: `lagos_sample_sep24_pct_unionexp_ext_df2.dta`  |  firms (firm x period): 16,472  |  pre = cba_period==2, post = cba_period>=3

## #1 Centroid similarity (4 measures). Higher = closer.

| comparison                                  |   cosine_shares |   tv_shares |   ruzicka_counts |   bc_counts |
|:--------------------------------------------|----------------:|------------:|-----------------:|------------:|
| U_post vs T_pre  (U approaching T's 2011?)  |          0.9127 |      0.7998 |           0.6679 |      0.8009 |
| U_pre  vs T_pre  (baseline U-to-T2011)      |          0.9205 |      0.8055 |           0.662  |      0.7966 |
| T_post vs U_pre  (T approaching U's 2011?)  |          0.8886 |      0.7788 |           0.5981 |      0.7485 |
| T_pre  vs U_pre  (baseline T-to-U2011)      |          0.9205 |      0.8055 |           0.662  |      0.7966 |
| T_post vs U_post (mutual: groups converge?) |          0.8835 |      0.7777 |           0.6273 |      0.771  |
| T_pre  vs U_pre  (baseline between-group)   |          0.9205 |      0.8055 |           0.662  |      0.7966 |
| U_post vs U_pre  (U self-movement)          |          0.9938 |      0.9519 |           0.8715 |      0.9313 |
| T_post vs T_pre  (T self-movement)          |          0.9309 |      0.8518 |           0.7076 |      0.8287 |

## #1 Displacement vectors (do both groups move the same way?)

| quantity                  |   value |
|:--------------------------|--------:|
| |dT| counts               |  2.3119 |
| |dU| counts               |  0.6707 |
| angle(dT,dU) counts [cos] |  0.2943 |
| |dT| shares               |  0.0529 |
| |dU| shares               |  0.015  |
| angle(dT,dU) shares [cos] |  0.0534 |
| total clauses T_pre       | 33.7411 |
| total clauses T_post      | 42.6578 |
| total clauses U_pre       | 29.0901 |
| total clauses U_post      | 32.3958 |

## #4 Clause-group decomposition (share of total clauses; dShare in pct points)

|   group | label                     |   n_clausetypes |   share_T_pre |   share_T_post |   dShare_T |   share_U_pre |   share_U_post |   dShare_U | same_direction   |
|--------:|:--------------------------|----------------:|--------------:|---------------:|-----------:|--------------:|---------------:|-----------:|:-----------------|
|       0 | Unclassified              |               2 |        0      |         0      |    -0      |        0      |         0      |     0      | no               |
|       1 | Pay / Remuneration        |               9 |        0.1008 |         0.0793 |    -0.0216 |        0.1224 |         0.119  |    -0.0034 | yes              |
|       2 | Bonuses & Allowances      |              29 |        0.248  |         0.2628 |     0.0148 |        0.2197 |         0.2258 |     0.0061 | yes              |
|       3 | Employment / Job security |              13 |        0.0534 |         0.0577 |     0.0043 |        0.0862 |         0.0894 |     0.0032 | yes              |
|       4 | Work relations & Equality |              28 |        0.0729 |         0.0911 |     0.0182 |        0.1037 |         0.0948 |    -0.0089 | no               |
|       5 | Workday / Hours           |              12 |        0.1227 |         0.1236 |     0.0009 |        0.131  |         0.12   |    -0.011  | no               |
|       6 | Health & Safety           |              19 |        0.0814 |         0.065  |    -0.0164 |        0.0814 |         0.0848 |     0.0034 | no               |
|       7 | Vacation & Leave          |               9 |        0.0587 |         0.0546 |    -0.0041 |        0.0397 |         0.0437 |     0.004  | no               |
|       8 | Union relations           |              12 |        0.1583 |         0.1395 |    -0.0188 |        0.1016 |         0.1006 |    -0.001  | yes              |
|       9 | General / Enforcement     |               6 |        0.1039 |         0.1264 |     0.0226 |        0.1143 |         0.1217 |     0.0074 | yes              |

## Centroid trajectory vs fixed anchors (cosine & TV on shares)

|   cba_period | group     |   n_firms |   sim_to_Tpre_cosine |   sim_to_Tpre_tv |   sim_to_Upre_cosine |   sim_to_Upre_tv |
|-------------:|:----------|----------:|---------------------:|-----------------:|---------------------:|-----------------:|
|            1 | treated   |     12276 |               0.9671 |           0.9061 |               0.8966 |           0.7752 |
|            1 | untreated |      4196 |               0.9143 |           0.7984 |               0.9956 |           0.9639 |
|            2 | treated   |     12276 |               1      |           1      |               0.9205 |           0.8055 |
|            2 | untreated |      4196 |               0.9205 |           0.8055 |               1      |           1      |
|            3 | treated   |      9462 |               0.9392 |           0.8411 |               0.8846 |           0.7427 |
|            3 | untreated |      2875 |               0.9052 |           0.796  |               0.9912 |           0.9446 |
|            4 | treated   |      9164 |               0.8237 |           0.7794 |               0.7778 |           0.7051 |
|            4 | untreated |      2605 |               0.9143 |           0.7994 |               0.9675 |           0.9221 |
|            5 | treated   |      8543 |               0.8382 |           0.7891 |               0.7811 |           0.7257 |
|            5 | untreated |      2346 |               0.8955 |           0.7885 |               0.9909 |           0.9362 |
|            6 | treated   |      5116 |               0.9116 |           0.8082 |               0.9843 |           0.9059 |
|            6 | untreated |      2104 |               0.8963 |           0.7862 |               0.9884 |           0.9282 |

## #2/#3 Connectivity-graded firm-level reg (untreated; coef on connectivity x post)

old(T_pre) = moving toward treated's 2011 bundle; new(T_post) = toward treated's post bundle.

| region      | measure        | spec   |   coef |     se |      t |     N |
|:------------|:---------------|:-------|-------:|-------:|-------:|------:|
| old(T_pre)  | cosine_shares  | base   | 0.1749 | 0.0432 | 4.0514 | 18321 |
| old(T_pre)  | tv_shares      | base   | 0.0592 | 0.0288 | 2.0559 | 18321 |
| old(T_pre)  | ruzicka_counts | base   | 0.0509 | 0.0178 | 2.8643 | 18322 |
| old(T_pre)  | bc_counts      | base   | 0.0751 | 0.0259 | 2.8953 | 18322 |
| new(T_post) | cosine_shares  | base   | 0.1619 | 0.0411 | 3.9382 | 18321 |
| new(T_post) | tv_shares      | base   | 0.051  | 0.028  | 1.8241 | 18321 |
| new(T_post) | ruzicka_counts | base   | 0.0495 | 0.0191 | 2.595  | 18322 |
| new(T_post) | bc_counts      | base   | 0.0732 | 0.0274 | 2.6731 | 18322 |
