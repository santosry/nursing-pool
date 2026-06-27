# Check ML packages
ml_pkgs <- c("xgboost","ranger","glmnet","shapviz","fastshap","vip",
             "yardstick","rsample","recipes","parsnip","workflows","tune",
             "themis","DALEX","iml","dplyr","tidyr","purrr","readr","stringr",
             "janitor","knitr","rmarkdown")
for(p in ml_pkgs) {
  v <- tryCatch(as.character(packageVersion(p)), error=function(e) "NOT INSTALLED")
  cat(sprintf("%-20s: %s\n", p, v))
}
