#!/usr/bin/env python3
# build_real_db.py — Constroi banco de enfermagem com dados REAIS do MIMIC-IV Demo v2.2
import sqlite3, pandas as pd, os, sys

BASE = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic-iv-clinical-database-demo-2.2'
DB   = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic_nursing_poc\output\nursing_db.sqlite'

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip')
    plain = path.replace('.gz','')
    if os.path.exists(plain):
        return pd.read_csv(plain)
    return pd.read_csv(path)

print('=== CARREGANDO DADOS REAIS MIMIC-IV Demo v2.2 ===')
patients   = load('hosp/patients.csv.gz')
admissions = load('hosp/admissions.csv.gz')
dx         = load('hosp/diagnoses_icd.csv.gz')
ce         = load('icu/chartevents.csv')
icu        = load('icu/icustays.csv.gz')
lab        = load('hosp/labevents.csv.gz')
emar       = load('hosp/emar.csv.gz')
emar_det   = load('hosp/emar_detail.csv.gz')
inp        = load('icu/inputevents.csv')
out        = load('icu/outputevents.csv')
omr        = load('hosp/omr.csv.gz')
presc      = load('hosp/prescriptions.csv.gz')
proc       = load('icu/procedureevents.csv')

N = len(patients)
print(f'Pacientes: {N} | Adms: {len(admissions)} | ICU: {len(icu)} | CE: {len(ce)} | eMAR: {len(emar)}')

os.makedirs(os.path.dirname(DB), exist_ok=True)
if os.path.exists(DB):
    os.remove(DB)
con = sqlite3.connect(DB)

# 1. dim_patient
patients[['subject_id','gender','anchor_age','anchor_year']].to_sql('dim_patient', con, index=False)

# 2. dim_admission
adm_cols = ['subject_id','hadm_id','admittime','dischtime','admission_type','discharge_location']
admissions[adm_cols].to_sql('dim_admission', con, index=False)

# 3. dim_icustay
icu_cols = ['subject_id','hadm_id','stay_id','intime','outtime','first_careunit']
icu[icu_cols].to_sql('dim_icustay', con, index=False)

# 4. NANDA mapping
print('Construindo camada NANDA-I...')
nanda_map = {
    'E4':('Nutricao','Nutricao desequilibrada'),'E66':('Nutricao','Obesidade'),
    'E10':('Nutricao','Risco de glicemia instavel'),'E11':('Nutricao','Risco de glicemia instavel'),
    'E03':('Nutricao','Nutricao desequilibrada'),'E78':('Nutricao','Nutricao desequilibrada'),
    'R63':('Nutricao','Nutricao desequilibrada'),'E43':('Nutricao','Nutricao desequilibrada'),
    'N17':('Eliminacao','Eliminacao urinaria prejudicada'),'N18':('Eliminacao','Eliminacao urinaria prejudicada'),
    'N39':('Eliminacao','Eliminacao urinaria prejudicada'),'N40':('Eliminacao','Eliminacao urinaria prejudicada'),
    'I10':('Cardiovascular','Risco de debito cardiaco diminuido'),'I11':('Cardiovascular','Risco de debito cardiaco diminuido'),
    'I12':('Cardiovascular','Risco de debito cardiaco diminuido'),'I13':('Cardiovascular','Debito cardiaco diminuido'),
    'I20':('Cardiovascular','Risco de perfusao tissular ineficaz'),'I21':('Cardiovascular','Debito cardiaco diminuido'),
    'I25':('Cardiovascular','Perfusao tissular ineficaz'),'I48':('Cardiovascular','Debito cardiaco diminuido'),
    'I50':('Cardiovascular','Debito cardiaco diminuido'),'I71':('Cardiovascular','Risco de perfusao tissular ineficaz'),
    'A41':('Seguranca/Protecao','Risco de infeccao'),'J15':('Seguranca/Protecao','Risco de infeccao'),
    'J18':('Seguranca/Protecao','Risco de infeccao'),'J44':('Seguranca/Protecao','Risco de infeccao'),
    'J96':('Atividade/Repouso','Padrao respiratorio ineficaz'),'R06':('Atividade/Repouso','Padrao respiratorio ineficaz'),
    'G93':('Percepcao/Cognicao','Perfusao tissular cerebral ineficaz'),'F05':('Percepcao/Cognicao','Confusao aguda'),
    'F32':('Percepcao/Cognicao','Risco de automutilacao'),'F41':('Percepcao/Cognicao','Ansiedade'),
    'R52':('Conforto','Dor aguda'),'M79':('Conforto','Dor cronica'),'R07':('Conforto','Dor aguda'),
    'R10':('Conforto','Dor aguda'),'R51':('Conforto','Nausea'),'G89':('Conforto','Dor cronica'),
    'L89':('Seguranca/Protecao','Integridade da pele prejudicada'),'R55':('Seguranca/Protecao','Risco de quedas'),
    'W19':('Seguranca/Protecao','Risco de quedas'),'R53':('Atividade/Repouso','Intolerancia a atividade'),
    'Z68':('Nutricao','Obesidade'),'Z79':('Nutricao','Risco de glicemia instavel'),
    'K59':('Eliminacao','Constipacao'),'K92':('Eliminacao','Risco de motilidade gastrintestinal'),
    'R11':('Eliminacao','Nausea'),'R33':('Eliminacao','Eliminacao urinaria prejudicada'),
    'I63':('Percepcao/Cognicao','Perfusao tissular cerebral ineficaz'),'I61':('Percepcao/Cognicao','Perfusao tissular cerebral ineficaz'),
    'I26':('Cardiovascular','Perfusao tissular ineficaz'),'D64':('Cardiovascular','Risco de perfusao tissular ineficaz'),
    'T78':('Seguranca/Protecao','Risco de reacao alergica'),'B95':('Seguranca/Protecao','Risco de infeccao'),
    'Z87':('Seguranca/Protecao','Risco de infeccao'),'L03':('Seguranca/Protecao','Integridade da pele prejudicada'),
}

