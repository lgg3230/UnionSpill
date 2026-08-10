## Variable audit for the extension analyses.
## Verifies each variable used downstream behaves as documented before any regression.
suppressMessages({library(haven); library(data.table)})
DATA <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/Luis_og/data"
options(width = 200)
sink("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/checks/variable_audit.txt", split = TRUE)
cat("VARIABLE AUDIT —", format(Sys.time()), "\n\n")

## ---------- 1. Layer outcome files: structure, wage levels, employment identity ----------
fp_small <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
    col_select = c("identificad", "year", "firm_emp", "treat_ultra", "in_balanced_panel", "lagos_sample_avg",
                   "lr_remdezr_w", "lr_remdezr_stayers", "lr_remdezr_switchers",
                   "quits", "layoffs", "separations", "hiring", "totaltreat_pw_n")))

for (layer in c("edu2", "gender", "race", "occ4", "ten2")) {
  o <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_outcomes_%s.dta", layer))))
  cat(sprintf("== outcomes_%s: %d rows, years %d-%d, layers: %s\n", layer, nrow(o),
      min(o$year), max(o$year), paste(sort(unique(o$layer_id)), collapse = "/")))
  ok <- o[year >= 2009]
  cs <- ok[, .(cells = .N, med_emp = median(layer_emp, na.rm = TRUE),
               mean_wage_brl = round(exp(mean(lr_remdezr_layer, na.rm = TRUE))),
               pct_missing_wage = round(100 * mean(is.na(lr_remdezr_layer)), 1)), by = layer_id]
  print(cs)
  ## employment adding-up: sum of layer_emp vs firm_emp (Dec employment), 2012
  s <- ok[year == 2012, .(sum_layer_emp = sum(layer_emp, na.rm = TRUE)), by = .(identificad, year)]
  s <- merge(s, fp_small[year == 2012, .(identificad, firm_emp)], by = "identificad")
  s <- s[!is.na(firm_emp) & firm_emp > 0]
  cat(sprintf("   adding-up (2012): corr(sum layer_emp, firm_emp)=%.3f | median ratio=%.3f | pct within 5pct=%.1f\n\n",
      cor(s$sum_layer_emp, s$firm_emp), median(s$sum_layer_emp / s$firm_emp),
      100 * mean(abs(s$sum_layer_emp / s$firm_emp - 1) < .05)))
}

## ---------- 2. ten2 composition caveat: is short-tenure share stable? ----------
o <- as.data.table(read_dta(file.path(DATA, "firm_layer_outcomes_ten2.dta")))
o <- o[year >= 2009]
w <- dcast(o[, .(identificad, year, layer_id, layer_emp)], identificad + year ~ layer_id, value.var = "layer_emp")
w[, sh_short := lt12mo / (lt12mo + ge12mo)]
cat("== ten2: short-tenure share distribution (firm-years):\n")
print(round(quantile(w$sh_short, c(.05, .25, .5, .75, .95), na.rm = TRUE), 3))
cat(sprintf("   pct firm-years with NO short-tenure workers: %.1f\n\n", 100 * mean(is.na(w$sh_short) | w$sh_short == 0, na.rm = TRUE)))

## ---------- 3. Connectivity files: year-pair measures ----------
for (layer in c("edu2", "gender")) {
  k <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer))))
  pairs <- paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011"))
  cat(sprintf("== connectivity_%s: %d firm-layer rows\n", layer, nrow(k)))
  cat("   missingness by year-pair (%):", sapply(pairs, function(p) round(100 * mean(is.na(k[[p]])), 1)), "\n")
  cc <- cor(k[, ..pairs], use = "pairwise.complete.obs")
  cat("   corr across year pairs (levels): min offdiag =", round(min(cc[upper.tri(cc)]), 3),
      " max =", round(max(cc[upper.tri(cc)]), 3), "\n")
  ## check _n = mean of available pairs?
  k[, mean_pairs := rowMeans(.SD, na.rm = TRUE), .SDcols = pairs]
  cat(sprintf("   layer_treat_pw_n vs mean of pairs: corr=%.4f, max abs diff=%.5f\n",
      cor(k$layer_treat_pw_n, k$mean_pairs, use = "complete.obs"),
      max(abs(k$layer_treat_pw_n - k$mean_pairs), na.rm = TRUE)))
  cat(sprintf("   count var (# pairs available): "))
  print(table(k$layer_treat_pw_n_count_n, useNA = "ifany"))
  cat("\n")
}

