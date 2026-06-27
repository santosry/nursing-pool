# Capture versions
cat("=== AMBIENTE ===\n")
cat("R version:", R.version.string, "\n")
cat("OS:", Sys.info()["sysname"], Sys.info()["release"], "\n")
cat("Date:", as.character(Sys.time()), "\n")

cat("\n=== PACKAGES ===\n")
pkgs <- c("data.table","ggplot2","RSQLite","DBI","duckdb","survival",
          "survminer","pROC","reshape2","scales","here","lubridate",
          "FSA","sysfonts")
for(p in pkgs) {
  v <- tryCatch(as.character(packageVersion(p)), error=function(e) "NOT FOUND")
  cat(sprintf("%-20s: %s\n", p, v))
}
cat("\n=== SYSTEM ===\n")
cat("Git:", tryCatch(system("git --version", intern=TRUE), error=function(e) "not found"), "\n")
cat("Docker:", tryCatch(system("docker --version", intern=TRUE), error=function(e) "not found"), "\n")
