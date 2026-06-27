# =============================================================================
# config.R - Configuração do Pipeline de Enfermagem MIMIC-IV
# =============================================================================
# Define paths, parâmetros e constantes para todo o pipeline.
# Compatível com Windows, Linux e macOS. Encoding: UTF-8.
# =============================================================================

# --- Paths -------------------------------------------------------------------
PATHS <- list(

  # Entrada de dados reais (sobrescrever via args)
  data_dir       = "../mimic-iv-3.1",
  hosp_dir       = "../mimic-iv-3.1/hosp",
  icu_dir        = "../mimic-iv-3.1/icu",
  ed_dir         = "../mimic-iv-3.1/ed",
  note_dir       = "../mimic-iv-3.1/note",

  # Saída
  output_dir     = here::here("output"),
  figures_dir    = here::here("output", "figures"),
  db_path        = here::here("output", "nursing_db.sqlite"),

  # Cache
  cache_dir      = here::here("output", "cache")
)

# --- Parâmetros de Execução --------------------------------------------------
PARAMS <- list(
  mode            = "synthetic",   # "synthetic" | "real"
  n_patients      = 2000,          # Número de pacientes no modo sintético
  n_admissions    = 3500,          # Número de admissões
  n_icu_stays     = 1200,          # Número de estadias em UTI
  random_seed     = 20240101,      # Semente para reprodutibilidade
  db_engine       = "duckdb",      # "duckdb" | "sqlite"
  parallel_cores  = 4,             # Núcleos para paralelização
  benchmark_runs  = 3              # Iterações para benchmarks
)

# --- Thresholds e Limiares de Enfermagem -------------------------------------
THRESHOLDS <- list(

  # Sinais vitais - Valores anormais (adulto)
  vitals = list(
    heart_rate_high = 100,       # Taquicardia (bpm)
    heart_rate_low  = 60,        # Bradicardia (bpm)
    systolic_high   = 140,       # Hipertensão sistólica (mmHg)
    systolic_low    = 90,        # Hipotensão sistólica (mmHg)
    spo2_low        = 92,        # Hipoxemia (%)
    temp_high       = 38.0,      # Febre (°C)
    temp_low        = 36.0,      # Hipotermia (°C)
    rr_high         = 20,        # Taquipneia (rpm)
    rr_low          = 12         # Bradipneia (rpm)
  ),

  # Exames laboratoriais
  labs = list(
    creatinine_high = 1.3,       # mg/dL
    bun_high        = 20,        # mg/dL
    albumin_low     = 3.5,       # g/dL
    hemoglobin_low  = 12.0,      # g/dL (mulher)
    hemoglobin_low_m = 13.5,     # g/dL (homem)
    glucose_high    = 200,       # mg/dL
    glucose_low     = 70,        # mg/dL
    potassium_high  = 5.0,       # mEq/L
    potassium_low   = 3.5,       # mEq/L
    sodium_high     = 145,       # mEq/L
    sodium_low      = 135,       # mEq/L
    wbc_high        = 11000,     # /µL
    wbc_low         = 4000       # /µL
  ),

  # Avaliação
  pain_high        = 7,          # Dor severa (escala 0-10)
  pain_mod         = 4,          # Dor moderada
  braden_low       = 12,         # Risco alto de UP
  gcs_low          = 8,          # Coma
  rass_agitated    = 2,          # Agitação (RASS >= 2)

  # Balanço hídrico
  fluid_balance_pos = 500,       # Balanço positivo significativo (mL/24h)
  fluid_balance_neg = -500,      # Balanço negativo significativo (mL/24h)
  urine_output_low  = 0.5        # Oligúria (mL/kg/h)
)

# --- Mapeamento de IDs do MIMIC → Conceitos de Enfermagem --------------------
ITEM_IDS <- list(

  # Chartevents - Sinais vitais
  vitals = list(
    heart_rate    = c(220045, 211, 223761),
    systolic_bp   = c(220050, 51, 442, 455, 6701, 220179, 220051, 223752),
    diastolic_bp  = c(220051, 8368, 220180, 220052, 225310, 223751),
    mean_bp       = c(220052, 456, 52, 443, 6702, 224322, 220181, 225312),
    spo2          = c(220277, 646, 834, 223769, 220644),
    temperature   = c(223761, 678, 223762, 676, 223761, 227054),
    respiratory   = c(220210, 618, 615, 220211, 224690, 224689, 224688, 223750),
    weight        = c(224639, 226512, 763, 3580, 3581, 3582, 3693, 226531),
    height        = c(226707, 1394, 226730)
  ),

  # Escalas e avaliações
  scores = list(
    gcs_eye        = c(220739, 226755),
    gcs_motor      = c(220741, 226756),
    gcs_verbal     = c(223900, 226757),
    gcs_total      = c(223901, 228412),
    rass           = c(228096, 228314, 223912),
    cam_icu        = c(228300, 228301, 229148),
    pain_score     = c(223901, 222951, 228232, 227013),
    pain_nrs       = c(226568, 227013, 228088),
    braden         = c(225105, 224886, 227099, 228275),
    braden_moisture    = c(224877),
    braden_activity    = c(224878),
    braden_mobility    = c(224879),
    braden_nutrition   = c(224880),
    braden_friction    = c(224881)
  ),

  # Ventilação e oxigenação
  respiratory = list(
    fio2           = c(223835, 190, 3420, 3422, 226754),
    peep           = c(220339, 224700, 226755),
    tidal_volume   = c(224684, 639, 2400, 229174),
    airway_type    = c(224792, 228218)
  )
)

