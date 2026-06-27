# =============================================================================
# 06_nursing_db.R — Banco de Dados de Enfermagem (v4.1)
# =============================================================================
# ATENCAO: A estrutura correta do banco (v4.1) usa:
#   - mapping_nanda_evidence: evidencias clinicas classificadas
#   - fact_nanda_hypothesis: hipoteses diagnosticas (NAO diagnosticos confirmados)
#   - fact_noc_measurement: indicadores NOC vinculados a hipoteses
#   - fact_nic_observed_proxy: proxies observaveis de intervencoes
#   - fact_nic_recommended: recomendacoes NIC via ligacao NNN
#   - nnn_linkage_rules: regras de ligacao NANDA-NOC-NIC
#
# A implementacao principal em Python (rebuild_embeddings.py) reflete a v4.1.
# Este script R mantem compatibilidade com o modo sintetico legado.
#   - dim_nic_intervention: tipos de intervenção NIC
# =============================================================================

#' Constrói o banco de dados de enfermagem
build_nursing_database <- function(data, nanda, noc, nic, engine = "duckdb") {

  message(sprintf("[DB] Construindo banco de dados de enfermagem (%s)...", engine))

  db_path <- PATHS$db_path
  dir.create(dirname(db_path), showWarnings = FALSE, recursive = TRUE)

  # Remover banco anterior se existir
  if (file.exists(db_path)) {
    file.remove(db_path)
  }

  if (engine == "duckdb") {
    if (!requireNamespace("duckdb", quietly = TRUE)) {
      message("[DB] duckdb não instalado. Usando SQLite como fallback.")
      engine <- "sqlite"
    }
  }

  if (engine == "duckdb") {
    library(duckdb)
    con <- dbConnect(duckdb(), db_path)
    message("[DB] DuckDB conectado.")
  } else {
    library(RSQLite)
    con <- dbConnect(SQLite(), db_path)
    message("[DB] SQLite conectado.")
  }

  # --- Dimensões ------------------------------------------------------------
  # dim_patient
  if (!is.null(data$hosp$patients)) {
    pat <- data$hosp$patients[, .(subject_id, gender, anchor_age, anchor_year)]
    if (engine == "duckdb") {
      dbWriteTable(con, "dim_patient", pat, overwrite = TRUE)
    } else {
      dbWriteTable(con, "dim_patient", as.data.frame(pat), overwrite = TRUE)
    }
    message(sprintf("[DB] dim_patient: %d linhas", nrow(pat)))
  }

  # dim_admission
  if (!is.null(data$hosp$admissions)) {
    adm <- data$hosp$admissions[, .(subject_id, hadm_id, admittime, dischtime,
                                    admission_type, discharge_location,
                                    insurance, ethnicity, marital_status)]
    adm[, los_days := as.numeric(difftime(dischtime, admittime, units = "days"))]

    if (engine == "duckdb") {
      dbWriteTable(con, "dim_admission", adm, overwrite = TRUE)
    } else {
      dbWriteTable(con, "dim_admission", as.data.frame(adm), overwrite = TRUE)
    }
    message(sprintf("[DB] dim_admission: %d linhas", nrow(adm)))
  }

  # dim_icustay
  if (!is.null(data$icu$icustays)) {
    icu <- data$icu$icustays[, .(subject_id, hadm_id, stay_id, intime, outtime,
                                 los, first_careunit)]
    if (engine == "duckdb") {
      dbWriteTable(con, "dim_icustay", icu, overwrite = TRUE)
    } else {
      dbWriteTable(con, "dim_icustay", as.data.frame(icu), overwrite = TRUE)
    }
    message(sprintf("[DB] dim_icustay: %d linhas", nrow(icu)))
  }

  # --- Tabelas de Referência (Enfermagem) ------------------------------------

  # dim_nanda_domain
  nanda_domains <- data.table(
    domain_id = 1:13,
    domain_name = c("Promoção da Saúde", "Nutrição", "Eliminação e Troca",
                    "Atividade/Repouso", "Percepção/Cognição", "Autopercepção",
                    "Papéis e Relacionamentos", "Sexualidade",
                    "Enfrentamento/Tolerância ao Estresse", "Princípios da Vida",
                    "Segurança/Proteção", "Conforto", "Crescimento/Desenvolvimento"),
    domain_code = c("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13")
  )

  if (engine == "duckdb") {
    dbWriteTable(con, "dim_nanda_domain", nanda_domains, overwrite = TRUE)
  } else {
    dbWriteTable(con, "dim_nanda_domain", as.data.frame(nanda_domains), overwrite = TRUE)
  }
  message(sprintf("[DB] dim_nanda_domain: %d domínios", nrow(nanda_domains)))

  # dim_noc_outcome
  noc_outcomes <- data.table(
    outcome_id = 1:length(NOC_OUTCOME_MAP),
    noc_code = sapply(NOC_OUTCOME_MAP, `[[`, "noc_code"),
    noc_label = sapply(NOC_OUTCOME_MAP, `[[`, "noc_label")
  )

  if (engine == "duckdb") {
    dbWriteTable(con, "dim_noc_outcome", noc_outcomes, overwrite = TRUE)
  } else {
    dbWriteTable(con, "dim_noc_outcome", as.data.frame(noc_outcomes), overwrite = TRUE)
  }
  message(sprintf("[DB] dim_noc_outcome: %d indicadores", nrow(noc_outcomes)))

  # dim_nic_intervention
  nic_interventions <- data.table(
    intervention_id = 1:length(NIC_ACTIVITY_MAP),
    nic_code = sapply(NIC_ACTIVITY_MAP, `[[`, "nic_code"),
    nic_label = sapply(NIC_ACTIVITY_MAP, `[[`, "nic_label")
  )

  if (engine == "duckdb") {
    dbWriteTable(con, "dim_nic_intervention", nic_interventions, overwrite = TRUE)
  } else {
    dbWriteTable(con, "dim_nic_intervention", as.data.frame(nic_interventions),
                 overwrite = TRUE)
  }
  message(sprintf("[DB] dim_nic_intervention: %d intervenções", nrow(nic_interventions)))

  # --- Tabelas de Fatos -----------------------------------------------------

  # fact_nanda
  if (nrow(nanda) > 0) {
    nanda_fact <- nanda[, .(subject_id, hadm_id, nanda_domain, nanda_label,
                            severity, source, evidence)]
    nanda_fact[, diagnosis_id := .I]

    if (engine == "duckdb") {
      dbWriteTable(con, "fact_nanda_hypothesis", nanda_fact, overwrite = TRUE)
    } else {
      dbWriteTable(con, "fact_nanda_hypothesis", as.data.frame(nanda_fact), overwrite = TRUE)
    }
    message(sprintf("[DB] fact_nanda: %d diagnósticos", nrow(nanda_fact)))
  }

  # fact_noc
  if (nrow(noc) > 0) {
    noc_cols <- intersect(c("stay_id", "subject_id", "hadm_id", "charttime",
                            "noc_code", "noc_label", "indicator", "value",
                            "unit", "abnormal"),
                          names(noc))
    noc_fact <- noc[, ..noc_cols]
    noc_fact[, outcome_id := .I]

    if (engine == "duckdb") {
      dbWriteTable(con, "fact_noc_measurement", noc_fact, overwrite = TRUE)
    } else {
      dbWriteTable(con, "fact_noc_measurement", as.data.frame(noc_fact), overwrite = TRUE)
    }
    message(sprintf("[DB] fact_noc: %d resultados", nrow(noc_fact)))
  }

  # fact_nic
  if (nrow(nic) > 0) {
    nic_cols <- intersect(c("stay_id", "subject_id", "hadm_id", "charttime",
                            "nic_code", "nic_label", "intervention_type"),
                          names(nic))
    nic_fact <- nic[, ..nic_cols]
    nic_fact[, intervention_event_id := .I]

    if (engine == "duckdb") {
      dbWriteTable(con, "fact_nic_observed_proxy", nic_fact, overwrite = TRUE)
    } else {
      dbWriteTable(con, "fact_nic_observed_proxy", as.data.frame(nic_fact), overwrite = TRUE)
    }
    message(sprintf("[DB] fact_nic: %d intervenções", nrow(nic_fact)))
  }

  # --- Índices --------------------------------------------------------------
  if (engine != "duckdb") {
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_nanda_subject ON fact_nanda(subject_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_nanda_hadm ON fact_nanda(hadm_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_noc_stay ON fact_noc(stay_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_noc_subject ON fact_noc(subject_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_nic_stay ON fact_nic(stay_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_nic_subject ON fact_nic(subject_id)")
    message("[DB] Índices criados.")
  }

  # --- Estatísticas do banco -------------------------------------------------
  tables <- dbListTables(con)
  total_rows <- 0
  for (tbl in tables) {
    rows <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM \"%s\"", tbl))$n
    message(sprintf("  [DB] %-30s: %8d linhas", tbl, rows))
    total_rows <- total_rows + rows
  }

  message(sprintf("[DB] Total: %d tabelas, %d linhas", length(tables), total_rows))
  message(sprintf("[DB] Banco salvo: %s (%.1f MB)",
                  db_path, file.size(db_path) / 1e6))

  dbDisconnect(con)
  message("[DB] Conexão fechada.")

  invisible(db_path)
}

#' Testa queries no banco de dados de enfermagem
test_nursing_queries <- function(db_path = PATHS$db_path) {
  message("\n[DB] Testando queries no banco de dados...")

  # Tentar DuckDB primeiro, fallback SQLite
  if (requireNamespace("duckdb", quietly = TRUE)) {
    library(duckdb)
    con <- dbConnect(duckdb(), db_path)
  } else {
    library(RSQLite)
    con <- dbConnect(SQLite(), db_path)
  }

  # Query 1: Top 5 hipóteses NANDA-I
  q1 <- dbGetQuery(con, "
    SELECT nanda_domain, nanda_label, COUNT(*) as count
    FROM fact_nanda
    GROUP BY nanda_domain, nanda_label
    ORDER BY count DESC
    LIMIT 5
  ")
  message("\n[DB] Query 1 - Top 5 hipóteses NANDA-I:")
  print(q1)

  # Query 2: Pacientes com mais intervenções NIC
  q2 <- dbGetQuery(con, "
    SELECT nic_label, COUNT(DISTINCT subject_id) as n_patients,
           COUNT(*) as total_interventions
    FROM fact_nic
    GROUP BY nic_label
    ORDER BY n_patients DESC
  ")
  message("\n[DB] Query 2 - Intervenções NIC por paciente:")
  print(q2)

  # Query 3: Indicadores NOC mais alterados
  q3 <- dbGetQuery(con, "
    SELECT indicator, COUNT(*) as total,
           SUM(CASE WHEN abnormal THEN 1 ELSE 0 END) as abnormal_count,
           ROUND(100.0 * SUM(CASE WHEN abnormal THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_abnormal
    FROM fact_noc
    WHERE abnormal IS NOT NULL
    GROUP BY indicator
    ORDER BY pct_abnormal DESC
  ")
  message("\n[DB] Query 3 - Indicadores NOC anormais (%):")
  print(q3)

  # Query 4: Perfil do paciente por gênero (join com dim_patient)
  q4 <- dbGetQuery(con, "
    SELECT p.gender, COUNT(DISTINCT n.subject_id) as patients,
           COUNT(*) as diagnoses,
           ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT n.subject_id), 1) as dx_per_patient
    FROM fact_nanda n
    JOIN dim_patient p ON n.subject_id = p.subject_id
    GROUP BY p.gender
  ")
  message("\n[DB] Query 4 - Diagnósticos por gênero:")
  print(q4)

  dbDisconnect(con)
  message("[DB] Teste de queries concluído.")
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

  db_path <- build_nursing_database(data, nanda, noc, nic)
  test_nursing_queries(db_path)
}