nanda_rows = []
codes_mapped = set()
for _, row in dx.iterrows():
    code = str(row['icd_code'])
    matched = False
    for prefix, (domain, label) in nanda_map.items():
        if code.startswith(prefix):
            nanda_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),
                'nanda_domain':domain,'nanda_label':label,'source':'ICD-10',
                'evidence':f'ICD-10: {code}','severity':'Moderado'})
            codes_mapped.add(code)
            matched = True
            break
    if not matched and code[0] in ('I','E','A','J','R','G','F','N','M','L','K','Z'):
        nanda_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),
            'nanda_domain':'Clinico Geral','nanda_label':'Diagnostico clinico sem mapeamento NANDA',
            'source':'ICD-10','evidence':f'ICD-10: {code}','severity':'Moderado'})

icd_mapped = len(set(r['hadm_id'] for r in nanda_rows if r['source']=='ICD-10' and r['nanda_domain']!='Clinico Geral'))
print(f'ICD->NANDA: {sum(1 for r in nanda_rows if r["nanda_domain"]!="Clinico Geral")} diagnosticos mapeados, {icd_mapped} admissoes')

# Vital signs inference
hr_items = [220045,211,223761]; sbp_items = [220050,51,442,455,6701,220179,220051,223752]
spo2_items = [220277,646,834,223769,220644]; temp_items = [223761,678,223762,676,227054]
pain_items = [223901,222951,228232,227013,226568,228088]; gcs_items = [223901,228412]

for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    sid, pid, hid = int(row['subject_id']), int(row['hadm_id']), int(row['stay_id'])
    if itemid in hr_items and val > 100:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Cardiovascular',
            'nanda_label':'Risco de debito cardiaco diminuido','source':'Vital Signs',
            'evidence':f'FC: {val:.0f} bpm','severity':'Moderado'})
    elif itemid in sbp_items and val < 90:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Cardiovascular',
            'nanda_label':'Risco de perfusao tissular ineficaz','source':'Vital Signs',
            'evidence':f'PAS: {val:.0f} mmHg','severity':'Moderado'})
    elif itemid in spo2_items and val < 92:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso',
            'nanda_label':'Troca de gases prejudicada','source':'Vital Signs',
            'evidence':f'SpO2: {val:.0f}%','severity':('Crítico' if val < 85 else 'Moderado')})
    elif itemid in temp_items and val > 38.0:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Seguranca/Protecao',
            'nanda_label':'Hipertermia','source':'Vital Signs',
            'evidence':f'Temp: {val:.1f}C','severity':'Moderado'})
    elif itemid in pain_items and val >= 7:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Conforto',
            'nanda_label':'Dor aguda','source':'Vital Signs',
            'evidence':f'Dor: {val:.0f}/10','severity':('Severo' if val>=8 else 'Moderado')})
    elif itemid in gcs_items and val <= 8:
        nanda_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Percepcao/Cognicao',
            'nanda_label':'Perfusao tissular cerebral ineficaz','source':'Vital Signs',
            'evidence':f'GCS: {val:.0f}','severity':'Crítico'})

