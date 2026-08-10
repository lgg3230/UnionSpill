source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output/prep_layer.R")
options(width = 220)
SCR <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output"
d <- get_prepped("edu2", SCR)
p90_pool <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
d[, conn := layer_treat_pw_n / p90_pool]
d[, c_no_raw  := {v <- layer_treat_pw_n[layer_id == "no_hs"];  if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by = identificad]
d[, c_has_raw := {v <- layer_treat_pw_n[layer_id == "has_hs"]; if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by = identificad]
d[, c_no := c_no_raw / p90_pool]; d[, c_has := c_has_raw / p90_pool]

## (a) exact buggy n_cells for A7 within, edu2, full sample
d2 <- d[s_base == TRUE & !is.na(lr_remdezr_layer) & !is.na(conn)]
d2[, fy := paste(identificad, year)]
d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
d2[, b2y := paste(l_layer_emp_pre4, year)]
d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
fes <- c("firm_layer_id", "fy", "b1y", "b2y", "b3y")
dm <- drop_singletons(copy(d2), fes)
dm[, key := paste(firm_layer_id, year)]
d[, key := paste(firm_layer_id, year)]
d[, in_samp := as.integer(key %in% dm$key)]
buggy <- d[, .(allin = as.integer(min(in_samp) == 1)), by = firm_layer_id][, sum(allin)]
cat(sprintf("(a) A7 within edu2 full: correct cells=%d, buggy do-file count=%d (paper reports 6,273)\n",
    uniqueN(dm$firm_layer_id), buggy))

## (b) event studies, published A8 spec (plain/pool), no_hs column
es_one <- function(y, lv) {
  dd <- d[treat_ultra == 0 & in_balanced_panel == 1 & layer_id == lv &
          !is.na(get(y)) & !is.na(c_no) & !is.na(c_has)]
  dd[, b1y := paste(lr_remdezr_layer_pre4, year)]
  dd[, b2y := paste(l_layer_emp_pre4, year)]
  dd[, b3y := paste(layer_totalflows_pw_pre4, year)]
  bins <- if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes <- c("firm_layer_id", "year", bins)
  dm <- drop_singletons(copy(dd), fes)
  dm[, yearf := relevel(factor(year), ref = "2011")]
  est <- feols(as.formula(paste0(y, " ~ i(yearf, c_no, ref='2011') + i(yearf, c_has, ref='2011') | ",
              paste(fes, collapse = " + "))), data = dm, cluster = ~identificad)
  ct <- coeftable(est)
  cat(sprintf("\n(b) Event study %s, %s (published A8 spec):\n", y, lv))
  print(round(ct[, 1:2], 4))
}
es_one("l_layer_emp", "no_hs")
es_one("lr_remdezr_layer", "no_hs")

## (c) collinearity of the two connectivity regressors (firm level, spillover sample)
fdt <- unique(d[s_base == TRUE & !is.na(c_no) & !is.na(c_has), .(identificad, c_no, c_has)])
cat(sprintf("\n(c) corr(c_no_hs, c_has_hs) across %d firms: %.3f (spearman %.3f)\n",
    nrow(fdt), cor(fdt$c_no, fdt$c_has), cor(fdt$c_no, fdt$c_has, method = "spearman")))

## (d) clustering robustness on published A8 firm-level wage spec
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "lr_remdezr_w", "l_firm_emp")))
fw <- d[, .(c_no = c_no[1], c_has = c_has[1], treat_ultra = treat_ultra[1],
            in_balanced_panel = in_balanced_panel[1], microregion = microregion[1],
            industry1 = industry1[1]), by = .(identificad, year)]
fw <- merge(fw, fp, by = c("identificad", "year"))
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character = 1))
setnames(tf, 1, "identificad")
fw <- merge(fw, tf, by = "identificad", all.x = TRUE)
fw[, treat_year := as.integer(year >= 2012)]
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
d2 <- fw[treat_ultra == 0 & in_balanced_panel == 1 & !is.na(lr_remdezr_w) & !is.na(c_no) & !is.na(c_has)]
d2[, b1y := paste(lr_remdezr_w_pre4, year)]
d2[, b2y := paste(l_firm_emp_pre4, year)]
d2[, b3y := paste(totalflows_pw_pre4, year)]
fes <- c("identificad", "year", "b1y", "b2y", "b3y")
dm <- drop_singletons(copy(d2), fes)
fml <- lr_remdezr_w ~ c_no:treat_year + c_has:treat_year | identificad + year + b1y + b2y + b3y
for (cl in c("identificad", "microregion", "industry1")) {
  est <- feols(fml, data = dm, cluster = as.formula(paste0("~", cl)))
  ct <- coeftable(est)
  cat(sprintf("(d) A8 firm wage (published spec), cluster=%s (G=%d): Low=%7.4f (%6.4f)  High=%7.4f (%6.4f)\n",
      cl, uniqueN(dm[[cl]]), ct[1,1], ct[1,2], ct[2,1], ct[2,2]))
}
