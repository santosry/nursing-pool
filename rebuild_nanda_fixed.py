#!/usr/bin/env python3
# rebuild_nanda_fixed.py — Reconstroi banco com dominios NANDA CORRETOS (Taxonomia II)
import sqlite3, pandas as pd, os, sys

BASE = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic-iv-clinical-database-demo-2.2'
DB   = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic_nursing_poc\output\nursing_db.sqlite'

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip')
    plain = path.replace('.gz','')
    if os.path.exists(plain): return pd.read_csv(plain)
    return pd.read_csv(path)

print('Carregando dados...')
patients   = load('hosp/patients.csv.gz')
admissions = load('hosp/admissions.csv.gz')
dx         = load('hosp/diagnoses_icd.csv.gz')
ce         = load('icu/chartevents.csv')
icu        = load('icu/icustays.csv.gz')
emar       = load('hosp/emar.csv.gz')
inp        = load('icu/inputevents.csv')
out        = load('icu/outputevents.csv')
proc       = load('icu/procedureevents.csv')
omr        = load('hosp/omr.csv.gz')

N = len(patients)

# ============================================================
# MAPEAMENTO ICD-10 -> DOMINIOS NANDA-I (Taxonomia II, 13 dominios, 48 classes)
# ============================================================
# Cada entrada: (dominio, classe, label_nanda)
NANDA_MAP = {
    # DOMINIO 1: Promocao da Saude
    'Z00': ('Promocao da Saude', 'Exame de saude', 'Disposicao para melhora do autocuidado'),
    'Z71': ('Promocao da Saude', 'Aconselhamento', 'Disposicao para melhora do conhecimento'),
    # DOMINIO 2: Nutricao
    'E40': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E41': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E43': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E44': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E46': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E66': ('Nutricao', 'Ingestao', 'Obesidade'),
    'Z68': ('Nutricao', 'Ingestao', 'Obesidade'),
    'R63': ('Nutricao', 'Ingestao', 'Nutricao desequilibrada: menor do que as necessidades corporais'),
    'E10': ('Nutricao', 'Metabolismo', 'Risco de glicemia instavel'),
    'E11': ('Nutricao', 'Metabolismo', 'Risco de glicemia instavel'),
    'E78': ('Nutricao', 'Metabolismo', 'Risco de glicemia instavel'),
    'E03': ('Nutricao', 'Metabolismo', 'Nutricao desequilibrada'),
    'E86': ('Nutricao', 'Hidratacao', 'Volume de liquidos deficiente'),
    'E87': ('Nutricao', 'Hidratacao', 'Risco de desequilibrio eletrolitico'),
    'Z79': ('Nutricao', 'Metabolismo', 'Risco de glicemia instavel'),
    # DOMINIO 3: Eliminacao e Troca
    'N17': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'N18': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'N19': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'N39': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'N40': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'R33': ('Eliminacao e Troca', 'Funcao urinaria', 'Retencao urinaria'),
    'R34': ('Eliminacao e Troca', 'Funcao urinaria', 'Eliminacao urinaria prejudicada'),
    'K59': ('Eliminacao e Troca', 'Funcao gastrintestinal', 'Constipacao'),
    'K56': ('Eliminacao e Troca', 'Funcao gastrintestinal', 'Constipacao'),
    'R11': ('Eliminacao e Troca', 'Funcao gastrintestinal', 'Nausea'),
    'R15': ('Eliminacao e Troca', 'Funcao gastrintestinal', 'Incontinencia intestinal'),
    'K92': ('Eliminacao e Troca', 'Funcao gastrintestinal', 'Risco de motilidade gastrintestinal disfuncional'),
    # DOMINIO 4: Atividade/Repouso
    'I50': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Debito cardiaco diminuido'),
    'J96': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Padrao respiratorio ineficaz'),
    'R06': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Padrao respiratorio ineficaz'),
    'R53': ('Atividade/Repouso', 'Equilibrio de energia', 'Intolerancia a atividade'),
    'R26': ('Atividade/Repouso', 'Atividade/Exercicio', 'Mobilidade fisica prejudicada'),
    'G47': ('Atividade/Repouso', 'Sono/Repouso', 'Insônia'),
    'F51': ('Atividade/Repouso', 'Sono/Repouso', 'Padrao de sono prejudicado'),
    'M62': ('Atividade/Repouso', 'Atividade/Exercicio', 'Mobilidade fisica prejudicada'),
    # DOMINIO 5: Percepcao/Cognicao
    'G93': ('Percepcao/Cognicao', 'Cognicao', 'Perfusao tissular cerebral ineficaz'),
    'I63': ('Percepcao/Cognicao', 'Cognicao', 'Perfusao tissular cerebral ineficaz'),
    'I61': ('Percepcao/Cognicao', 'Cognicao', 'Perfusao tissular cerebral ineficaz'),
    'F05': ('Percepcao/Cognicao', 'Cognicao', 'Confusao aguda'),
    'F06': ('Percepcao/Cognicao', 'Cognicao', 'Confusao aguda'),
    'R40': ('Percepcao/Cognicao', 'Cognicao', 'Confusao aguda'),
    'R41': ('Percepcao/Cognicao', 'Cognicao', 'Memoria prejudicada'),
    'G40': ('Percepcao/Cognicao', 'Cognicao', 'Risco de confusao aguda'),
    'G41': ('Percepcao/Cognicao', 'Cognicao', 'Risco de confusao aguda'),
    'F32': ('Percepcao/Cognicao', 'Cognicao', 'Risco de automutilacao'),
    'F41': ('Percepcao/Cognicao', 'Cognicao', 'Ansiedade'),
    # DOMINIO 6: Autopercepcao
    'F50': ('Autopercepcao', 'Autoestima', 'Baixa autoestima situacional'),
    'Z73': ('Autopercepcao', 'Autoestima', 'Baixa autoestima situacional'),
    # DOMINIO 7: Papeis e Relacionamentos
    'Z63': ('Papeis e Relacionamentos', 'Desempenho de papel', 'Tensao do papel de cuidador'),
    # DOMINIO 9: Enfrentamento/Tolerancia ao Estresse
    'F10': ('Enfrentamento/Tolerancia ao Estresse', 'Respostas de enfrentamento', 'Enfrentamento ineficaz'),
    'F11': ('Enfrentamento/Tolerancia ao Estresse', 'Respostas de enfrentamento', 'Enfrentamento ineficaz'),
    'F19': ('Enfrentamento/Tolerancia ao Estresse', 'Respostas de enfrentamento', 'Enfrentamento ineficaz'),
    'R57': ('Enfrentamento/Tolerancia ao Estresse', 'Respostas de enfrentamento', 'Risco de choque'),
    # DOMINIO 11: Seguranca/Protecao
    'A41': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'B95': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'B96': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'J15': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'J18': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'J44': ('Seguranca/Protecao', 'Infeccao', 'Risco de infeccao'),
    'L03': ('Seguranca/Protecao', 'Lesao fisica', 'Integridade da pele prejudicada'),
    'L89': ('Seguranca/Protecao', 'Lesao fisica', 'Integridade da pele prejudicada'),
    'T81': ('Seguranca/Protecao', 'Lesao fisica', 'Risco de infeccao'),
    'W19': ('Seguranca/Protecao', 'Lesao fisica', 'Risco de quedas'),
    'R55': ('Seguranca/Protecao', 'Lesao fisica', 'Risco de quedas'),
    'S06': ('Seguranca/Protecao', 'Lesao fisica', 'Risco de trauma'),
    'T78': ('Seguranca/Protecao', 'Defesa imunologica', 'Risco de reacao alergica'),
    'Z87': ('Seguranca/Protecao', 'Defesa imunologica', 'Risco de infeccao'),
    # DOMINIO 12: Conforto
    'R52': ('Conforto', 'Conforto fisico', 'Dor aguda'),
    'G89': ('Conforto', 'Conforto fisico', 'Dor cronica'),
    'R07': ('Conforto', 'Conforto fisico', 'Dor aguda'),
    'R10': ('Conforto', 'Conforto fisico', 'Dor aguda'),
    'M79': ('Conforto', 'Conforto fisico', 'Dor cronica'),
    'R51': ('Conforto', 'Conforto fisico', 'Nausea'),
    'J90': ('Conforto', 'Conforto fisico', 'Desconforto'),
    # DOMINIO 4 (continuacao): Atividade/Repouso - Cardiovascular
    'I10': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de debito cardiaco diminuido'),
    'I11': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de debito cardiaco diminuido'),
    'I12': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de debito cardiaco diminuido'),
    'I13': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Debito cardiaco diminuido'),
    'I20': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de perfusao tissular ineficaz'),
    'I21': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Debito cardiaco diminuido'),
    'I25': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Perfusao tissular ineficaz'),
    'I26': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Perfusao tissular ineficaz'),
    'I48': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Debito cardiaco diminuido'),
    'I71': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de perfusao tissular ineficaz'),
    'D64': ('Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Risco de perfusao tissular ineficaz'),
}

