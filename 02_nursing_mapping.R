# =============================================================================
# 02_nursing_mapping.R - Mapeamento NANDA/NOC/NIC → MIMIC-IV
# =============================================================================
# Etapa 2: Define as funções de mapeamento entre os conceitos de enfermagem
# (NANDA-I, NOC, NIC) e as tabelas/eventos do MIMIC-IV.
#
# Documentação de referência:
#   NANDA-I: Herdman et al. (2021) Nursing Diagnoses 2021-2023
#   NOC:     Moorhead et al. (2018) Nursing Outcomes Classification, 6th ed.
#   NIC:     Butcher et al. (2018) Nursing Interventions Classification, 7th ed.
# =============================================================================

#' Mapeia diagnósticos ICD-10 para domínios NANDA-I
#' @param icd_codes Vector de códigos ICD-10
#' @return data.table com mapeamento NANDA
map_icd_to_nanda <- function(icd_codes) {
  dt <- data.table(icd_code = icd_codes)
  dt[, nanda_domain := NA_character_]
  dt[, nanda_label := NA_character_]

  for (domain_name in names(NANDA_ICD_MAP)) {
    domain <- NANDA_ICD_MAP[[domain_name]]

    for (i in seq_along(domain$icd_codes)) {
      pattern <- domain$icd_codes[i]
      # Suporte a códigos parciais (ex: "E40" mapeia "E40", "E40.1", etc.)
      if (nchar(pattern) <= 3) {
        matched <- grepl(paste0("^", pattern), dt$icd_code)
      } else {
        matched <- dt$icd_code == pattern
      }

      label <- domain$nanda_labels[min(i, length(domain$nanda_labels))]
      dt[matched, nanda_domain := gsub("_", " ", domain_name)]
      dt[matched, nanda_label := label]
    }
  }

  # Contabilizar
  mapped <- dt[!is.na(nanda_domain), .N]
  unmapped <- dt[is.na(nanda_domain), .N]
  message(sprintf("[NANDA] Mapeados: %d/%d (%.1f%%) diagnósticos ICD → NANDA",
                  mapped, nrow(dt), 100*mapped/nrow(dt)))

  dt
}

