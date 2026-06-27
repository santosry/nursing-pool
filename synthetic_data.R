# =============================================================================
# synthetic_data.R - Gerador de Dados Sintéticos MIMIC-IV para Testes
# =============================================================================
# Gera um conjunto de dados sintéticos que mimetiza a estrutura do MIMIC-IV
# para permitir teste e demonstração do pipeline sem acesso aos dados reais.
# TODO: Dados reais exigem acesso credenciado via PhysioNet.
# =============================================================================

library(data.table)
library(lubridate)

#' Gera dados sintéticos do módulo HOSP
generate_hosp_module <- function(n_patients = 2000, n_admissions = 3500,
                                  start_date = "2100-01-01", end_date = "2103-12-31") {

  message("[SYNTHETIC] Gerando módulo HOSP...")
  set.seed(PARAMS$random_seed)

  # Criar sequências temporais
  start_dt <- as.POSIXct(start_date)
  end_dt   <- as.POSIXct(end_date)
  hourly_seq   <- seq(start_dt, end_dt, by = "hour")
  minutely_seq <- seq(start_dt, end_dt, by = "min")

  # Calcular dias no período para probabilidades
  all_dates <- seq(as.Date(start_date), as.Date(end_date), by = "day")
  n_dates <- length(all_dates)

  # --- patients --------------------------------------------------------------
  patients <- data.table(
    subject_id    = 1:n_patients,
    gender        = sample(c("M", "F"), n_patients, replace = TRUE, prob = c(0.54, 0.46)),
    anchor_age    = pmax(pmin(round(rnorm(n_patients, 62, 18)), 89), 18),
    anchor_year   = sample(2150:2180, n_patients, replace = TRUE),
    dod           = sample(c(NA_character_, as.character(all_dates)), n_patients,
                         replace = TRUE, prob = c(0.78, rep(0.22/n_dates, n_dates)))
  )

  # --- admissions ------------------------------------------------------------
  admissions <- data.table(
    subject_id        = sample(1:n_patients, n_admissions, replace = TRUE),
    hadm_id           = 20000000 + (1:n_admissions),
    admittime         = sample(hourly_seq, n_admissions, replace = TRUE),
    dischtime         = NA,
    admission_type    = sample(c("EMERGENCY", "URGENT", "ELECTIVE", "OBSERVATION"),
                               n_admissions, replace = TRUE,
                               prob = c(0.55, 0.10, 0.30, 0.05)),
    admission_location = sample(c("EMERGENCY ROOM", "TRANSFER FROM HOSP",
                                  "PHYSICIAN REFERRAL", "INTERNAL"),
                                n_admissions, replace = TRUE),
    discharge_location = sample(c("HOME", "SNF", "REHAB", "DEAD/EXPIRED",
                                  "AGAINST ADVICE"),
                                n_admissions, replace = TRUE,
                                prob = c(0.58, 0.15, 0.10, 0.12, 0.05)),
    insurance          = sample(c("Medicare", "Medicaid", "Private", "Other"),
                                n_admissions, replace = TRUE,
                                prob = c(0.45, 0.15, 0.32, 0.08)),
    language          = sample(c("ENG", "SPA", "OTHER"), n_admissions,
                               replace = TRUE, prob = c(0.80, 0.10, 0.10)),
    marital_status    = sample(c("MARRIED", "SINGLE", "WIDOWED", "DIVORCED"),
                               n_admissions, replace = TRUE),
    ethnicity         = sample(c("WHITE", "BLACK", "HISPANIC", "ASIAN", "OTHER"),
                               n_admissions, replace = TRUE,
                               prob = c(0.60, 0.15, 0.10, 0.08, 0.07))
  )

  # Calcular dischtime (LOS ~ log-normal)
  los <- pmax(0.5, rlnorm(n_admissions, meanlog = 1.8, sdlog = 0.7))
  admissions[, dischtime := admittime + days(floor(los)) + hours(floor((los - floor(los)) * 24))]

  # --- diagnoses_icd ---------------------------------------------------------
  # Criar diagnósticos relevantes para enfermagem (NANDA domains)
  nursing_relevant_icd <- c(
    # Nutrição
    "E46", "E66.9", "E11.9", "E43",
    # Eliminação
    "N17.9", "N18.9", "N39.0", "K59.0",
    # Percepção/Cognição
    "F05.9", "G93.40", "R41.0",
    # Segurança/Proteção
    "A41.9", "J18.9", "L89.9", "R55",
    # Conforto
    "R52", "M79.1", "R10.9",
    # Atividade/Repouso
    "I50.9", "J96.9", "R53.1", "R26.2",
    # Cardiovascular
    "I10", "I21.9", "I48.91", "R57.0",
    # Outros (para diversidade)
    "F32.9", "I12.0", "J44.9", "K92.2", "N40.0",
    "S06.9", "T78.4", "Z68.41", "D64.9", "E87.1"
  )

  n_diagnoses <- n_admissions * 6  # ~6 diagnoses per admission
  diagnoses_icd <- data.table(
    subject_id = sample(patients$subject_id, n_diagnoses, replace = TRUE),
    hadm_id    = sample(admissions$hadm_id, n_diagnoses, replace = TRUE),
    icd_code   = sample(nursing_relevant_icd, n_diagnoses, replace = TRUE),
    icd_version = 10
  )
  # Remove duplicatas
  diagnoses_icd <- unique(diagnoses_icd, by = c("hadm_id", "icd_code"))

  # --- prescriptions ---------------------------------------------------------
  nursing_meds <- c(
    "Morphine Sulfate", "Fentanyl", "Acetaminophen", "Ibuprofen",
    "Insulin Regular", "Metformin", "Lisinopril", "Metoprolol",
    "Furosemide", "Heparin", "Enoxaparin", "Warfarin",
    "Docusate Sodium", "Senna", "Omeprazole", "Ondansetron",
    "Dexamethasone", "Vancomycin", "Ceftriaxone", "Piperacillin-Tazobactam",
    "Lorazepam", "Haloperidol", "Propofol", "Midazolam"
  )

  n_prescriptions <- n_admissions * 8
  prescriptions <- data.table(
    subject_id  = sample(patients$subject_id, n_prescriptions, replace = TRUE),
    hadm_id     = sample(admissions$hadm_id, n_prescriptions, replace = TRUE),
    drug        = sample(nursing_meds, n_prescriptions, replace = TRUE),
    route       = sample(c("IV", "PO", "SC", "IM", "NG"), n_prescriptions,
                        replace = TRUE, prob = c(0.40, 0.30, 0.10, 0.10, 0.10)),
    dose_val_rx = round(rlnorm(n_prescriptions, 0, 1), 1)
  )

  # --- labevents -------------------------------------------------------------
  lab_items <- data.table(
    itemid = unlist(LAB_ITEM_IDS, use.names = FALSE),
    label  = c("Creatinine", "Urea Nitrogen", "Glucose", "Sodium",
               "Potassium", "Chloride", "Hemoglobin", "Hematocrit",
               "White Blood Cells", "Platelets", "Albumin", "Lactate",
               "INR", "PTT", "Troponin I", "pH", "pCO2", "pO2", "Bicarbonate")
  )

  n_labevents <- n_admissions * 25
  labevents <- data.table(
    subject_id  = sample(patients$subject_id, n_labevents, replace = TRUE),
    hadm_id     = sample(admissions$hadm_id, n_labevents, replace = TRUE),
    itemid      = sample(lab_items$itemid, n_labevents, replace = TRUE),
    valuenum    = NA_real_,
    charttime   = sample(hourly_seq, n_labevents, replace = TRUE)
  )

  # Valores realistas
  labevents[itemid == 50912, valuenum := pmax(0.3, rnorm(.N, 1.2, 0.8))]          # creatinine
  labevents[itemid == 51006, valuenum := pmax(2, rnorm(.N, 22, 15))]               # BUN
  labevents[itemid == 50931, valuenum := pmax(30, rnorm(.N, 140, 50))]             # glucose
  labevents[itemid == 50983, valuenum := rnorm(.N, 138, 5)]                        # sodium
  labevents[itemid == 50971, valuenum := pmax(2, rnorm(.N, 4.1, 0.8))]             # potassium
  labevents[itemid == 51222, valuenum := pmax(3, rnorm(.N, 12, 2.5))]              # hemoglobin
  labevents[itemid == 51301, valuenum := pmax(0.5, rlnorm(.N, 2, 0.5))]            # WBC
  labevents[itemid == 51265, valuenum := pmax(5, rnorm(.N, 220, 80))]              # platelets
  labevents[itemid == 50862, valuenum := pmax(1, rnorm(.N, 3.5, 0.8))]             # albumin
  labevents[itemid == 50813, valuenum := pmax(0.3, rlnorm(.N, 0.2, 0.6))]          # lactate
  labevents[itemid == 50818, valuenum := rnorm(.N, 7.38, 0.08)]                    # pH
  labevents[itemid == 50804, valuenum := rnorm(.N, 40, 8)]                         # pCO2
  labevents[itemid == 50821, valuenum := rnorm(.N, 85, 20)]                        # pO2

  # --- emar (Electronic Medication Administration Record) ---------------------
  n_emar <- n_admissions * 30
  emar <- data.table(
    subject_id         = sample(patients$subject_id, n_emar, replace = TRUE),
    hadm_id            = sample(admissions$hadm_id, n_emar, replace = TRUE),
    emar_id            = 1:n_emar,
    medication         = sample(nursing_meds, n_emar, replace = TRUE),
    route              = sample(c("IV", "PO", "SC", "IM", "NG"), n_emar,
                                replace = TRUE, prob = c(0.40, 0.30, 0.10, 0.10, 0.10)),
    administration_type = sample(c("Scheduled", "PRN", "STAT", "Once"),
                                 n_emar, replace = TRUE,
                                 prob = c(0.60, 0.25, 0.10, 0.05))
  )

  emar_detail <- data.table(
    emar_id    = sample(1:n_emar, n_emar * 3, replace = TRUE),
    charttime  = sample(hourly_seq, n_emar * 3, replace = TRUE),
    dose_given = runif(n_emar * 3, 0.5, 100)
  )

  # --- omr (Online Medical Record - avaliações de enfermagem) -----------------
  n_omr <- n_admissions * 5
  omr_assessments <- c(
    "Braden Scale", "Braden Moisture", "Braden Activity",
    "Braden Mobility", "Braden Nutrition", "Braden Friction",
    "Pain Assessment", "Fall Risk", "Restraint Assessment",
    "Skin Assessment", "Delirium Screening", "Nutritional Screening"
  )

  omr <- data.table(
    subject_id  = sample(patients$subject_id, n_omr, replace = TRUE),
    chartdate   = as.Date(sample(seq(as.Date(start_date), as.Date(end_date),
                                     by = "day"), n_omr, replace = TRUE)),
    result_name = sample(omr_assessments, n_omr, replace = TRUE),
    result_value = NA_character_
  )

  omr[result_name == "Braden Scale",
      result_value := as.character(sample(6:23, .N, replace = TRUE))]
  omr[result_name == "Braden Moisture",
      result_value := as.character(sample(1:4, .N, replace = TRUE))]
  omr[result_name == "Pain Assessment",
      result_value := as.character(sample(0:10, .N, replace = TRUE))]
  omr[result_name == "Fall Risk",
      result_value := sample(c("High", "Medium", "Low"), .N, replace = TRUE)]
  omr[result_name == "Delirium Screening",
      result_value := sample(c("Positive", "Negative"), .N, replace = TRUE,
                             prob = c(0.15, 0.85))]

  # --- services (serviço de admissão) ----------------------------------------
  services <- data.table(
    subject_id   = admissions$subject_id,
    hadm_id      = admissions$hadm_id,
    curr_service = sample(c("MEDICAL", "SURGICAL", "ORTHOPEDIC", "NEUROLOGIC",
                            "CARDIAC", "TRAUMA"),
                          n_admissions, replace = TRUE,
                          prob = c(0.35, 0.20, 0.10, 0.10, 0.15, 0.10))
  )

  # --- transfers -------------------------------------------------------------
  n_transfers <- n_admissions * 2
  transfers <- data.table(
    subject_id      = sample(patients$subject_id, n_transfers, replace = TRUE),
    hadm_id         = sample(admissions$hadm_id, n_transfers, replace = TRUE),
    careunit        = sample(c("Medical ICU", "Surgical ICU", "Cardiac ICU",
                               "Neuro ICU", "Trauma ICU", "Medical Ward",
                               "Observation"),
                             n_transfers, replace = TRUE,
                             prob = c(0.15, 0.10, 0.08, 0.07, 0.05, 0.50, 0.05)),
    intime          = sample(hourly_seq, n_transfers, replace = TRUE),
    eventtype       = "transfer"
  )

  message(sprintf("[SYNTHETIC] HOSP gerado: %d patients, %d admissions, %d diagnoses, %d labevents",
                  n_patients, n_admissions, nrow(diagnoses_icd), nrow(labevents)))

  list(
    patients      = patients,
    admissions    = admissions,
    diagnoses_icd = diagnoses_icd,
    prescriptions = prescriptions,
    labevents     = labevents,
    lab_items     = lab_items,
    emar          = emar,
    emar_detail   = emar_detail,
    omr           = omr,
    services      = services,
    transfers     = transfers
  )
}

