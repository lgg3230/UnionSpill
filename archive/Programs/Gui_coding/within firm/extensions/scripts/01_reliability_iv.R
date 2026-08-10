## E1 — Is the within-firm null a true zero or measurement-error attenuation?
## (a) split-half reliability of the within-firm connectivity gap (early vs late year-pairs)
## (b) split-sample IV: late-pair connectivity instrumented by early-pair connectivity
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")
res <- list()

for (layer in c("edu2", "gender")) {
  d <- load_layer(layer)
  ## merge year-pair measures
  k <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer)),
       col_select = c("identificad", "layer_id", paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")))))
  k[, c_early_raw := rowMeans(.SD, na.rm = TRUE), .SDcols = paste0("layer_treat_pw_", c("0708", "0809"))]
  k[, c_late_raw  := rowMeans(.SD, na.rm = TRUE), .SDcols = paste0("layer_treat_pw_", c("0910", "1011"))]
  k[is.nan(c_early_raw), c_early_raw := NA_real_]
  k[is.nan(c_late_raw),  c_late_raw  := NA_real_]
  d <- merge(d, k[, .(identificad, layer_id, c_early_raw, c_late_raw)],
             by = c("identificad", "layer_id"), all.x = TRUE)
  p90e <- stata_pctile(d[s_base == TRUE & year == 2009, c_early_raw], 90)
  p90l <- stata_pctile(d[s_base == TRUE & year == 2009, c_late_raw], 90)
  d[, c_early := c_early_raw / p90e]
  d[, c_late  := c_late_raw / p90l]

  ## ---- (a) reliability of the within-firm gap ----
  gv <- if (layer == "edu2") c("no_hs", "has_hs") else c("female", "male")
  fx <- unique(d[s_base == TRUE, .(identificad, layer_id, c_early, c_late, conn)], by = c("identificad", "layer_id"))
  gw <- dcast(fx, identificad ~ layer_id, value.var = c("c_early", "c_late", "conn"))
  g1 <- gv[1]; g2 <- gv[2]
  gw[, gap_early := get(paste0("c_early_", g1)) - get(paste0("c_early_", g2))]
  gw[, gap_late  := get(paste0("c_late_", g1))  - get(paste0("c_late_", g2))]
  gw2 <- gw[!is.na(gap_early) & !is.na(gap_late)]
  r_gap <- cor(gw2$gap_early, gw2$gap_late)
  r_lvl <- cor(fx[!is.na(c_early) & !is.na(c_late), c_early], fx[!is.na(c_early) & !is.na(c_late), c_late])
  sb <- 2 * r_gap / (1 + r_gap)   # Spearman-Brown: reliability of the 4-pair average gap
  cat(sprintf("\n[%s] reliability: split-half corr of within-firm GAP = %.3f (N=%d firms) | levels = %.3f | Spearman-Brown 4-pair gap reliability = %.3f\n",
      layer, r_gap, nrow(gw2), r_lvl, sb))
  res[[paste0(layer, "_rel")]] <- data.table(layer = layer, r_gap = r_gap, r_lvl = r_lvl, sb = sb, n_firms_rel = nrow(gw2))

  ## ---- (b) OLS baseline and split-sample IV, within-firm spec ----
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    d2 <- samp(d, y)[!is.na(c_early) & !is.na(c_late)]
    add_fe_cols(d2)
    d2[, clate_tt  := c_late  * treat_year]
    d2[, cearly_tt := c_early * treat_year]
    d2[, clate_pp  := c_late  * placebo_year]
    d2[, cearly_pp := c_early * placebo_year]
    fes <- fes_for("within", y)
    ffe <- paste(fes, collapse = " + ")
    dm <- drop_singletons(copy(d2), fes)
    dpre <- drop_singletons(d2[year <= 2011], fes)

    ols_n  <- coeftable(feols(as.formula(paste0(y, " ~ conn:treat_year | ", ffe)), dm, cluster = ~identificad))
    ols_l  <- coeftable(feols(as.formula(paste0(y, " ~ clate_tt | ", ffe)), dm, cluster = ~identificad))
    iv     <- feols(as.formula(paste0(y, " ~ 1 | ", ffe, " | clate_tt ~ cearly_tt")), dm, cluster = ~identificad)
    ivct   <- coeftable(iv)
    ivF    <- fitstat(iv, "ivwald1", simplify = TRUE)$stat
    ivp    <- feols(as.formula(paste0(y, " ~ 1 | ", ffe, " | clate_pp ~ cearly_pp")), dpre, cluster = ~identificad)
    ivpct  <- coeftable(ivp)
    olsp   <- coeftable(feols(as.formula(paste0(y, " ~ conn:placebo_year | ", ffe)), dpre, cluster = ~identificad))

    cat(sprintf("[%s] %-16s OLS(avg)=%s | OLS(late)=%s | IV(late<-early)=%s [F1=%.1f] | preOLS=%s preIV=%s | N=%d F=%d\n",
        layer, y, fmt(ols_n[1,1], ols_n[1,2]), fmt(ols_l[1,1], ols_l[1,2]),
        fmt(ivct[1,1], ivct[1,2]), ivF, fmt(olsp[1,1], olsp[1,2]), fmt(ivpct[1,1], ivpct[1,2]),
        nrow(dm), uniqueN(dm$identificad)))
    res[[paste(layer, y, sep = "_")]] <- data.table(layer = layer, outcome = y,
      b_ols = ols_n[1,1], se_ols = ols_n[1,2], b_olsl = ols_l[1,1], se_olsl = ols_l[1,2],
      b_iv = ivct[1,1], se_iv = ivct[1,2], ivF = ivF,
      b_ols_pre = olsp[1,1], se_ols_pre = olsp[1,2], b_iv_pre = ivpct[1,1], se_iv_pre = ivpct[1,2],
      n = nrow(dm), firms = uniqueN(dm$identificad))
  }
}
saveRDS(res, file.path(OUT, "e1_reliability_iv.rds"))
cat("\nSaved e1_reliability_iv.rds\n")
