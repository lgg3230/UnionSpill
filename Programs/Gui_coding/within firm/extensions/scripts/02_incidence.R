## E2 — Incidence: when the FIRM-level shock hits, which group's wages move more?
## Spec: y_g = delta (C_firm x Post x 1[g=G2]) + firm x group FE + firm x year FE +
##       group x year FE + group-level bin x year controls.  delta = differential
##       response of group G2 vs G1 to firm-level connectivity, identified within firm-year.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

## firm-level official connectivity, Table-2 scaling
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "treat_ultra", "in_balanced_panel", "totaltreat_pw_n")))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
p90f <- stata_pctile(fp[treat_ultra == 0 & in_balanced_panel == 1 & year == 2009, totaltreat_pw_n], 90)
cf <- unique(fp[year == 2009, .(identificad, c_off = totaltreat_pw_n / p90f)])

G2 <- c(edu2 = "has_hs", gender = "male", race = "white")
res <- list()
for (layer in names(G2)) {
  d <- load_layer(layer)
  d <- merge(d, cf, by = "identificad", all.x = TRUE)
  d[, g2 := as.integer(layer_id == G2[[layer]])]
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    d2 <- samp(d, y, "c_off")
    add_fe_cols(d2)
    d2[, trip_tt := c_off * treat_year * g2]
    d2[, trip_pp := c_off * placebo_year * g2]
    fes <- c("firm_layer_id", "fy", "gy", bins_for(y))
    r <- run_did(d2, y, "trip_tt", "trip_pp", fes, es_var = NULL)
    ## event-study joint pre-F on the triple
    dm <- drop_singletons(copy(d2), fes); dm[, yearf := factor(year)]
    dm[, cg := c_off * g2]
    ese <- feols(as.formula(paste0(y, " ~ i(yearf, cg, ref = '2011') | ", paste(fes, collapse = "+"))),
                 dm, cluster = ~identificad)
    w <- tryCatch(fixest::wald(ese, keep = "yearf::(2009|2010)", print = FALSE), error = function(e) NULL)
    esF <- if (!is.null(w)) w$p else NA_real_
    cat(sprintf("[%s] %-16s C_firm x Post x %s = %s | pre = %s | esF-p=%.3f | N=%d F=%d\n",
        layer, y, G2[[layer]], fmt(r$main[1,1], r$main[1,2]), fmt(r$pre[1,1], r$pre[1,2]), esF, r$n, r$firms))
    res[[paste(layer, y)]] <- data.table(layer = layer, outcome = y, g2 = G2[[layer]],
      b = r$main[1,1], se = r$main[1,2], b_pre = r$pre[1,1], se_pre = r$pre[1,2],
      esF = esF, n = r$n, firms = r$firms)
  }
}
saveRDS(rbindlist(res), file.path(OUT, "e2_incidence.rds"))
cat("Saved e2_incidence.rds\n")
