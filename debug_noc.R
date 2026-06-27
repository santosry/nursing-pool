# debug_noc.R
library(here); library(data.table)
source(here::here("config.R"))
source(here::here("02_nursing_mapping.R"))

data <- readRDS(file.path(PATHS$cache_dir, "loaded_data_real.rds"))
ce <- data$icu$chartevents

cat("Chartevents columns:", paste(names(ce), collapse=", "), "\n")
cat("Rows:", nrow(ce), "\n")
cat("Has charttime:", "charttime" %in% names(ce), "\n")

# Check heart rate itemids
hr_items <- ITEM_IDS$vitals$heart_rate
cat("HR itemids:", paste(hr_items, collapse=", "), "\n")
hr_data <- ce[itemid %in% hr_items]
cat("HR rows:", nrow(hr_data), "\n")
if(nrow(hr_data) > 0) {
  print(head(hr_data[, .(stay_id, subject_id, hadm_id, charttime, valuenum)], 5))
}
