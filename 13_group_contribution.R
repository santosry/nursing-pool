# =============================================================================
# 13_group_contribution.R — Contribuição por Bloco Conceitual
# =============================================================================
# Agrupa preditores em blocos (NANDA, NOC, NIC, demografia, internação)
# e calcula contribuição por grupo via SHAP + importância por permutação.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(data.table)
  library(ggplot2)
  library(xgboost)
})

source(here::here("config.R"))
source(here::here("theme_cellpress.R"))

message("\n[GROUP] ===== CONTRIBUIÇÃO POR BLOCO CONCEITUAL =====")

# Carregar dados
ml_results <- readRDS(file.path(PATHS$output_dir, "ml", "ml_models.rds"))
split_info <- readRDS(file.path(PATHS$output_dir, "ml", "data_split.rds"))
shap_vals <- readRDS(file.path(PATHS$output_dir, "ml", "shap_values.rds"))

data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
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

# Reconstruir dados
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

# --- Definir blocos conceituais (los_days removido: vazamento temporal) ---
feature_blocks <- list(
  "Demografia" = c("anchor_age", "gender_male"),
  "Admissão" = c("admission_emergency"),
  "NANDA-I (Diagnósticos)" = c("n_nanda", "n_domains", "has_cardiac", "has_comfort",
                                "has_safety", "has_nutrition", "has_activity",
                                "has_cognition", "has_elimination",
                                "has_critical", "has_severe"),
  "NOC (Resultados)" = c("n_noc_measurements", "n_noc_abnormal", "pct_noc_abnormal"),
  "NIC (Intervenções)" = c("n_nic", "n_nic_types")
)

# Filtrar apenas features presentes no modelo
for (block_name in names(feature_blocks)) {
  feature_blocks[[block_name]] <- intersect(feature_blocks[[block_name]],
                                            colnames(model_data))
  message(sprintf("  Bloco %-25s: %d features", block_name,
                  length(feature_blocks[[block_name]])))
}

# --- Método 1: Soma de |SHAP| por bloco -------------------------------------
shap_matrix <- as.matrix(shap_vals)
block_shap <- data.table()

for (block_name in names(feature_blocks)) {
  features <- feature_blocks[[block_name]]
  if (length(features) == 0) next

  # Features presentes na matriz SHAP
  shap_features <- intersect(features, colnames(shap_matrix))
  if (length(shap_features) == 0) next

  # Soma de |SHAP| por amostra
  block_contrib <- rowSums(abs(shap_matrix[, shap_features, drop = FALSE]))

  # Bootstrap CI
  set.seed(20240101)
  boot_means <- replicate(500, mean(sample(block_contrib, replace = TRUE)))

  block_shap <- rbind(block_shap, data.table(
    Bloco = block_name,
    Mean_Abs_SHAP = mean(block_contrib),
    CI_Lower = quantile(boot_means, 0.025),
    CI_Upper = quantile(boot_means, 0.975),
    N_Features = length(shap_features)
  ))
}

block_shap <- block_shap[order(-Mean_Abs_SHAP)]
block_shap[, Pct_Total := round(100 * Mean_Abs_SHAP / sum(Mean_Abs_SHAP), 1)]

message("\nContribuição por bloco conceitual (|SHAP| médio):")
print(block_shap)

# --- Método 2: Importância por permutação agrupada --------------------------
message("\n[Método 2] Permutation importance por bloco (XGBoost)...")

test_x <- as.matrix(model_data[subject_id %in% split_info$test_subjects,
                                intersect(unlist(feature_blocks), names(model_data)),
                                with = FALSE])
test_y <- model_data[subject_id %in% split_info$test_subjects, mortality]
dtest <- xgb.DMatrix(test_x, label = test_y)

# Baseline AUC
base_pred <- predict(ml_results$xgb$model, dtest)
base_auc <- pROC::auc(pROC::roc(test_y, base_pred))

block_perm <- data.table()

