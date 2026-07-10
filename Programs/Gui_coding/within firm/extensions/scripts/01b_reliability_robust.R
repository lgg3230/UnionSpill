## E1b — stress-test the reliability finding:
##  - Pearson AND Spearman; winsorized versions
##  - early/late split AND odd/even split (guards against secular drift in exposure)
##  - benchmark: reliability of BETWEEN-firm variation (firm mean / firm-level connectivity)
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")
wins <- function(x, p = .99) { q <- quantile(x, c(1 - p, p), na.rm = TRUE); pmin(pmax(x, q[1]), q[2]) }

out <- list()
for (layer in c("edu2", "gender")) {
  d <- load_layer(layer)
  k <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer)),
       col_select = c("identificad", "layer_id", paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")))))
  setnames(k, paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")), paste0("p", 1:4))
  ## keep cells in the spillover sample (one row per firm-layer)
  cells <- unique(d[s_base == TRUE, .(identificad, layer_id)])
  k <- merge(k, cells, by = c("identificad", "layer_id"))
  ## employment shares for firm-level aggregation
  e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
  k <- merge(k, e, by = c("identificad", "layer_id"), all.x = TRUE)

  splits <- list(early_late = list(a = c("p1", "p2"), b = c("p3", "p4")),
                 odd_even   = list(a = c("p1", "p3"), b = c("p2", "p4")))
  for (sn in names(splits)) {
    s <- splits[[sn]]
    k[, ca := rowMeans(.SD, na.rm = TRUE), .SDcols = s$a]
    k[, cb := rowMeans(.SD, na.rm = TRUE), .SDcols = s$b]
    k[is.nan(ca), ca := NA_real_]; k[is.nan(cb), cb := NA_real_]
    kk <- k[!is.na(ca) & !is.na(cb)]
    ## within-firm gap (2-group partitions)
    gw <- dcast(kk, identificad ~ layer_id, value.var = c("ca", "cb"))
    gv <- sort(unique(kk$layer_id))
    gw[, ga := get(paste0("ca_", gv[1])) - get(paste0("ca_", gv[2]))]
    gw[, gb := get(paste0("cb_", gv[1])) - get(paste0("cb_", gv[2]))]
    gw <- gw[!is.na(ga) & !is.na(gb)]
    ## between-firm: employment-weighted firm mean
    fb <- kk[!is.na(E), .(fa = weighted.mean(ca, E), fb2 = weighted.mean(cb, E)), by = identificad]
    ## firm-level count of cells (only firms with both groups for gap)
    r <- data.table(layer = layer, split = sn,
      gap_pearson  = cor(gw$ga, gw$gb),
      gap_pearson_w = cor(wins(gw$ga), wins(gw$gb)),
      gap_spearman = cor(gw$ga, gw$gb, method = "spearman"),
      lvl_pearson  = kk[, cor(ca, cb)],
      lvl_spearman = kk[, cor(ca, cb, method = "spearman")],
      firm_pearson = fb[, cor(fa, fb2)],
      firm_pearson_w = fb[, cor(wins(fa), wins(fb2))],
      firm_spearman = fb[, cor(fa, fb2, method = "spearman")],
      n_gap = nrow(gw), n_cells = nrow(kk), n_firms = nrow(fb))
    out[[paste(layer, sn)]] <- r
  }
}
res <- rbindlist(out)
res_round <- copy(res)
num <- names(res)[sapply(res, is.numeric)]
res_round[, (num) := lapply(.SD, function(x) round(x, 3)), .SDcols = num]
print(res_round)
fwrite(res, file.path(OUT, "e1b_reliability_robust.csv"))
cat("\nInterpretation guide: 'gap_*' = reliability of the WITHIN-firm identifying variation;\n'firm_*' = reliability of the BETWEEN-firm variation (what the firm-level result uses).\nSpearman-Brown for the 4-pair average: 2r/(1+r).\n")
