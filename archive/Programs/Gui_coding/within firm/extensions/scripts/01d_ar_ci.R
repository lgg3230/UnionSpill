## E1d — Anderson-Rubin confidence set for the firm-level split-sample IV (weak-ID robust).
## Just-identified case: AR test of beta0 = cluster-robust t-test of the instrument
## coefficient in the regression of (y - beta0 * endo) on the instrument + FE.
## CI = { beta0 : p > 0.05 }, found by grid + bisection refinement.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

## rebuild the exact 01c estimation data (wages)
layer <- "edu2"
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
        .(c_early_f = weighted.mean(ca, E), c_late_f = weighted.mean(cb, E)), by = identificad]
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "treat_ultra", "in_balanced_panel", "lagos_sample_avg",
                     "industry1", "mode_base_month", "microregion", "lr_remdezr_w", "l_firm_emp", "totaltreat_pw_n")))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character = 1)); setnames(tf, 1, "identificad")
fp <- merge(fp, tf, by = "identificad", all.x = TRUE)
fp <- merge(fp, fk, by = "identificad", all.x = TRUE)
fp[, treat_year := as.integer(year >= 2012)]
sB <- quote(treat_ultra == 0 & in_balanced_panel == 1)
p90e <- stata_pctile(fp[eval(sB) & year == 2009, c_early_f], 90)
p90l <- stata_pctile(fp[eval(sB) & year == 2009, c_late_f], 90)
fp[, c_e := c_early_f / p90e]; fp[, c_l := c_late_f / p90l]
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

y <- "lr_remdezr_w"
d2 <- fp[eval(sB) & !is.na(get(y)) & !is.na(c_e) & !is.na(c_l)]
d2[, b1y := paste(lr_remdezr_w_pre4, year)]
d2[, b2y := paste(l_firm_emp_pre4, year)]
d2[, b3y := paste(totalflows_pw_pre4, year)]
d2[, iy := paste(industry1, year)]; d2[, my := paste(mode_base_month, year)]; d2[, ry := paste(microregion, year)]
fes <- c("identificad", "b1y", "b2y", "b3y", "iy", "my", "ry")
ffe <- paste(fes, collapse = " + ")
dm <- drop_singletons(copy(d2), fes)
dm[, cl_tt := c_l * treat_year]; dm[, ce_tt := c_e * treat_year]

ar_p <- function(b0) {
  dm[, ytil := get(y) - b0 * cl_tt]
  est <- feols(as.formula(paste0("ytil ~ ce_tt | ", ffe)), dm, cluster = ~identificad)
  coeftable(est)[1, 4]
}
## coarse grid to locate the region, then fine grid at the edges
grid <- seq(-0.02, 0.14, by = 0.004)
pv <- sapply(grid, ar_p)
inside <- grid[pv > 0.05]
cat(sprintf("coarse AR 95%% region: [%.4f, %.4f]\n", min(inside), max(inside)))
lo_grid <- seq(min(inside) - 0.004, min(inside) + 0.004, by = 0.001)
hi_grid <- seq(max(inside) - 0.004, max(inside) + 0.008, by = 0.001)
lo <- min(lo_grid[sapply(lo_grid, ar_p) > 0.05])
hi <- max(hi_grid[sapply(hi_grid, ar_p) > 0.05])
cat(sprintf("AR 95%% CI (wages, firm-level split-sample IV): [%.3f, %.3f]\n", lo, hi))
cat(sprintf("point estimate check (2SLS): %.4f\n",
    coeftable(feols(as.formula(paste0(y, " ~ 1 | ", ffe, " | cl_tt ~ ce_tt")), dm, cluster = ~identificad))[1, 1]))
saveRDS(list(lo = lo, hi = hi), file.path(OUT, "e1d_ar_ci.rds"))
