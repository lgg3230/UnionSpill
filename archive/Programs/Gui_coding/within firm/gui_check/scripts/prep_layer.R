## Shared prep: replicate 01a/02a data construction in R (edu2 / gender)
suppressMessages({library(haven); library(data.table); library(fixest)})

DATA <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/Luis_og/data"

# Stata type-2 percentile (summarize/detail, _pctile, pctile)
stata_pctile <- function(x, p) {
  x <- sort(x[!is.na(x)]); n <- length(x)
  np <- n * p / 100
  if (abs(np - round(np)) < 1e-9) (x[np] + x[min(np + 1, n)]) / 2 else x[ceiling(np)]
}
# egen cut, group(4): bins 0-3 with [q_i, q_{i+1}) intervals
stata_cut4 <- function(x) {
  br <- sapply(c(25, 50, 75), function(p) stata_pctile(x, p))
  findInterval(x, br)
}

prep_layer <- function(layer) {
  out <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_outcomes_%s.dta", layer))))
  out <- out[year >= 2009]
  cn <- as.data.table(read_dta(file.path(DATA, sprintf("firm_layer_connectivity_%s.dta", layer)),
        col_select = c("identificad", "layer_id", "layer_treat_pw_n", "totalflows_layer_pw_n")))
  fp <- as.data.table(read_dta(file.path(DATA, "lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
        col_select = c("identificad", "year", "treat_ultra", "in_balanced_panel", "lagos_sample_avg",
                       "firm_emp", "industry1", "mode_base_month", "microregion")))
  for (v in names(fp)) if (inherits(fp[[v]], "haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
  d <- merge(out, cn, by = c("identificad", "layer_id"), all.x = TRUE)
  d <- merge(d, fp, by = c("identificad", "year"), all.x = TRUE)
  d <- d[lagos_sample_avg == 1]

  # above-median pre-treatment firm employment
  d[, avg_pre_firm_emp := {m <- mean(firm_emp[year %in% 2009:2011], na.rm = TRUE);
                           if (is.nan(m)) NA_real_ else m}, by = identificad]
  firms <- d[, .(avg_pre = avg_pre_firm_emp[1], bal = in_balanced_panel[1],
                 tu = treat_ultra[1]), by = identificad]
  med <- stata_pctile(firms[bal == 1 & tu == 0, avg_pre], 50)
  d[, in_above_med_firm := fifelse(!is.na(avg_pre_firm_emp), as.integer(avg_pre_firm_emp > med), NA_integer_)]

  d[, treat_year := as.integer(year >= 2012)]
  d[, placebo_year := as.integer(year < 2011)]
  d[, s_base := lagos_sample_avg == 1 & treat_ultra == 0 & in_balanced_panel == 1]
  d[, s_abv := s_base & in_above_med_firm == 1 & !is.na(in_above_med_firm)]

  # pre-treatment bins (computed on year==2009 & in_balanced_panel==1, incl. treated)
  for (v in c("lr_remdezr_layer", "l_layer_emp")) {
    d[, pre_tmp := {m <- mean(get(v)[year %in% 2009:2011], na.rm = TRUE);
                    if (is.nan(m)) NA_real_ else m}, by = .(identificad, layer_id)]
    sel <- d$year == 2009 & d$in_balanced_panel == 1 & !is.na(d$in_balanced_panel) & !is.na(d$pre_tmp)
    br <- sapply(c(25, 50, 75), function(p) stata_pctile(d$pre_tmp[sel], p))
    d[, bin_tmp := NA_integer_]
    d[sel, bin_tmp := findInterval(pre_tmp, br)]
    d[, (paste0(v, "_pre4")) := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L},
      by = .(identificad, layer_id)]
    d[, c("pre_tmp", "bin_tmp") := NULL]
  }
  sel <- d$year == 2009 & d$in_balanced_panel == 1 & !is.na(d$in_balanced_panel) & !is.na(d$totalflows_layer_pw_n)
  br <- sapply(c(25, 50, 75), function(p) stata_pctile(d$totalflows_layer_pw_n[sel], p))
  d[, bin_tmp := NA_integer_]
  d[sel, bin_tmp := findInterval(totalflows_layer_pw_n, br)]
  d[, layer_totalflows_pw_pre4 := {b <- bin_tmp[!is.na(bin_tmp)]; if (length(b)) b[1] else 0L},
    by = .(identificad, layer_id)]
  d[, bin_tmp := NULL]

  d[, firm_layer_id := paste(identificad, layer_id)]
  d
}

# iterative singleton drop over a list of FE columns (mimics reghdfe)
drop_singletons <- function(dt, fe_cols) {
  repeat {
    n0 <- nrow(dt)
    for (fc in fe_cols) {
      dt[, .n_ := .N, by = fc]
      dt <- dt[.n_ > 1]
    }
    dt[, .n_ := NULL]
    if (nrow(dt) == n0) break
  }
  dt
}

# load cached prepped data, or build and cache it
get_prepped <- function(layer, out_dir) {
  f <- file.path(out_dir, sprintf("prepped_%s.rds", layer))
  if (file.exists(f)) readRDS(f) else { d <- prep_layer(layer); saveRDS(d, f); d }
}
