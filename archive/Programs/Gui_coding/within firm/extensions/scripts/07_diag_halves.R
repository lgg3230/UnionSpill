## Diagnostic for the early/late/full comparison:
## (1) reproduce Table 2 all 4 outcomes with the official measure (find clause var),
## (2) build firm-level early/late/full connectivity by employment-weighted
##     aggregation of edu2 layer year-pair measures, (3) P90s + agg-vs-official corr.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

## ---- build firm-level year-pair-aggregated connectivity from edu2 layers ----
d <- load_layer("edu2")
k <- as.data.table(read_dta(file.path(DATA, "firm_layer_connectivity_edu2.dta"),
     col_select = c("identificad", "layer_id", paste0("layer_treat_pw_", c("0708","0809","0910","1011")))))
setnames(k, paste0("layer_treat_pw_", c("0708","0809","0910","1011")), paste0("p", 1:4))
e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
k <- merge(k, e, by = c("identificad","layer_id"))
k[, c_full  := rowMeans(.SD, na.rm = TRUE), .SDcols = paste0("p", 1:4)]
k[, c_early := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p1","p2")]
k[, c_late  := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p3","p4")]
for (v in c("c_full","c_early","c_late")) k[is.nan(get(v)), (v) := NA_real_]
agg <- k[!is.na(E), .(
  cf_full  = weighted.mean(c_full,  E, na.rm = TRUE),
  cf_early = weighted.mean(c_early, E, na.rm = TRUE),
  cf_late  = weighted.mean(c_late,  E, na.rm = TRUE)), by = identificad]
for (v in c("cf_full","cf_early","cf_late")) agg[is.nan(get(v)), (v) := NA_real_]

## ---- firm panel + official measure ----
vars <- c("identificad","year","treat_ultra","in_balanced_panel","lagos_sample_avg",
          "industry1","mode_base_month","microregion","lr_remdezr_w","lr_remdezr_h_w",
          "l_firm_emp","totaltreat_pw_n","numb_clauses","numb_clauses_original","treat_cba")
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = intersect(vars, names(read_dta(file.path(DATA,"lagos_sample_sep24_pct_unionexp_ext_df2.dta"), n_max=1)))))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
fp <- merge(fp, agg, by = "identificad", all.x = TRUE)
sB <- quote(treat_ultra == 0 & in_balanced_panel == 1)

cat("clause var candidates (non-missing counts, untreated balanced panel):\n")
cat("  numb_clauses:", fp[eval(sB) & !is.na(numb_clauses), .N], " establishments:",
    fp[eval(sB) & !is.na(numb_clauses), uniqueN(identificad)], "\n")
if ("numb_clauses_original" %in% names(fp))
  cat("  numb_clauses_original:", fp[eval(sB) & !is.na(numb_clauses_original), .N], "\n")
cat("  (Table 2 col 4 target: N=19,693, Est=4,142)\n\n")

## ---- P90s (untreated balanced panel, one row per firm) ----
fx <- unique(fp[eval(sB), .(identificad, totaltreat_pw_n, cf_full, cf_early, cf_late)])
p90 <- sapply(c("totaltreat_pw_n","cf_full","cf_early","cf_late"),
              function(v) stata_pctile(fx[[v]], 90))
cat("P90s (untreated balanced panel):\n"); print(round(p90, 5))
cat(sprintf("\ncorr(full-agg, official) = %.3f | corr(early,late)=%.3f | corr(early,full)=%.3f | corr(late,full)=%.3f\n",
    cor(fx$cf_full, fx$totaltreat_pw_n, use="complete.obs"),
    cor(fx$cf_early, fx$cf_late, use="complete.obs"),
    cor(fx$cf_early, fx$cf_full, use="complete.obs"),
    cor(fx$cf_late, fx$cf_full, use="complete.obs")))
cat(sprintf("common non-missing (full,early,late): %d firms | official non-missing: %d\n",
    fx[!is.na(cf_full) & !is.na(cf_early) & !is.na(cf_late), .N], fx[!is.na(totaltreat_pw_n), .N]))
saveRDS(list(p90 = p90), file.path(OUT, "e7_p90.rds"))
