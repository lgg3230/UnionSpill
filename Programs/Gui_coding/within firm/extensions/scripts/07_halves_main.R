## E7 — Firm-level spillover with connectivity measured from different pre-period
## windows: main (official 4-yr), full aggregate (4-yr, my construction), first half
## (2007-09 flows), second half (2009-11 flows). Table-2 specification, all 4 outcomes.
## Both normalizations derived from one raw-connectivity regression per (outcome,measure):
## coef in P90 units = b_raw * P90 (own or main). Significance is normalization-invariant.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

## ---------- build firm-level year-pair-aggregated connectivity (edu2 layers) ----------
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
agg <- k[!is.na(E), .(cf_full = weighted.mean(c_full, E, na.rm=TRUE),
                      cf_early = weighted.mean(c_early, E, na.rm=TRUE),
                      cf_late = weighted.mean(c_late, E, na.rm=TRUE)), by = identificad]
for (v in c("cf_full","cf_early","cf_late")) agg[is.nan(get(v)), (v) := NA_real_]

## ---------- firm panel ----------
fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select = c("identificad","year","treat_ultra","in_balanced_panel","lagos_sample_avg",
                     "industry1","mode_base_month","microregion","lr_remdezr_w","lr_remdezr_h_w",
                     "l_firm_emp","totaltreat_pw_n","numb_clauses","_est_es_clauses")))
for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
setnames(fp, "_est_es_clauses", "es_clauses")
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
tf <- fread(file.path(DATA, "totalflows_wide_2007_2011.csv"), colClasses = list(character=1)); setnames(tf, 1, "identificad")
fp <- merge(fp, tf, by = "identificad", all.x = TRUE)
fp <- merge(fp, agg, by = "identificad", all.x = TRUE)
fp[, treat_year := as.integer(year >= 2012)]
fp[, placebo_year := as.integer(year < 2011)]
sB <- quote(treat_ultra == 0 & in_balanced_panel == 1)

## common sample for the aggregate family (firms with all three built)
fp[, has_all3 := as.integer(!is.na(cf_full) & !is.na(cf_early) & !is.na(cf_late))]

## ---------- P90s (untreated balanced panel, one row per firm) ----------
fx <- unique(fp[eval(sB), .(identificad, totaltreat_pw_n, cf_full, cf_early, cf_late)])
P90 <- list(official = stata_pctile(fx$totaltreat_pw_n, 90),
            full = stata_pctile(fx$cf_full, 90),
            early = stata_pctile(fx$cf_early, 90),
            late = stata_pctile(fx$cf_late, 90))

## ---------- pre-treatment quartile bins ----------
mkbin <- function(dt, src, name) {
  dt[, pre_tmp := {m <- mean(get(src)[year %in% 2009:2011], na.rm=TRUE); if (is.nan(m)) NA_real_ else m}, by = identificad]
  sel <- dt$year == 2009 & dt$in_balanced_panel == 1 & !is.na(dt$in_balanced_panel) & !is.na(dt$pre_tmp)
  br <- sapply(c(25,50,75), function(p) stata_pctile(dt$pre_tmp[sel], p))
  dt[, bin_tmp := NA_integer_]; dt[sel, bin_tmp := findInterval(pre_tmp, br)]
  dt[, (name) := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L}, by = identificad]
  dt[, c("pre_tmp","bin_tmp") := NULL]
}
fp[, tf_pre := rowMeans(.SD, na.rm=TRUE), .SDcols = c("totalflows_pw_07_08","totalflows_pw_08_09","totalflows_pw_09_10","totalflows_pw_10_11")]
fp[is.nan(tf_pre), tf_pre := NA_real_]
for (v in c("lr_remdezr_w","lr_remdezr_h_w","l_firm_emp","numb_clauses","tf_pre")) mkbin(fp, v, paste0(v, "_b"))

## ---------- outcome config ----------
OC <- list(
  lr_remdezr_w   = list(lab = "Log wages",         obin = "lr_remdezr_w_b",   samp = "std"),
  lr_remdezr_h_w = list(lab = "Log hourly wages",  obin = "lr_remdezr_h_w_b", samp = "std"),
  l_firm_emp     = list(lab = "Log employment",    obin = "l_firm_emp_b",     samp = "std"),
  numb_clauses   = list(lab = "Clause count",      obin = "numb_clauses_b",   samp = "clause"))
MEAS <- c(official = "totaltreat_pw_n", full = "cf_full", early = "cf_early", late = "cf_late")

run_cell <- function(y, oc, mvar, mkey) {
  base <- fp[eval(sB) & !is.na(get(y)) & !is.na(get(mvar))]
  if (oc$samp == "clause") base <- base[es_clauses == 1]
  if (mkey != "official") base <- base[has_all3 == 1]      # common sample for aggregate family
  base[, cc := get(mvar)]
  base[, cc_tt := cc * treat_year]; base[, cc_pp := cc * placebo_year]
  base[, b_out := paste(get(oc$obin), year)]
  base[, b_emp := paste(l_firm_emp_b, year)]
  base[, b_flw := paste(tf_pre_b, year)]
  base[, iy := paste(industry1, year)]; base[, my := paste(mode_base_month, year)]; base[, ry := paste(microregion, year)]
  bins <- if (y == "l_firm_emp") c("b_emp","b_flw") else c("b_out","b_emp","b_flw")
  fes <- c("identificad","year", bins, "iy","my","ry")
  ffe <- paste(fes, collapse = " + ")
  dm <- drop_singletons(copy(base), fes)
  dp <- drop_singletons(base[year <= 2011], fes)
  est <- coeftable(feols(as.formula(paste0(y, " ~ cc_tt | ", ffe)), dm, cluster = ~identificad))
  pre <- coeftable(feols(as.formula(paste0(y, " ~ cc_pp | ", ffe)), dp, cluster = ~identificad))
  dm[, yearf := factor(year)]
  ese <- feols(as.formula(paste0(y, " ~ i(yearf, cc, ref='2011') | ", ffe)), dm, cluster = ~identificad)
  w <- tryCatch(fixest::wald(ese, keep = "yearf::(2009|2010)", print = FALSE), error = function(e) NULL)
  data.table(outcome = y, measure = mkey,
             b_raw = est[1,1], se_raw = est[1,2], pb_raw = pre[1,1], pse_raw = pre[1,2],
             esF = if (!is.null(w)) w$p else NA_real_, n = nrow(dm), est = uniqueN(dm$identificad))
}

res <- rbindlist(lapply(names(OC), function(y)
  rbindlist(lapply(names(MEAS), function(mk) {
    r <- run_cell(y, OC[[y]], MEAS[[mk]], mk)
    cat(sprintf("%-16s %-8s b_raw=%9.4f se=%8.4f | own-P90 coef=%7.4f | N=%d Est=%d\n",
        y, mk, r$b_raw, r$se_raw, r$b_raw * P90[[mk]], r$n, r$est)); r
  }))))
res[, p90_own := sapply(measure, function(m) P90[[m]])]
res[, p90_main := P90$full]   # main = 4-yr measure P90
saveRDS(list(res = res, P90 = P90, OC = OC), file.path(OUT, "e7_halves.rds"))
cat("\nP90s:", paste(sprintf("%s=%.5f", names(P90), unlist(P90)), collapse="  "), "\n")
cat("Saved e7_halves.rds\n")
