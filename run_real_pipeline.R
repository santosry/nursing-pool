# run_real_pipeline.R - Pipeline completo com dados MIMIC-IV Demo
suppressPackageStartupMessages({library(here);library(data.table);library(ggplot2);library(lubridate)})
source(here::here("config.R"))
source(here::here("theme_cellpress.R"))
source(here::here("02_nursing_mapping.R"))
source(here::here("03_nanda_diagnostics.R"))
source(here::here("04_noc_outcomes.R"))
source(here::here("05_nic_interventions.R"))
source(here::here("06_nursing_db.R"))
source(here::here("07_statistical_analysis.R"))
source(here::here("08_visualization.R"))

# Carregar dados reais cacheados
data <- readRDS(file.path(PATHS$cache_dir, "loaded_data_real.rds"))
cat(sprintf("\n[DADOS REAIS] %d pacientes | %d admissões | %d ICU stays | %d chartevents\n",
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

# Banco
db_path <- build_nursing_database(data, nanda, noc, nic)

# Estatísticas
stat_results <- main_statistical_analysis(nanda, noc, nic, data)

# Figuras
gerar_todas_figuras(nanda, noc, nic, stat_results)

cat("\n[DONE] Pipeline completo executado com dados reais.\n")
