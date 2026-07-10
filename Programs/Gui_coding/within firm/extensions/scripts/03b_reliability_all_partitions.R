## E3b — split-half reliability of the within-firm identifying variation for ALL
## partitions (deviation-from-firm-mean version, works for 2- and 4-group partitions).
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

out <- list()
for (layer in c("edu2", "gender", "race", "occ4", "ten2")) {
  d <- load_layer(layer)
  k <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer)),
       col_select = c("identificad", "layer_id", paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")))))
  setnames(k, paste0("layer_treat_pw_", c("0708", "0809", "0910", "1011")), paste0("p", 1:4))
  cells <- unique(d[s_base == TRUE, .(identificad, layer_id)])
  k <- merge(k, cells, by = c("identificad", "layer_id"))
  e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
  k <- merge(k, e, by = c("identificad", "layer_id"), all.x = TRUE)
  k[, ca := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p1", "p2")]
  k[, cb := rowMeans(.SD, na.rm = TRUE), .SDcols = c("p3", "p4")]
  k[is.nan(ca), ca := NA_real_]; k[is.nan(cb), cb := NA_real_]
  kk <- k[!is.na(ca) & !is.na(cb) & !is.na(E)]
  kk[, n_g := .N, by = identificad]
  kk <- kk[n_g >= 2]
  kk[, dev_a := ca - weighted.mean(ca, E), by = identificad]
  kk[, dev_b := cb - weighted.mean(cb, E), by = identificad]
  r <- data.table(layer = layer,
    dev_pearson  = kk[, cor(dev_a, dev_b)],
    dev_spearman = kk[, cor(dev_a, dev_b, method = "spearman")],
    n_cells = nrow(kk), n_firms = uniqueN(kk$identificad))
  out[[layer]] <- r
}
res <- rbindlist(out)
res[, sb_pearson := round(2 * dev_pearson / (1 + dev_pearson), 3)]
res[, c("dev_pearson", "dev_spearman") := lapply(.SD, round, 3), .SDcols = c("dev_pearson", "dev_spearman")]
print(res)
fwrite(res, file.path(OUT, "e3b_reliability_all.csv"))
