# Setup renv
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org")
renv::init(bare = TRUE, force = TRUE, restart = FALSE)
renv::install(c(
  "here", "data.table", "lubridate", "ggplot2", "RSQLite", "DBI", "duckdb",
  "survival", "survminer", "pROC", "reshape2", "scales", "sysfonts", "FSA",
  "xgboost", "ranger", "glmnet", "shapviz", "fastshap", "vip",
  "yardstick", "rsample", "recipes", "parsnip", "workflows", "tune",
  "themis", "DALEX",
  "dplyr", "tidyr", "purrr", "readr", "stringr", "janitor",
  "knitr", "rmarkdown"
), prompt = FALSE)
renv::snapshot(force = TRUE)
message("renv.lock created successfully")
