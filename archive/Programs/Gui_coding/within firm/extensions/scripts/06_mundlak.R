## E6 — Common vs idiosyncratic pass-through (Mundlak-style decomposition):
## C_g = chat_F (employment-weighted firm average) + dev_g (within-firm deviation).
## y_g = a (chat_F x Post) + b (dev_g x Post) + FE. "Firms transmit the common
## component and ignore the idiosyncratic component" -> a ~ firm-level effect, b ~ 0.
## NOTE from E1: dev_g has split-half reliability ~0.1 -> b is attenuated toward 0
## mechanically; interpret jointly with E1.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

res <- list()
for (layer in c("edu2", "gender")) {
  d <- load_layer(layer)
  e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
  e[, s := E / sum(E), by = identificad]
  d <- merge(d, e[, .(identificad, layer_id, s)], by = c("identificad", "layer_id"), all.x = TRUE)
  cellconn <- unique(d[!is.na(conn) & !is.na(s), .(identificad, layer_id, conn, s)])
  ch <- cellconn[, .(chat = sum(s * conn) / sum(s), ng = .N), by = identificad]
  d <- merge(d, ch[ng == 2, .(identificad, chat)], by = "identificad", all.x = TRUE)
  d[, dev := conn - chat]
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    d2 <- samp(d, y)[!is.na(chat)]
    add_fe_cols(d2)
    d2[, chat_t := chat * treat_year]; d2[, dev_t := dev * treat_year]
    d2[, chat_p := chat * placebo_year]; d2[, dev_p := dev * placebo_year]
    fes <- fes_for("overall", y)
    r <- run_did(d2, y, c("chat_t", "dev_t"), c("chat_p", "dev_p"), fes)
    cat(sprintf("[%s] %-16s common=%s idio=%s | pre: %s / %s | N=%d F=%d\n",
        layer, y, fmt(r$main["chat_t", 1], r$main["chat_t", 2]), fmt(r$main["dev_t", 1], r$main["dev_t", 2]),
        fmt(r$pre["chat_p", 1], r$pre["chat_p", 2]), fmt(r$pre["dev_p", 1], r$pre["dev_p", 2]), r$n, r$firms))
    res[[paste(layer, y)]] <- data.table(layer = layer, outcome = y,
      b_common = r$main["chat_t", 1], se_common = r$main["chat_t", 2],
      b_idio = r$main["dev_t", 1], se_idio = r$main["dev_t", 2],
      b_common_pre = r$pre["chat_p", 1], se_common_pre = r$pre["chat_p", 2],
      b_idio_pre = r$pre["dev_p", 1], se_idio_pre = r$pre["dev_p", 2],
      n = r$n, firms = r$firms)
  }
}
saveRDS(rbindlist(res), file.path(OUT, "e6_mundlak.rds"))
cat("Saved e6_mundlak.rds\n")