# Tambem mapear codigos que nao tem letra+numero (somente numero ou V)
def map_icd(code):
    code = str(code).strip()
    for prefix, (domain, classe, label) in NANDA_MAP.items():
        if code.startswith(prefix):
            return domain, classe, label
    # Mapear por primeira letra
    first_char = code[0] if code else ''
    if first_char == 'I':
        return 'Atividade/Repouso', 'Respostas cardiovasculares/pulmonares', 'Diagnostico cardiovascular a especificar'
    elif first_char == 'E':
        return 'Nutricao', 'Metabolismo', 'Diagnostico nutricional/metabolico a especificar'
    elif first_char == 'N':
        return 'Eliminacao e Troca', 'Funcao urinaria', 'Diagnostico renal/urinario a especificar'
    elif first_char == 'A' or first_char == 'B':
        return 'Seguranca/Protecao', 'Infeccao', 'Diagnostico infeccioso a especificar'
    elif first_char == 'J':
        return 'Seguranca/Protecao', 'Infeccao', 'Diagnostico respiratorio a especificar'
    elif first_char == 'G':
        return 'Percepcao/Cognicao', 'Cognicao', 'Diagnostico neurologico a especificar'
    elif first_char == 'F':
        return 'Percepcao/Cognicao', 'Cognicao', 'Diagnostico psiquiatrico a especificar'
    elif first_char == 'R':
        return 'Conforto', 'Conforto fisico', 'Sintoma a especificar'
    elif first_char == 'M' or first_char == 'S':
        return 'Conforto', 'Conforto fisico', 'Condicao musculoesqueletica a especificar'
    elif first_char == 'K':
        return 'Eliminacao e Troca', 'Funcao gastrintestinal', 'Diagnostico gastrintestinal a especificar'
    elif first_char == 'L':
        return 'Seguranca/Protecao', 'Lesao fisica', 'Diagnostico dermatologico a especificar'
    elif first_char == 'Z':
        return 'Promocao da Saude', 'Exame de saude', 'Diagnostico de promocao da saude a especificar'
    return None, None, None

