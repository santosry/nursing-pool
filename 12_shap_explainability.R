# =============================================================================
# 12_shap_explainability.R — Explicabilidade SHAP dos Modelos Preditivos
# =============================================================================
# Calcula valores SHAP para o melhor modelo (XGBoost) e gera visualizações
# de importância e explicação. Usa fastshap + shapviz.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(data.table)
  library(ggplot2)
  library(xgboost)
  library(fastshap)
  library(shapviz)
})

source(here::here("config.R"))
source(here::here("theme_cellpress.R"))

message("\n[SHAP] ===== EXPLICABILIDADE SHAP =====")

# Carregar modelos e dados
ml_results <- readRDS(file.path(PATHS$output_dir, "ml", "ml_models.rds"))
split_info <- readRDS(file.path(PATHS$output_dir, "ml", "data_split.rds"))
data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))

# Reconstruir dados de teste
source(here::here("02_nursing_mapping.R"))
source(here::here("03_nanda_diagnostics.R"))
source(here::here("04_noc_outcomes.R"))
source(here::here("05_nic_interventions.R"))

nanda <- extract_nanda_diagnostics(data)
nanda <- process_nanda_diagnostics(nanda, data)
noc   <- extract_noc_outcomes(data)
noc   <- process_noc_outcomes(noc, data)
nic   <- extract_nic_interventions(data)
nic   <- process_nic_interventions(nic, data)

# Reconstruir model_data (mesmo código do 11_ml_outcomes.R)
adm <- data$hosp$admissions[, .(hadm_id, subject_id, admittime, dischtime,
                                admission_type, discharge_location, insurance)]
adm[, mortality := discharge_location == "DEAD/EXPIRED"]
adm[, los_days := as.numeric(difftime(dischtime, admittime, units = "days"))]
pat <- data$hosp$patients[, .(subject_id, gender, anchor_age)]

nanda_features <- nanda[, .(
  n_nanda = .N, n_domains = uniqueN(nanda_domain),
  has_cardiac = as.integer(any(nanda_domain == "Cardiovascular")),
  has_comfort = as.integer(any(nanda_domain == "Conforto")),
  has_safety = as.integer(any(nanda_domain %like% "Seguran")),
  has_nutrition = as.integer(any(nanda_domain %like% "Nutri")),
  has_activity = as.integer(any(nanda_domain == "Atividade Repouso")),
  has_cognition = as.integer(any(nanda_domain %like% "Percep")),
  has_elimination = as.integer(any(nanda_domain %like% "Elimin")),
  has_critical = as.integer(any(severity == "Crítico")),
  has_severe = as.integer(any(severity == "Severo"))
), by = hadm_id]

noc_features <- noc[!is.na(hadm_id), .(
  n_noc_measurements = .N,
  n_noc_abnormal = sum(abnormal, na.rm = TRUE),
  pct_noc_abnormal = round(100 * sum(abnormal, na.rm = TRUE) / pmax(1, .N), 1)
), by = hadm_id]

nic_features <- nic[, .(n_nic = .N, n_nic_types = uniqueN(nic_label)), by = hadm_id]

model_data <- merge(adm, pat, by = "subject_id", all.x = TRUE)
model_data <- merge(model_data, nanda_features, by = "hadm_id", all.x = TRUE)
model_data <- merge(model_data, noc_features, by = "hadm_id", all.x = TRUE)
model_data <- merge(model_data, nic_features, by = "hadm_id", all.x = TRUE)

for (col in names(model_data)) {
  if (is.numeric(model_data[[col]])) {
    set(model_data, which(is.na(model_data[[col]])), col, 0)
  }
}

model_data[, gender_male := as.integer(gender == "M")]
model_data[, admission_emergency := as.integer(admission_type == "EMERGENCY")]

exclude_cols <- c("subject_id", "hadm_id", "gender", "admission_type",
                  "discharge_location", "dischtime", "admittime", "insurance")
feature_cols <- intersect(split_info$feature_cols, names(model_data))

message(sprintf("[SHAP] %d features disponíveis para SHAP", length(feature_cols)))

# Dados de teste (apenas 500 amostras para SHAP, por performance)
test_subjects <- split_info$test_subjects
test_data <- model_data[subject_id %in% test_subjects]
set.seed(20240101)
shap_sample <- test_data[sample(.N, min(500, .N))]

