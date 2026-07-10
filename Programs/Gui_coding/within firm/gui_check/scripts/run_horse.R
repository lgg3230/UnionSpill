source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output/prep_layer.R")
options(width = 220)
SCR <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output"

d <- get_prepped("edu2", SCR)

## connectivity scalings
p90_pool <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
p90_no   <- stata_pctile(d[s_base == TRUE & year == 2009 & layer_id == "no_hs",  layer_treat_pw_n], 90)
p90_has  <- stata_pctile(d[s_base == TRUE & year == 2009 & layer_id == "has_hs", layer_treat_pw_n], 90)
cat(sprintf("P90 pooled=%.6f  no_hs=%.6f  has_hs=%.6f\n", p90_pool, p90_no, p90_has))

## broadcast each layer's raw connectivity to the firm
d[, c_no_raw  := {v <- layer_treat_pw_n[layer_id == "no_hs"];  if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by = identificad]
d[, c_has_raw := {v <- layer_treat_pw_n[layer_id == "has_hs"]; if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by = identificad]
d[, c_no_pool  := c_no_raw / p90_pool];  d[, c_has_pool := c_has_raw / p90_pool]
d[, c_no_own   := c_no_raw / p90_no];    d[, c_has_own  := c_has_raw / p90_has]

run_layer <- function(lv, y, fes_kind, scale) {
  cn <- paste0("c_no_", scale); ch <- paste0("c_has_", scale)
  d2 <- d[treat_ultra == 0 & in_balanced_panel == 1 & layer_id == lv &
          !is.na(get(y)) & !is.na(get(cn)) & !is.na(get(ch))]
  d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
  d2[, b2y := paste(l_layer_emp_pre4, year)]
  d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]
  d2[, my := paste(mode_base_month, year)]
  d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes <- if (fes_kind == "bundled") c("firm_layer_id", "year", bins, "iy", "my", "ry")
         else c("firm_layer_id", "year", bins)
  dm <- drop_singletons(copy(d2), fes)
  fml <- as.formula(paste0(y, " ~ ", cn, ":treat_year + ", ch, ":treat_year | ", paste(fes, collapse = " + ")))
  est <- feols(fml, data = dm, cluster = ~identificad)
  dp <- drop_singletons(d2[year <= 2011], fes)
  fmlp <- as.formula(paste0(y, " ~ ", cn, ":placebo_year + ", ch, ":placebo_year | ", paste(fes, collapse = " + ")))
  estp <- feols(fmlp, data = dp, cluster = ~identificad)
  ct <- coeftable(est); ctp <- coeftable(estp)
  cat(sprintf("%-16s %-6s %-8s %-5s | Low=%8.4f (%6.4f) High=%8.4f (%6.4f) | preL=%8.4f (%6.4f) preH=%8.4f (%6.4f) | N=%6d F=%5d\n",
    y, lv, fes_kind, scale, ct[1,1], ct[1,2], ct[2,1], ct[2,2], ctp[1,1], ctp[1,2], ctp[2,1], ctp[2,2],
    est$nobs, uniqueN(dm$identificad)))
}

cat("\n--- LAYER-LEVEL HORSE RACE ---\n")
for (y in c("lr_remdezr_layer", "l_layer_emp")) for (lv in c("no_hs", "has_hs"))
  for (fk in c("bundled", "plain")) for (sc in c("pool", "own")) run_layer(lv, y, fk, sc)

## ---- firm-level ----
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "lr_remdezr_w", "l_firm_emp")))
fw <- d[, .(c_no_pool = c_no_pool[1], c_has_pool = c_has_pool[1], c_no_own = c_no_own[1], c_has_own = c_has_own[1],
            treat_ultra = treat_ultra[1], in_balanced_panel = in_balanced_panel[1],
            industry1 = industry1[1], mode_base_month = mode_base_month[1], microregion = microregion[1]),
        by = .(identificad, year)]
