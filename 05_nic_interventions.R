# =============================================================================
# 05_nic_interventions.R - Intervenções de Enfermagem NIC
# =============================================================================
# Etapa 5: Processamento e análise das intervenções de enfermagem (NIC)
# extraídas do MIMIC-IV.
#
# Ref: Butcher, H.K. et al. (2018). Nursing Interventions Classification
#      (NIC). Elsevier. 7th Edition.
# =============================================================================

#' Processa intervenções NIC com métricas de cuidado
process_nic_interventions <- function(nic_data, data) {

  if (nrow(nic_data) == 0) {
    warning("[NIC] Sem dados para processar.")
    return(nic_data)
  }

  message("[NIC] Processando ", nrow(nic_data), " intervenções...")

  # Adicionar demográficos
  if (!is.null(data$hosp$patients)) {
    pat <- data$hosp$patients[, .(subject_id, gender, anchor_age)]
    nic_data <- merge(nic_data, pat, by = "subject_id", all.x = TRUE)
  }

  # --- Análise por tipo de intervenção NIC ----------------------------------
  nic_summary <- nic_data[, .(
    n_interventions = .N,
    n_patients = uniqueN(subject_id),
    n_stays = if ("stay_id" %in% names(.SD)) uniqueN(stay_id) else NA_integer_,
    interventions_per_patient = round(.N / uniqueN(subject_id), 1)
  ), by = .(nic_code, nic_label)]

  message("\n[NIC] Resumo por intervenção:")
  print(nic_summary[, .(Intervenção = nic_label, Código = nic_code,
                        `N Intervenções` = n_interventions,
                        Pacientes = n_patients,
                        `Interv/Paciente` = interventions_per_patient)])

  # --- Frequência de administração de medicamentos --------------------------
  if ("medication" %in% names(nic_data)) {
    med_stats <- nic_data[nic_code == "2300",
                          .(n_admin = .N,
                            n_patients = uniqueN(subject_id)),
                          by = medication][order(-n_admin)]

    message("\n[NIC] Top 10 medicamentos mais administrados:")
    print(head(med_stats, 10))

    # Via de administração
    if ("route" %in% names(nic_data)) {
      route_stats <- nic_data[nic_code == "2300", .N, by = route][order(-N)]
      message("\n[NIC] Distribuição por via de administração:")
      print(route_stats)
    }

    # Tipo de administração (Scheduled vs PRN vs STAT)
    if ("administration_type" %in% names(nic_data)) {
      adm_type <- nic_data[nic_code == "2300", .N, by = administration_type][order(-N)]
      message("\n[NIC] Tipo de administração:")
      print(adm_type)
    }

    attr(nic_data, "med_stats") <- med_stats
  }

  # --- Carga de trabalho de enfermagem (NIC 6680) --------------------------
  if ("n_measurements" %in% names(nic_data)) {
    vitals_stats <- nic_data[nic_code == "6680",
                             .(mean_measurements = mean(n_measurements, na.rm = TRUE),
                               median_measurements = median(n_measurements, na.rm = TRUE),
                               sd_measurements = sd(n_measurements, na.rm = TRUE),
                               min_measurements = min(n_measurements, na.rm = TRUE),
                               max_measurements = max(n_measurements, na.rm = TRUE))]

    message(sprintf("\n[NIC] Carga de monitorização (por stay ICU):"))
    message(sprintf("  Média de aferições: %.0f (SD: %.0f, mediana: %.0f)",
                    vitals_stats$mean_measurements, vitals_stats$sd_measurements,
                    vitals_stats$median_measurements))
    message(sprintf("  Range: %d - %d",
                    vitals_stats$min_measurements, vitals_stats$max_measurements))

    attr(nic_data, "vitals_stats") <- vitals_stats
  }

  # --- Análise de fluidos IV (NIC 4200) -------------------------------------
  if (all(c("ordercategoryname", "amount") %in% names(nic_data))) {
    fluid_stats <- nic_data[nic_code == "4200" & !is.na(amount),
                            .(total_volume = sum(amount, na.rm = TRUE),
                              mean_volume = mean(amount, na.rm = TRUE),
                              n_infusions = .N,
                              n_patients = uniqueN(subject_id)),
                            by = ordercategoryname][order(-total_volume)]

    message("\n[NIC] Volume de fluidos IV por tipo:")
    print(fluid_stats[, .(Fluido = ordercategoryname,
                          `Volume Total (L)` = round(total_volume/1000, 1),
                          `Média (mL)` = round(mean_volume, 0),
                          `N Infusões` = n_infusions)])

    attr(nic_data, "fluid_stats") <- fluid_stats
  }

  # --- Cuidados com pele (NIC 3540) -----------------------------------------
  if ("ordercategoryname" %in% names(nic_data)) {
    skin_proc <- nic_data[nic_code == "3540", .N, by = ordercategoryname][order(-N)]
    if (nrow(skin_proc) > 0) {
      message("\n[NIC] Procedimentos de cuidados com pele:")
      print(skin_proc)
      attr(nic_data, "skin_procedures") <- skin_proc
    }
  }

  # --- Análise temporal ------------------------------------------------------
  if ("charttime" %in% names(nic_data)) {
    nic_with_time <- nic_data[!is.na(charttime)]

    # Intervenções por hora do dia (padrão de turnos de enfermagem)
    nic_with_time[, hour_of_day := hour(charttime)]
    interventions_by_hour <- nic_with_time[, .N, by = hour_of_day][order(hour_of_day)]

    message("\n[NIC] Intervenções por hora do dia (turnos de enfermagem):")
    print(interventions_by_hour)

    attr(nic_data, "interventions_by_hour") <- interventions_by_hour
  }

  # --- Intensidade de cuidado por paciente ----------------------------------
  patient_intensity <- nic_data[, .(
    n_interventions = .N,
    n_types = uniqueN(nic_label)
  ), by = subject_id]

  message(sprintf("\n[NIC] Média de intervenções por paciente: %.1f (SD: %.1f)",
                  mean(patient_intensity$n_interventions),
                  sd(patient_intensity$n_interventions)))
  message(sprintf("[NIC] Média de tipos de intervenção por paciente: %.1f",
                  mean(patient_intensity$n_types)))

  attr(nic_data, "patient_intensity") <- patient_intensity
  attr(nic_data, "nic_summary") <- nic_summary
  attr(nic_data, "n_total") <- nrow(nic_data)
  attr(nic_data, "n_patients") <- nic_data[, uniqueN(subject_id)]

  nic_data
}

#' Salva as intervenções NIC processadas
save_nic_results <- function(nic_data) {
  dir.create(PATHS$output_dir, showWarnings = FALSE, recursive = TRUE)

  fwrite(nic_data, file.path(PATHS$output_dir, "nic_interventions.csv"))

  # Salvar sumário
  summary <- attr(nic_data, "nic_summary")
  if (!is.null(summary)) {
    fwrite(summary, file.path(PATHS$output_dir, "nic_summary.csv"))
  }

  message(sprintf("[NIC] Resultados salvos em: %s", PATHS$output_dir))
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  nic_raw <- extract_nic_interventions(data)
  nic_processed <- process_nic_interventions(nic_raw, data)
  save_nic_results(nic_processed)
}
