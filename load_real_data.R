# load_real_data.R - Carrega dados reais do MIMIC-IV Demo
suppressPackageStartupMessages({library(here);library(data.table);library(lubridate)})
source(here::here("config.R"))
DATA_DIR <- "C:/Users/oorie/OneDrive/Documentos/TRABALHOS/PROVA DE CONCEITO/mimic-iv-clinical-database-demo-2.2"

source(here::here("01_data_access.R"))
data <- load_mimic_csv(DATA_DIR)

cat("\n=== DADOS REAIS MIMIC-IV DEMO ===\n")
for(mod in names(data)) {
  if(is.null(data[[mod]])) next
  for(tbl in names(data[[mod]])) {
    if(is.null(data[[mod]][[tbl]])) next
    cat(sprintf("  %s/%-25s: %s linhas\n", mod, tbl,
                format(nrow(data[[mod]][[tbl]]), big.mark=",")))
  }
}
cat(sprintf("\nPacientes: %d | Admissoes: %d | ICU stays: %d\n",
            nrow(data$hosp$patients), nrow(data$hosp$admissions),
            nrow(data$icu$icustays)))

# Salvar cache
dir.create(file.path(PATHS$cache_dir), showWarnings=FALSE, recursive=TRUE)
saveRDS(data, file.path(PATHS$cache_dir, "loaded_data_real.rds"))
cat("Cache salvo.\n")