#' Extrai hipóteses NANDA-I do módulo HOSP
#' Considera tanto diagnósticos médicos (ICD) quanto avaliações OMR
extract_nanda_diagnostics <- function(data) {

  message("[NANDA] Gerando hipóteses diagnósticas NANDA-I...")

  hosp <- data$hosp
  icu  <- data$icu

  # --- 1. Mapeamento ICD → NANDA (diagnósticos médicos) ---------------------
  if (!is.null(hosp$diagnoses_icd) && nrow(hosp$diagnoses_icd) > 0) {
    nanda_from_icd <- map_icd_to_nanda(hosp$diagnoses_icd$icd_code)
    nanda_from_icd[, hadm_id := hosp$diagnoses_icd$hadm_id]
    nanda_from_icd[, subject_id := hosp$diagnoses_icd$subject_id]
    nanda_from_icd[, source := "ICD-10"]
  } else {
    nanda_from_icd <- data.table()
  }

  # --- 2. Sinais vitais anormais como indicadores NANDA ---------------------
  if (!is.null(icu$chartevents) && nrow(icu$chartevents) > 0) {
    ce <- icu$chartevents

    # Taquicardia → "Risco de débito cardíaco diminuído"
    hr_high <- ce[itemid %in% ITEM_IDS$vitals$heart_rate &
                  valuenum > THRESHOLDS$vitals$heart_rate_high,
                  .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Atividade Repouso",
                    nanda_label = "Risco de débito cardíaco diminuído",
                    evidence = sprintf("FC: %.0f bpm", valuenum[1])),
                  by = stay_id]

    # Hipotensão → "Risco de perfusão tissular ineficaz"
    sys_low <- ce[itemid %in% ITEM_IDS$vitals$systolic_bp &
                  valuenum < THRESHOLDS$vitals$systolic_low,
                  .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Cardiovascular",
                    nanda_label = "Risco de perfusão tissular ineficaz",
                    evidence = sprintf("PAS: %.0f mmHg", valuenum[1])),
                  by = stay_id]

    # Hipoxemia → "Troca de gases prejudicada"
    spo2_low <- ce[itemid %in% ITEM_IDS$vitals$spo2 &
                   valuenum < THRESHOLDS$vitals$spo2_low,
                   .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Atividade Repouso",
                     nanda_label = "Troca de gases prejudicada",
                     evidence = sprintf("SpO2: %.0f%%", valuenum[1])),
                   by = stay_id]

    # Febre → "Hipertermia"
    fever <- ce[itemid %in% ITEM_IDS$vitals$temperature &
                valuenum > THRESHOLDS$vitals$temp_high,
                .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Segurança Proteção",
                  nanda_label = "Hipertermia",
                  evidence = sprintf("Temp: %.1f°C", valuenum[1])),
                by = stay_id]

    # Dor severa → "Dor aguda"
    pain_high <- ce[itemid %in% ITEM_IDS$scores$pain_score &
                    valuenum >= THRESHOLDS$pain_high,
                    .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Conforto",
                      nanda_label = "Dor aguda",
                      evidence = sprintf("Dor: %.0f/10", valuenum[1])),
                    by = stay_id]

    # GCS baixo → "Risco de perfusão tissular cerebral ineficaz"
    gcs_low <- ce[itemid %in% ITEM_IDS$scores$gcs_total &
                  valuenum <= THRESHOLDS$gcs_low,
                  .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Percepção Cognição",
                    nanda_label = "Perfusão tissular cerebral ineficaz",
                    evidence = sprintf("GCS: %.0f", valuenum[1])),
                  by = stay_id]

    # RASS elevado → "Risco de violência direcionada a outros"
    rass_high <- ce[itemid %in% ITEM_IDS$scores$rass &
                    valuenum >= THRESHOLDS$rass_agitated,
                    .(subject_id, hadm_id = hadm_id[1], nanda_domain = "Segurança Proteção",
                      nanda_label = "Risco de comportamento violento",
                      evidence = sprintf("RASS: +%.0f", valuenum[1])),
                    by = stay_id]

    nanda_from_vitals <- rbindlist(list(hr_high, sys_low, spo2_low, fever,
                                        pain_high, gcs_low, rass_high),
                                   use.names = TRUE, fill = TRUE)
    if (nrow(nanda_from_vitals) > 0) {
      nanda_from_vitals[, source := "Vital Signs"]
      nanda_from_vitals[, stay_id := NULL]
    }
  } else {
    nanda_from_vitals <- data.table()
  }

  # --- 3. Avaliações OMR → NANDA -------------------------------------------
  if (!is.null(hosp$omr) && nrow(hosp$omr) > 0) {
    omr <- hosp$omr

    # Braden baixo → "Risco de úlcera por pressão"
    braden_low <- omr[result_name == "Braden Scale" &
                      as.numeric(result_value) <= THRESHOLDS$braden_low,
                      .(subject_id, nanda_domain = "Segurança Proteção",
                        nanda_label = "Risco de úlcera por pressão",
                        evidence = paste("Braden:", result_value)),
                      by = chartdate]

    # Risco de queda → "Risco de quedas"
    fall_risk <- omr[result_name == "Fall Risk" & result_value == "High",
                     .(subject_id, nanda_domain = "Segurança Proteção",
                       nanda_label = "Risco de quedas",
                       evidence = "Alto risco de queda"),
                     by = chartdate]

    # Delirium positivo → "Confusão aguda"
    delirium <- omr[result_name == "Delirium Screening" & result_value == "Positive",
                    .(subject_id, nanda_domain = "Percepção Cognição",
                      nanda_label = "Confusão aguda",
                      evidence = "CAM-ICU positivo"),
                    by = chartdate]

    nanda_from_omr <- rbindlist(list(braden_low, fall_risk, delirium),
                                use.names = TRUE, fill = TRUE)
    if (nrow(nanda_from_omr) > 0) {
      nanda_from_omr[, source := "OMR Assessment"]
    }
  } else {
    nanda_from_omr <- data.table()
  }

  # --- 4. Anormalidades laboratoriais → NANDA ------------------------------
  if (!is.null(hosp$labevents) && nrow(hosp$labevents) > 0) {
    lab <- hosp$labevents

    # Albumina baixa → "Nutrição desequilibrada: menor que as necessidades"
    alb_low <- lab[itemid == LAB_ITEM_IDS["albumin"] &
                   valuenum < THRESHOLDS$labs$albumin_low,
                   .(subject_id, hadm_id, nanda_domain = "Nutrição",
                     nanda_label = "Nutrição desequilibrada",
                     evidence = sprintf("Albumina: %.1f g/dL", valuenum))]

    # Creatinina alta → "Risco de função renal prejudicada"
    creat_high <- lab[itemid == LAB_ITEM_IDS["creatinine"] &
                      valuenum > THRESHOLDS$labs$creatinine_high,
                      .(subject_id, hadm_id, nanda_domain = "Eliminação",
                        nanda_label = "Eliminação urinária prejudicada",
                        evidence = sprintf("Creatinina: %.2f mg/dL", valuenum))]

    # Hemoglobina baixa → "Risco de perfusão tissular ineficaz"
    hb_low <- lab[itemid == LAB_ITEM_IDS["hemoglobin"] &
                  valuenum < THRESHOLDS$labs$hemoglobin_low,
                  .(subject_id, hadm_id, nanda_domain = "Cardiovascular",
                    nanda_label = "Risco de perfusão tissular ineficaz",
                    evidence = sprintf("Hb: %.1f g/dL", valuenum))]

    # Glicose alta → "Risco de glicemia instável"
    glu_high <- lab[itemid == LAB_ITEM_IDS["glucose"] &
                    valuenum > THRESHOLDS$labs$glucose_high,
                    .(subject_id, hadm_id, nanda_domain = "Nutrição",
                      nanda_label = "Risco de glicemia instável",
                      evidence = sprintf("Glicose: %.0f mg/dL", valuenum))]

    # Potássio alterado → "Risco de desequilíbrio eletrolítico"
    k_abnormal <- lab[itemid == LAB_ITEM_IDS["potassium"] &
                      (valuenum < THRESHOLDS$labs$potassium_low |
                       valuenum > THRESHOLDS$labs$potassium_high),
                      .(subject_id, hadm_id, nanda_domain = "Nutrição",
                        nanda_label = "Risco de desequilíbrio eletrolítico",
                        evidence = sprintf("K+: %.1f mEq/L", valuenum))]

    # Lactato alto → "Risco de perfusão tissular ineficaz"
    lac_high <- lab[itemid == LAB_ITEM_IDS["lactate"] & valuenum > 2.0,
                    .(subject_id, hadm_id, nanda_domain = "Cardiovascular",
                      nanda_label = "Perfusão tissular periférica ineficaz",
                      evidence = sprintf("Lactato: %.1f mmol/L", valuenum))]

    nanda_from_labs <- rbindlist(list(alb_low, creat_high, hb_low, glu_high,
                                      k_abnormal, lac_high),
                                 use.names = TRUE, fill = TRUE)
    if (nrow(nanda_from_labs) > 0) {
      nanda_from_labs[, source := "Laboratory"]
    }
  } else {
    nanda_from_labs <- data.table()
  }

  # --- Consolidar -----------------------------------------------------------
  all_nanda <- rbindlist(list(nanda_from_icd, nanda_from_vitals,
                              nanda_from_omr, nanda_from_labs),
                         use.names = TRUE, fill = TRUE)

  if (nrow(all_nanda) == 0) {
    warning("[NANDA] Nenhum diagnóstico de enfermagem identificado!")
    return(data.table())
  }

  # Adicionar IDs únicos
  all_nanda[, nanda_id := .I]

  # Cleanup
  all_nanda[, chartdate := NULL]

  message(sprintf("[NANDA] Total de hipóteses diagnósticas NANDA-I derivadas: %d", nrow(all_nanda)))

  # Resumo por domínio
  summary <- all_nanda[, .N, by = nanda_domain][order(-N)]
  message("[NANDA] Distribuição por domínio:")
  for (i in seq_len(min(8, nrow(summary)))) {
    message(sprintf("  %-30s: %5d", summary$nanda_domain[i], summary$N[i]))
  }

  all_nanda
}

