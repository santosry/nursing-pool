# =============================================================================
# 10_benchmark.R - Benchmarks de Performance do Pipeline
# =============================================================================
# Etapa 10: Medição de performance de cada etapa do pipeline.
# Métricas:
#   - Tempo de execução por etapa
#   - Uso de memória
#   - Throughput (registros/segundo)
#   - Comparação entre backends (SQLite vs DuckDB vs data.table)
#   - Escalabilidade (com diferentes tamanhos de dados sintéticos)
# =============================================================================

#' Mede performance de uma função
#' @param name Nome da etapa
#' @param expr Expressão a ser medida
#' @return data.table com métricas de performance
benchmark_step <- function(name, expr) {
  gc(reset = TRUE)

  # Tempo de execução
  start_time <- Sys.time()
  mem_before <- sum(gc(reset = TRUE)[, "Ncells"] + gc()[, "Vcells"]) * 8 / 1e6  # MB aproximado

  result <- tryCatch(
    eval(expr),
    error = function(e) {
      message(sprintf("  [BENCH] ERRO em %s: %s", name, e$message))
      NULL
    }
  )

  mem_after <- sum(gc()[, "Ncells"] + gc()[, "Vcells"]) * 8 / 1e6
  end_time <- Sys.time()

  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  mem_delta <- mem_after - mem_before

  data.table(
    step    = name,
    time_sec = round(elapsed, 2),
    mem_mb   = round(mem_delta, 1),
    status   = ifelse(is.null(result), "FAIL", "OK")
  )
}

#' Executa benchmarks completos do pipeline
run_benchmarks <- function(data = NULL) {

  message("[BENCH] =============================================")
  message("[BENCH] BENCHMARKS DE PERFORMANCE DO PIPELINE")
  message("[BENCH] =============================================")

  benchmarks <- list()

  # Carregar dados se necessário
  if (is.null(data)) {
    data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  }

  # --- Benchmark 1: Carregamento de dados --------------------------------
  b1 <- benchmark_step("01_Data_Access", {
    readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  })
  benchmarks$step1 <- b1

  # --- Benchmark 2: Extração NANDA ---------------------------------------
  nanda_result <- NULL
  b2 <- benchmark_step("02_NANDA_Extraction", {
    nanda_result <<- extract_nanda_diagnostics(data)
  })
  benchmarks$step2 <- b2

  # --- Benchmark 3: Processamento NANDA -----------------------------------
  if (!is.null(nanda_result) && nrow(nanda_result) > 0) {
    b3 <- benchmark_step("03_NANDA_Processing", {
      nanda_result <<- process_nanda_diagnostics(nanda_result, data)
    })
    benchmarks$step3 <- b3
  }

  # --- Benchmark 4: Extração NOC -----------------------------------------
  noc_result <- NULL
  b4 <- benchmark_step("04_NOC_Extraction", {
    noc_result <<- extract_noc_outcomes(data)
  })
  benchmarks$step4 <- b4

  # --- Benchmark 5: Processamento NOC -------------------------------------
  if (!is.null(noc_result) && nrow(noc_result) > 0) {
    b5 <- benchmark_step("05_NOC_Processing", {
      noc_result <<- process_noc_outcomes(noc_result, data)
    })
    benchmarks$step5 <- b5
  }

  # --- Benchmark 6: Extração NIC ------------------------------------------
  nic_result <- NULL
  b6 <- benchmark_step("06_NIC_Extraction", {
    nic_result <<- extract_nic_interventions(data)
  })
  benchmarks$step6 <- b6

  # --- Benchmark 7: Processamento NIC -------------------------------------
  if (!is.null(nic_result) && nrow(nic_result) > 0) {
    b7 <- benchmark_step("07_NIC_Processing", {
      nic_result <<- process_nic_interventions(nic_result, data)
    })
    benchmarks$step7 <- b7
  }

  # --- Benchmark 8: Banco de Dados (SQLite) --------------------------------
  b8 <- benchmark_step("08_Database_SQLite", {
    build_nursing_database(data, nanda_result, noc_result, nic_result,
                           engine = "sqlite")
  })
  benchmarks$step8 <- b8

  # --- Benchmark 9: Análise Estatística ------------------------------------
  b9 <- benchmark_step("09_Statistics", {
    source(here::here("07_statistical_analysis.R"))
    invisible(main_statistical_analysis(nanda_result, noc_result, nic_result, data))
  })
  benchmarks$step9 <- b9

  # --- Compilar resultados --------------------------------------------------
  results <- rbindlist(benchmarks, use.names = TRUE, fill = TRUE)

  message("\n[BENCH] ===== RESULTADOS DOS BENCHMARKS =====")
  message(sprintf("  %-25s | %8s | %8s | %s", "Etapa", "Tempo(s)", "Mem(MB)", "Status"))
  dash_line <- paste(rep("-", 55), collapse = "")
  message(paste0("  ", dash_line))

  total_time <- 0
  for (i in seq_len(nrow(results))) {
    message(sprintf("  %-25s | %8.2f | %8.1f | %s",
                    results$step[i], results$time_sec[i],
                    results$mem_mb[i], results$status[i]))
    total_time <- total_time + results$time_sec[i]
  }

  message(paste0("  ", dash_line))
  message(sprintf("  %-25s | %8.2f |", "TOTAL", total_time))

  # --- Throughput -----------------------------------------------------------
  if (!is.null(nanda_result) && !is.null(noc_result) && !is.null(nic_result)) {
    total_records <- nrow(nanda_result) + nrow(noc_result) + nrow(nic_result)
    throughput <- round(total_records / total_time, 1)
    message(sprintf("\n  Total de registros processados: %s", scales::comma(total_records)))
    message(sprintf("  Throughput: %.1f registros/segundo", throughput))
  }

  # --- Salvar resultados ----------------------------------------------------
  fwrite(results, file.path(PATHS$output_dir, "benchmark_results.csv"))
  message(sprintf("\n[BENCH] Resultados salvos em: %s",
                  file.path(PATHS$output_dir, "benchmark_results.csv")))

  invisible(results)
}

