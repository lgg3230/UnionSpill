## E4 — Firm-level adjustment margins: stayer wages vs new-hire (switcher) wages,
## and turnover rates (quits, layoffs, hiring). Table-2 FE structure.
## CAVEAT (from 00_variable_audit): lr_remdezr_switchers missingness jumps from ~20%
## (2009-12) to ~41% (2013-16) -> selection risk; we also run a balanced-reporting
## subsample (firms with non-missing switcher wage in all 8 years).
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad", "year", "treat_ultra", "in_balanced_panel", "lagos_sample_avg",
                     "industry1", "mode_base_month", "microregion", "lr_remdezr_w", "l_firm_emp",
                     "totaltreat_pw_n", "lr_remdezr_stayers", "lr_remdezr_switchers",
                     "quits", "layoffs", "hiring")))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character = 1)); setnames(tf, 1, "identificad")
fp <- merge(fp, tf, by = "identificad", all.x = TRUE)
fp[, treat_year := as.integer(year >= 2012)]
fp[, placebo_year := as.integer(year < 2011)]
sB <- quote(treat_ultra == 0 & in_balanced_panel == 1)
p90 <- stata_pctile(fp[eval(sB) & year == 2009, totaltreat_pw_n], 90)
fp[, c_off := totaltreat_pw_n / p90]

## winsorize turnover rates at p99 (audit found extreme outliers, e.g. quits max 216).
## Threshold from PRE-PERIOD (2009-2011) untreated balanced-panel rows only, Stata
## percentile convention — post-period or treated-firm outcomes must not set the cap.
for (v in c("quits", "layoffs", "hiring")) {
  cap <- stata_pctile(fp[eval(sB) & year <= 2011][[v]], 99)
  fp[, (paste0(v, "_w")) := pmin(get(v), cap)]
}

yp <- c("totalflows_pw_07_08", "totalflows_pw_08_09", "totalflows_pw_09_10", "totalflows_pw_10_11")
fp[, tf_pre := rowMeans(.SD, na.rm = TRUE), .SDcols = yp]; fp[is.nan(tf_pre), tf_pre := NA_real_]
mkbin <- function(dt, src, name) {
  dt[, pre_tmp := {m <- mean(get(src)[year %in% 2009:2011], na.rm = TRUE); if (is.nan(m)) NA_real_ else m}, by = identificad]
  sel <- dt$year == 2009 & dt$in_balanced_panel == 1 & !is.na(dt$in_balanced_panel) & !is.na(dt$pre_tmp)
  br <- sapply(c(25, 50, 75), function(p) stata_pctile(dt$pre_tmp[sel], p))
  dt[, bin_tmp := NA_integer_]; dt[sel, bin_tmp := findInterval(pre_tmp, br)]
  dt[, (name) := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
  dt[, c("pre_tmp", "bin_tmp") := NULL]
}
for (v in c("lr_remdezr_w", "l_firm_emp", "lr_remdezr_stayers", "lr_remdezr_switchers",
            "quits_w", "layoffs_w", "hiring_w")) mkbin(fp, v, paste0(v, "_pre4"))
fp[, pre_tmp := {m <- mean(tf_pre[year == 2009], na.rm = TRUE); if (is.nan(m)) NA_real_ else m}, by = identificad]
sel <- fp$year == 2009 & fp$in_balanced_panel == 1 & !is.na(fp$in_balanced_panel) & !is.na(fp$tf_pre)
br <- sapply(c(25, 50, 75), function(p) stata_pctile(fp$tf_pre[sel], p))
fp[, bin_tmp := NA_integer_]; fp[sel, bin_tmp := findInterval(tf_pre, br)]
fp[, tf_pre4 := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
fp[, c("pre_tmp", "bin_tmp") := NULL]

## balanced-reporting flag for switcher wages
fp[, sw_all8 := as.integer(sum(!is.na(lr_remdezr_switchers)) == 8), by = identificad]

run_firm <- function(y, extra_filter = TRUE, label = "") {
  d2 <- fp[eval(sB) & !is.na(get(y)) & !is.na(c_off)][eval(extra_filter)]
  d2[, b0y := paste(get(paste0(y, "_pre4")), year)]
  d2[, b2y := paste(l_firm_emp_pre4, year)]
  d2[, b3y := paste(tf_pre4, year)]
  d2[, iy := paste(industry1, year)]; d2[, my := paste(mode_base_month, year)]; d2[, ry := paste(microregion, year)]
  fes <- c("identificad", "year", "b0y", "b2y", "b3y", "iy", "my", "ry")
  ffe <- paste(fes, collapse = " + ")
  dm <- drop_singletons(copy(d2), fes)
  dpre <- drop_singletons(d2[year <= 2011], fes)
  est <- coeftable(feols(as.formula(paste0(y, " ~ c_off:treat_year | ", ffe)), dm, cluster = ~identificad))
  pre <- coeftable(feols(as.formula(paste0(y, " ~ c_off:placebo_year | ", ffe)), dpre, cluster = ~identificad))
  dm[, yearf := factor(year)]
  ese <- feols(as.formula(paste0(y, " ~ i(yearf, c_off, ref = '2011') | ", ffe)), dm, cluster = ~identificad)
  w <- tryCatch(fixest::wald(ese, keep = "yearf::(2009|2010)", print = FALSE), error = function(e) NULL)
  esF <- if (!is.null(w)) w$p else NA_real_
  cat(sprintf("[FIRM] %-22s%-14s %s | pre %s | ES pre-F p=%.3f | N=%d F=%d\n",
      y, label, fmt(est[1,1], est[1,2]), fmt(pre[1,1], pre[1,2]), esF, nrow(dm), uniqueN(dm$identificad)))
  data.table(outcome = y, sample = ifelse(label == "", "full", label),
    b = est[1,1], se = est[1,2], b_pre = pre[1,1], se_pre = pre[1,2], esF = esF,
    n = nrow(dm), firms = uniqueN(dm$identificad))
}
res <- list(
  run_firm("lr_remdezr_w"),
  run_firm("lr_remdezr_stayers"),
  run_firm("lr_remdezr_switchers"),
  run_firm("lr_remdezr_switchers", quote(sw_all8 == 1), "[all-8yr]"),
  run_firm("quits_w"), run_firm("layoffs_w"), run_firm("hiring_w"))
saveRDS(rbindlist(res), file.path(OUT, "e4_firm_margins.rds"))
cat("Saved e4_firm_margins.rds\n")
