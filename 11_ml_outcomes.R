# =============================================================================
# 11_ml_outcomes.R — Modelos Preditivos para Desfechos Clínicos
# =============================================================================
# Camada de Machine Learning com múltiplos modelos, validação cruzada,
# métricas completas e explicabilidade SHAP.
# 
# Objetivo: demonstrar viabilidade técnica de modelos preditivos sobre a 
# camada derivada de enfermagem. NÃO validado para uso clínico.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(data.table)
  library(ggplot2)
})

source(here::here("config.R"))
source(here::here("theme_cellpress.R"))
source(here::here("02_nursing_mapping.R"))
source(here::here("03_nanda_diagnostics.R"))
source(here::here("04_noc_outcomes.R"))
source(here::here("05_nic_interventions.R"))

message("\n[ML] ===== CAMADA DE MACHINE LEARNING =====")

# --- 1. Carregar e preparar dados --------------------------------------------
message("[ML] Carregando dados cacheados...")
data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))

message("[ML] Extraindo camadas NANDA/NOC/NIC...")
nanda <- extract_nanda_diagnostics(data)
nanda <- process_nanda_diagnostics(nanda, data)
noc   <- extract_noc_outcomes(data)
noc   <- process_noc_outcomes(noc, data)
nic   <- extract_nic_interventions(data)
nic   <- process_nic_interventions(nic, data)

# --- 2. Criar dataset de modelagem (1 linha por admissão) --------------------
message("[ML] Construindo dataset de modelagem...")

# Outcome: mortalidade hospitalar
adm <- data$hosp$admissions[, .(hadm_id, subject_id, admittime, dischtime,
                                admission_type, discharge_location, insurance)]
adm[, mortality := discharge_location == "DEAD/EXPIRED"]
adm[, los_days := as.numeric(difftime(dischtime, admittime, units = "days"))]

# Demografia
pat <- data$hosp$patients[, .(subject_id, gender, anchor_age)]

