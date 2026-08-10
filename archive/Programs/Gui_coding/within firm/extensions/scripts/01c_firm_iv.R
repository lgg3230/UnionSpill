## E1c — Firm-level split-sample IV: is the HEADLINE spillover attenuated by
## measurement error in connectivity? Instrument late-pair firm connectivity
## (built as employment-share-weighted group connectivity, identity checked in
## gui_check/run_a8_identity.R: R2=0.94 vs the official firm measure) with the
## early-pair version. Table-2 FE structure, full spillover sample.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

layer <- "edu2"   # partition used only to build the firm-level aggregate
d <- load_layer(layer)
k <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer)),
     col_select = c("identificad", "layer_id", paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")))))
setnames(k, paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")), paste0("p", 1:4))
k[, ca := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p1", "p2")]
k[, cb := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p3", "p4")]
k[is.nan(ca), ca := NA_real_]; k[is.nan(cb), cb := NA_real_]
e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
k <- merge(k, e, by = c("identificad", "layer_id"))
fk <- k[!is.na(ca) & !is.na(cb) & !is.na(E),
        .(c_early_f = weighted.mean(ca, E), c_late_f = weighted.mean(cb, E), ncell = .N), by = identificad]

## firm panel with Table-2 controls (same construction as gui_check/run_t2_sample.R,
## which reproduces Table 2 exactly: 0.0051 (0.0023), N=32,498)
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "treat_ultra", "in_balanced_panel", "lagos_sample_avg",
                     "industry1", "mode_base_month", "microregion", "lr_remdezr_w", "l_firm_emp", "totaltreat_pw_n")))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character = 1)); setnames(tf, 1, "identificad")
fp <- merge(fp, tf, by = "identificad", all.x = TRUE)
fp <- merge(fp, fk, by = "identificad", all.x = TRUE)
fp[, treat_year := as.integer(year >= 2012)]
fp[, placebo_year := as.integer(year < 2011)]
sB <- quote(treat_ultra == 0 & in_balanced_panel == 1)
p90n <- stata_pctile(fp[eval(sB) & year == 2009, totaltreat_pw_n], 90)
p90e <- stata_pctile(fp[eval(sB) & year == 2009, c_early_f], 90)
p90l <- stata_pctile(fp[eval(sB) & year == 2009, c_late_f], 90)
fp[, c_off := totaltreat_pw_n / p90n]
fp[, c_e := c_early_f / p90e]
fp[, c_l := c_late_f / p90l]
## split-half reliability at the firm level, estimation universe
fr <- unique(fp[eval(sB) & !is.na(c_e) & !is.na(c_l), .(identificad, c_e, c_l)])
cat(sprintf("firm-level split-half reliability (Pearson) = %.3f | Spearman = %.3f | N=%d firms\n",
    cor(fr$c_e, fr$c_l), cor(fr$c_e, fr$c_l, method = "spearman"), nrow(fr)))

yp <- c("totalflows_pw_07_08", "totalflows_pw_08_09", "totalflows_pw_09_10", "totalflows_pw_10_11")
fp[, tf_pre := rowMeans(.SD, na.rm = TRUE), .SDcols = yp]; fp[is.nan(tf_pre), tf_pre := NA_real_]
for (v in c("lr_remdezr_w", "l_firm_emp")) {
  fp[, pre_tmp := {m <- mean(get(v)[year %in% 2009:2011], na.rm = TRUE); if (is.nan(m)) NA_real_ else m}, by = identificad]
  sel <- fp$year == 2009 & fp$in_balanced_panel == 1 & !is.na(fp$in_balanced_panel) & !is.na(fp$pre_tmp)
  br <- sapply(c(25, 50, 75), function(p) stata_pctile(fp$pre_tmp[sel], p))
  fp[, bin_tmp := NA_integer_]; fp[sel, bin_tmp := findInterval(pre_tmp, br)]
  fp[, (paste0(v, "_pre4")) := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
  fp[, c("pre_tmp", "bin_tmp") := NULL]
}
sel <- fp$year == 2009 & fp$in_balanced_panel == 1 & !is.na(fp$in_balanced_panel) & !is.na(fp$tf_pre)
br <- sapply(c(25, 50, 75), function(p) stata_pctile(fp$tf_pre[sel], p))
fp[, bin_tmp := NA_integer_]; fp[sel, bin_tmp := findInterval(tf_pre, br)]
fp[, totalflows_pw_pre4 := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
fp[, bin_tmp := NULL]

res <- list()
for (y in c("lr_remdezr_w", "l_firm_emp")) {
  d2 <- fp[eval(sB) & !is.na(get(y)) & !is.na(c_e) & !is.na(c_l) & !is.na(c_off)]
  d2[, b1y := paste(lr_remdezr_w_pre4, year)]
  d2[, b2y := paste(l_firm_emp_pre4, year)]
  d2[, b3y := paste(totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]; d2[, my := paste(mode_base_month, year)]; d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_firm_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes <- c("identificad", "year", bins, "iy", "my", "ry")
  ffe <- paste(fes, collapse = " + ")
  dm <- drop_singletons(copy(d2), fes)
  dpre <- drop_singletons(d2[year <= 2011], fes)
  dm[, cl_tt := c_l * treat_year]; dm[, ce_tt := c_e * treat_year]
  dpre[, cl_pp := c_l * placebo_year]; dpre[, ce_pp := c_e * placebo_year]

  ols_off <- coeftable(feols(as.formula(paste0(y, " ~ c_off:treat_year | ", ffe)), dm, cluster = ~identificad))
  ols_l   <- coeftable(feols(as.formula(paste0(y, " ~ cl_tt | ", ffe)), dm, cluster = ~identificad))
  iv      <- feols(as.formula(paste0(y, " ~ 1 | ", ffe, " | cl_tt ~ ce_tt")), dm, cluster = ~identificad)
  ivct    <- coeftable(iv); ivF <- fitstat(iv, "ivwald1", simplify = TRUE)$stat
  ivp     <- feols(as.formula(paste0(y, " ~ 1 | ", ffe, " | cl_pp ~ ce_pp")), dpre, cluster = ~identificad)
  ivpct   <- coeftable(ivp)
  olspre  <- coeftable(feols(as.formula(paste0(y, " ~ c_off:placebo_year | ", ffe)), dpre, cluster = ~identificad))

  cat(sprintf("[FIRM] %-14s OLS(official)=%s | OLS(late)=%s | IV(late<-early)=%s [F1=%.1f] | preOLS=%s preIV=%s | N=%d F=%d\n",
      y, fmt(ols_off[1,1], ols_off[1,2]), fmt(ols_l[1,1], ols_l[1,2]), fmt(ivct[1,1], ivct[1,2]), ivF,
      fmt(olspre[1,1], olspre[1,2]), fmt(ivpct[1,1], ivpct[1,2]), nrow(dm), uniqueN(dm$identificad)))
  res[[y]] <- data.table(outcome = y, b_off = ols_off[1,1], se_off = ols_off[1,2],
    b_olsl = ols_l[1,1], se_olsl = ols_l[1,2], b_iv = ivct[1,1], se_iv = ivct[1,2], ivF = ivF,
    b_pre_ols = olspre[1,1], se_pre_ols = olspre[1,2], b_pre_iv = ivpct[1,1], se_pre_iv = ivpct[1,2],
    n = nrow(dm), firms = uniqueN(dm$identificad))
}
saveRDS(res, file.path(OUT, "e1c_firm_iv.rds"))
cat("Saved e1c_firm_iv.rds\n")
