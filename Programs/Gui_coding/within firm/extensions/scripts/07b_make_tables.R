## Emit paper-style markdown tables for the early/late/full comparison, both normalizations.
suppressMessages(library(data.table))
OUT <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/output"
x <- readRDS(file.path(OUT, "e7_halves.rds")); r <- as.data.table(x$res); P90 <- x$P90
OUTCOMES <- c("lr_remdezr_w","lr_remdezr_h_w","l_firm_emp","numb_clauses")
OLAB <- c("Log wages","Log hourly wages","Log employment","Clause count")
MLAB <- c(official="Main: official measure (4-yr)", full="Full aggregate (4-yr)",
          early="First half (2007--09 flows)", late="Second half (2009--11 flows)")
star <- function(t){p<-2*pnorm(-abs(t)); if(p<.01)"***" else if(p<.05)"**" else if(p<.10)"*" else ""}
fmtc <- function(b,se,dec=4){f<-paste0("%.",dec,"f"); sprintf(paste0(f,"%s"),b,star(b/se))}
fmts <- function(se,dec=4){sprintf(paste0("(%.",dec,"f)"),se)}

emit <- function(scale_mode){        # "own" or "main"
  scl <- function(m) if(scale_mode=="own") P90[[m]] else P90[["full"]]
  L <- c(sprintf("| | %s |", paste(OLAB, collapse=" | ")),
         paste0("|", paste(rep("---", length(OLAB)+1), collapse="|"), "|"))
  for(m in names(MLAB)){
    dec <- 4
    rowc <- rows <- rowp <- rowps <- character(0)
    esf <- nn <- ee <- character(0)
    for(o in OUTCOMES){
      z <- r[outcome==o & measure==m]
      b <- z$b_raw*scl(m); se <- z$se_raw*scl(m); pb <- z$pb_raw*scl(m); ps <- z$pse_raw*scl(m)
      dd <- if(o=="numb_clauses") 3 else 4
      rowc <- c(rowc, fmtc(b,se,dd)); rows <- c(rows, fmts(se,dd))
      rowp <- c(rowp, fmtc(pb,ps,dd)); rowps <- c(rowps, fmts(ps,dd))
      esf <- c(esf, sprintf("%.2f", z$esF)); nn <- c(nn, format(z$n,big.mark=",")); ee <- c(ee, format(z$est,big.mark=","))
    }
    L <- c(L, sprintf("| **%s** | | | | |", MLAB[[m]]),
           sprintf("| Post $\\times$ Connectivity | %s |", paste(rowc, collapse=" | ")),
           sprintf("| | %s |", paste(rows, collapse=" | ")),
           sprintf("| Pre-trend (placebo) | %s |", paste(rowp, collapse=" | ")),
           sprintf("| | %s |", paste(rowps, collapse=" | ")),
           sprintf("| Joint pre-trend $p$ | %s |", paste(esf, collapse=" | ")),
           sprintf("| Observations | %s |", paste(nn, collapse=" | ")),
           sprintf("| Establishments | %s |", paste(ee, collapse=" | ")))
  }
  paste(L, collapse="\n")
}
cat("### TABLE OWN-P90\n\n"); cat(emit("own")); cat("\n\n### TABLE MAIN-P90\n\n"); cat(emit("main")); cat("\n")
writeLines(c("<!-- OWN -->", emit("own"), "", "<!-- MAIN -->", emit("main")), file.path(OUT,"e7_tables.md"))
## quick numeric summary for prose
cat("\n\nP90s: ", paste(sprintf("%s=%.5f",names(P90),unlist(P90)),collapse="  "), "\n")
