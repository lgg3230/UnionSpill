# ------------------------------------------------------------------------------
# check/verify.R -- confirm Tables A6 and A8 reproduce the original Stata output.
#
#   cd within_firm_final && Rscript check/verify.R
#
# A6 and A8 are firm-level objects and are NOT affected by the Table A7 revision,
# so they should reproduce the original estimates. The reference CSVs in
# check/reference_stata/ are the Stata output, copied verbatim.
#
# A7 has no external reference: it is the revised specification. Its estimates
# are in output/a7{,_hw}.csv.
# ------------------------------------------------------------------------------
source("R/00_config.R")
REF <- file.path(ROOT, "check", "reference_stata")
reldiff <- function(a, b) { d <- abs(a - b); s <- pmax(abs(a), abs(b))
                            ifelse(s == 0, 0, d / s) }

check1 <- function(f, keys, note = "") {
  A <- fread(file.path(OUT, f)); B <- fread(file.path(REF, f))
  M <- merge(A, B, by = keys, suffixes = c(".a", ".b")); stopifnot(nrow(M) == nrow(B))
  vs <- sub("[.]a$", "", grep("[.]a$", names(M), value = TRUE))
  worst <- 0; wv <- ""; cnt <- TRUE; nc <- 0L
  for (v in vs) {
    x <- M[[paste0(v, ".a")]]; y <- M[[paste0(v, ".b")]]
    if (!is.numeric(x)) next
    ok <- !is.na(x) & !is.na(y); if (!any(ok)) next
    nc <- nc + sum(ok)
    if (v %in% c("n", "firms")) cnt <- cnt && all(x[ok] == y[ok])
    r <- max(reldiff(x[ok], y[ok])); if (r > worst) { worst <- r; wv <- v }
  }
  msg("  %-22s cells=%4d  counts identical=%-5s  max rel diff=%.2e (%s)%s",
      f, nc, cnt, worst, wv, note)
  invisible(worst)
}

msg("")
msg("=== Tables A6 and A8 vs the original Stata output ===")
for (f in c("a6_group.csv","a6_group_hw.csv"))        check1(f, c("partition","group"))
for (f in c("a6_partition.csv","a6_partition_hw.csv")) check1(f, c("partition"))
for (f in c("a8.csv","a8_hw.csv"))
  check1(f, c("partition","col","p90","outcome"), "  <- see note")

msg("")
msg("=== Table A7 columns (1) and (4) vs the original Stata output ===")
msg("  (firm-level regressions; the revision touches only the group columns)")
for (f in c("a7.csv", "a7_hw.csv")) {
  A <- fread(file.path(OUT, f))[col %in% c("firm_full", "firm")]
  B <- fread(file.path(REF, f))[col %in% c("firm_full", "firm")]
  M <- merge(A, B, by = c("partition","col","outcome"), suffixes = c(".a",".b"))
  stopifnot(nrow(M) == nrow(B))
  w <- 0; wv <- ""; cnt <- TRUE
  for (v in c("b","se","bpre","sepre")) {
    r <- max(reldiff(M[[paste0(v,".a")]], M[[paste0(v,".b")]]))
    if (r > w) { w <- r; wv <- v }
  }
  for (v in c("n","firms")) cnt <- cnt && all(M[[paste0(v,".a")]] == M[[paste0(v,".b")]])
  msg("  %-22s rows=%2d  counts identical=%-5s  max rel diff=%.2e (%s)",
      f, nrow(M), cnt, w, wv)
}

msg("")
msg("  Note on A8: the rows Table A8 prints are col == \"firm\". Those reproduce")
msg("  the Stata output exactly. Larger relative differences, all below 1e-5 in")
msg("  ABSOLUTE terms, occur only in the col == \"g1\"/\"g2\" rows, which the")
msg("  engine computes but no table prints.")
msg("")
A <- fread(file.path(OUT,"a8.csv")); B <- fread(file.path(REF,"a8.csv"))
M <- merge(A[col=="firm"], B[col=="firm"], by=c("partition","col","p90","outcome"),
           suffixes=c(".a",".b"))
vs <- c("b1","se1","b2","se2","bp1","sp1","bp2","sp2","peq")
w <- max(sapply(vs, function(v) max(reldiff(M[[paste0(v,".a")]], M[[paste0(v,".b")]]))))
msg("  A8, printed rows only (col == \"firm\"): max rel diff = %.2e", w)
msg("")
