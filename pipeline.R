# =============================================================================
# pipeline.R - Orquestrador Principal do Pipeline de Enfermagem MIMIC-IV
# =============================================================================
# Pipeline completo em R para criação de banco de dados de enfermagem
# (NANDA/NOC/NIC) a partir do MIMIC-IV.
#
# Uso:
#   Rscript pipeline.R                      # Modo sintético (default)
#   Rscript pipeline.R --mode=synthetic     # Dados sintéticos
#   Rscript pipeline.R --mode=real --data_dir=/path/to/mimic-iv
#   Rscript pipeline.R --mode=real --data_dir=./data --skip-viz
#
# Etapas:
#   01 - Carregamento de dados
#   02 - Mapeamento NANDA/NOC/NIC
#   03 - Diagnósticos NANDA
#   04 - Resultados NOC
#   05 - Intervenções NIC
#   06 - Banco de dados de enfermagem
#   07 - Análises estatísticas
#   08 - Visualizações (Cell Press)
#   09 - Auditoria
#   10 - Benchmarks
# =============================================================================

# --- Setup -------------------------------------------------------------------
suppressPackageStartupMessages({
  library(here)
  library(data.table)
  library(ggplot2)
})

# Carregar configuração antes de tudo
source(here::here("config.R"))

# Parse argumentos de linha de comando
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  parsed <- list(
    mode     = "synthetic",
    data_dir = NULL,
    skip_viz = FALSE,
    skip_stat = FALSE,
    skip_bench = FALSE,
    cores    = 4
  )

  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--mode" && i < length(args)) {
      parsed$mode <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--data_dir" && i < length(args)) {
      parsed$data_dir <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--skip-viz") {
      parsed$skip_viz <- TRUE; i <- i + 1
    } else if (args[i] == "--skip-stat") {
      parsed$skip_stat <- TRUE; i <- i + 1
    } else if (args[i] == "--skip-bench") {
      parsed$skip_bench <- TRUE; i <- i + 1
    } else if (args[i] == "--cores" && i < length(args)) {
      parsed$cores <- as.integer(args[i + 1]); i <- i + 2
    } else if (args[i] %in% c("-h", "--help")) {
      cat("Pipeline de Enfermagem MIMIC-IV\n",
          "Uso: Rscript pipeline.R [opções]\n",
          "  --mode=synthetic|real   Modo de execução (default: synthetic)\n",
          "  --data_dir=PATH         Diretório dos dados MIMIC-IV (modo real)\n",
          "  --skip-viz              Pular geração de gráficos\n",
          "  --skip-stat             Pular análises estatísticas\n",
          "  --skip-bench            Pular benchmarks\n",
          "  --cores=N               Número de núcleos para paralelização\n")
      quit(status = 0)
    } else {
      i <- i + 1
    }
  }
  parsed
}

# --- Timestamp para logging --------------------------------------------------
timestamp <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%S")
}

# --- Inicialização -----------------------------------------------------------
init_pipeline <- function(args) {
  sep_line <- paste(rep("=", 70), collapse = "")
  message(sep_line)
  message("  PIPELINE DE ENFERMAGEM MIMIC-IV → NANDA/NOC/NIC")
  message("  Prova de Conceito para Enfermagem de Precisão")
  message("  Início: ", timestamp())
  message(sep_line)

  # Configurar parâmetros
  PARAMS$mode    <- args$mode
  PARAMS$parallel_cores <- args$cores

  if (!is.null(args$data_dir)) {
    PATHS$data_dir <- args$data_dir
    PATHS$hosp_dir <- file.path(args$data_dir, "hosp")
    PATHS$icu_dir  <- file.path(args$data_dir, "icu")
  }

  # Criar diretórios de saída
  for (d in c(PATHS$output_dir, PATHS$figures_dir, PATHS$cache_dir)) {
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
  }

  message(sprintf("[PIPELINE] Modo: %s | Cores: %d", PARAMS$mode, PARAMS$parallel_cores))
  message(sprintf("[PIPELINE] Output: %s", PATHS$output_dir))

  args
}