# --- IDs de itens de laboratório relevantes para enfermagem ------------------
LAB_ITEM_IDS <- c(
  creatinine  = 50912, bun       = 51006, glucose   = 50931,
  sodium      = 50983, potassium = 50971, chloride  = 50902,
  hemoglobin  = 51222, hematocrit= 51221, wbc       = 51301,
  platelets   = 51265, albumin   = 50862, lactate   = 50813,
  inr         = 51237, ptt       = 51275, troponin  = 51003,
  ph          = 50818, pco2      = 50804, po2       = 50821,
  bicarbonate = 50882
)

# --- Mapeamento NANDA → ICD-10 (domínios de enfermagem) ----------------------
# Adaptado do mapeamento NANDA-I para condições clínicas
NANDA_ICD_MAP <- list(
  "Nutricao" = list(
    icd_codes = c("E40", "E41", "E43", "E44", "E46", "R63", "R64",
                  "E66", "E10", "E11", "F50"),
    nanda_labels = c("Nutrição desequilibrada", "Obesidade",
                     "Risco de glicemia instável", "Déficit de volume de líquidos")
  ),
  "Eliminacao" = list(
    icd_codes = c("N17", "N18", "N19", "R33", "R34", "N39", "K59",
                  "R11", "R15", "K56"),
    nanda_labels = c("Eliminação urinária prejudicada", "Constipação",
                     "Risco de motilidade gastrintestinal disfuncional")
  ),
  "Percepcao_Cognicao" = list(
    icd_codes = c("G93", "F05", "F06", "I63", "I61", "G40", "G41",
                  "R40", "R41", "F10", "F11", "F19"),
    nanda_labels = c("Confusão aguda", "Risco de perfusão tissular cerebral ineficaz",
                     "Memória prejudicada", "Risco de delirium")
  ),
  "Seguranca_Protecao" = list(
    icd_codes = c("A41", "A49", "B95", "B96", "L89", "T81", "Y95",
                  "J15", "J18", "N39", "L03", "W19", "R55"),
    nanda_labels = c("Risco de infecção", "Integridade da pele prejudicada",
                     "Risco de quedas", "Termorregulação ineficaz")
  ),
  "Conforto" = list(
    icd_codes = c("R52", "G89", "R07", "R10", "M79", "J90", "R51"),
    nanda_labels = c("Dor aguda", "Dor crônica", "Conforto prejudicado", "Náusea")
  ),
  "Atividade_Repouso" = list(
    icd_codes = c("I50", "J96", "R06", "G47", "M62", "I48", "Z73",
                  "R26", "R53", "F51"),
    nanda_labels = c("Intolerância à atividade", "Padrão respiratório ineficaz",
                     "Mobilidade física prejudicada", "Insônia")
  ),
  "Cardiovascular" = list(
    icd_codes = c("I10", "I21", "I25", "I48", "I49", "I50", "R00",
                  "R57", "I26", "I71"),
    nanda_labels = c("Débito cardíaco diminuído", "Perfusão tissular ineficaz",
                     "Risco de choque", "Risco de sangramento")
  )
)

