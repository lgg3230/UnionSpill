# Cross-check of 3252_drdid.do against the R package DRDID (Sant'Anna & Zhao).
#
# Re-estimates every pooled-post 2x2 (design x outcome) from the firm-level file
# 3252 saves, with the same sample flags and covariates, and compares the ATT and
# SE to Tables/drdid/results_drdid.csv.
#   Stata dr_drimp  <-> DRDID::drdid(estMethod = "imp")
#   Stata dr_dripw  <-> DRDID::drdid(estMethod = "trad")
#   Stata dr_reg    <-> DRDID::ordid
#   Stata dr_stdipw <-> DRDID::ipwdid(normalized = TRUE)
# Output: Tables/drdid/crosscheck_drdid_R.csv
# Usage:  Rscript Programs/analysis/drdid/3253_drdid_crosscheck.R   (from the project root)

suppressPackageStartupMessages({
  library(haven)
  library(DRDID)
})

args <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", args[grep("^--file=", args)])))
root <- normalizePath(file.path(here, "..", "..", ".."))

firm  <- as.data.frame(read_dta(file.path(root, "Data", "RAIS_aux", "drdid_firm_wide.dta")))
stata <- read.csv2(file.path(root, "Tables", "drdid", "results_drdid.csv"),
                   stringsAsFactors = FALSE, dec = ".")
stata$b  <- as.numeric(stata$b)
stata$se <- as.numeric(stata$se)

outcomes <- c(w = "lr_remdezr_w", hw = "lr_remdezr_h_w", emp = "l_firm_emp", cl = "numb_clauses")
treat_of <- function(ds) if (ds %in% c("dA", "dC")) "treat_ultra" else "exposed"

xform <- function(tag) {
  own <- c(w = "lr_remdezr_w_pre4", hw = "lr_remdezr_h_w_pre4", emp = NA, cl = "numb_clauses_pre4")[[tag]]
  v <- c(own, "l_firm_emp_pre4", "totalflows_pw_pre_07_114", "month0", "uf", "ind2")
  v <- v[!is.na(v)]
  as.formula(paste("~", paste0("factor(", v, ")", collapse = " + ")))
}

flags <- grep("^s_", names(firm), value = TRUE)
rows <- list()
for (f in flags) {
  parts <- strsplit(sub("^s_", "", f), "_")[[1]]
  ds <- parts[1]; tag <- parts[2]
  sub <- firm[firm[[f]] == 1, ]
  sub$D <- sub[[treat_of(ds)]]
  long <- rbind(
    data.frame(sub, t = 0, y = sub[[paste0("y_", tag, "_2")]]),
    data.frame(sub, t = 1, y = sub[[paste0("y_", tag, "_3")]])
  )
  fx <- xform(tag)
  fits <- list(
    dr_drimp  = function() drdid(yname = "y", tname = "t", idname = "fid", dname = "D", xformla = fx,
                                 data = long, panel = TRUE, estMethod = "imp"),
    dr_dripw  = function() drdid(yname = "y", tname = "t", idname = "fid", dname = "D", xformla = fx,
                                 data = long, panel = TRUE, estMethod = "trad"),
    dr_reg    = function() ordid(yname = "y", tname = "t", idname = "fid", dname = "D", xformla = fx,
                                 data = long, panel = TRUE),
    dr_stdipw = function() ipwdid(yname = "y", tname = "t", idname = "fid", dname = "D", xformla = fx,
                                  data = long, panel = TRUE, normalized = TRUE)
  )
  for (m in names(fits)) {
    r <- tryCatch(fits[[m]](), error = function(e) NULL)
    s <- stata[stata$design == ds & stata$outcome == outcomes[[tag]] &
               stata$estimand == "post" & stata$estimator == m, ]
    rows[[length(rows) + 1]] <- data.frame(
      design = ds, outcome = outcomes[[tag]], estimator = m,
      b_stata = if (nrow(s)) s$b else NA, b_R = if (is.null(r)) NA else r$ATT,
      se_stata = if (nrow(s)) s$se else NA, se_R = if (is.null(r)) NA else r$se
    )
  }
}
out <- do.call(rbind, rows)
out$b_diff <- out$b_R - out$b_stata
write.csv2(out, file.path(root, "Tables", "drdid", "crosscheck_drdid_R.csv"), row.names = FALSE)
print(format(out, digits = 5), row.names = FALSE)
cat("Max |b_R - b_stata|:", max(abs(out$b_diff), na.rm = TRUE), "\n")