#' Extrai resultados de enfermagem (NOC) dos dados
extract_noc_outcomes <- function(data) {
  message("\n[NOC] Extraindo resultados de enfermagem...")

  icu  <- data$icu
  hosp <- data$hosp
  output <- list()

  # --- 1. Sinais Vitais (NOC 0802) ------------------------------------------
  if (!is.null(icu$chartevents) && nrow(icu$chartevents) > 0) {
    ce <- icu$chartevents

    # Heart Rate
    hr <- ce[itemid %in% ITEM_IDS$vitals$heart_rate,
             .(stay_id, subject_id, hadm_id, charttime,
               noc_code = "0802", noc_label = "Estado dos Sinais Vitais",
               indicator = "Frequência Cardíaca",
               value = valuenum, unit = "bpm",
               abnormal = valuenum < THRESHOLDS$vitals$heart_rate_low |
                          valuenum > THRESHOLDS$vitals$heart_rate_high)]

    # Systolic BP
    sbp <- ce[itemid %in% ITEM_IDS$vitals$systolic_bp,
              .(stay_id, subject_id, hadm_id, charttime,
                noc_code = "0802", noc_label = "Estado dos Sinais Vitais",
                indicator = "Pressão Arterial Sistólica",
                value = valuenum, unit = "mmHg",
                abnormal = valuenum < THRESHOLDS$vitals$systolic_low |
                           valuenum > THRESHOLDS$vitals$systolic_high)]

    # Diastolic BP
    dbp <- ce[itemid %in% ITEM_IDS$vitals$diastolic_bp,
              .(stay_id, subject_id, hadm_id, charttime,
                noc_code = "0802", noc_label = "Estado dos Sinais Vitais",
                indicator = "Pressão Arterial Diastólica",
                value = valuenum, unit = "mmHg",
                abnormal = FALSE)]  # Generic DBP threshold harder to define

    # SpO2
    spo2 <- ce[itemid %in% ITEM_IDS$vitals$spo2,
               .(stay_id, subject_id, hadm_id, charttime,
                 noc_code = "0415", noc_label = "Estado Respiratório",
                 indicator = "Saturação de Oxigênio",
                 value = valuenum, unit = "%",
                 abnormal = valuenum < THRESHOLDS$vitals$spo2_low)]

    # Temperature
    temp <- ce[itemid %in% ITEM_IDS$vitals$temperature,
               .(stay_id, subject_id, hadm_id, charttime,
                 noc_code = "0802", noc_label = "Estado dos Sinais Vitais",
                 indicator = "Temperatura Corporal",
                 value = valuenum, unit = "°C",
                 abnormal = valuenum > THRESHOLDS$vitals$temp_high |
                            valuenum < THRESHOLDS$vitals$temp_low)]

    # Respiratory Rate
    rr <- ce[itemid %in% ITEM_IDS$vitals$respiratory,
             .(stay_id, subject_id, hadm_id, charttime,
               noc_code = "0415", noc_label = "Estado Respiratório",
               indicator = "Frequência Respiratória",
               value = valuenum, unit = "rpm",
               abnormal = valuenum > THRESHOLDS$vitals$rr_high |
                          valuenum < THRESHOLDS$vitals$rr_low)]

    # GCS (NOC 0912 - Estado Neurológico)
    gcs <- ce[itemid %in% ITEM_IDS$scores$gcs_total,
              .(stay_id, subject_id, hadm_id, charttime,
                noc_code = "0912", noc_label = "Estado Neurológico: Consciência",
                indicator = "Escala de Coma de Glasgow",
                value = valuenum, unit = "score",
                abnormal = valuenum <= THRESHOLDS$gcs_low)]

    # Pain Scores (NOC 1605 - Controle da Dor)
    pain <- ce[itemid %in% ITEM_IDS$scores$pain_score,
               .(stay_id, subject_id, hadm_id, charttime,
                 noc_code = "1605", noc_label = "Controle da Dor",
                 indicator = "Intensidade da Dor (NRS)",
                 value = valuenum, unit = "0-10",
                 abnormal = valuenum >= THRESHOLDS$pain_high)]

    # Weight (NOC 1006 - Peso Corporal)
    weight <- ce[itemid %in% ITEM_IDS$vitals$weight,
                 .(stay_id, subject_id, hadm_id, charttime,
                   noc_code = "0601", noc_label = "Equilíbrio Hídrico",
                   indicator = "Peso Corporal",
                   value = valuenum, unit = "kg",
                   abnormal = FALSE)]

    output$vitals <- rbindlist(list(hr, sbp, dbp, spo2, temp, rr, gcs, pain, weight),
                               use.names = TRUE, fill = TRUE)
  }

  # --- 2. Balanço Hídrico (NOC 0601) ----------------------------------------
  if (!is.null(icu$inputevents) && nrow(icu$inputevents) > 0) {
    inp <- icu$inputevents
    intake <- inp[, .(stay_id, subject_id, hadm_id, charttime,
                      noc_code = "0601", noc_label = "Equilíbrio Hídrico",
                      indicator = "Volume Infundido",
                      value = amount, unit = "mL",
                      abnormal = FALSE)]

    output$intake <- intake
  }

  if (!is.null(icu$outputevents) && nrow(icu$outputevents) > 0) {
    out <- icu$outputevents
    urine <- out[, .(stay_id, subject_id, hadm_id, charttime,
                     noc_code = "0601", noc_label = "Equilíbrio Hídrico",
                     indicator = "Débito Urinário",
                     value = value, unit = "mL",
                     abnormal = FALSE)]

    output$urine <- urine
  }

  # --- 3. Escala de Braden (NOC 1101 - Integridade Tissular) -----------------
  if (!is.null(hosp$omr) && nrow(hosp$omr) > 0) {
    braden <- hosp$omr[result_name == "Braden Scale",
                       .(subject_id, chartdate,
                         noc_code = "1101",
                         noc_label = "Integridade Tissular: Pele e Mucosas",
                         indicator = "Escore de Braden",
                         value = as.numeric(result_value),
                         unit = "6-23",
                         abnormal = as.numeric(result_value) <= THRESHOLDS$braden_low)]

    if (nrow(braden) > 0) {
      output$braden <- braden
    }
  }

  # Consolidar
  all_noc <- rbindlist(output, use.names = TRUE, fill = TRUE)

  if (nrow(all_noc) > 0) {
    all_noc[, noc_id := .I]
  }

  message(sprintf("[NOC] Total de indicadores NOC operacionalizados: %d", nrow(all_noc)))
  if (nrow(all_noc) > 0) {
    message("[NOC] Distribuição por resultado:")
    summary <- all_noc[, .N, by = noc_label][order(-N)]
    for (i in seq_len(min(6, nrow(summary)))) {
      message(sprintf("  %-40s: %6d", summary$noc_label[i], summary$N[i]))
    }
  }

  all_noc
}

