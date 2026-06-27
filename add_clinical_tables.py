#!/usr/bin/env python3
# add_clinical_tables.py — Adiciona TODAS as tabelas clinicas do MIMIC-IV Demo ao banco
import sqlite3, pandas as pd, os

BASE = r'..\mimic-iv-clinical-database-demo-2.2'
DB   = r'output\nursing_db.sqlite'

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip', low_memory=False)
    plain = path.replace('.gz','')
    if os.path.exists(plain):
        return pd.read_csv(plain, low_memory=False)
    return pd.read_csv(path, low_memory=False)

print('=== ADICIONANDO TODAS AS TABELAS CLINICAS DO MIMIC-IV Demo ===')
con = sqlite3.connect(DB)

# HOSP module
tables_hosp = [
    ('labevents', 'hosp/labevents.csv'),
    ('d_labitems', 'hosp/d_labitems.csv.gz'),
    ('microbiologyevents', 'hosp/microbiologyevents.csv.gz'),
    ('prescriptions', 'hosp/prescriptions.csv'),
    ('pharmacy', 'hosp/pharmacy.csv.gz'),
    ('emar_detail', 'hosp/emar_detail.csv'),
    ('poe', 'hosp/poe.csv.gz'),
    ('poe_detail', 'hosp/poe_detail.csv.gz'),
    ('drgcodes', 'hosp/drgcodes.csv.gz'),
    ('hcpcsevents', 'hosp/hcpcsevents.csv.gz'),
    ('procedures_icd', 'hosp/procedures_icd.csv.gz'),
    ('d_icd_procedures', 'hosp/d_icd_procedures.csv.gz'),
    ('d_icd_diagnoses', 'hosp/d_icd_diagnoses.csv.gz'),
    ('d_hcpcs', 'hosp/d_hcpcs.csv.gz'),
    ('provider', 'hosp/provider.csv.gz'),
    ('services', 'hosp/services.csv'),
    ('transfers', 'hosp/transfers.csv'),
    ('omr', 'hosp/omr.csv'),
]

# ICU module
tables_icu = [
    ('caregiver', 'icu/caregiver.csv'),
    ('d_items', 'icu/d_items.csv'),
    ('datetimeevents', 'icu/datetimeevents.csv.gz'),
    ('ingredientevents', 'icu/ingredientevents.csv.gz'),
]

for table_name, file_path in tables_hosp + tables_icu:
    try:
        df = load(file_path)
        df.to_sql(table_name, con, index=False, if_exists='replace')
        print(f'  {table_name:25s}: {len(df):>10,} registros | {len(df.columns):>3} colunas')
    except Exception as e:
        print(f'  {table_name:25s}: ERRO - {e}')

con.commit()

# Summary
print(f'\n=== BANCO COMPLETO ===')
for t in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall():
    n = con.execute(f'SELECT COUNT(*) FROM \"{t[0]}\"').fetchone()[0]
    print(f'  {t[0]:30s}: {n:>10,}')

size_mb = os.path.getsize(DB)/1e6
print(f'\nBanco: {DB} ({size_mb:.1f} MB)')
con.close()
print('PRONTO.')