print(f'Total NANDA: {len(nanda_rows)}')
fact_nanda = pd.DataFrame(nanda_rows)
fact_nanda['diagnosis_id'] = range(1, len(fact_nanda)+1)
fact_nanda.to_sql('fact_nanda', con, index=False)

# 5. NOC
print('Construindo camada NOC...')
noc_rows = []
step = max(1, len(ce)//10)
for i, (_, row) in enumerate(ce.iterrows()):
    if i % step == 0: print(f'  NOC: {100*i//len(ce)}%', end='\r')
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    sid, pid, hid = int(row['stay_id']), int(row['subject_id']), int(row['hadm_id'])
    ct = str(row['charttime'])
    if itemid in hr_items:
        noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Frequencia Cardiaca','value':float(val),'unit':'bpm','abnormal':int(val<60 or val>100)})
    elif itemid in sbp_items:
        noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Pressao Arterial Sistolica','value':float(val),'unit':'mmHg','abnormal':int(val<90 or val>140)})
    elif itemid in spo2_items:
        noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0415','noc_label':'Estado Respiratorio','indicator':'Saturacao de Oxigenio','value':float(val),'unit':'%','abnormal':int(val<92)})
    elif itemid in temp_items:
        noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'0802','noc_label':'Estado dos Sinais Vitais','indicator':'Temperatura Corporal','value':float(val),'unit':'C','abnormal':int(val>38.0 or val<36.0)})
    elif itemid in pain_items:
        noc_rows.append({'stay_id':sid,'subject_id':pid,'hadm_id':hid,'charttime':ct,'noc_code':'1605','noc_label':'Controle da Dor','indicator':'Intensidade da Dor','value':float(val),'unit':'0-10','abnormal':int(val>=7)})

print(f'  NOC: 100%')
for _, row in inp.iterrows():
    noc_rows.append({'stay_id':int(row['stay_id']),'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'charttime':str(row['starttime']),'noc_code':'0601','noc_label':'Equilibrio Hidrico','indicator':'Volume Infundido','value':float(row['amount']) if pd.notna(row['amount']) else 0.0,'unit':'mL','abnormal':0})
for _, row in out.iterrows():
    noc_rows.append({'stay_id':int(row['stay_id']),'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'charttime':str(row['charttime']),'noc_code':'0601','noc_label':'Equilibrio Hidrico','indicator':'Debito Urinario','value':float(row['value']) if pd.notna(row['value']) else 0.0,'unit':'mL','abnormal':0})

print(f'Total NOC: {len(noc_rows)}')
fact_noc = pd.DataFrame(noc_rows)
fact_noc['outcome_id'] = range(1, len(fact_noc)+1)
fact_noc.to_sql('fact_noc', con, index=False)

# 6. NIC
print('Construindo camada NIC...')
nic_rows = []
emar_clean = emar.dropna(subset=['subject_id','hadm_id'])
for _, row in emar_clean.iterrows():
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code':'2300','nic_label':'Administracao de Medicamentos','intervention_type':f'Medicacao: {row["medication"]}'})
inp_clean = inp.dropna(subset=['subject_id','hadm_id','stay_id'])
for _, row in inp_clean.iterrows():
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'stay_id':int(row['stay_id']),'charttime':str(row['starttime']),'nic_code':'4200','nic_label':'Terapia Intravenosa','intervention_type':f'Fluido IV: {row.get("ordercategoryname","IV Fluid")}'})
proc_clean = proc.dropna(subset=['subject_id','hadm_id','stay_id'])
for _, row in proc_clean.iterrows():
    ct = str(row.get('starttime', row.get('storetime', '')))
    nic_rows.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'stay_id':int(row['stay_id']),'charttime':ct,'nic_code':'3540','nic_label':'Cuidados com Pele','intervention_type':str(row.get('ordercategoryname','Procedimento'))})