# Reconstruir NANDA
print('Reconstruindo camada NANDA-I (Taxonomia II)...')
nanda_rows = []
for _, row in dx.iterrows():
    code = str(row['icd_code'])
    domain, classe, label = map_icd(code)
    if domain:
        nanda_rows.append({
            'subject_id': int(row['subject_id']),
            'hadm_id': int(row['hadm_id']),
            'nanda_domain': domain,
            'nanda_class': classe,
            'nanda_label': label,
            'source': 'ICD-10',
            'evidence': f'ICD-10: {code}',
            'severity': 'Moderado'
        })

# Vital signs inference (mantido igual)
hr_items = [220045,211,223761]; sbp_items = [220050,51,442,455,6701,220179,220051,223752]
spo2_items = [220277,646,834,223769,220644]; temp_items = [223761,678,223762,676,227054]
pain_items = [223901,222951,228232,227013,226568,228088]; gcs_items = [223901,228412]

print('Inferindo NANDA por sinais vitais...')
for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    pid, hid = int(row['subject_id']), int(row['hadm_id'])
    if itemid in hr_items and val > 100:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','nanda_class':'Respostas cardiovasculares/pulmonares','nanda_label':'Risco de debito cardiaco diminuido','source':'Vital Signs','evidence':f'FC: {val:.0f} bpm','severity':'Moderado'})
    elif itemid in sbp_items and val < 90:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','nanda_class':'Respostas cardiovasculares/pulmonares','nanda_label':'Risco de perfusao tissular ineficaz','source':'Vital Signs','evidence':f'PAS: {val:.0f} mmHg','severity':'Moderado'})
    elif itemid in spo2_items and val < 92:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','nanda_class':'Respostas cardiovasculares/pulmonares','nanda_label':'Troca de gases prejudicada','source':'Vital Signs','evidence':f'SpO2: {val:.0f}%','severity':'Crítico' if val<85 else 'Moderado'})
    elif itemid in temp_items and val > 38.0:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Seguranca/Protecao','nanda_class':'Termorregulacao','nanda_label':'Hipertermia','source':'Vital Signs','evidence':f'Temp: {val:.1f}C','severity':'Moderado'})
    elif itemid in pain_items and val >= 7:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Conforto','nanda_class':'Conforto fisico','nanda_label':'Dor aguda','source':'Vital Signs','evidence':f'Dor: {val:.0f}/10','severity':'Severo' if val>=8 else 'Moderado'})
    elif itemid in gcs_items and val <= 8:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Percepcao/Cognicao','nanda_class':'Cognicao','nanda_label':'Perfusao tissular cerebral ineficaz','source':'Vital Signs','evidence':f'GCS: {val:.0f}','severity':'Crítico'})

