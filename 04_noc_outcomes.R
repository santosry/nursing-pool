# =============================================================================
# 04_noc_measurements.R — Indicadores NOC Operacionalizados (v4.1)
# =============================================================================
# ATENÇÃO: Este script operacionaliza indicadores NOC a partir de variáveis
# clínicas do MIMIC-IV. Sinais vitais e medidas clínicas são usados como
# indicadores potenciais de resultado, sempre vinculados a hipóteses NANDA-I.
# NÃO são resultados NOC documentados originalmente por enfermeiros.
#
# Ref: Moorhead, S. et al. (2024). Nursing Outcomes Classification (NOC).
#      7th ed. Elsevier.
# =============================================================================

#' Processa resultados NOC com cálculos de tendência e desfecho
process_noc_outcomes <- function(noc_data, data) {

  if (nrow(noc_data) == 0) {
    warning("[NOC] Sem dados para processar.")
    return(noc_data)
  }

  message("[NOC] Processando ", nrow(noc_data), " indicadores de resultado...")

  # Adicionar demográficos
  if (!is.null(data$hosp$patients)) {
    pat <- data$hosp$patients[, .(subject_id, gender, anchor_age)]
    noc_data <- merge(noc_data, pat, by = "subject_id", all.x = TRUE)
  }

  # Adicionar informações de ICU stay
  if (!is.null(data$icu$icustays) && "stay_id" %in% names(noc_data)) {
    stays <- data$icu$icustays[, .(stay_id, intime, outtime, los)]
    noc_data <- merge(noc_data, stays, by = "stay_id", all.x = TRUE)
  }

  # --- Análise por indicador NOC --------------------------------------------
  # Estatísticas agregadas por indicador
  indicator_stats <- noc_data[, .(
    n_measurements = .N,
    n_patients = uniqueN(subject_id),
    n_stays = uniqueN(stay_id),
    mean_value = mean(value, na.rm = TRUE),
    median_value = median(value, na.rm = TRUE),
    sd_value = sd(value, na.rm = TRUE),
    min_value = min(value, na.rm = TRUE),
    max_value = max(value, na.rm = TRUE),
    q25 = quantile(value, 0.25, na.rm = TRUE),
    q75 = quantile(value, 0.75, na.rm = TRUE),
    pct_abnormal = round(100 * sum(abnormal, na.rm = TRUE) / .N, 1)
  ), by = .(noc_code, noc_label, indicator, unit)]

  message("\n[NOC] Estatísticas por indicador:")
  print(indicator_stats[, .(Indicador = indicator, N = n_measurements,
                            Pacientes = n_patients,
                            Média = round(mean_value, 1), SD = round(sd_value, 1),
                            `% Anormal` = pct_abnormal)])

  # --- Tendências temporais (primeiras 24h vs últimas 24h) ------------------
  if (all(c("charttime", "intime", "stay_id") %in% names(noc_data))) {

    trend_data <- copy(noc_data[!is.na(charttime)])

    # Calcular horas desde admissão UTI
    trend_data[, hours_from_icu := as.numeric(difftime(charttime, intime,
                                                       units = "hours"))]

    # Primeiras 24h
    first_24h <- trend_data[hours_from_icu >= 0 & hours_from_icu <= 24,
                            .(first_mean = mean(value, na.rm = TRUE),
                              first_n = .N),
                            by = .(stay_id, noc_label, indicator)]

    # Últimas 24h
    last_24h <- trend_data[, .(max_hours = max(hours_from_icu, na.rm = TRUE)),
                           by = stay_id]
    last_24h <- last_24h[!is.infinite(max_hours)]

    trend_data <- merge(trend_data, last_24h, by = "stay_id")
    last_data <- trend_data[hours_from_icu >= (max_hours - 24) & hours_from_icu <= max_hours,
                            .(last_mean = mean(value, na.rm = TRUE),
                              last_n = .N),
                            by = .(stay_id, noc_label, indicator)]

    # Juntar e calcular delta
    trends <- merge(first_24h, last_data, by = c("stay_id", "noc_label", "indicator"),
                    all = TRUE)
    trends[, delta := last_mean - first_mean]
    trends[, pct_change := round(100 * delta / first_mean, 1)]

    # Análise de tendência
    trend_summary <- trends[!is.na(delta),
                            .(n_stays = .N,
                              mean_first = mean(first_mean, na.rm = TRUE),
                              mean_last = mean(last_mean, na.rm = TRUE),
                              mean_delta = mean(delta, na.rm = TRUE),
                              pct_improved = round(100*sum(delta > 0, na.rm=TRUE)/.N, 1),
                              pct_worsened = round(100*sum(delta < 0, na.rm=TRUE)/.N, 1),
                              pct_stable = round(100*sum(abs(delta) < 0.01, na.rm=TRUE)/.N, 1)),
                            by = .(noc_label, indicator)]

    message("\n[NOC] Análise de tendências (primeiras 24h vs últimas 24h):")
    print(trend_summary)

    attr(noc_data, "trends") <- trends
    attr(noc_data, "trend_summary") <- trend_summary
  }

  # --- Análise por desfecho (alta vs óbito) ----------------------------------
  if (!is.null(data$hosp$admissions)) {
    adm <- data$hosp$admissions[, .(hadm_id, discharge_location)]
    adm[, mortality := discharge_location == "DEAD/EXPIRED"]

    if ("hadm_id" %in% names(noc_data)) {
      noc_data <- merge(noc_data, adm, by = "hadm_id", all.x = TRUE)

      outcome_analysis <- noc_data[!is.na(mortality),
                                   .(mean_value = mean(value, na.rm = TRUE),
                                     sd_value = sd(value, na.rm = TRUE),
                                     n = .N,
                                     pct_abnormal = round(100*sum(abnormal,na.rm=TRUE)/.N, 1)),
                                   by = .(indicator, mortality)]

      message("\n[NOC] Análise por mortalidade:")
      print(outcome_analysis)

      attr(noc_data, "outcome_analysis") <- outcome_analysis
    }
  }

  attr(noc_data, "indicator_stats") <- indicator_stats
  attr(noc_data, "n_total") <- nrow(noc_data)
  attr(noc_data, "n_patients") <- noc_data[, uniqueN(subject_id)]

  noc_data
}

#' Salva os resultados NOC processados
save_noc_results <- function(noc_data) {
  dir.create(PATHS$output_dir, showWarnings = FALSE, recursive = TRUE)

  fwrite(noc_data, file.path(PATHS$output_dir, "noc_outcomes.csv"))

  # Salvar estatísticas
  stats <- attr(noc_data, "indicator_stats")
  if (!is.null(stats)) {
    fwrite(stats, file.path(PATHS$output_dir, "noc_indicator_stats.csv"))
  }

  # Salvar tendências
  trends <- attr(noc_data, "trend_summary")
  if (!is.null(trends)) {
    fwrite(trends, file.path(PATHS$output_dir, "noc_trends.csv"))
  }

  message(sprintf("[NOC] Resultados salvos em: %s", PATHS$output_dir))
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  noc_raw <- extract_noc_outcomes(data)
  noc_processed <- process_noc_outcomes(noc_raw, data)
  save_noc_results(noc_processed)
}