print(f'Total NIC: {len(nic_rows)}')
fact_nic = pd.DataFrame(nic_rows)
fact_nic['intervention_event_id'] = range(1, len(fact_nic)+1)
fact_nic.to_sql('fact_nic', con, index=False)

# 7. Reference tables
pd.DataFrame({'domain_id':range(1,14),'domain_name':['Promocao da Saude','Nutricao','Eliminacao e Troca','Atividade/Repouso','Percepcao/Cognicao','Autopercepcao','Papeis e Relacionamentos','Sexualidade','Enfrentamento','Princípios da Vida','Seguranca/Protecao','Conforto','Crescimento'],'domain_code':['1','2','3','4','5','6','7','8','9','10','11','12','13']}).to_sql('dim_nanda_domain', con, index=False)
pd.DataFrame({'outcome_id':range(1,9),'noc_code':['0802','0601','1605','1101','0415','0407','0912','0208'],'noc_label':['Estado dos Sinais Vitais','Equilibrio Hidrico','Controle da Dor','Integridade Tissular','Estado Respiratorio','Perfusao Tissular','Nivel de Consciencia','Mobilidade']}).to_sql('dim_noc_outcome', con, index=False)
pd.DataFrame({'intervention_id':range(1,11),'nic_code':['2300','4200','6680','4120','0840','3540','1400','3320','3180','1056'],'nic_label':['Administracao de Medicamentos','Terapia Intravenosa','Monitorizacao Sinais Vitais','Controle Hidrico','Posicionamento','Prevencao Ulcera Pressao','Controle da Dor','Oxigenoterapia','Cuidados Traqueostomia','Nutricao Enteral']}).to_sql('dim_nic_intervention', con, index=False)

# Indices
con.execute('CREATE INDEX IF NOT EXISTS idx_nanda_subj ON fact_nanda(subject_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_nanda_hadm ON fact_nanda(hadm_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_noc_subj ON fact_noc(subject_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_noc_stay ON fact_noc(stay_id)')
con.execute('CREATE INDEX IF NOT EXISTS idx_nic_subj ON fact_nic(subject_id)')
con.commit()

# Final summary
print('\n' + '='*65)
print('BANCO DE ENFERMAGEM — DADOS REAIS MIMIC-IV Demo v2.2')
print('='*65)
for t in ['dim_patient','dim_admission','dim_icustay','dim_nanda_domain','dim_noc_outcome','dim_nic_intervention','fact_nanda','fact_noc','fact_nic']:
    n = con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
    print(f'  {t:30s}: {n:>10,}')

print('\n--- Dominios NANDA mais frequentes ---')
for row in con.execute('SELECT nanda_domain, COUNT(*) as n FROM fact_nanda GROUP BY nanda_domain ORDER BY n DESC LIMIT 8'):
    print(f'  {row[0]:30s}: {row[1]:>6,}')

print('\n--- Intervencoes NIC ---')
for row in con.execute('SELECT nic_label, COUNT(*) as n FROM fact_nic GROUP BY nic_label ORDER BY n DESC'):
    print(f'  {row[0]:35s}: {row[1]:>8,}')

print('\n--- NOC: anormalidade por indicador ---')
for row in con.execute('SELECT indicator, COUNT(*) as t, SUM(abnormal) as a, ROUND(100.0*SUM(abnormal)/COUNT(*),1) as pct FROM fact_noc WHERE abnormal IS NOT NULL GROUP BY indicator ORDER BY pct DESC'):
    print(f'  {row[0]:35s}: {row[2]:>5,}/{row[1]:>6,} = {row[3]}%')

n_all = con.execute('SELECT COUNT(DISTINCT n.subject_id) FROM fact_nanda n JOIN fact_noc o ON n.subject_id=o.subject_id JOIN fact_nic i ON n.subject_id=i.subject_id').fetchone()[0]
print(f'\nPacientes com NANDA+NOC+NIC: {n_all}/{N}')

size_mb = os.path.getsize(DB)/1e6
print(f'\nBanco: {DB}  ({size_mb:.1f} MB)')
print('PRONTO.')
con.close()