print(f'Total NANDA: {len(nanda_rows)}')

# Reconstruir banco
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)

patients[['subject_id','gender','anchor_age','anchor_year']].to_sql('dim_patient', con, index=False)
admissions[['subject_id','hadm_id','admittime','dischtime','admission_type','discharge_location']].to_sql('dim_admission', con, index=False)
icu[['subject_id','hadm_id','stay_id','intime','outtime','first_careunit']].to_sql('dim_icustay', con, index=False)

fact_nanda = pd.DataFrame(nanda_rows)
fact_nanda['diagnosis_id'] = range(1, len(fact_nanda)+1)
fact_nanda.to_sql('fact_nanda', con, index=False)

# NOC (mantido igual, simplificado)
print('NOC...')
noc_rows = []
for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    sid, pid, hid = int(row['stay_id']), int(row['subject_id']), int(row['hadm_id'])
    ct = str(row['charttime'])
    if itemid in hr_items: noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Frequencia Cardiaca','value':float(val),'unit':'bpm','abnormal':int(val<60 or val>100)})
    elif itemid in sbp_items: noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Pressao Arterial Sistolica','value':float(val),'unit':'mmHg','abnormal':int(val<90 or val>140)})
    elif itemid in spo2_items: noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0415','noc_label':'Estado Respiratorio','indicator':'Saturacao de Oxigenio','value':float(val),'unit':'%','abnormal':int(val<92)})
    elif itemid in temp_items: noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Temperatura Corporal','value':float(val),'unit':'C','abnormal':int(val>38.0 or val<36.0)})
    elif itemid in pain_items: noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'1605','noc_label':'Controle da Dor','indicator':'Intensidade da Dor','value':float(val),'unit':'0-10','abnormal':int(val>=7)})

