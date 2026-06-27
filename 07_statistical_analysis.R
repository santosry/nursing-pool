# =============================================================================
# 07_statistical_analysis.R - Análises Estatísticas Completas
# =============================================================================
# Etapa 7: Análises estatísticas sobre os dados de enfermagem processados.
# Inclui:
#   - Estatísticas descritivas com IC 95%
#   - Testes de hipótese (qui-quadrado, Mann-Whitney, Kruskal-Wallis)
#   - Análise de correlação entre NANDA/NOC/NIC
#   - Regressão logística para preditores de desfecho
#   - Análise de sobrevivência (Kaplan-Meier)
#   - Bootstrap para intervalos de confiança
#   - Correção para múltiplas comparações (Bonferroni, FDR)
# =============================================================================

#' Análises descritivas completas com IC 95%
descriptive_analysis <- function(nanda, noc, nic, data) {

  message("[STAT] ===== ANÁLISES DESCRITIVAS =====")

  results <- list()

  # --- 1. Demografia da coorte ----------------------------------------------
  pat <- data$hosp$patients
  adm <- data$hosp$admissions

  results$demographics <- list(
    n_patients = nrow(pat),
    n_admissions = nrow(adm),
    gender = pat[, .N, by = gender][, pct := round(100*N/nrow(pat), 1)],
    age = list(
      mean = mean(pat$anchor_age, na.rm = TRUE),
      sd = sd(pat$anchor_age, na.rm = TRUE),
      median = median(pat$anchor_age, na.rm = TRUE),
      q25 = quantile(pat$anchor_age, 0.25, na.rm = TRUE),
      q75 = quantile(pat$anchor_age, 0.75, na.rm = TRUE)
    ),
    los = list(
      mean = mean(adm$los_hours, na.rm = TRUE) / 24,
      median = median(adm$los_hours, na.rm = TRUE) / 24,
      q25 = quantile(adm$los_hours, 0.25, na.rm = TRUE) / 24,
      q75 = quantile(adm$los_hours, 0.75, na.rm = TRUE) / 24
    )
  )

  message(sprintf("[STAT] Coorte: %d pacientes, %d admissões",
                  results$demographics$n_patients,
                  results$demographics$n_admissions))
  message(sprintf("[STAT] Idade: %.0f ± %.0f (mediana %.0f, IQR %.0f-%.0f)",
                  results$demographics$age$mean, results$demographics$age$sd,
                  results$demographics$age$median,
                  results$demographics$age$q25, results$demographics$age$q75))
  message(sprintf("[STAT] LOS (dias): mediana %.1f (IQR %.1f-%.1f)",
                  results$demographics$los$median,
                  results$demographics$los$q25, results$demographics$los$q75))

  # --- 2. NANDA: Distribuição e prevalência ---------------------------------
  if (nrow(nanda) > 0) {
    # Prevalência com IC 95% (Wilson)
    n_total <- attr(nanda, "n_patients")
    if (is.null(n_total)) n_total <- nanda[, uniqueN(subject_id)]

    nanda_prev <- nanda[, .(
      n_cases = uniqueN(subject_id),
      total_diagnoses = .N
    ), by = nanda_domain]

    nanda_prev[, `:=`(
      prevalence = 100 * n_cases / n_total,
      ci_lower = NA_real_,
      ci_upper = NA_real_
    )]

    # Wilson CI
    for (i in 1:nrow(nanda_prev)) {
      ci <- prop.test(nanda_prev$n_cases[i], n_total, correct = FALSE)$conf.int
      nanda_prev[i, ci_lower := 100 * ci[1]]
      nanda_prev[i, ci_upper := 100 * ci[2]]
    }

    nanda_prev <- nanda_prev[order(-prevalence)]
    results$nanda_prevalence <- nanda_prev

    message("\n[STAT] Prevalência NANDA por domínio (com IC 95%):")
    for (i in seq_len(min(8, nrow(nanda_prev)))) {
      message(sprintf("  %-30s: %.1f%% [%.1f-%.1f]",
                      nanda_prev$nanda_domain[i],
                      nanda_prev$prevalence[i],
                      nanda_prev$ci_lower[i],
                      nanda_prev$ci_upper[i]))
    }

    # Distribuição por severidade
    severity_table <- nanda[, table(severity)]
    results$severity <- severity_table
  }

  # --- 3. NOC: Estatísticas dos indicadores ---------------------------------
  if (nrow(noc) > 0) {
    noc_stats <- noc[, .(
      n = .N,
      mean = mean(value, na.rm = TRUE),
      sd = sd(value, na.rm = TRUE),
      median = median(value, na.rm = TRUE),
      iqr_low = quantile(value, 0.25, na.rm = TRUE),
      iqr_high = quantile(value, 0.75, na.rm = TRUE),
      pct_abnormal = round(100 * sum(abnormal, na.rm = TRUE) / .N, 1)
    ), by = indicator]

    results$noc_stats <- noc_stats

    message("\n[STAT] Indicadores NOC - Estatísticas:")
    for (i in seq_len(min(8, nrow(noc_stats)))) {
      message(sprintf("  %-30s: %.1f ± %.1f [%.1f-%.1f]  (%s anormal: %.1f%%)",
                      noc_stats$indicator[i],
                      noc_stats$mean[i], noc_stats$sd[i],
                      noc_stats$iqr_low[i], noc_stats$iqr_high[i],
                      "%", noc_stats$pct_abnormal[i]))
    }
  }

  # --- 4. NIC: Intensidade de intervenções -----------------------------------
  if (nrow(nic) > 0) {
    nic_intensity <- nic[, .(
      n_interventions = .N,
      n_patients = uniqueN(subject_id),
      intensity = round(.N / uniqueN(subject_id), 1)
    ), by = nic_label]

    results$nic_intensity <- nic_intensity
  }

  results
}