# --- Mapeamento de Intervenções NIC → Eventos MIMIC --------------------------
NIC_ACTIVITY_MAP <- list(
  "Administracao_Medicamentos" = list(
    nic_code = "2300",
    nic_label = "Administração de Medicamentos",
    mimic_tables = c("emar", "emar_detail", "prescriptions", "pharmacy"),
    mimic_events = c("Medication Administered", "PRN Medication")
  ),
  "Terapia_Intravenosa" = list(
    nic_code = "4200",
    nic_label = "Terapia Intravenosa",
    mimic_tables = c("inputevents", "poe"),
    mimic_events = c("IV Fluid", "Bolus", "Infusion")
  ),
  "Monitorizacao_Sinais_Vitais" = list(
    nic_code = "6680",
    nic_label = "Monitorização de Sinais Vitais",
    mimic_tables = c("chartevents"),
    mimic_events = c("Heart Rate", "Blood Pressure", "SpO2", "Temperature")
  ),
  "Controle_Hidrico" = list(
    nic_code = "4120",
    nic_label = "Controle Hídrico",
    mimic_tables = c("inputevents", "outputevents"),
    mimic_events = c("Intake", "Output", "Urine Output")
  ),
  "Posicionamento" = list(
    nic_code = "0840",
    nic_label = "Posicionamento",
    mimic_tables = c("procedureevents", "chartevents"),
    mimic_events = c("Positioning", "Turning", "Repositioning")
  ),
  "Prevencao_Ulcera_Pressao" = list(
    nic_code = "3540",
    nic_label = "Prevenção de Úlcera por Pressão",
    mimic_tables = c("chartevents", "procedureevents", "omr"),
    mimic_events = c("Braden Scale", "Skin Assessment", "Wound Care")
  ),
  "Controle_Dor" = list(
    nic_code = "1400",
    nic_label = "Controle da Dor",
    mimic_tables = c("chartevents", "emar", "prescriptions"),
    mimic_events = c("Pain Assessment", "Analgesic", "Pain Score")
  ),
  "Oxigenoterapia" = list(
    nic_code = "3320",
    nic_label = "Oxigenoterapia",
    mimic_tables = c("chartevents", "procedureevents"),
    mimic_events = c("FiO2", "O2 Device", "Mechanical Ventilation")
  ),
  "Cuidados_Traqueostomia" = list(
    nic_code = "3180",
    nic_label = "Cuidados com Traqueostomia",
    mimic_tables = c("procedureevents", "chartevents"),
    mimic_events = c("Tracheostomy Care", "Suctioning", "Airway Management")
  ),
  "Nutricao_Enteral" = list(
    nic_code = "1056",
    nic_label = "Nutrição Enteral",
    mimic_tables = c("inputevents", "procedureevents"),
    mimic_events = c("Tube Feeding", "Enteral Nutrition", "NG Tube")
  )
)

# --- Mapeamento para Resultados NOC ------------------------------------------
NOC_OUTCOME_MAP <- list(
  "Sinais_Vitais" = list(
    noc_code = "0802",
    noc_label = "Estado dos Sinais Vitais",
    indicators = c("Frequência cardíaca", "Pressão arterial sistólica",
                   "Pressão arterial diastólica", "Frequência respiratória",
                   "Saturação de O2", "Temperatura corporal")
  ),
  "Equilibrio_Hidrico" = list(
    noc_code = "0601",
    noc_label = "Equilíbrio Hídrico",
    indicators = c("Débito urinário", "Ingestão hídrica", "Balanço hídrico 24h",
                   "Peso corporal diário", "Turgor cutâneo")
  ),
  "Controle_Dor" = list(
    noc_code = "1605",
    noc_label = "Controle da Dor",
    indicators = c("Nível de dor relatado", "Uso de analgésicos",
                   "Expressão facial de dor", "Frequência da dor")
  ),
  "Integridade_Tissular" = list(
    noc_code = "1101",
    noc_label = "Integridade Tissular: Pele e Mucosas",
    indicators = c("Escore de Braden", "Presença de lesão por pressão",
                   "Hidratação da pele", "Perfusão periférica")
  ),
  "Estado_Respiratorio" = list(
    noc_code = "0415",
    noc_label = "Estado Respiratório",
    indicators = c("SpO2", "PaO2/FiO2", "Frequência respiratória",
                   "Padrão respiratório", "Ausculta pulmonar")
  ),
  "Perfusao_Tissular" = list(
    noc_code = "0407",
    noc_label = "Perfusão Tissular: Periférica",
    indicators = c("Pulsos periféricos", "Tempo de enchimento capilar",
                   "Temperatura de extremidades", "Edema periférico")
  ),
  "Nivel_Consciencia" = list(
    noc_code = "0912",
    noc_label = "Estado Neurológico: Consciência",
    indicators = c("Glasgow Coma Scale", "RASS", "CAM-ICU",
                   "Orientação", "Resposta a estímulos")
  ),
  "Mobilidade" = list(
    noc_code = "0208",
    noc_label = "Mobilidade",
    indicators = c("Deambulação", "Transferência", "Equilíbrio",
                   "Amplitude de movimento", "Força muscular")
  )
)

# --- Catergorias de Cuidadores (Enfermagem) ----------------------------------
CAREGIVER_CATEGORIES <- c(
  "RN", "Registered Nurse", "Nurse", "Enfermeiro", "Enfermeira",
  "LPN", "Licensed Practical Nurse", "Nursing Assistant",
  "CNA", "Certified Nursing Assistant"
)

# --- Mensagem de início ------------------------------------------------------
message("[CONFIG] Configuração carregada com sucesso.")
message(sprintf("[CONFIG] Modo: %s | Pacientes sintéticos: %d | Semente: %d",
                PARAMS$mode, PARAMS$n_patients, PARAMS$random_seed))
