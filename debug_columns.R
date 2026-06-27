# debug_columns.R
library(data.table)
ce <- fread("C:/Users/oorie/OneDrive/Documentos/TRABALHOS/PROVA DE CONCEITO/mimic-iv-clinical-database-demo-2.2/icu/chartevents.csv.gz", nrows=2)
cat("Chartevents columns:\n")
cat(paste(names(ce), collapse=", "), "\n")
cat("Has charttime:", "charttime" %in% names(ce), "\n")
cat("Has stay_id:", "stay_id" %in% names(ce), "\n")
cat("Has itemid:", "itemid" %in% names(ce), "\n")
cat("Has valuenum:", "valuenum" %in% names(ce), "\n")
# Check a few items
cat("\nSample itemids:", paste(head(unique(ce$itemid), 10), collapse=", "), "\n")

# Also check inputevents
ie <- fread("C:/Users/oorie/OneDrive/Documentos/TRABALHOS/PROVA DE CONCEITO/mimic-iv-clinical-database-demo-2.2/icu/inputevents.csv.gz", nrows=2)
cat("\nInputevents columns:\n")
cat(paste(names(ie), collapse=", "), "\n")