fw <- merge(fw, fp, by = c("identificad", "year"))  # keep(match) inner join
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character = 1))
setnames(tf, 1, "identificad")
fw <- merge(fw, tf, by = "identificad", all.x = TRUE)
fw[, treat_year := as.integer(year >= 2012)]
fw[, placebo_year := as.integer(year < 2011)]
ypcols <- c("totalflows_pw_07_08", "totalflows_pw_08_09", "totalflows_pw_09_10", "totalflows_pw_10_11")
fw[, tf_pre := rowMeans(.SD, na.rm = TRUE), .SDcols = ypcols]
fw[is.nan(tf_pre), tf_pre := NA_real_]
for (v in c("lr_remdezr_w", "l_firm_emp")) {
  fw[, pre_tmp := {m <- mean(get(v)[year %in% 2009:2011], na.rm = TRUE); if (is.nan(m)) NA_real_ else m}, by = identificad]
  sel <- fw$year == 2009 & fw$in_balanced_panel == 1 & !is.na(fw$in_balanced_panel) & !is.na(fw$pre_tmp)
  br <- sapply(c(25, 50, 75), function(p) stata_pctile(fw$pre_tmp[sel], p))
  fw[, bin_tmp := NA_integer_]; fw[sel, bin_tmp := findInterval(pre_tmp, br)]
  fw[, (paste0(v, "_pre4")) := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
  fw[, c("pre_tmp", "bin_tmp") := NULL]
}
sel <- fw$year == 2009 & fw$in_balanced_panel == 1 & !is.na(fw$in_balanced_panel) & !is.na(fw$tf_pre)
br <- sapply(c(25, 50, 75), function(p) stata_pctile(fw$tf_pre[sel], p))
fw[, bin_tmp := NA_integer_]; fw[sel, bin_tmp := findInterval(tf_pre, br)]
fw[, totalflows_pw_pre4 := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
fw[, bin_tmp := NULL]

run_firm <- function(y, fes_kind, scale) {
  cn <- paste0("c_no_", scale); ch <- paste0("c_has_", scale)
  d2 <- fw[treat_ultra == 0 & in_balanced_panel == 1 & !is.na(get(y)) & !is.na(get(cn)) & !is.na(get(ch))]
  d2[, b1y := paste(lr_remdezr_w_pre4, year)]
  d2[, b2y := paste(l_firm_emp_pre4, year)]
  d2[, b3y := paste(totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]
  d2[, my := paste(mode_base_month, year)]
  d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_firm_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes <- if (fes_kind == "bundled") c("identificad", "year", bins, "iy", "my", "ry")
         else c("identificad", "year", bins)
  dm <- drop_singletons(copy(d2), fes)
  fml <- as.formula(paste0(y, " ~ ", cn, ":treat_year + ", ch, ":treat_year | ", paste(fes, collapse = " + ")))
  est <- feols(fml, data = dm, cluster = ~identificad)
  dp <- drop_singletons(d2[year <= 2011], fes)
  fmlp <- as.formula(paste0(y, " ~ ", cn, ":placebo_year + ", ch, ":placebo_year | ", paste(fes, collapse = " + ")))
  estp <- feols(fmlp, data = dp, cluster = ~identificad)
  ct <- coeftable(est); ctp <- coeftable(estp)
  cat(sprintf("%-16s FIRM  %-8s %-5s | Low=%8.4f (%6.4f) High=%8.4f (%6.4f) | preL=%8.4f (%6.4f) preH=%8.4f (%6.4f) | N=%6d F=%5d\n",
    y, fes_kind, scale, ct[1,1], ct[1,2], ct[2,1], ct[2,2], ctp[1,1], ctp[1,2], ctp[2,1], ctp[2,2],
    est$nobs, uniqueN(dm$identificad)))
}
cat("\n--- FIRM-LEVEL HORSE RACE ---\n")
for (y in c("lr_remdezr_w", "l_firm_emp")) for (fk in c("bundled", "plain")) for (sc in c("pool", "own")) run_firm(y, fk, sc)

cat("\nPAPER A8 wage:  no_hs: L -0.0015 (0.0053) H 0.0062 (0.0040) N=26,786 F=3,602 | has_hs: L 0.0023 (0.0022) H 0.0066 (0.0028) N=28,539 F=3,642 | firm: L 0.0034 (0.0022) H 0.0058 (0.0026) N=29,095 F=3,654\n")
cat("PAPER A8 emp:   no_hs: L -0.0209 (0.0093) H 0.0144 (0.0086) | has_hs: L 0.0108 (0.0078) H 0.0045 (0.0092) | firm: L 0.0036 (0.0075) H 0.0078 (0.0077)\n")
cat("PAPER A8 preW:  no_hs: L 0.0030 (0.0064) H -0.0080 (0.0041) | has_hs: L 0.0005 (0.0027) H -0.0023 (0.0039) | firm: L -0.0006 (0.0026) H -0.0007 (0.0026)\n")
cat("BUNDLED CSV:    no_hs wage: L 0.0003 (0.0058) H 0.0013 (0.0041) N=25,882 F=3,492 | firm wage: L 0.0029 (0.0020) H 0.0022 (0.0023) N=28,227 F=3,546\n")
