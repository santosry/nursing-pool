# =============================================================================
# 03_nanda_diagnostics.R - Diagnósticos de Enfermagem NANDA-I
# =============================================================================
# Etapa 3: Extração, classificação e análise dos diagnósticos de enfermagem
# segundo a taxonomia NANDA-I a partir dos dados MIMIC-IV.
#
# Ref: Herdman, T.H. et al. (2021). Nursing Diagnoses: Definitions 
#      and Classification 2021-2023. Thieme. 12th Edition.
# =============================================================================

#' Processa e enriquece os diagnósticos NANDA
#' Adiciona:
#'   - Agrupamento por domínios NANDA
#'   - Cálculo de prevalência
#'   - Severidade baseada em evidências
#'   - Co-ocorrência de diagnósticos
process_nanda_diagnostics <- function(nanda_data, data) {

  if (nrow(nanda_data) == 0) {
    warning("[NANDA] Sem dados para processar.")
    return(nanda_data)
  }

  message("[NANDA] Processando ", nrow(nanda_data), " diagnósticos...")

  # Adicionar informações demográficas
  if (!is.null(data$hosp$patients)) {
    pat <- data$hosp$patients[, .(subject_id, gender, anchor_age)]
    nanda_data <- merge(nanda_data, pat, by = "subject_id", all.x = TRUE)
  }

  # Adicionar informações de admissão
  if (!is.null(data$hosp$admissions)) {
    adm_cols <- intersect(c("subject_id", "hadm_id", "admittime", "dischtime",
                            "admission_type", "discharge_location",
                            "ethnicity", "insurance"),
                          names(data$hosp$admissions))
    adm <- data$hosp$admissions[, ..adm_cols]
    if ("hadm_id" %in% names(nanda_data)) {
      nanda_data <- merge(nanda_data, adm, by = intersect(c("subject_id", "hadm_id"), names(adm)),
                         all.x = TRUE)
    }
  }

  # Adicionar LOS
  if (all(c("admittime", "dischtime") %in% names(nanda_data))) {
    nanda_data[, los_days := as.numeric(difftime(dischtime, admittime, units = "days"))]
  }

  # Classificar severidade por etiologia
  # Foco em diagnósticos com evidências críticas
  nanda_data[, severity := "Moderado"]

  nanda_data[evidence %like% "GCS: [0-7]|coma",
             severity := "Crítico"]
  nanda_data[evidence %like% "RASS: \\+[3-4]|violento",
             severity := "Crítico"]
  nanda_data[evidence %like% "SpO2: [0-8][0-9]%|SpO2: 70",
             severity := "Crítico"]
  nanda_data[evidence %like% "Dor: (10|[8-9])",
             severity := "Severo"]
  nanda_data[evidence %like% "Lactato: [4-9]|Lactato: [1-9][0-9]",
             severity := "Crítico"]
  nanda_data[evidence %like% "Braden: [0-9]|Braden: 1[0-1]",
             severity := "Severo"]
  nanda_data[evidence %like% "Hb: [0-6]\\.",
             severity := "Crítico"]

  # --- Análise de prevalência -----------------------------------------------
  n_patients <- nanda_data[, uniqueN(subject_id)]
  n_admissions <- nanda_data[, uniqueN(hadm_id)]

  message(sprintf("[NANDA] Pacientes únicos com diagnóstico: %d", n_patients))
  message(sprintf("[NANDA] Admissões únicas: %d", n_admissions))

  # Prevalência por domínio
  prevalence_domain <- nanda_data[, .(
    n_patients = uniqueN(subject_id),
    n_diagnoses = .N,
    prevalence_pct = round(100 * uniqueN(subject_id) / n_patients, 1)
  ), by = nanda_domain][order(-prevalence_pct)]

  message("\n[NANDA] Prevalência por domínio:")
  print(prevalence_domain[, .(Domínio = nanda_domain, Pacientes = n_patients,
                              Diagnósticos = n_diagnoses, Prevalência = paste0(prevalence_pct, "%"))])

  # Prevalência por diagnóstico específico
  prevalence_label <- nanda_data[, .(
    n_patients = uniqueN(subject_id),
    n_occurrences = .N,
    prevalence_pct = round(100 * uniqueN(subject_id) / n_patients, 1)
  ), by = .(nanda_domain, nanda_label)][order(-prevalence_pct)]

  message("\n[NANDA] Top 10 diagnósticos mais prevalentes:")
  print(head(prevalence_label[, .(Diagnóstico = nanda_label, Domínio = nanda_domain,
                                   Pacientes = n_patients, Prevalência = paste0(prevalence_pct, "%"))], 10))

  # --- Análise de co-ocorrência ---------------------------------------------
  # Pacientes com múltiplos diagnósticos
  patient_dx_count <- nanda_data[, .(n_dx = .N, n_domains = uniqueN(nanda_domain)),
                                 by = subject_id]

  message(sprintf("\n[NANDA] Média de diagnósticos por paciente: %.1f (SD: %.1f)",
                  mean(patient_dx_count$n_dx), sd(patient_dx_count$n_dx)))
  message(sprintf("[NANDA] Média de domínios NANDA por paciente: %.1f (SD: %.1f)",
                  mean(patient_dx_count$n_domains), sd(patient_dx_count$n_domains)))

  # --- Distribuição por fonte de evidência ----------------------------------
  source_dist <- nanda_data[, .N, by = source][order(-N)]
  message("\n[NANDA] Distribuição por fonte de evidência:")
  print(source_dist)

  # --- Distribuição por severidade ------------------------------------------
  severity_dist <- nanda_data[, .N, by = severity][order(-N)]
  message("\n[NANDA] Distribuição por severidade:")
  print(severity_dist)

  # --- Análise por gênero ----------------------------------------------------
  if ("gender" %in% names(nanda_data)) {
    gender_analysis <- nanda_data[, .(
      n_dx = .N,
      n_patients = uniqueN(subject_id),
      dx_per_patient = .N / uniqueN(subject_id)
    ), by = .(gender, nanda_domain)][order(nanda_domain, gender)]

    message("\n[NANDA] Análise por gênero:")
    print(gender_analysis[order(-dx_per_patient)])
  }

  # --- Análise por faixa etária ---------------------------------------------
  if ("anchor_age" %in% names(nanda_data)) {
    nanda_data[, age_group := cut(anchor_age,
                                  breaks = c(18, 35, 50, 65, 80, 99),
                                  labels = c("18-34", "35-49", "50-64", "65-79", "80+"),
                                  include.lowest = TRUE)]

    age_analysis <- nanda_data[, .(
      n_dx = .N,
      n_patients = uniqueN(subject_id)
    ), by = .(age_group, nanda_domain)][order(age_group, -n_dx)]

    message("\n[NANDA] Distribuição por faixa etária:")
    print(age_analysis)
  }

  # Salvar resultados
  attr(nanda_data, "prevalence_domain") <- prevalence_domain
  attr(nanda_data, "prevalence_label") <- prevalence_label
  attr(nanda_data, "patient_dx_count") <- patient_dx_count
  attr(nanda_data, "n_patients") <- n_patients
  attr(nanda_data, "n_admissions") <- n_admissions

  nanda_data
}

#' Salva os diagnósticos NANDA processados
save_nanda_results <- function(nanda_data) {
  dir.create(PATHS$output_dir, showWarnings = FALSE, recursive = TRUE)

  fwrite(nanda_data, file.path(PATHS$output_dir, "nanda_diagnostics.csv"))
  message(sprintf("[NANDA] Resultados salvos: %s",
                  file.path(PATHS$output_dir, "nanda_diagnostics.csv")))

  # Salvar também sumário
  summary <- attr(nanda_data, "prevalence_domain")
  if (!is.null(summary)) {
    fwrite(summary, file.path(PATHS$output_dir, "nanda_summary.csv"))
  }
}

# Executar se chamado diretamente
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  nanda_raw <- extract_nanda_diagnostics(data)
  nanda_processed <- process_nanda_diagnostics(nanda_raw, data)
  save_nanda_results(nanda_processed)
}
