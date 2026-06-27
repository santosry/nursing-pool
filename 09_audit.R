# =============================================================================
# 09_audit.R - Auditoria Linha a Linha do Pipeline
# =============================================================================
# Etapa 9: Auditoria completa e determinística de cada etapa do pipeline.
# Verifica:
#   - Integridade dos dados em cada transformação
#   - Consistência de identificadores
#   - Completude do mapeamento NANDA/NOC/NIC
#   - Valores plausíveis (range checks)
#   - Perda de dados entre etapas (data lineage)
#   - Conformidade com o schema esperado
# =============================================================================

#' Auditoria completa do pipeline
full_pipeline_audit <- function(data, nanda_raw, nanda_proc,
                                 noc_raw, noc_proc,
                                 nic_raw, nic_proc,
                                 db_path) {

  message("[AUDIT] ===================================================")
  message("[AUDIT] AUDITORIA COMPLETA DO PIPELINE DE ENFERMAGEM")
  message("[AUDIT] ===================================================")

  report <- list()
  issues <- 0
  warnings <- 0

  # === ETAPA 1: Dados de Entrada ============================================

  message("\n[AUDIT] --- Etapa 1: Dados de Entrada ---")

  # Verificar módulos carregados
  modules <- names(data)[!sapply(data, is.null)]
  message(sprintf("  Módulos carregados: %s", paste(modules, collapse = ", ")))

  if (!"hosp" %in% modules) {
    issues <- issues + 1
    message("  [ERROR] Módulo HOSP não carregado!")
  }
  if (!"icu" %in% modules) {
    issues <- issues + 1
    message("  [ERROR] Módulo ICU não carregado!")
  }

  # Verificar tabelas essenciais
  essential_hosp <- c("patients", "admissions", "diagnoses_icd", "labevents", "emar")
  for (tbl in essential_hosp) {
    if (is.null(data$hosp[[tbl]])) {
      warning(sprintf("  [WARN] Tabela %s não encontrada no módulo HOSP", tbl))
      warnings <- warnings + 1
    } else {
      message(sprintf("  [OK] %-20s: %d linhas", tbl, nrow(data$hosp[[tbl]])))
    }
  }

  essential_icu <- c("icustays", "chartevents", "inputevents", "outputevents")
  for (tbl in essential_icu) {
    if (is.null(data$icu[[tbl]])) {
      warning(sprintf("  [WARN] Tabela %s não encontrada no módulo ICU", tbl))
      warnings <- warnings + 1
    } else {
      message(sprintf("  [OK] %-20s: %d linhas", tbl, nrow(data$icu[[tbl]])))
    }
  }

  # === ETAPA 2: Mapeamento NANDA ============================================

  message("\n[AUDIT] --- Etapa 2: Mapeamento NANDA ---")

  # Verificar códigos ICD não mapeados
  if (!is.null(data$hosp$diagnoses_icd)) {
    icd_codes <- unique(data$hosp$diagnoses_icd$icd_code)
    mapped_count <- 0

    for (domain_name in names(NANDA_ICD_MAP)) {
      domain <- NANDA_ICD_MAP[[domain_name]]
      for (pattern in domain$icd_codes) {
        if (nchar(pattern) <= 3) {
          mapped_count <- mapped_count + sum(grepl(paste0("^", pattern), icd_codes))
        } else {
          mapped_count <- mapped_count + sum(icd_codes == pattern)
        }
      }
    }

    pct_mapped <- round(100 * mapped_count / length(icd_codes), 1)
    message(sprintf("  [OK] Códigos ICD: %d únicos | %d com mapeamento NANDA (%.1f%%)",
                    length(icd_codes), mapped_count, pct_mapped))

    if (pct_mapped < 50) {
      warning(sprintf("  [WARN] Apenas %.1f%% dos códigos ICD possuem mapeamento NANDA",
                      pct_mapped))
      warnings <- warnings + 1
    }
  }

  # Verificar consistência das hipóteses NANDA-I derivadas
  message(sprintf("  [OK] Hipóteses NANDA-I derivadas: %d", nrow(nanda_raw)))
  n_domains <- nanda_raw[, uniqueN(nanda_domain)]
  n_labels <- nanda_raw[, uniqueN(nanda_label)]
  message(sprintf("  [OK] Domínios NANDA: %d | Rótulos: %d", n_domains, n_labels))

  # Verificar NAs em colunas essenciais
  for (col in c("nanda_domain", "nanda_label")) {
    na_count <- sum(is.na(nanda_raw[[col]]))
    if (na_count > 0) {
      issues <- issues + 1
      message(sprintf("  [ERROR] %d NAs em coluna %s", na_count, col))
    }
  }

  # Verificar ranges plausíveis
  if ("severity" %in% names(nanda_proc)) {
    valid_severities <- c("Moderado", "Severo", "Crítico")
    invalid_sev <- setdiff(unique(nanda_proc$severity), valid_severities)
    if (length(invalid_sev) > 0) {
      issues <- issues + 1
      message(sprintf("  [ERROR] Severidades inválidas: %s",
                      paste(invalid_sev, collapse = ", ")))
    } else {
      message("[OK] Todas as severidades válidas.")
    }
  }

  # === ETAPA 3: Mapeamento NOC ==============================================

  message("\n[AUDIT] --- Etapa 3: Mapeamento NOC ---")

  message(sprintf("  [OK] Indicadores NOC operacionalizados: %d", nrow(noc_raw)))

  if (nrow(noc_raw) > 0) {
    n_indicators <- noc_raw[, uniqueN(indicator)]
    n_outcomes <- noc_raw[, uniqueN(noc_label)]
    message(sprintf("  [OK] Indicadores únicos: %d | Resultados NOC: %d",
                    n_indicators, n_outcomes))

    # Verificar valores plausíveis
    value_ranges <- list(
      "Frequência Cardíaca" = c(20, 300),
      "Pressão Arterial Sistólica" = c(40, 300),
      "Pressão Arterial Diastólica" = c(20, 200),
      "Saturação de Oxigênio" = c(40, 100),
      "Temperatura Corporal" = c(28, 45),
      "Frequência Respiratória" = c(4, 60),
      "Escala de Coma de Glasgow" = c(3, 15),
      "Intensidade da Dor (NRS)" = c(0, 10),
      "Peso Corporal" = c(20, 300),
      "Escore de Braden" = c(6, 23)
    )

    for (indicator in names(value_ranges)) {
      vals <- noc_raw[indicator == indicator & !is.na(value), value]
      if (length(vals) > 0) {
        out_of_range <- sum(vals < value_ranges[[indicator]][1] |
                            vals > value_ranges[[indicator]][2])
        if (out_of_range > 0) {
          warning(sprintf("  [WARN] %s: %d valores fora do range fisiológico [%.0f-%.0f]",
                          indicator, out_of_range,
                          value_ranges[[indicator]][1],
                          value_ranges[[indicator]][2]))
          warnings <- warnings + 1
        }
      }
    }

    if (warnings == 0) {
      message("  [OK] Valores fisiológicos dentro dos ranges esperados.")
    }
  }

  # === ETAPA 4: Mapeamento NIC ==============================================

  message("\n[AUDIT] --- Etapa 4: Mapeamento NIC ---")

  message(sprintf("  [OK] Intervenções NIC extraídas: %d", nrow(nic_raw)))

  if (nrow(nic_raw) > 0) {
    n_interventions <- nic_raw[, uniqueN(nic_label)]
    message(sprintf("  [OK] Tipos de intervenção únicos: %d", n_interventions))

    # Verificar campos essenciais
    required_nic_cols <- c("subject_id", "nic_code", "nic_label")
    missing_nic_cols <- setdiff(required_nic_cols, names(nic_raw))
    if (length(missing_nic_cols) > 0) {
      issues <- issues + 1
      message(sprintf("  [ERROR] Colunas faltando em NIC: %s",
                      paste(missing_nic_cols, collapse = ", ")))
    }
  }

  # === ETAPA 5: Banco de Dados ==============================================

  message("\n[AUDIT] --- Etapa 5: Banco de Dados ---")

  if (file.exists(db_path)) {
    message(sprintf("  [OK] Banco de dados existe: %s (%.1f MB)",
                    db_path, file.size(db_path) / 1e6))

    if (requireNamespace("duckdb", quietly = TRUE)) {
      library(duckdb)
      con <- dbConnect(duckdb(), db_path)
    } else {
      library(RSQLite)
      con <- dbConnect(SQLite(), db_path)
    }
    tables <- dbListTables(con)

    expected_tables <- c("dim_patient", "dim_admission", "dim_icustay",
                         "fact_nanda", "fact_noc", "fact_nic",
                         "dim_nanda_domain", "dim_noc_outcome",
                         "dim_nic_intervention")

    missing_tables <- setdiff(expected_tables, tables)
    if (length(missing_tables) > 0) {
      issues <- issues + 1
      message(sprintf("  [ERROR] Tabelas faltando no banco: %s",
                      paste(missing_tables, collapse = ", ")))
    } else {
      message("  [OK] Todas as tabelas esperadas estão presentes.")
    }

    # Verificar registros nas tabelas de fatos
    for (tbl in c("fact_nanda", "fact_noc", "fact_nic")) {
      if (tbl %in% tables) {
        count <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM \"%s\"", tbl))$n
        message(sprintf("  [OK] %-20s: %d registros", tbl, count))

        if (count == 0) {
          warning(sprintf("  [WARN] Tabela %s está vazia!", tbl))
          warnings <- warnings + 1
        }
      }
    }

    dbDisconnect(con)
  } else {
    issues <- issues + 1
    message(sprintf("  [ERROR] Banco de dados não encontrado: %s", db_path))
  }

  # === VERIFICAÇÃO DE DATA LINEAGE ==========================================

  message("\n[AUDIT] --- Data Lineage (Rastreamento de Perda) ---")

  # Pacientes no início vs pacientes com dados de enfermagem
  n_patients_total <- nrow(data$hosp$patients)
  n_patients_nanda <- nanda_raw[, uniqueN(subject_id)]
  n_patients_noc <- noc_raw[, uniqueN(subject_id)]
  n_patients_nic <- nic_raw[, uniqueN(subject_id)]

  message(sprintf("  Pacientes totais: %d", n_patients_total))
  message(sprintf("  Pacientes com NANDA: %d (%.1f%%)",
                  n_patients_nanda, 100*n_patients_nanda/n_patients_total))
  message(sprintf("  Pacientes com NOC: %d (%.1f%%)",
                  n_patients_noc, 100*n_patients_noc/n_patients_total))
  message(sprintf("  Pacientes com NIC: %d (%.1f%%)",
                  n_patients_nic, 100*n_patients_nic/n_patients_total))

  # Pacientes com os 3 (NANDA + NOC + NIC)
  n_all_three <- Reduce(intersect, list(
    unique(nanda_raw$subject_id),
    unique(noc_raw$subject_id),
    unique(nic_raw$subject_id)
  )) |> length()

  message(sprintf("  Pacientes com NANDA+NOC+NIC: %d (%.1f%%)",
                  n_all_three, 100*n_all_three/n_patients_total))

  # === RESUMO ===============================================================

  message("\n[AUDIT] ===================================================")
  message(sprintf("[AUDIT] RESUMO: %d ERROS | %d AVISOS", issues, warnings))

  if (issues == 0 && warnings == 0) {
    message("[AUDIT] ✓ PIPELINE APROVADO - Nenhuma inconformidade encontrada.")
  } else if (issues == 0) {
    message("[AUDIT] ✓ PIPELINE APROVADO COM RESSALVAS - Apenas avisos não críticos.")
  } else {
    message(sprintf("[AUDIT] ✗ PIPELINE REPROVADO - %d erros críticos encontrados.", issues))
  }
  message("[AUDIT] ===================================================")

  # Salvar relatório
  report$issues <- issues
  report$warnings <- warnings
  report$n_patients_total <- n_patients_total
  report$n_patients_nanda <- n_patients_nanda
  report$n_patients_noc <- n_patients_noc
  report$n_patients_nic <- n_patients_nic
  report$n_all_three <- n_all_three

  saveRDS(report, file.path(PATHS$output_dir, "audit_report.rds"))

  invisible(report)
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  source(here::here("03_nanda_diagnostics.R"))
  source(here::here("04_noc_outcomes.R"))
  source(here::here("05_nic_interventions.R"))
  source(here::here("06_nursing_db.R"))

  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))

  nanda_raw <- extract_nanda_diagnostics(data)
  nanda_proc <- process_nanda_diagnostics(nanda_raw, data)

  noc_raw <- extract_noc_outcomes(data)
  noc_proc <- process_noc_outcomes(noc_raw, data)

  nic_raw <- extract_nic_interventions(data)
  nic_proc <- process_nic_interventions(nic_raw, data)

  db_path <- build_nursing_database(data, nanda_proc, noc_proc, nic_proc)

  full_pipeline_audit(data, nanda_raw, nanda_proc,
                      noc_raw, noc_proc,
                      nic_raw, nic_proc,
                      db_path)
}
