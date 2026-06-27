# run_all_real_v2.R
rm(list=ls())
gc()

suppressPackageStartupMessages({
  library(here); library(data.table); library(ggplot2); library(lubridate)
})

source(here::here("config.R"))
source(here::here("theme_cellpress.R"))

# Source core mapping file FIRST (defines all extract functions)
source(here::here("02_nursing_mapping.R"))
# Source processing files (define process_* and save_* functions)
source(here::here("03_nanda_diagnostics.R"))
source(here::here("04_noc_outcomes.R"))
source(here::here("05_nic_interventions.R"))
source(here::here("06_nursing_db.R"))
source(here::here("07_statistical_analysis.R"))
source(here::here("08_visualization.R"))

cat("\n=== PIPELINE COM DADOS REAIS ===\n")
data <- readRDS(file.path(PATHS$cache_dir, "loaded_data_real.rds"))
cat(sprintf("%d pacientes | %d adm | %d ICU | %d chartevents\n",
    nrow(data$hosp$patients), nrow(data$hosp$admissions),
    nrow(data$icu$icustays), nrow(data$icu$chartevents)))

# NANDA
nanda <- extract_nanda_diagnostics(data)
nanda <- process_nanda_diagnostics(nanda, data)
save_nanda_results(nanda)

# NOC
noc <- extract_noc_outcomes(data)
noc <- process_noc_outcomes(noc, data)
save_noc_results(noc)

# NIC
nic <- extract_nic_interventions(data)
nic <- process_nic_interventions(nic, data)
save_nic_results(nic)

# DB
db_path <- build_nursing_database(data, nanda, noc, nic)

# Stats
stat_results <- main_statistical_analysis(nanda, noc, nic, data)

# Figs
gerar_todas_figuras(nanda, noc, nic, stat_results)

cat(sprintf("\nDONE: NANDA=%d NOC=%d NIC=%d\n", nrow(nanda), nrow(noc), nrow(nic)))
