# config.py — Configuracao do pipeline de inferencia NANDA-I por embeddings
# Caminhos relativos para portabilidade entre maquinas

import os

# Caminho base dos dados MIMIC-IV Demo (relativo ao diretorio do projeto)
BASE_DIR = os.path.join("..", "mimic-iv-clinical-database-demo-2.2")

# Caminho do banco de saida (relativo ao diretorio do projeto)
DB_PATH = os.path.join("output", "nursing_db.sqlite")

# Diretorio de saida para figuras
FIG_DIR = os.path.join("output", "figures")

# Diretorio de saida para CSVs exportados
DATA_DIR = "data"

# Random seed para reprodutibilidade
RANDOM_SEED = 20240101

# Limiares clinicos para sinais vitais
THRESHOLDS = {
    "heart_rate_high": 100,
    "systolic_low": 90,
    "spo2_low": 92,
    "temp_high": 38.0,
    "temp_low": 36.0,
    "pain_high": 7,
    "gcs_low": 8,
}

# Item IDs do MIMIC-IV para sinais vitais
ITEM_IDS = {
    "heart_rate": [220045, 211, 223761],
    "systolic_bp": [220050, 51, 442, 455, 6701, 220179, 220051, 223752],
    "spo2": [220277, 646, 834, 223769, 220644],
    "temperature": [223761, 678, 223762, 676, 227054],
    "pain": [223901, 222951, 228232, 227013, 226568, 228088],
    "gcs": [223901, 228412],
}