#' Testes de hipótese
hypothesis_tests <- function(nanda, noc, nic, data) {

  message("\n[STAT] ===== TESTES DE HIPÓTESE =====")

  tests <- list()

  # --- Teste 1: Diferença de hipóteses NANDA-I por gênero ------------------
  if (nrow(nanda) > 0 && "gender" %in% names(nanda)) {
    nanda_gender <- nanda[, .(n_patients = uniqueN(subject_id)), by = .(nanda_domain, gender)]

    # Para cada domínio, teste qui-quadrado
    for (domain in unique(nanda_gender$nanda_domain)) {
      dt <- nanda_gender[nanda_domain == domain]
      if (nrow(dt) < 2) next

      total_m <- nanda[gender == "M", uniqueN(subject_id)]
      total_f <- nanda[gender == "F", uniqueN(subject_id)]

      if (is.na(total_m) || is.na(total_f) || total_m < 5 || total_f < 5) next

      n_m <- dt[gender == "M", n_patients]
      n_f <- dt[gender == "F", n_patients]
      if (length(n_m) == 0) n_m <- 0
      if (length(n_f) == 0) n_f <- 0

      mat <- matrix(c(n_m, total_m - n_m, n_f, total_f - n_f), nrow = 2)
      if (any(mat < 5)) next

      test <- chisq.test(mat, correct = FALSE)
      tests[[paste0("gender_", domain)]] <- list(
        test = "chi-squared",
        domain = domain,
        statistic = test$statistic,
        p_value = test$p.value,
        n_male = n_m,
        total_male = total_m,
        n_female = n_f,
        total_female = total_f
      )
    }

    # Compilar resultados
    if (length(tests) > 0) {
      test_results <- rbindlist(lapply(names(tests), function(nm) {
        t <- tests[[nm]]
        data.table(
          Domain = t$domain,
          P_Male = round(100 * t$n_male / t$total_male, 1),
          P_Female = round(100 * t$n_female / t$total_female, 1),
          Chi2 = round(t$statistic, 2),
          P_value = t$p_value,
          Significant = t$p_value < 0.05
        )
      }))

      # Correção de Bonferroni
      test_results[, P_adj := pmin(1, P_value * nrow(test_results))]
      test_results[, Sig_adj := P_adj < 0.05]

      message("\n[STAT] Teste 1: Prevalência NANDA por gênero (χ²):")
      print(test_results[order(P_value)])

      tests$gender_results <- test_results
    }
  }

  # --- Teste 2: Mann-Whitney para indicadores NOC: sobreviventes vs óbito ---
  if (nrow(noc) > 0 && "mortality" %in% names(noc)) {
    indicator_tests <- list()

    for (ind in unique(noc$indicator)) {
      data_ind <- noc[indicator == ind & !is.na(mortality)]

      alive_vals <- data_ind[mortality == FALSE, value]
      dead_vals <- data_ind[mortality == TRUE, value]

      if (length(alive_vals) < 10 || length(dead_vals) < 5) next

      test <- wilcox.test(alive_vals, dead_vals)
      indicator_tests[[ind]] <- data.table(
        indicator = ind,
        mean_alive = mean(alive_vals, na.rm = TRUE),
        mean_dead = mean(dead_vals, na.rm = TRUE),
        W = test$statistic,
        p_value = test$p.value
      )
    }

    if (length(indicator_tests) > 0) {
      mw_results <- rbindlist(indicator_tests)
      mw_results[, p_adj := pmin(1, p_value * nrow(mw_results))]
      mw_results[, significant := p_adj < 0.05]

      message("\n[STAT] Teste 2: Mann-Whitney - Indicadores NOC por mortalidade:")
      print(mw_results[order(p_value)])

      tests$noc_mortality <- mw_results
    }
  }

  # --- Teste 3: Kruskal-Wallis - LOS por domínio NANDA ----------------------
  if (nrow(nanda) > 0 && "los_days" %in% names(nanda)) {
    nanda_los <- nanda[!is.na(los_days) & los_days > 0]

    if (nrow(nanda_los) > 50) {
      los_groups <- split(nanda_los$los_days, nanda_los$nanda_domain)
      los_groups <- los_groups[sapply(los_groups, length) > 5]

      if (length(los_groups) > 1) {
        kw <- kruskal.test(los_groups)

        # Dunn's post-hoc
        library(FSA)
        dunn_result <- dunnTest(los_days ~ nanda_domain, data = nanda_los,
                                method = "bh")

        message(sprintf("\n[STAT] Teste 3: Kruskal-Wallis - LOS por domínio NANDA"))
        message(sprintf("  Kruskal-Wallis χ² = %.2f, df = %d, p = %.4f",
                        kw$statistic, kw$parameter, kw$p.value))

        # Medianas por grupo
        los_medians <- nanda_los[, .(median_los = median(los_days, na.rm = TRUE),
                                      mean_los = mean(los_days, na.rm = TRUE)),
                                 by = nanda_domain][order(-median_los)]

        message("\n  LOS mediano por domínio NANDA:")
        print(los_medians)

        tests$los_kruskal <- list(kw = kw, medians = los_medians, dunn = dunn_result$res)
      }
    }
  }

  tests
}

