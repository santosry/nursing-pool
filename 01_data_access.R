# =============================================================================
# 01_data_access.R - Acesso e Carregamento de Dados MIMIC-IV
# =============================================================================
# Etapa 1 do pipeline: Carregamento dos dados MIMIC-IV (real ou sintético)
# Suporte a múltiplos backends: CSV nativo, DuckDB, SQLite
# Auditoria completa de integridade dos dados carregados
# =============================================================================

#' Carrega dados MIMIC-IV de arquivos CSV
#' @param data_dir Diretório raiz dos dados MIMIC-IV
#' @return Lista de data.tables com todos os módulos
load_mimic_csv <- function(data_dir) {
  message("[LOAD] Carregando dados MIMIC-IV de CSV: ", data_dir)

  # Verificar estrutura de diretórios
  required_dirs <- c("hosp", "icu")
  for (d in required_dirs) {
    if (!dir.exists(file.path(data_dir, d))) {
      stop("Diretório '", d, "' não encontrado em ", data_dir)
    }
  }

  hosp_dir <- file.path(data_dir, "hosp")
  icu_dir  <- file.path(data_dir, "icu")

  # Carregar cada tabela com tratamento de erros
  load_table <- function(dir, table_name) {
    fpath <- file.path(dir, paste0(table_name, ".csv.gz"))
    if (!file.exists(fpath)) {
      fpath <- file.path(dir, paste0(table_name, ".csv"))
    }
    if (file.exists(fpath)) {
      message(sprintf("  [LOAD] %-25s → %s", table_name, basename(fpath)))
      fread(fpath, showProgress = FALSE, na.strings = c("", "NA", "N/A"))
    } else {
      warning(sprintf("  [SKIP] %s não encontrado", table_name))
      NULL
    }
  }

  # Módulo HOSP - Tabelas essenciais para enfermagem
  hosp <- list()
  hosp_tables <- c("patients", "admissions", "diagnoses_icd", "d_icd_diagnoses",
                   "procedures_icd", "d_icd_procedures", "prescriptions",
                   "pharmacy", "labevents", "d_labitems", "microbiologyevents",
                   "emar", "emar_detail", "poe", "poe_detail",
                   "omr", "services", "transfers", "provider")

  for (tbl in hosp_tables) {
    hosp[[tbl]] <- load_table(hosp_dir, tbl)
  }

  # Módulo ICU - Essencial para enfermagem
  icu <- list()
  icu_tables <- c("icustays", "chartevents", "d_items", "inputevents",
                  "outputevents", "procedureevents", "datetimeevents",
                  "caregiver", "ingredientevents")

  for (tbl in icu_tables) {
    icu[[tbl]] <- load_table(icu_dir, tbl)
  }

  # Módulos opcionais (ED, Note)
  ed <- NULL
  note <- NULL

  ed_dir <- file.path(data_dir, "ed")
  if (dir.exists(ed_dir)) {
    ed <- list()
    for (tbl in c("edstays", "triage", "vitalsign", "diagnosis",
                  "medrecon", "pyxis")) {
      ed[[tbl]] <- load_table(ed_dir, tbl)
    }
  }

  note_dir <- file.path(data_dir, "note")
  if (dir.exists(note_dir)) {
    note <- list()
    for (tbl in c("discharge", "discharge_detail", "radiology",
                  "radiology_detail")) {
      note[[tbl]] <- load_table(note_dir, tbl)
    }
  }

  list(hosp = hosp, icu = icu, ed = ed, note = note)
}