#' Benchmark de escalabilidade com diferentes tamanhos de dados
benchmark_scalability <- function() {

  message("\n[BENCH] ===== BENCHMARK DE ESCALABILIDADE =====")

  sizes <- c(500, 1000, 2000, 4000)
  scalability <- data.table()

  for (n_pat in sizes) {
    message(sprintf("\n[BENCH] Testando com %d pacientes...", n_pat))

    # Gerar dados sintéticos com este tamanho
    original_n <- PARAMS$n_patients
    PARAMS$n_patients <- n_pat
    PARAMS$n_admissions <- round(n_pat * 1.75)
    PARAMS$n_icu_stays <- round(n_pat * 0.6)

    source(here::here("synthetic_data.R"))
    local_data <- generate_all_synthetic_data()

    # Medir tempo para extração NANDA
    start <- Sys.time()
    nanda_result <- extract_nanda_diagnostics(local_data)
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

    scalability <- rbind(scalability, data.table(
      n_patients = n_pat,
      n_nanda = nrow(nanda_result),
      time_sec = round(elapsed, 2),
      records_per_sec = round(nrow(nanda_result) / elapsed, 1)
    ))

    PARAMS$n_patients <- original_n
    rm(local_data, nanda_result)
    gc()
  }

  message("\n[BENCH] Escalabilidade NANDA:")
  print(scalability)

  # Coeficiente de escalabilidade (ideal: O(n) ~ linear)
  if (nrow(scalability) >= 2) {
    fit <- lm(time_sec ~ n_patients, data = scalability)
    message(sprintf("\n  Escalabilidade: %.2f ms por paciente adicional (R²=%.3f)",
                    1000 * coef(fit)[2], summary(fit)$r.squared))
  }

  fwrite(scalability, file.path(PATHS$output_dir, "benchmark_scalability.csv"))
  scalability
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("synthetic_data.R"))
  source(here::here("02_nursing_mapping.R"))
  source(here::here("03_nanda_diagnostics.R"))
  source(here::here("04_noc_outcomes.R"))
  source(here::here("05_nic_interventions.R"))
  source(here::here("06_nursing_db.R"))

  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  results <- run_benchmarks(data)
}