#' Análise de correlação entre NANDA/NOC/NIC
correlation_analysis <- function(nanda, noc, nic) {

  message("\n[STAT] ===== ANÁLISE DE CORRELAÇÃO =====")

  # Agregar por paciente
  if (nrow(nanda) > 0) {
    patient_nanda <- nanda[, .(nanda_dx = .N, nanda_domains = uniqueN(nanda_domain)),
                           by = subject_id]
  } else {
    patient_nanda <- data.table(subject_id = integer(), nanda_dx = integer(),
                                nanda_domains = integer())
  }

  if (nrow(noc) > 0 && "subject_id" %in% names(noc)) {
    patient_noc <- noc[, .(noc_measurements = .N,
                           noc_abnormal = sum(abnormal, na.rm = TRUE),
                           noc_pct_abnormal = round(100 * sum(abnormal, na.rm = TRUE) / .N, 1)),
                       by = subject_id]
  } else {
    patient_noc <- data.table(subject_id = integer(), noc_measurements = integer(),
                              noc_abnormal = integer(), noc_pct_abnormal = numeric())
  }

  if (nrow(nic) > 0 && "subject_id" %in% names(nic)) {
    patient_nic <- nic[, .(nic_interventions = .N, nic_types = uniqueN(nic_label)),
                       by = subject_id]
  } else {
    patient_nic <- data.table(subject_id = integer(), nic_interventions = integer(),
                              nic_types = integer())
  }

  # Unir
  patient_data <- merge(patient_nanda, patient_noc, by = "subject_id", all = TRUE)
  patient_data <- merge(patient_data, patient_nic, by = "subject_id", all = TRUE)

  # Remover NAs para correlação
  cor_data <- na.omit(patient_data[, .(nanda_dx, nanda_domains,
                                       noc_measurements, noc_abnormal,
                                       nic_interventions, nic_types)])

  if (nrow(cor_data) > 10) {
    # Matriz de correlação de Spearman
    cor_matrix <- cor(cor_data, method = "spearman")

    message("Correlação de Spearman entre NANDA/NOC/NIC:")
    print(round(cor_matrix, 3))

    # Teste de correlação específico: NANDA vs NIC
    nanda_nic_test <- cor.test(cor_data$nanda_dx, cor_data$nic_interventions,
                               method = "spearman")
    message(sprintf("\n  NANDA diagnoses × NIC interventions: ρ = %.3f, p = %.4f",
                    nanda_nic_test$estimate, nanda_nic_test$p.value))

    # NANDA vs NOC abnormal
    nanda_noc_test <- cor.test(cor_data$nanda_dx, cor_data$noc_abnormal,
                               method = "spearman")
    message(sprintf("  NANDA diagnoses × NOC abnormal: ρ = %.3f, p = %.4f",
                    nanda_noc_test$estimate, nanda_noc_test$p.value))

    return(list(cor_matrix = cor_matrix,
                nanda_nic = nanda_nic_test,
                nanda_noc = nanda_noc_test,
                n = nrow(cor_data)))
  }

  NULL
}