for _, row in inp.dropna(subset=['stay_id','subject_id','hadm_id']).iterrows():
    noc_rows.append({'stay_id':int(row['stay_id']),'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'charttime':str(row['starttime']),'noc_code':'0601','noc_label':'Equilibrio Hidrico','indicator':'Volume Infundido','value':float(row['amount']) if pd.notna(row['amount']) else 0.0,'unit':'mL','abnormal':0})
for _, row in out.dropna(subset=['stay_id','subject_id','hadm_id']).iterrows():
    noc_rows.append({'stay_id':int(row['stay_id']),'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'charttime':str(row['charttime']),'noc_code':'0601','noc_label':'Equilibrio Hidrico','indicator':'Debito Urinario','value':float(row['value']) if pd.notna(row['value']) else 0.0,'unit':'mL','abnormal':0})

fact_noc = pd.DataFrame(noc_rows)
fact_noc['outcome_id'] = range(1, len(fact_noc)+1)
fact_noc.to_sql('fact_noc', con, index=False)

# NIC
print('NIC...')
nic_rows = []
emar_c = emar.dropna(subset=['subject_id','hadm_id'])
for _, row in emar_c.iterrows():
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code':'2300','nic_label':'Administracao de Medicamentos','intervention_type':f'Medicacao: {row["medication"]}'})
inp_c = inp.dropna(subset=['subject_id','hadm_id','stay_id'])
for _, row in inp_c.iterrows():
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'stay_id':int(row['stay_id']),'charttime':str(row['starttime']),'nic_code':'4200','nic_label':'Terapia Intravenosa','intervention_type':f'Fluido IV: {row.get("ordercategoryname","IV Fluid")}'})
proc_c = proc.dropna(subset=['subject_id','hadm_id','stay_id'])
for _, row in proc_c.iterrows():
    ct = str(row.get('starttime', row.get('storetime', '')))
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'stay_id':int(row['stay_id']),'charttime':ct,'nic_code':'3540','nic_label':'Prevencao de Ulcera por Pressao','intervention_type':str(row.get('ordercategoryname','Procedimento'))})

fact_nic = pd.DataFrame(nic_rows)
fact_nic['intervention_event_id'] = range(1, len(fact_nic)+1)
fact_nic.to_sql('fact_nic', con, index=False)

# Referencia
pd.DataFrame({'domain_id':range(1,14),'domain_name':['Promocao da Saude','Nutricao','Eliminacao e Troca','Atividade/Repouso','Percepcao/Cognicao','Autopercepcao','Papeis e Relacionamentos','Sexualidade','Enfrentamento/Tolerancia ao Estresse','Principios Vitais','Seguranca/Protecao','Conforto','Crescimento/Desenvolvimento'],'n_classes':[2,5,4,6,5,2,3,3,3,3,6,3,3]}).to_sql('dim_nanda_domain', con, index=False)
pd.DataFrame({'outcome_id':range(1,9),'noc_code':['0802','0601','1605','1101','0415','0407','0912','0208'],'noc_label':['Estado dos Sinais Vitais','Equilibrio Hidrico','Controle da Dor','Integridade Tissular','Estado Respiratorio','Perfusao Tissular','Nivel de Consciencia','Mobilidade']}).to_sql('dim_noc_outcome', con, index=False)
pd.DataFrame({'intervention_id':range(1,11),'nic_code':['2300','4200','6680','4120','0840','3540','1400','3320','3180','1056'],'nic_label':['Administracao de Medicamentos','Terapia Intravenosa','Monitorizacao Sinais Vitais','Controle Hidrico','Posicionamento','Prevencao Ulcera Pressao','Controle da Dor','Oxigenoterapia','Cuidados Traqueostomia','Nutricao Enteral']}).to_sql('dim_nic_intervention', con, index=False)

con.execute('CREATE INDEX IF NOT EXISTS idx_nanda_subj ON fact_nanda(subject_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_nanda_hadm ON fact_nanda(hadm_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_noc_subj ON fact_noc(subject_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_noc_stay ON fact_noc(stay_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_nic_subj ON fact_nic(subject_id)')
con.commit()

# Resumo
print('\n' + '='*65)
print('BANCO ATUALIZADO — NANDA Taxonomia II (13 dominios, 48 classes)')
print('='*65)
for t in ['dim_patient','dim_admission','dim_icustay','fact_nanda','fact_noc','fact_nic','dim_nanda_domain','dim_noc_outcome','dim_nic_intervention']:
    n = con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
    print(f'  {t:30s}: {n:>10,}')

print('\n--- Dominios NANDA-I (Taxonomia II) ---')
for row in con.execute('SELECT nanda_domain, nanda_class, COUNT(*) as n FROM fact_nanda GROUP BY nanda_domain, nanda_class ORDER BY n DESC LIMIT 15'):
    print(f'  {row[0]:35s} | {row[1]:40s} | {row[2]:>6,}')

con.close()
size_mb = os.path.getsize(DB)/1e6
print(f'\nBanco: {DB} ({size_mb:.1f} MB)')
print('PRONTO.')