## ---------- 4. Firm panel: stayers/switchers wages ----------
fp <- fp_small[year >= 2009 & lagos_sample_avg == 1]
cat("== firm panel (lagos_sample_avg==1, 2009+):", nrow(fp), "rows,", uniqueN(fp$identificad), "firms\n")
for (v in c("lr_remdezr_w", "lr_remdezr_stayers", "lr_remdezr_switchers")) {
  cat(sprintf("   %-22s missing %.1f%%  mean %.3f  (BRL %s)\n", v,
      100 * mean(is.na(fp[[v]])), mean(fp[[v]], na.rm = TRUE),
      format(round(exp(mean(fp[[v]], na.rm = TRUE))), big.mark = ",")))
}
cat(sprintf("   corr(stayers, firm avg)=%.3f | corr(switchers, firm avg)=%.3f | corr(stayers, switchers)=%.3f\n",
    cor(fp$lr_remdezr_stayers, fp$lr_remdezr_w, use = "complete.obs"),
    cor(fp$lr_remdezr_switchers, fp$lr_remdezr_w, use = "complete.obs"),
    cor(fp$lr_remdezr_stayers, fp$lr_remdezr_switchers, use = "complete.obs")))
cat(sprintf("   stayer premium (mean stayers - switchers): %.3f log points\n",
    mean(fp$lr_remdezr_stayers - fp$lr_remdezr_switchers, na.rm = TRUE)))
## missing by year (composition of the two series)
cat("   pct missing switchers by year:\n")
print(fp[, .(pct_na_switch = round(100 * mean(is.na(lr_remdezr_switchers)), 1),
             pct_na_stay = round(100 * mean(is.na(lr_remdezr_stayers)), 1)), by = year][order(year)])

## turnover variables (candidate outcomes)
for (v in c("quits", "layoffs", "separations", "hiring")) {
  x <- fp[[v]]
  cat(sprintf("   %-12s missing %.1f%%  mean %.3f  p95 %.3f  max %.2f\n", v,
      100 * mean(is.na(x)), mean(x, na.rm = TRUE), quantile(x, .95, na.rm = TRUE), max(x, na.rm = TRUE)))
}

## ---------- 5. Group employment shares (edu2) for size interaction ----------
o <- as.data.table(read_dta(file.path(DATA, "firm_layer_outcomes_edu2.dta")))
e <- o[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
e <- dcast(e, identificad ~ layer_id, value.var = "E")
e[, s_no := no_hs / (no_hs + has_hs)]
cat("\n== edu2 pre-period share of no_hs workers (firms):\n")
print(round(quantile(e$s_no, c(.05, .25, .5, .75, .95), na.rm = TRUE), 3))

## ---------- 6. same/cross-layer treated flows (availability note) ----------
k <- as.data.table(read_dta(file.path(DATA, "firm_layer_connectivity_edu2.dta"),
     col_select = c("layer_treat_pw_n", "sametreat_pw_n", "crosstreat_pw_n")))
k2 <- k[complete.cases(k)]
cat(sprintf("\n== same/cross split (edu2): corr(same+cross, total)=%.4f | mean share same=%.2f\n",
    cor(k2$sametreat_pw_n + k2$crosstreat_pw_n, k2$layer_treat_pw_n),
    mean(k2$sametreat_pw_n / pmax(k2$layer_treat_pw_n, 1e-12))))
sink()