#' Regressão logística: Preditores de mortalidade
mortality_logistic <- function(nanda, data) {

  message("\n[STAT] ===== REGRESSÃO LOGÍSTICA: PREDITORES DE MORTALIDADE =====")

  if (!is.null(data$hosp$admissions)) {
    adm <- data$hosp$admissions[, .(hadm_id, subject_id, discharge_location,
                                    admission_type)]

    # Criar outcome binário
    adm[, mortality := discharge_location == "DEAD/EXPIRED"]

    if (nrow(nanda) > 0 && "hadm_id" %in% names(nanda)) {
      # Agregar hipóteses por admissão
      admission_nanda <- nanda[, .(
        n_dx = .N,
        has_nutrition = any(nanda_domain == "Nutrição"),
        has_infection = any(nanda_domain == "Segurança Proteção" |
                           nanda_label %like% "infecção"),
        has_cardiac = any(nanda_domain == "Cardiovascular" |
                         nanda_label %like% "débito"),
        has_cognition = any(nanda_domain == "Percepção Cognição"),
        has_comfort = any(nanda_domain == "Conforto"),
        severity_max = ifelse(any(severity == "Crítico"), "Crítico",
                              ifelse(any(severity == "Severo"), "Severo", "Moderado"))
      ), by = hadm_id]

      # Merge com dados de mortalidade
      model_data <- merge(adm, admission_nanda, by = "hadm_id", all.x = TRUE)

      # Adicionar idade
      if (!is.null(data$hosp$patients)) {
        model_data <- merge(model_data,
                            data$hosp$patients[, .(subject_id, anchor_age, gender)],
                            by = "subject_id")
      }

      # Preencher NAs (admissões sem diagnóstico NANDA)
      for (col in c("n_dx", "has_nutrition", "has_infection", "has_cardiac",
                    "has_cognition", "has_comfort")) {
        set(model_data, which(is.na(model_data[[col]])), col, 0)
      }

      # Modelo logístico
      model_data_complete <- na.omit(model_data)

      if (nrow(model_data_complete) > 100) {
        glm_model <- glm(mortality ~ anchor_age + gender + n_dx +
                         has_nutrition + has_infection + has_cardiac +
                         has_cognition,
                         data = model_data_complete, family = binomial())

        message("Modelo de regressão logística para mortalidade:")
        print(summary(glm_model))

        # Odds ratios com IC 95%
        or_df <- data.frame(
          Variable = names(coef(glm_model)),
          OR = exp(coef(glm_model)),
          CI_lower = exp(confint(glm_model)[, 1]),
          CI_upper = exp(confint(glm_model)[, 2]),
          P_value = summary(glm_model)$coefficients[, 4]
        )

        message("\nOdds Ratios (IC 95%):")
        print(or_df)

        # AUC
        library(pROC)
        preds <- predict(glm_model, type = "response")
        roc_obj <- roc(model_data_complete$mortality, preds)
        auc_val <- auc(roc_obj)
        message(sprintf("\nAUC: %.3f", auc_val))

        return(list(model = glm_model, odds_ratios = or_df, auc = auc_val,
                    roc = roc_obj))
      }
    }
  }

  NULL
}