# --- Execução Principal ------------------------------------------------------
main <- function() {

  # Parse args e inicializar
  args <- parse_args()
  args <- init_pipeline(args)

  total_start <- Sys.time()

  # =========================================================================
  # ETAPA 1: Carregamento de Dados
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 1/10: CARREGAMENTO DE DADOS")
  message(step_line)

  source(here::here("01_data_access.R"))
  data <- main_data_access(mode = PARAMS$mode, data_dir = args$data_dir)

  # =========================================================================
  # ETAPA 2: Mapeamento NANDA/NOC/NIC
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 2/10: MAPEAMENTO NANDA/NOC/NIC → MIMIC-IV")
  message(step_line)

  source(here::here("02_nursing_mapping.R"))

  nanda_raw <- extract_nanda_diagnostics(data)
  noc_raw   <- extract_noc_outcomes(data)
  nic_raw   <- extract_nic_interventions(data)

  # =========================================================================
  # ETAPA 3: Diagnósticos NANDA
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 3/10: PROCESSAMENTO DIAGNÓSTICOS NANDA")
  message(step_line)

  source(here::here("03_nanda_diagnostics.R"))
  nanda <- process_nanda_diagnostics(nanda_raw, data)
  save_nanda_results(nanda)

  # =========================================================================
  # ETAPA 4: Resultados NOC
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 4/10: PROCESSAMENTO RESULTADOS NOC")
  message(step_line)

  source(here::here("04_noc_outcomes.R"))
  noc <- process_noc_outcomes(noc_raw, data)
  save_noc_results(noc)

  # =========================================================================
  # ETAPA 5: Intervenções NIC
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 5/10: PROCESSAMENTO INTERVENÇÕES NIC")
  message(step_line)

  source(here::here("05_nic_interventions.R"))
  nic <- process_nic_interventions(nic_raw, data)
  save_nic_results(nic)

  # =========================================================================
  # ETAPA 6: Banco de Dados
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 6/10: CONSTRUÇÃO DO BANCO DE DADOS DE ENFERMAGEM")
  message(step_line)

  source(here::here("06_nursing_db.R"))
  db_path <- build_nursing_database(data, nanda, noc, nic)
  test_nursing_queries(db_path)

  # =========================================================================
  # ETAPA 7: Análises Estatísticas
  # =========================================================================
  stat_results <- NULL
  if (!args$skip_stat) {
    step_line <- paste(rep("#", 70), collapse = "")
    message(paste0("\n", step_line))
    message(" ETAPA 7/10: ANÁLISES ESTATÍSTICAS")
    message(step_line)

    source(here::here("07_statistical_analysis.R"))
    stat_results <- main_statistical_analysis(nanda, noc, nic, data)
  } else {
    message("\n[PIPELINE] Análises estatísticas puladas (--skip-stat).")
  }

  # =========================================================================
  # ETAPA 8: Visualizações
  # =========================================================================
  if (!args$skip_viz) {
    step_line <- paste(rep("#", 70), collapse = "")
    message(paste0("\n", step_line))
    message(" ETAPA 8/10: VISUALIZAÇÕES (CELL PRESS)")
    message(step_line)

    source(here::here("08_visualization.R"))
    gerar_todas_figuras(nanda, noc, nic, stat_results)
  } else {
    message("\n[PIPELINE] Visualizações puladas (--skip-viz).")
  }

  # =========================================================================
  # ETAPA 9: Auditoria
  # =========================================================================
  step_line <- paste(rep("#", 70), collapse = "")
  message(paste0("\n", step_line))
  message(" ETAPA 9/10: AUDITORIA DO PIPELINE")
  message(step_line)

  source(here::here("09_audit.R"))
  audit_report <- full_pipeline_audit(data, nanda_raw, nanda,
                                       noc_raw, noc,
                                       nic_raw, nic,
                                       db_path)

  # =========================================================================
  # ETAPA 10: Benchmarks
  # =========================================================================
  if (!args$skip_bench) {
    step_line <- paste(rep("#", 70), collapse = "")
    message(paste0("\n", step_line))
    message(" ETAPA 10/10: BENCHMARKS DE PERFORMANCE")
    message(step_line)

    source(here::here("10_benchmark.R"))
    bench_results <- run_benchmarks(data)
  } else {
    message("\n[PIPELINE] Benchmarks pulados (--skip-bench).")
  }

  # =========================================================================
  # FINALIZAÇÃO
  # =========================================================================
  total_elapsed <- as.numeric(difftime(Sys.time(), total_start, units = "secs"))

  final_line <- paste(rep("=", 70), collapse = "")
  message(paste0("\n", final_line))
  message("  PIPELINE CONCLUÍDO COM SUCESSO")
  message("  Fim: ", timestamp())
  message(sprintf("  Tempo total: %.1f segundos (%.1f minutos)",
                  total_elapsed, total_elapsed / 60))
  message(final_line)

  # --- Resumo dos artefatos gerados ------------------------------------------
  message("\n[RESUMO] Artefatos gerados em: ", PATHS$output_dir)

  artifacts <- list.files(PATHS$output_dir, recursive = TRUE, full.names = TRUE)
  for (a in artifacts) {
    if (!dir.exists(a)) {
      size <- file.size(a)
      message(sprintf("  %-50s %s", basename(a),
                      ifelse(size > 1e6, sprintf("%.1f MB", size/1e6),
                             sprintf("%.1f KB", size/1e3))))
    }
  }

  # --- Métricas finais -------------------------------------------------------
  message("\n[MÉTRICAS FINAIS]")
  message(sprintf("  Pacientes: %d", nrow(data$hosp$patients)))
  message(sprintf("  Diagnósticos NANDA: %d", nrow(nanda)))
  message(sprintf("  Indicadores NOC: %d", nrow(noc)))
  message(sprintf("  Intervenções NIC: %d", nrow(nic)))
  message(sprintf("  Banco de dados: %s", db_path))
  message(sprintf("  Auditoria: %s",
                  ifelse(audit_report$issues == 0, "APROVADO ✓", "REPROVADO ✗")))

  invisible(list(
    data = data, nanda = nanda, noc = noc, nic = nic,
    db_path = db_path, audit = audit_report
  ))
}

# Executar
main()