#' Auditoria de integridade dos dados carregados
audit_data_integrity <- function(data, mode = PARAMS$mode) {
  message("\n[AUDIT] ===== AUDITORIA DE INTEGRIDADE DOS DADOS =====\n")

  report <- list()
  issues <- 0

  # 1. Contagem de registros
  for (module in names(data)) {
    if (is.null(data[[module]])) next
    for (tbl in names(data[[module]])) {
      if (is.null(data[[module]][[tbl]])) next
      n <- nrow(data[[module]][[tbl]])
      report[[paste0(module, ".", tbl)]] <- list(
        rows = n,
        cols = ncol(data[[module]][[tbl]]),
        size_mb = round(object.size(data[[module]][[tbl]]) / 1e6, 2)
      )
      message(sprintf("  [%s/%-25s] %s linhas | %2d colunas | %.1f MB",
                     module, tbl, format(n, big.mark = ","), ncol(data[[module]][[tbl]]),
                     round(object.size(data[[module]][[tbl]]) / 1e6, 2)))
    }
  }

  # 2. Verificar subject_id em todas as tabelas
  message("\n[AUDIT] Verificando consistência de subject_id...")
  all_subject_ids <- data$hosp$patients$subject_id

  for (module in names(data)) {
    if (is.null(data[[module]])) next
    for (tbl in names(data[[module]])) {
      dt <- data[[module]][[tbl]]
      if (is.null(dt) || !"subject_id" %in% names(dt)) next

      orphan <- setdiff(unique(dt$subject_id), all_subject_ids)
      if (length(orphan) > 0) {
        issues <- issues + 1
        warning(sprintf("  [ISSUE] %s.%s: %d subject_id(s) órfão(s) não encontrados em patients",
                       module, tbl, length(orphan)))
      }
    }
  }

  # 3. Verificar valores nulos
  message("\n[AUDIT] Verificando dados ausentes em colunas críticas...")
  critical_cols <- c("subject_id", "hadm_id", "stay_id", "charttime",
                     "itemid", "valuenum", "icd_code")

  for (module in names(data)) {
    if (is.null(data[[module]])) next
    for (tbl in names(data[[module]])) {
      dt <- data[[module]][[tbl]]
      if (is.null(dt)) next

      for (col in intersect(critical_cols, names(dt))) {
        na_count <- sum(is.na(dt[[col]]))
        if (na_count > 0) {
          pct <- round(100 * na_count / nrow(dt), 2)
          message(sprintf("  [INFO] %s.%s$%s: %d NAs (%.1f%%)",
                         module, tbl, col, na_count, pct))
        }
      }
    }
  }

  # 4. Verificar datas
  message("\n[AUDIT] Verificando coerência temporal...")
  if (!is.null(data$hosp$admissions)) {
    adm <- data$hosp$admissions
    # Verificar se dischtime > admittime
    if (all(c("admittime", "dischtime") %in% names(adm))) {
      bad_times <- adm[dischtime <= admittime, .N]
      if (bad_times > 0) {
        issues <- issues + 1
        warning(sprintf("  [ISSUE] %d admissões com dischtime <= admittime", bad_times))
      }
      # LOS distribution
      adm[, los_hours := as.numeric(difftime(dischtime, admittime, units = "hours"))]
      message(sprintf("  [INFO] LOS mediano: %.1f horas (IQR: %.1f-%.1f)",
                      median(adm$los_hours, na.rm = TRUE),
                      quantile(adm$los_hours, 0.25, na.rm = TRUE),
                      quantile(adm$los_hours, 0.75, na.rm = TRUE)))
    }
  }

  # 5. Verificar duplicatas
  message("\n[AUDIT] Verificando duplicatas...")
  if (!is.null(data$hosp$diagnoses_icd)) {
    dup <- data$hosp$diagnoses_icd[duplicated(data$hosp$diagnoses_icd,
                                              by = c("hadm_id", "icd_code")), .N]
    if (dup > 0) {
      issues <- issues + 1
      warning(sprintf("  [ISSUE] %d diagnósticos duplicados", dup))
    }
  }

  message(sprintf("\n[AUDIT] Total de problemas encontrados: %d", issues))
  message("[AUDIT] ===== FIM DA AUDITORIA =====\n")

  invisible(report)
}

#' Função principal de carregamento - orquestra modo real ou sintético
main_data_access <- function(mode = PARAMS$mode, data_dir = NULL) {

  if (mode == "synthetic") {
    message("[DATA] Modo SINTÉTICO: Gerando dados simulados...")
    source(here::here("synthetic_data.R"))
    data <- generate_all_synthetic_data()

  } else if (mode == "real") {
    if (is.null(data_dir)) {
      data_dir <- PATHS$data_dir
    }
    if (!dir.exists(data_dir)) {
      stop("[DATA] Diretório de dados não encontrado: ", data_dir,
           "\n  Certifique-se de ter baixado os dados do PhysioNet.")
    }
    data <- load_mimic_csv(data_dir)

  } else {
    stop("[DATA] Modo inválido: ", mode, ". Use 'synthetic' ou 'real'.")
  }

  # Auditoria
  audit_data_integrity(data, mode)

  # Salvar cache para etapas seguintes
  cache_path <- file.path(PATHS$cache_dir, "loaded_data.rds")
  dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE)
  saveRDS(data, cache_path, compress = "xz")
  message(sprintf("[DATA] Dados cacheados em: %s", cache_path))

  return(data)
}

# Executar se chamado diretamente
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  data <- main_data_access()
}