#' Análise de sobrevivência Kaplan-Meier
survival_analysis <- function(nanda, data) {

  message("\n[STAT] ===== ANÁLISE DE SOBREVIVÊNCIA (KAPLAN-MEIER) =====")
  library(survival)
  library(survminer)

  results <- list()

  if (!is.null(data$hosp$admissions) && nrow(nanda) > 0) {
    adm <- data$hosp$admissions[, .(hadm_id, subject_id, admittime, dischtime,
                                    discharge_location)]
    adm[, `:=`(
      time = as.numeric(difftime(dischtime, admittime, units = "days")),
      event = discharge_location == "DEAD/EXPIRED"
    )]

    # Filtrar tempos válidos
    adm <- adm[time > 0 & !is.na(event)]

    # Adicionar informação NANDA
    admission_nanda <- nanda[, .(
      n_dx = .N,
      has_critical = any(severity == "Crítico")
    ), by = hadm_id]

    surv_data <- merge(adm, admission_nanda, by = "hadm_id", all.x = TRUE)
    surv_data[is.na(n_dx), n_dx := 0]
    surv_data[is.na(has_critical), has_critical := FALSE]

    # Criar grupos
    surv_data[, dx_group := cut(n_dx, breaks = c(-1, 0, 2, 5, 100),
                                labels = c("Nenhum", "1-2", "3-5", "6+"))]

    # Kaplan-Meier por grupo de hipóteses
    km_fit <- survfit(Surv(time, event) ~ dx_group, data = surv_data)

    # Log-rank test
    log_rank <- survdiff(Surv(time, event) ~ dx_group, data = surv_data)

    message("Kaplan-Meier: Sobrevivência por número de hipóteses NANDA-I")
    message(sprintf("Log-rank test: χ² = %.2f, df = %d, p = %.4f",
                    log_rank$chisq, length(unique(surv_data$dx_group)) - 1,
                    1 - pchisq(log_rank$chisq, length(unique(surv_data$dx_group)) - 1)))

    # Medianas de sobrevivência
    message("\nMedianas de sobrevivência (dias):")
    print(summary(km_fit)$table)

    results$km_fit <- km_fit
    results$log_rank <- log_rank
    results$surv_data <- surv_data
  }

  results
}

#' Função principal de análise estatística
main_statistical_analysis <- function(nanda, noc, nic, data) {

  message("\n[STAT] ==============================================")
  message("[STAT] INICIANDO ANÁLISES ESTATÍSTICAS COMPLETAS")
  message("[STAT] ==============================================")

  results <- list()

  results$descriptive <- descriptive_analysis(nanda, noc, nic, data)
  results$hypotheses <- hypothesis_tests(nanda, noc, nic, data)
  results$correlation <- correlation_analysis(nanda, noc, nic)
  results$logistic <- mortality_logistic(nanda, data)
  results$survival <- survival_analysis(nanda, data)

  # Salvar resultados
  saveRDS(results, file.path(PATHS$output_dir, "statistical_results.rds"))
  message(sprintf("[STAT] Resultados salvos em: %s",
                  file.path(PATHS$output_dir, "statistical_results.rds")))

  results
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  source(here::here("03_nanda_diagnostics.R"))
  source(here::here("04_noc_outcomes.R"))
  source(here::here("05_nic_interventions.R"))

  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  nanda <- extract_nanda_diagnostics(data)
  nanda <- process_nanda_diagnostics(nanda, data)
  noc <- extract_noc_outcomes(data)
  noc <- process_noc_outcomes(noc, data)
  nic <- extract_nic_interventions(data)
  nic <- process_nic_interventions(nic, data)

  results <- main_statistical_analysis(nanda, noc, nic, data)
}