#' Extrai intervenções de enfermagem (NIC) dos dados
extract_nic_interventions <- function(data) {
  message("\n[NIC] Extraindo intervenções de enfermagem...")

  icu  <- data$icu
  hosp <- data$hosp
  output <- list()

  # --- 1. Administração de Medicamentos (NIC 2300) --------------------------
  if (!is.null(hosp$emar) && nrow(hosp$emar) > 0) {
    emar <- hosp$emar

    if (!is.null(hosp$emar_detail) && nrow(hosp$emar_detail) > 0) {
      # Join com emar_detail para ter horário exato
      med_adm <- merge(emar[, .(subject_id, hadm_id, emar_id, medication,
                                route, administration_type)],
                       hosp$emar_detail[, .(emar_id, charttime, dose_given)],
                       by = "emar_id", all.x = TRUE, allow.cartesian = TRUE)

      med_adm[, `:=`(nic_code = "2300",
                     nic_label = "Administração de Medicamentos",
                     intervention_type = paste0("Medicação: ", medication))]

      output$medications <- med_adm
    }
  }

  # --- 2. Terapia Intravenosa (NIC 4200) ------------------------------------
  if (!is.null(icu$inputevents) && nrow(icu$inputevents) > 0) {
    iv_fluids <- icu$inputevents[ordercategoryname %like% "NS|LR|D5|Plasma|RBC|FFP|Platelet"]

    if (nrow(iv_fluids) > 0) {
      iv_fluids[, `:=`(nic_code = "4200",
                       nic_label = "Terapia Intravenosa",
                       intervention_type = paste0("Fluido IV: ", ordercategoryname))]
      output$iv_fluids <- iv_fluids
    }
  }

  # --- 3. Monitorização de Sinais Vitais (NIC 6680) -------------------------
  if (!is.null(icu$chartevents) && nrow(icu$chartevents) > 0) {
    # Contar frequência de monitorização
    vitals_monitoring <- icu$chartevents[
      itemid %in% c(unlist(ITEM_IDS$vitals), unlist(ITEM_IDS$scores)),
      .(n_measurements = .N, first_measurement = min(charttime),
        last_measurement = max(charttime)),
      by = stay_id]

    if (nrow(vitals_monitoring) > 0) {
      vitals_monitoring[, `:=`(nic_code = "6680",
                               nic_label = "Monitorização de Sinais Vitais",
                               intervention_type = "Monitorização de Sinais Vitais")]
      output$vitals_monitoring <- vitals_monitoring
    }
  }

  # --- 4. Controle da Dor (NIC 1400) ----------------------------------------
  if (!is.null(hosp$prescriptions) && nrow(hosp$prescriptions) > 0) {
    analgesics <- hosp$prescriptions[
      drug %like% "Morphine|Fentanyl|Acetaminophen|Ibuprofen|Hydromorphone|Oxycodone|Ketorolac"]

    if (nrow(analgesics) > 0) {
      analgesics[, `:=`(nic_code = "1400",
                        nic_label = "Controle da Dor",
                        intervention_type = paste0("Analgésico: ", drug))]
      output$analgesics <- analgesics
    }
  }

  # --- 5. Cuidados com Pele / Posicionamento (NIC 3540, 0840) ---------------
  if (!is.null(icu$procedureevents) && nrow(icu$procedureevents) > 0) {
    proc <- icu$procedureevents

    skin_care <- proc[ordercategoryname %like% "Wound|Dressing|Skin|Pressure|Oral|Eye"]
    if (nrow(skin_care) > 0) {
      skin_care[, `:=`(nic_code = "3540",
                       nic_label = "Prevenção de Úlcera por Pressão",
                       intervention_type = ordercategoryname)]
      output$skin_care <- skin_care
    }

    positioning <- proc[ordercategoryname %like% "Positioning|Turning"]
    if (nrow(positioning) > 0) {
      positioning[, `:=`(nic_code = "0840",
                         nic_label = "Posicionamento",
                         intervention_type = ordercategoryname)]
      output$positioning <- positioning
    }

    airway <- proc[ordercategoryname %like% "Suctioning|Tracheostomy|Airway"]
    if (nrow(airway) > 0) {
      airway[, `:=`(nic_code = "3180",
                    nic_label = "Cuidados com Vias Aéreas",
                    intervention_type = ordercategoryname)]
      output$airway_care <- airway
    }
  }

  # --- 6. Nutrição Enteral (NIC 1056) ---------------------------------------
  if (!is.null(icu$inputevents) && nrow(icu$inputevents) > 0) {
    nutrition <- icu$inputevents[ordercategoryname %like% "Enteral|TPN|Tube Feed"]

    if (nrow(nutrition) > 0) {
      nutrition[, `:=`(nic_code = "1056",
                       nic_label = "Nutrição Enteral",
                       intervention_type = ordercategoryname)]
      output$nutrition <- nutrition
    }
  }

  # Consolidar
  all_nic <- rbindlist(output, use.names = TRUE, fill = TRUE)

  if (nrow(all_nic) > 0) {
    all_nic[, nic_id := .I]
  }

  message(sprintf("[NIC] Total de proxies/recomendações NIC derivadas: %d", nrow(all_nic)))
  if (nrow(all_nic) > 0) {
    message("[NIC] Distribuição por intervenção:")
    summary <- all_nic[, .N, by = nic_label][order(-N)]
    for (i in seq_len(min(8, nrow(summary)))) {
      message(sprintf("  %-40s: %6d", summary$nic_label[i], summary$N[i]))
    }
  }

  all_nic
}

# Executar
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  nanda <- extract_nanda_diagnostics(data)
  noc   <- extract_noc_outcomes(data)
  nic   <- extract_nic_interventions(data)
}