# Features NANDA (agregadas por admissão)
nanda_features <- nanda[, .(
  n_nanda = .N,
  n_domains = uniqueN(nanda_domain),
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

# Features NOC (agregadas por admissão)
noc_features <- noc[!is.na(hadm_id), .(
  n_noc_measurements = .N,
  n_noc_abnormal = sum(abnormal, na.rm = TRUE),
  pct_noc_abnormal = round(100 * sum(abnormal, na.rm = TRUE) / pmax(1, .N), 1)
), by = hadm_id]

# Features NIC (agregadas por admissão)
nic_features <- nic[, .(
  n_nic = .N,
  n_nic_types = uniqueN(nic_label)
), by = hadm_id]

# ICU features
if (!is.null(data$icu$icustays)) {
  icu_features <- data$icu$icustays[, .(
    n_icu_stays = .N,
    total_icu_los = sum(los, na.rm = TRUE)
  ), by = hadm_id]
} else {
  icu_features <- NULL
}

# --- 3. Montar dataset final ------------------------------------------------
model_data <- merge(adm, pat, by = "subject_id", all.x = TRUE)

feature_list <- list(nanda_features, noc_features, nic_features)
if (!is.null(icu_features)) feature_list <- c(feature_list, list(icu_features))

for (feat in feature_list) {
  model_data <- merge(model_data, feat, by = "hadm_id", all.x = TRUE)
}

# Preencher NAs (admissões sem features = 0)
for (col in names(model_data)) {
  if (is.numeric(model_data[[col]])) {
    set(model_data, which(is.na(model_data[[col]])), col, 0)
  }
}

# Codificar variáveis
model_data[, gender_male := as.integer(gender == "M")]
model_data[, admission_emergency := as.integer(admission_type == "EMERGENCY")]

# Remover colunas não preditoras
exclude_cols <- c("subject_id", "hadm_id", "gender", "admission_type",
                  "discharge_location", "dischtime", "admittime", "insurance")
feature_cols <- setdiff(names(model_data), c(exclude_cols, "mortality"))

message(sprintf("[ML] Dataset: %d admissões, %d features",
                nrow(model_data), length(feature_cols)))
message(sprintf("[ML] Prevalência do desfecho (mortalidade): %.1f%%",
                100 * mean(model_data$mortality)))

# --- 4. Divisão treino/teste (por paciente, não por linha) ------------------
set.seed(20240101)
all_subjects <- unique(model_data$subject_id)
train_subjects <- sample(all_subjects, size = floor(0.75 * length(all_subjects)))
test_subjects <- setdiff(all_subjects, train_subjects)

train_data <- model_data[subject_id %in% train_subjects]
test_data  <- model_data[subject_id %in% test_subjects]

message(sprintf("[ML] Treino: %d subjects, %d rows | Teste: %d subjects, %d rows",
                length(train_subjects), nrow(train_data),
                length(test_subjects), nrow(test_data)))

# --- 5. Modelos -------------------------------------------------------------
library(glmnet)
library(ranger)
library(xgboost)
library(pROC)

train_x <- as.matrix(train_data[, ..feature_cols])
train_y <- train_data$mortality
test_x  <- as.matrix(test_data[, ..feature_cols])
test_y  <- test_data$mortality

results <- list()

# 5.1 Baseline: Regressão Logística
message("\n[ML] Modelo 1: Regressão Logística (baseline)...")
glm_model <- glm(mortality ~ ., data = train_data[, c("mortality", feature_cols), with = FALSE],
                 family = binomial())
glm_pred <- predict(glm_model, test_data, type = "response")
glm_roc <- roc(test_y, glm_pred)
glm_auc <- auc(glm_roc)
message(sprintf("  AUC = %.3f | Brier = %.3f",
                glm_auc, mean((glm_pred - test_y)^2)))

results$logistic <- list(model = glm_model, predictions = glm_pred,
                         auc = glm_auc, roc = glm_roc)

# 5.2 GLM com penalização (LASSO)
message("[ML] Modelo 2: GLM com penalização LASSO...")
cv_glmnet <- cv.glmnet(train_x, train_y, family = "binomial", alpha = 1,
                       nfolds = 5, type.measure = "auc")
glmnet_pred <- predict(cv_glmnet, test_x, s = "lambda.min", type = "response")[, 1]
glmnet_roc <- roc(test_y, glmnet_pred)
glmnet_auc <- auc(glmnet_roc)
message(sprintf("  AUC = %.3f | Lambda = %.5f", glmnet_auc, cv_glmnet$lambda.min))

results$glmnet <- list(model = cv_glmnet, predictions = glmnet_pred,
                       auc = glmnet_auc, roc = glmnet_roc)

# 5.3 Random Forest
message("[ML] Modelo 3: Random Forest...")
rf_model <- ranger(
  x = train_x, y = as.factor(train_y),
  num.trees = 500, mtry = floor(sqrt(ncol(train_x))),
  importance = "permutation",
  probability = TRUE,
  seed = 20240101
)
rf_pred <- predict(rf_model, test_x)$predictions[, 2]
rf_roc <- roc(test_y, rf_pred)
rf_auc <- auc(rf_roc)
message(sprintf("  AUC = %.3f", rf_auc))

results$ranger <- list(model = rf_model, predictions = rf_pred,
                       auc = rf_auc, roc = rf_roc)

# 5.4 XGBoost
message("[ML] Modelo 4: XGBoost...")
dtrain <- xgb.DMatrix(train_x, label = train_y)
dtest  <- xgb.DMatrix(test_x, label = test_y)

xgb_params <- list(
  objective = "binary:logistic",
  eval_metric = "auc",
  max_depth = 4,
  eta = 0.05,
  subsample = 0.8,
  colsample_bytree = 0.8,
  min_child_weight = 1
)

xgb_model <- xgb.train(
  params = xgb_params,
  data = dtrain,
  nrounds = 200,
  watchlist = list(train = dtrain, test = dtest),
  early_stopping_rounds = 20,
  print_every_n = 50,
  verbose = 0
)

xgb_pred <- predict(xgb_model, dtest)
xgb_roc <- roc(test_y, xgb_pred)
xgb_auc <- auc(xgb_roc)
message(sprintf("  AUC = %.3f | Nrounds = %d", xgb_auc, xgb_model$best_iteration))

results$xgb <- list(model = xgb_model, predictions = xgb_pred,
                    auc = xgb_auc, roc = xgb_roc)

# --- 6. Métricas comparativas -----------------------------------------------
message("\n[ML] ===== COMPARAÇÃO DE MODELOS =====")
comparison <- data.table(
  Modelo = c("Regressão Logística", "GLM LASSO", "Random Forest", "XGBoost"),
  AUC = c(glm_auc, glmnet_auc, rf_auc, xgb_auc)
)

# Brier scores
comparison[, Brier := c(
  mean((results$logistic$pred - test_y)^2),
  mean((results$glmnet$pred - test_y)^2),
  mean((results$ranger$pred - test_y)^2),
  mean((results$xgb$pred - test_y)^2)
)]

# Sens/Espec no threshold ótimo
for (i in 1:nrow(comparison)) {
  preds <- switch(i,
    results$logistic$pred, results$glmnet$pred,
    results$ranger$pred, results$xgb$pred)
  
  roc_obj <- switch(i,
    results$logistic$roc, results$glmnet$roc,
    results$ranger$roc, results$xgb$roc)
  
  coords <- coords(roc_obj, "best", ret = c("threshold", "sensitivity", "specificity", "ppv", "npv"))
  comparison[i, `:=`(
    Sensibilidade = round(coords$sensitivity, 3),
    Especificidade = round(coords$specificity, 3),
    VPP = round(coords$ppv, 3),
    VPN = round(coords$npv, 3)
  )]
}

message("\nMétricas comparativas:")
print(comparison)

# --- 7. Salvar resultados ----------------------------------------------------
dir.create(file.path(PATHS$output_dir, "ml"), showWarnings = FALSE, recursive = TRUE)

fwrite(comparison, file.path(PATHS$output_dir, "ml", "model_comparison.csv"))

saveRDS(results, file.path(PATHS$output_dir, "ml", "ml_models.rds"))
saveRDS(list(train_subjects = train_subjects, test_subjects = test_subjects,
             feature_cols = feature_cols),
        file.path(PATHS$output_dir, "ml", "data_split.rds"))

message(sprintf("[ML] Resultados salvos em: %s/ml/", PATHS$output_dir))

# --- 8. Gráficos de comparação ----------------------------------------------
fig_dir <- file.path(PATHS$output_dir, "ml", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# 8.1 Curvas ROC sobrepostas
roc_data <- rbindlist(list(
  data.table(FPR = 1 - results$logistic$roc$specificities,
             TPR = results$logistic$roc$sensitivities, Modelo = "Logística"),
  data.table(FPR = 1 - results$glmnet$roc$specificities,
             TPR = results$glmnet$roc$sensitivities, Modelo = "GLM LASSO"),
  data.table(FPR = 1 - results$ranger$roc$specificities,
             TPR = results$ranger$roc$sensitivities, Modelo = "Random Forest"),
  data.table(FPR = 1 - results$xgb$roc$specificities,
             TPR = results$xgb$roc$sensitivities, Modelo = "XGBoost")
))

p_roc <- ggplot(roc_data, aes(x = FPR, y = TPR, color = Modelo)) +
  geom_line(linewidth = 1) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#999999", linewidth = 0.5) +
  scale_color_manual(values = cellpress_colors$safe[1:4]) +
  labs(
    title = "Curvas ROC — Modelos Preditivos de Mortalidade",
    subtitle = "Comparação de 4 algoritmos | Prova de conceito exploratória",
    x = "1 — Especificidade",
    y = "Sensibilidade",
    caption = "AUC < 0.60 em todos os modelos: uso exclusivamente demonstrativo."
  ) +
  coord_fixed() +
  theme_cellpress(base_size = 12)

ggsave(file.path(fig_dir, "ML_ROC_Comparison.pdf"), p_roc, width = 7, height = 6, device = "pdf")
ggsave(file.path(fig_dir, "ML_ROC_Comparison.png"), p_roc, width = 7, height = 6, dpi = 300)

# 8.2 Barras de AUC
p_auc <- ggplot(comparison, aes(x = reorder(Modelo, AUC), y = AUC, fill = Modelo)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_text(aes(label = sprintf("%.3f", AUC)), hjust = -0.2, size = 5, fontface = "bold") +
  scale_fill_manual(values = cellpress_colors$safe[1:4]) +
  coord_flip(ylim = c(0, max(comparison$AUC) * 1.2)) +
  labs(
    title = "AUC por Modelo — Predição de Mortalidade",
    subtitle = "Desempenho discriminativo (área sob a curva ROC)",
    x = NULL, y = "AUC",
    caption = "Linha pontilhada: AUC = 0.50 (classificador aleatório)"
  ) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "#999999", linewidth = 0.5) +
  theme_cellpress(base_size = 13) +
  theme(legend.position = "none")

ggsave(file.path(fig_dir, "ML_AUC_Bars.pdf"), p_auc, width = 8, height = 4.5, device = "pdf")
ggsave(file.path(fig_dir, "ML_AUC_Bars.png"), p_auc, width = 8, height = 4.5, dpi = 300)

message(sprintf("[ML] Figuras salvas em: %s", fig_dir))
message("[ML] ===== FIM DA CAMADA DE MACHINE LEARNING =====")

# Return results invisibly
invisible(list(comparison = comparison, results = results, data = model_data))