#' Gera dados sintéticos do módulo ICU
generate_icu_module <- function(patients, admissions, transfers,
                                 n_icu_stays = 1200, start_date = "2100-01-01",
                                 end_date = "2103-12-31") {

  message("[SYNTHETIC] Gerando módulo ICU...")

  # Criar sequências temporais
  start_dt <- as.POSIXct(start_date)
  end_dt   <- as.POSIXct(end_date)
  hourly_seq   <- seq(start_dt, end_dt, by = "hour")
  minutely_seq <- seq(start_dt, end_dt, by = "min")

  # --- icustays --------------------------------------------------------------
  icustays <- data.table(
    subject_id  = sample(patients$subject_id, n_icu_stays, replace = TRUE),
    hadm_id     = sample(admissions$hadm_id, n_icu_stays, replace = TRUE),
    stay_id     = 30000000 + (1:n_icu_stays),
    intime      = sample(hourly_seq, n_icu_stays, replace = TRUE),
    first_careunit = sample(c("Medical ICU", "Surgical ICU", "Cardiac ICU",
                              "Neuro ICU", "Trauma ICU"),
                            n_icu_stays, replace = TRUE,
                            prob = c(0.30, 0.20, 0.15, 0.15, 0.20))
  )
  # Calcular ICU stay length
  icu_los_hours <- pmax(0.5, rlnorm(n_icu_stays, 2.5, 1.2)) * 24  # hours
  icustays[, outtime := intime + dhours(round(icu_los_hours))]
  icustays[, los := as.numeric(difftime(outtime, intime, units = "days"))]

  # --- chartevents (Sinais vitais e avaliações de enfermagem) ----------------
  n_chartevents <- n_icu_stays * 120  # ~120 chartevents por ICU stay

  # Combinar todos os item_ids relevantes
  all_itemids <- c(unlist(ITEM_IDS$vitals), unlist(ITEM_IDS$scores),
                   unlist(ITEM_IDS$respiratory))

  chartevents <- data.table(
    subject_id  = sample(patients$subject_id, n_chartevents, replace = TRUE),
    hadm_id     = sample(admissions$hadm_id, n_chartevents, replace = TRUE),
    stay_id     = sample(icustays$stay_id, n_chartevents, replace = TRUE),
    charttime   = sample(minutely_seq, n_chartevents, replace = TRUE),
    storetime   = NA,
    itemid      = sample(all_itemids, n_chartevents, replace = TRUE),
    valuenum    = NA_real_,
    valueuom    = NA_character_,
    warning     = 0,
    error       = 0
  )

  # Adicionar storetime (sempre depois do charttime)
  chartevents[, storetime := charttime + minutes(sample(5:120, .N, replace = TRUE))]

  # Preencher valores realistas baseados no itemid
  # Heart Rate
  chartevents[itemid %in% c(220045, 211, 223761),
              `:=`(valuenum = pmax(30, rnorm(.N, 85, 18)),
                   valueuom = "bpm")]

  # Systolic BP
  chartevents[itemid %in% c(220050, 51, 442, 455, 6701, 220179, 220051, 223752),
              `:=`(valuenum = pmax(60, rnorm(.N, 125, 25)),
                   valueuom = "mmHg")]

  # Diastolic BP
  chartevents[itemid %in% c(220051, 8368, 220180, 220052, 225310, 223751),
              `:=`(valuenum = pmax(30, rnorm(.N, 72, 15)),
                   valueuom = "mmHg")]

  # SpO2
  chartevents[itemid %in% c(220277, 646, 834, 223769, 220644),
              `:=`(valuenum = pmax(70, rnorm(.N, 95, 6)),
                   valueuom = "%")]

  # Temperature
  chartevents[itemid %in% c(223761, 678, 223762, 676, 227054),
              `:=`(valuenum = rnorm(.N, 37, 1.2),
                   valueuom = "degC")]

  # Respiratory Rate
  chartevents[itemid %in% c(220210, 618, 615, 220211, 224690, 224689, 224688, 223750),
              `:=`(valuenum = pmax(6, rnorm(.N, 18, 5)),
                   valueuom = "bpm")]

  # Weight
  chartevents[itemid %in% c(224639, 226512, 763, 3580, 3581, 3582, 3693, 226531),
              `:=`(valuenum = pmax(30, rnorm(.N, 78, 22)),
                   valueuom = "kg")]

  # GCS Total
  chartevents[itemid %in% c(223901, 228412),
              `:=`(valuenum = sample(3:15, .N, replace = TRUE, prob = c(
                rep(0.01, 3), rep(0.02, 3), 0.05, 0.07, 0.10, 0.15, 0.20, 0.25, 0.10)),
                   valueuom = "score")]

  # RASS
  chartevents[itemid %in% c(228096, 228314, 223912),
              `:=`(valuenum = sample(c(-5:-1, 0:4), .N, replace = TRUE,
                                     prob = c(0.02, 0.03, 0.05, 0.05, 0.05, 0.20,
                                              0.15, 0.15, 0.15, 0.15)),
                   valueuom = "score")]

  # Pain Score (NRS 0-10)
  chartevents[itemid %in% c(226568, 227013, 228088, 222951, 228232),
              `:=`(valuenum = sample(0:10, .N, replace = TRUE,
                                     prob = c(0.15, 0.05, 0.05, 0.07, 0.10,
                                              0.13, 0.13, 0.10, 0.07, 0.05, 0.10)),
                   valueuom = "score")]

  # FiO2
  chartevents[itemid %in% c(223835, 190, 3420, 3422, 226754),
              `:=`(valuenum = sample(c(21, 25, 30, 35, 40, 45, 50, 60, 70, 80, 100),
                                     .N, replace = TRUE,
                                     prob = c(0.15, 0.10, 0.10, 0.10, 0.10,
                                              0.08, 0.07, 0.10, 0.08, 0.05, 0.07)),
                   valueuom = "%")]

  # --- inputevents (Fluidos IV, nutrição) ------------------------------------
  n_inputevents <- n_icu_stays * 80
  input_fluids <- c(
    "NS 0.9%", "LR", "D5W", "D5NS", "Plasma-Lyte",
    "Packed RBC", "FFP", "Platelets", "Albumin 5%", "Albumin 25%",
    "Propofol", "Fentanyl", "Norepinephrine", "Vasopressin",
    "Enteral Nutrition", "TPN", "Pantoprazole"
  )

  inputevents <- data.table(
    subject_id   = sample(patients$subject_id, n_inputevents, replace = TRUE),
    hadm_id      = sample(admissions$hadm_id, n_inputevents, replace = TRUE),
    stay_id      = sample(icustays$stay_id, n_inputevents, replace = TRUE),
    charttime    = sample(hourly_seq, n_inputevents, replace = TRUE),
    amount       = pmax(0.5, rlnorm(n_inputevents, 3, 2)),
    amountuom    = "mL",
    ordercategoryname = sample(input_fluids, n_inputevents, replace = TRUE)
  )

  # --- outputevents (Débito urinário, drenos) --------------------------------
  n_outputevents <- n_icu_stays * 50
  outputevents <- data.table(
    subject_id   = sample(patients$subject_id, n_outputevents, replace = TRUE),
    hadm_id      = sample(admissions$hadm_id, n_outputevents, replace = TRUE),
    stay_id      = sample(icustays$stay_id, n_outputevents, replace = TRUE),
    charttime    = sample(hourly_seq, n_outputevents, replace = TRUE),
    value        = pmax(5, rlnorm(n_outputevents, 5, 1)),
    valueuom     = "mL"
  )

  # --- caregiver (Equipe de enfermagem) --------------------------------------
  # Simular uma tabela de cuidadores
  nurse_titles <- c("RN", "Registered Nurse", "Nurse", "Enfermeiro(a)",
                    "LPN", "Nursing Assistant", "CNA")

  n_caregivers <- n_icu_stays * 4
  caregiver <- data.table(
    stay_id          = sample(icustays$stay_id, n_caregivers, replace = TRUE),
    caregiver_id     = sample(1:500, n_caregivers, replace = TRUE),
    caregiver_title  = sample(nurse_titles, n_caregivers, replace = TRUE),
    charttime        = sample(hourly_seq, n_caregivers, replace = TRUE)
  )

  # --- procedureevents (Procedimentos de enfermagem) -------------------------
  n_procedureevents <- n_icu_stays * 10
  nursing_procedures <- c(
    "Wound Care", "Dressing Change", "Central Line Dressing Change",
    "Foley Catheter Insertion", "NG Tube Insertion", "Suctioning",
    "Tracheostomy Care", "Chest Tube Management", "Arterial Line Insertion",
    "Positioning", "Oral Care", "Eye Care", "Skin Care",
    "Pressure Ulcer Prevention", "Fall Prevention"
  )

  procedureevents <- data.table(
    subject_id   = sample(patients$subject_id, n_procedureevents, replace = TRUE),
    hadm_id      = sample(admissions$hadm_id, n_procedureevents, replace = TRUE),
    stay_id      = sample(icustays$stay_id, n_procedureevents, replace = TRUE),
    charttime    = sample(hourly_seq, n_procedureevents, replace = TRUE),
    ordercategoryname = sample(nursing_procedures, n_procedureevents,
                               replace = TRUE)
  )

  message(sprintf("[SYNTHETIC] ICU gerado: %d stays, %d chartevents, %d inputs, %d outputs",
                  n_icu_stays, nrow(chartevents), nrow(inputevents), nrow(outputevents)))

  list(
    icustays         = icustays,
    chartevents      = chartevents,
    inputevents      = inputevents,
    outputevents     = outputevents,
    caregiver        = caregiver,
    procedureevents  = procedureevents
  )
}

#' Gera todos os dados sintéticos
generate_all_synthetic_data <- function() {
  message("[SYNTHETIC] ===== INICIANDO GERAÇÃO DE DADOS SINTÉTICOS =====")

  hosp <- generate_hosp_module(PARAMS$n_patients, PARAMS$n_admissions)
  icu  <- generate_icu_module(hosp$patients, hosp$admissions, hosp$transfers,
                              PARAMS$n_icu_stays)

  message("[SYNTHETIC] ===== GERAÇÃO CONCLUÍDA =====")
  message(sprintf("[SYNTHETIC] Memória utilizada: ~%.0f MB",
                  sum(sapply(hosp, object.size)) / 1e6 +
                  sum(sapply(icu, object.size)) / 1e6))

  list(hosp = hosp, icu = icu)
}

# Executar se chamado diretamente
if (sys.nframe() == 0) {
  source("config.R")
  data <- generate_all_synthetic_data()
  saveRDS(data, file.path(PATHS$output_dir, "synthetic_data.rds"))
  message("[SYNTHETIC] Dados salvos em output/synthetic_data.rds")
}