for (block_name in names(feature_blocks)) {
  features <- feature_blocks[[block_name]]
  if (length(features) == 0) next

  perm_features <- intersect(features, colnames(test_x))
  if (length(perm_features) == 0) next

  # Permutar features do bloco
  perm_x <- test_x
  for (f in perm_features) {
    perm_x[, f] <- sample(perm_x[, f])
  }

  perm_pred <- predict(ml_results$xgb$model, xgb.DMatrix(perm_x))
  perm_auc <- pROC::auc(pROC::roc(test_y, perm_pred))

  block_perm <- rbind(block_perm, data.table(
    Bloco = block_name,
    Baseline_AUC = base_auc,
    Permuted_AUC = perm_auc,
    AUC_Drop = base_auc - perm_auc,
    Pct_Drop = round(100 * (base_auc - perm_auc) / base_auc, 2)
  ))
}

block_perm <- block_perm[order(-AUC_Drop)]
message("\nQueda de AUC por permutação de bloco:")
print(block_perm)

# --- Gráficos ----------------------------------------------------------------
fig_dir <- file.path(PATHS$output_dir, "ml", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Gráfico 1: |SHAP| por bloco
p1 <- ggplot(block_shap, aes(x = reorder(Bloco, Mean_Abs_SHAP),
                              y = Mean_Abs_SHAP, fill = Bloco)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_errorbar(aes(ymin = CI_Lower, ymax = CI_Upper), width = 0.2,
                linewidth = 0.5) +
  geom_text(aes(label = paste0(Pct_Total, "%")),
            hjust = -0.2, size = 4.5, fontface = "bold") +
  scale_fill_manual(values = cellpress_colors$safe[1:nrow(block_shap)]) +
  coord_flip() +
  labs(
    title = "Contribuição por Bloco Conceitual — |SHAP| Médio",
    subtitle = "Soma dos valores absolutos de SHAP por grupo de features",
    x = NULL, y = "|SHAP| Médio",
    caption = "Barras: IC 95% (bootstrap). IMPOTÂNCIA PREDITIVA ≠ EFEITO CAUSAL."
  ) +
  theme_cellpress(base_size = 13) +
  theme(legend.position = "none") +
  expand_limits(y = max(block_shap$CI_Upper) * 1.3)

ggsave(file.path(fig_dir, "Group_SHAP_Contribution.pdf"), p1, width = 9, height = 5, device = "pdf")
ggsave(file.path(fig_dir, "Group_SHAP_Contribution.png"), p1, width = 9, height = 5, dpi = 300)

# Gráfico 2: Queda de AUC por permutação
p2 <- ggplot(block_perm, aes(x = reorder(Bloco, AUC_Drop), y = AUC_Drop,
                              fill = Bloco)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_text(aes(label = sprintf("%.4f", AUC_Drop)),
            hjust = -0.2, size = 4.5, fontface = "bold") +
  scale_fill_manual(values = cellpress_colors$safe[1:nrow(block_perm)]) +
  coord_flip() +
  labs(
    title = "Queda de AUC por Permutação de Bloco Conceitual",
    subtitle = "Redução na AUC ao permutar aleatoriamente features do bloco (XGBoost)",
    x = NULL, y = expression(Delta * " AUC"),
    caption = "Quanto maior a queda, maior a dependência do modelo naquele bloco."
  ) +
  theme_cellpress(base_size = 13) +
  theme(legend.position = "none") +
  expand_limits(y = max(block_perm$AUC_Drop) * 2)

ggsave(file.path(fig_dir, "Group_Permutation_AUC_Drop.pdf"), p2, width = 9, height = 5, device = "pdf")
ggsave(file.path(fig_dir, "Group_Permutation_AUC_Drop.png"), p2, width = 9, height = 5, dpi = 300)

# --- Salvar tabelas ----------------------------------------------------------
fwrite(block_shap, file.path(PATHS$output_dir, "ml", "group_shap_contribution.csv"))
fwrite(block_perm, file.path(PATHS$output_dir, "ml", "group_permutation_auc.csv"))

message("[GROUP] ===== FIM DA ANÁLISE POR BLOCO =====")