test_x <- as.matrix(shap_sample[, ..feature_cols])
test_y <- shap_sample$mortality

# --- SHAP via fastshap -------------------------------------------------------
message("[SHAP] Calculando valores SHAP (XGBoost, 500 amostras)...")
xgb_model <- ml_results$xgb$model

# Predict function for SHAP
predict_fn <- function(object, newdata) {
  predict(object, xgb.DMatrix(as.matrix(newdata)))
}

shap_values <- explain(
  object = xgb_model,
  X = as.data.frame(test_x),
  pred_wrapper = predict_fn,
  nsim = 30,
  adjust = TRUE
)

message(sprintf("[SHAP] SHAP calculado: %d amostras × %d features",
                nrow(shap_values), ncol(shap_values)))

# --- Visualizações SHAP via shapviz -----------------------------------------
shp <- shapviz(shap_values, X = test_x)

fig_dir <- file.path(PATHS$output_dir, "ml", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# SHAP global importance
message("[SHAP] Gerando gráficos...")

# 1. Importância global (bar plot)
sv_importance(shp, kind = "bar", show_numbers = TRUE) +
  labs(title = "Importância Global SHAP — XGBoost",
       subtitle = "Contribuição média absoluta de cada feature para a predição",
       caption = "IMPORTANTE: importância preditiva NÃO implica efeito causal") +
  theme_cellpress(base_size = 12)
ggsave(file.path(fig_dir, "SHAP_Global_Importance.pdf"), width = 9, height = 6, device = "pdf")
ggsave(file.path(fig_dir, "SHAP_Global_Importance.png"), width = 9, height = 6, dpi = 300)

# 2. Beeswarm (distribuição completa)
sv_importance(shp, kind = "beeswarm") +
  labs(title = "SHAP Beeswarm — Contribuição por Feature (XGBoost)",
       subtitle = "Cada ponto = 1 paciente. Vermelho = valor alto da feature, Azul = baixo",
       caption = "Eixo X: contribuição SHAP para log-odds de mortalidade") +
  theme_cellpress(base_size = 11)
ggsave(file.path(fig_dir, "SHAP_Beeswarm.pdf"), width = 10, height = 6, device = "pdf")
ggsave(file.path(fig_dir, "SHAP_Beeswarm.png"), width = 10, height = 6, dpi = 300)

# 3. Dependence plots para top 4 features
top_features <- names(sort(colMeans(abs(as.matrix(shap_values))), decreasing = TRUE))[1:4]
for (feat in top_features) {
  sv_dependence(shp, v = feat, color_var = NULL) +
    labs(title = paste("SHAP Dependence —", feat),
         subtitle = "Relação entre valor da feature e contribuição SHAP",
         x = feat, y = "Valor SHAP") +
    theme_cellpress(base_size = 12)
  ggsave(file.path(fig_dir, paste0("SHAP_Dependence_", gsub("[^a-zA-Z0-9]", "_", feat), ".pdf")),
         width = 7, height = 5, device = "pdf")
  ggsave(file.path(fig_dir, paste0("SHAP_Dependence_", gsub("[^a-zA-Z0-9]", "_", feat), ".png")),
         width = 7, height = 5, dpi = 300)
}

# 4. Waterfall para exemplo individual
sv_waterfall(shp, row_id = 1) +
  labs(title = "SHAP Waterfall — Exemplo Individual (Paciente 1 do teste)",
       subtitle = "Decomposição da predição do baseline até o valor final") +
  theme_cellpress(base_size = 11)
ggsave(file.path(fig_dir, "SHAP_Waterfall_Example.pdf"), width = 8, height = 5, device = "pdf")
ggsave(file.path(fig_dir, "SHAP_Waterfall_Example.png"), width = 8, height = 5, dpi = 300)

# --- Salvar SHAP values ------------------------------------------------------
saveRDS(shap_values, file.path(PATHS$output_dir, "ml", "shap_values.rds"))

# --- Tabela de importância ---------------------------------------------------
importance <- data.table(
  Feature = colnames(test_x),
  Mean_Abs_SHAP = colMeans(abs(as.matrix(shap_values)))
)[order(-Mean_Abs_SHAP)]

fwrite(importance, file.path(PATHS$output_dir, "ml", "shap_importance.csv"))

message("\nImportância SHAP (top 10):")
print(head(importance, 10))

message("[SHAP] ===== FIM DA EXPLICABILIDADE =====")
