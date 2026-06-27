#!/usr/bin/env python3
# =============================================================================
# rebuild_correct.py — Reconstrucao completa do banco de enfermagem
# com metodologia CORRETA: hipoteses NANDA, indicadores NOC vinculados,
# proxies/recomendacoes NIC separados, tabela de evidencias, linkage rules
# =============================================================================
import sqlite3, pandas as pd, os, sys, json
from datetime import datetime

BASE = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic-iv-clinical-database-demo-2.2'
DB   = r'C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic_nursing_poc\output\nursing_db.sqlite'

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip')
    plain = path.replace('.gz','')
    if os.path.exists(plain): return pd.read_csv(plain)
    return pd.read_csv(path)

print('=== REESTRUTURACAO DO BANCO — METODOLOGIA CORRETA ===')
print('Data:', datetime.now().strftime('%Y-%m-%d %H:%M'))
print()

# Carregar dados
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
print(f'Pacientes: {N} | Adm: {len(admissions)} | Chartevents: {len(ce)} | eMAR: {len(emar)}')

# Remover banco antigo
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)

# =========================================================================
# TABELAS DIMENSIONAIS (mantidas iguais)
# =========================================================================
patients[['subject_id','gender','anchor_age','anchor_year']].to_sql('dim_patient', con, index=False)
admissions[['subject_id','hadm_id','admittime','dischtime','admission_type','discharge_location']].to_sql('dim_admission', con, index=False)
icu[['subject_id','hadm_id','stay_id','intime','outtime','first_careunit']].to_sql('dim_icustay', con, index=False)

# =========================================================================
# TABELA: mapping_nanda_evidence
# Mapeia variaveis do MIMIC-IV para INDICADORES DIAGNOSTICOS (nao para diagnosticos diretos)
# =========================================================================
print('Construindo mapping_nanda_evidence...')
evidence_rows = []

# Mapeamento: (dominio, classe, titulo_diagnostico_NANDA, codigo_NANDA, tipo_diagnostico)
NANDA_DIAGNOSES = [
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Debito cardiaco diminuido','00029','foco_no_problema'),
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Risco de debito cardiaco diminuido','00240','risco'),
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Perfusao tissular periferica ineficaz','00204','foco_no_problema'),
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Risco de perfusao tissular periferica ineficaz','00228','risco'),
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Troca de gases prejudicada','00030','foco_no_problema'),
    ('Atividade/Repouso','Respostas cardiovasculares/pulmonares','Padrao respiratorio ineficaz','00032','foco_no_problema'),
    ('Atividade/Repouso','Atividade/Exercicio','Mobilidade fisica prejudicada','00085','foco_no_problema'),
    ('Atividade/Repouso','Atividade/Exercicio','Intolerancia a atividade','00092','foco_no_problema'),
    ('Atividade/Repouso','Sono/Repouso','Insônia','00095','foco_no_problema'),
    ('Atividade/Repouso','Sono/Repouso','Padrao de sono prejudicado','00198','foco_no_problema'),
    ('Nutricao','Ingestao','Nutricao desequilibrada: menor do que as necessidades corporais','00002','foco_no_problema'),
    ('Nutricao','Ingestao','Obesidade','00232','foco_no_problema'),
    ('Nutricao','Metabolismo','Risco de glicemia instavel','00179','risco'),
    ('Nutricao','Hidratacao','Volume de liquidos deficiente','00027','foco_no_problema'),
    ('Nutricao','Hidratacao','Risco de desequilibrio eletrolitico','00195','risco'),
    ('Eliminacao e Troca','Funcao urinaria','Eliminacao urinaria prejudicada','00016','foco_no_problema'),
    ('Eliminacao e Troca','Funcao urinaria','Retencao urinaria','00023','foco_no_problema'),
    ('Eliminacao e Troca','Funcao gastrintestinal','Constipacao','00011','foco_no_problema'),
    ('Eliminacao e Troca','Funcao gastrintestinal','Nausea','00134','foco_no_problema'),
    ('Percepcao/Cognicao','Cognicao','Confusao aguda','00128','foco_no_problema'),
    ('Percepcao/Cognicao','Cognicao','Memoria prejudicada','00131','foco_no_problema'),
    ('Percepcao/Cognicao','Cognicao','Ansiedade','00146','foco_no_problema'),
    ('Seguranca/Protecao','Infeccao','Risco de infeccao','00004','risco'),
    ('Seguranca/Protecao','Lesao fisica','Risco de quedas','00155','risco'),
    ('Seguranca/Protecao','Lesao fisica','Integridade da pele prejudicada','00046','foco_no_problema'),
    ('Seguranca/Protecao','Lesao fisica','Risco de integridade da pele prejudicada','00047','risco'),
    ('Seguranca/Protecao','Termorregulacao','Hipertermia','00007','foco_no_problema'),
    ('Seguranca/Protecao','Termorregulacao','Hipotermia','00006','foco_no_problema'),
    ('Seguranca/Protecao','Defesa imunologica','Risco de reacao alergica','00217','risco'),
    ('Conforto','Conforto fisico','Dor aguda','00132','foco_no_problema'),
    ('Conforto','Conforto fisico','Dor cronica','00133','foco_no_problema'),
    ('Conforto','Conforto fisico','Nausea','00134','foco_no_problema'),
    ('Enfrentamento/Tolerancia ao Estresse','Respostas de enfrentamento','Enfrentamento ineficaz','00069','foco_no_problema'),
]

# Mapear variaveis para indicadores diagnosticos
# (variavel, categoria_evidencia, detalhe)
EVIDENCE_CATEGORIES = {
    'characteristic_defining': 'Caracteristica definidora',
    'related_factor': 'Fator relacionado',
    'risk_factor': 'Fator de risco',
    'population_at_risk': 'Populacao em risco',
    'associated_condition': 'Condicao associada',
    'context_clinical': 'Contexto clinico'
}

# ICD-10 -> apenas como CONDICAO ASSOCIADA ou CONTEXTO CLINICO (nunca como prova suficiente)
icd_nanda_map = {
    'I50': ('Debito cardiaco diminuido','associated_condition','Insuficiencia cardiaca (ICD-10)'),
    'I21': ('Debito cardiaco diminuido','associated_condition','Infarto agudo do miocardio (ICD-10)'),
    'I25': ('Perfusao tissular periferica ineficaz','associated_condition','Doenca arterial coronariana (ICD-10)'),
    'I10': ('Risco de debito cardiaco diminuido','associated_condition','Hipertensao arterial (ICD-10)'),
    'I48': ('Debito cardiaco diminuido','associated_condition','Fibrilacao atrial (ICD-10)'),
    'J96': ('Troca de gases prejudicada','associated_condition','Insuficiencia respiratoria (ICD-10)'),
    'J18': ('Risco de infeccao','associated_condition','Pneumonia (ICD-10)'),
    'J15': ('Risco de infeccao','associated_condition','Pneumonia bacteriana (ICD-10)'),
    'A41': ('Risco de infeccao','associated_condition','Sepse (ICD-10)'),
    'N17': ('Eliminacao urinaria prejudicada','associated_condition','Insuficiencia renal aguda (ICD-10)'),
    'N18': ('Eliminacao urinaria prejudicada','associated_condition','Doenca renal cronica (ICD-10)'),
    'E11': ('Risco de glicemia instavel','associated_condition','Diabetes mellitus tipo 2 (ICD-10)'),
    'E10': ('Risco de glicemia instavel','associated_condition','Diabetes mellitus tipo 1 (ICD-10)'),
    'E66': ('Obesidade','associated_condition','Obesidade (ICD-10)'),
    'E46': ('Nutricao desequilibrada: menor do que as necessidades corporais','associated_condition','Desnutricao (ICD-10)'),
    'F05': ('Confusao aguda','associated_condition','Delirium (ICD-10)'),
    'F32': ('Ansiedade','associated_condition','Depressao (ICD-10)'),
    'G93': ('Confusao aguda','associated_condition','Encefalopatia (ICD-10)'),
    'L89': ('Risco de integridade da pele prejudicada','associated_condition','Ulcera por pressao (ICD-10)'),
    'R52': ('Dor aguda','associated_condition','Dor (ICD-10)'),
}

# Construir evidence_rows a partir de ICD-10
for _, row in dx.iterrows():
    code = str(row['icd_code'])
    for prefix, (dx_name, category, detail) in icd_nanda_map.items():
        if code.startswith(prefix):
            # Encontrar o diagnostico NANDA correspondente
            for d in NANDA_DIAGNOSES:
                if d[2] == dx_name:
                    evidence_rows.append({
                        'subject_id': int(row['subject_id']),
                        'hadm_id': int(row['hadm_id']),
                        'nanda_domain': d[0],
                        'nanda_class': d[1],
                        'nanda_label': dx_name,
                        'nanda_code': d[3],
                        'diagnosis_type': d[4],
                        'evidence_category': EVIDENCE_CATEGORIES[category],
                        'evidence_source': 'ICD-10',
                        'evidence_detail': f'{detail} (ICD-10: {code})',
                        'confidence_level': 'INDIRETO',
                        'limitation': 'Codigo ICD-10 e condicao associada, nao caracteristica definidora de diagnostico de enfermagem'
                    })
            break

# Sinais vitais anormais -> CARACTERISTICA DEFINIDORA (nao diagnostico direto)
hr_items = [220045,211,223761]; sbp_items = [220050,51,442,455,6701,220179,220051,223752]
spo2_items = [220277,646,834,223769,220644]; temp_items = [223761,678,223762,676,227054]
pain_items = [223901,222951,228232,227013,226568,228088]; gcs_items = [223901,228412]

# Mapear sinais vitais para CARACTERISTICAS DEFINIDORAS especificas
vital_evidence_map = {
    'hr_high': ('Debito cardiaco diminuido','characteristic_defining','Taquicardia > 100 bpm'),
    'sbp_low': ('Risco de perfusao tissular periferica ineficaz','characteristic_defining','Hipotensao sistolica < 90 mmHg'),
    'spo2_low': ('Troca de gases prejudicada','characteristic_defining','SpO2 < 92%'),
    'temp_high': ('Hipertermia','characteristic_defining','Temperatura > 38.0 C'),
    'temp_low': ('Hipotermia','characteristic_defining','Temperatura < 36.0 C'),
    'pain_high': ('Dor aguda','characteristic_defining','Dor >= 7 na escala NRS'),
    'gcs_low': ('Confusao aguda','characteristic_defining','GCS <= 8'),
}

for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    pid, hid = int(row['subject_id']), int(row['hadm_id'])
    
    if itemid in hr_items and val > 100:
        dx_name, cat, detail = vital_evidence_map['hr_high']
        for d in NANDA_DIAGNOSES:
            if d[2] == dx_name:
                evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':d[0],'nanda_class':d[1],'nanda_label':dx_name,'nanda_code':d[3],'diagnosis_type':d[4],'evidence_category':EVIDENCE_CATEGORIES[cat],'evidence_source':'chartevents','evidence_detail':f'{detail}: {val:.0f}','confidence_level':'COMPATIVEL','limitation':'Evidencia unica; necessario avaliacao completa para confirmacao'})
    elif itemid in sbp_items and val < 90:
        dx_name, cat, detail = vital_evidence_map['sbp_low']
        for d in NANDA_DIAGNOSES:
            if d[2] == dx_name:
                evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':d[0],'nanda_class':d[1],'nanda_label':dx_name,'nanda_code':d[3],'diagnosis_type':d[4],'evidence_category':EVIDENCE_CATEGORIES[cat],'evidence_source':'chartevents','evidence_detail':f'{detail}: {val:.0f}','confidence_level':'COMPATIVEL','limitation':'Evidencia unica'})
    elif itemid in spo2_items and val < 92:
        dx_name, cat, detail = vital_evidence_map['spo2_low']
        for d in NANDA_DIAGNOSES:
            if d[2] == dx_name:
                evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':d[0],'nanda_class':d[1],'nanda_label':dx_name,'nanda_code':d[3],'diagnosis_type':d[4],'evidence_category':EVIDENCE_CATEGORIES[cat],'evidence_source':'chartevents','evidence_detail':f'{detail}: {val:.0f}%','confidence_level':'COMPATIVEL','limitation':'Evidencia unica'})
    elif itemid in temp_items and val > 38.0:
        dx_name, cat, detail = vital_evidence_map['temp_high']
        for d in NANDA_DIAGNOSES:
            if d[2] == dx_name:
                evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':d[0],'nanda_class':d[1],'nanda_label':dx_name,'nanda_code':d[3],'diagnosis_type':d[4],'evidence_category':EVIDENCE_CATEGORIES[cat],'evidence_source':'chartevents','evidence_detail':f'{detail}: {val:.1f}C','confidence_level':'COMPATIVEL','limitation':'Evidencia unica'})
    elif itemid in pain_items and val >= 7:
        dx_name, cat, detail = vital_evidence_map['pain_high']
        for d in NANDA_DIAGNOSES:
            if d[2] == dx_name:
                evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':d[0],'nanda_class':d[1],'nanda_label':dx_name,'nanda_code':d[3],'diagnosis_type':d[4],'evidence_category':EVIDENCE_CATEGORIES[cat],'evidence_source':'chartevents','evidence_detail':f'{detail}: {val:.0f}/10','confidence_level':'COMPATIVEL','limitation':'Evidencia unica'})

mapping_evidence = pd.DataFrame(evidence_rows)
mapping_evidence['evidence_id'] = range(1, len(mapping_evidence)+1)
mapping_evidence.to_sql('mapping_nanda_evidence', con, index=False)
print(f'  mapping_nanda_evidence: {len(mapping_evidence)} registros')
print(f'  Categorias: {mapping_evidence["evidence_category"].value_counts().to_dict()}')

# =========================================================================
# TABELA: fact_nanda_hypothesis
# Hipoteses diagnosticas baseadas em evidencias, NAO diagnosticos confirmados
# =========================================================================
print('Construindo fact_nanda_hypothesis...')
# Agrupar evidencias por (subject_id, hadm_id, nanda_label)
hypothesis_rows = []
grouped = mapping_evidence.groupby(['subject_id','hadm_id','nanda_domain','nanda_class','nanda_label','nanda_code','diagnosis_type'])

status_map = {'COMPATIVEL':'candidate','INDIRETO':'candidate'}
for (sid, hid, dom, cls, label, code, dtype), group in grouped:
    evidence_list = group[['evidence_category','evidence_source','evidence_detail']].to_dict('records')
    confidence = 'rule_supported' if any(e['evidence_category'] == 'Caracteristica definidora' for e in evidence_list) else 'candidate'
    if all(e['evidence_category'] == 'Condicao associada' for e in evidence_list):
        confidence = 'candidate'
    
    # So gerar hipotese se ha pelo menos 1 evidencia de caracteristica definidora OU 1 fator de risco (para diagnosticos de risco)
    has_defining = any(e['evidence_category'] == 'Caracteristica definidora' for e in evidence_list)
    has_risk = any(e['evidence_category'] == 'Fator de risco' for e in evidence_list)
    is_risk_dx = dtype == 'risco'
    
    if has_defining or (is_risk_dx and has_risk):
        confidence = 'rule_supported'
    
    hypothesis_rows.append({
        'subject_id': int(sid),
        'hadm_id': int(hid),
        'nanda_domain': dom,
        'nanda_class': cls,
        'nanda_label': label,
        'nanda_code': code,
        'diagnosis_type': dtype,
        'n_evidence': len(group),
        'has_defining_characteristic': int(has_defining),
        'has_risk_factor': int(has_risk),
        'status': confidence,
        'confidence_note': 'Regra computacional; NAO validado por enfermeiro especialista',
        'evidence_summary': json.dumps([f'{e["evidence_category"]}: {e["evidence_detail"][:80]}' for e in evidence_list[:5]], ensure_ascii=False),
        'limitation': 'Hipotese gerada por regra computacional com suporte de IA (DeepSeek-v4-Pro). Nao validada por enfermeiro especialista.'
    })

fact_hypothesis = pd.DataFrame(hypothesis_rows)
fact_hypothesis['hypothesis_id'] = range(1, len(fact_hypothesis)+1)
fact_hypothesis.to_sql('fact_nanda_hypothesis', con, index=False)
print(f'  fact_nanda_hypothesis: {len(fact_hypothesis)} registros')
print(f'  Status: {fact_hypothesis["status"].value_counts().to_dict()}')

# =========================================================================
# TABELA: fact_noc_measurement  
# Resultados NOC vinculados a hipoteses NANDA (NAO sinais vitais isolados)
# =========================================================================
print('Construindo fact_noc_measurement...')
# Para CADA hipotese, buscar indicadores NOC nos chartevents na mesma janela
# Usar mapeamento NANDA -> NOC da literatura

# Mapeamento NANDA -> NOC (baseado em Moorhead et al., 2024 - apenas identificadores)
NANDA_NOC_MAP = {
    'Debito cardiaco diminuido': [('0401','Estado Circulatorio','Pressao Arterial Sistolica','mmHg','systolic_bp'),('0401','Estado Circulatorio','Frequencia Cardiaca','bpm','heart_rate')],
    'Risco de debito cardiaco diminuido': [('0401','Estado Circulatorio','Pressao Arterial Sistolica','mmHg','systolic_bp')],
    'Troca de gases prejudicada': [('0402','Estado Respiratorio: Troca Gasosa','Saturacao de Oxigenio','%','spo2')],
    'Dor aguda': [('2102','Nivel de Dor','Intensidade da Dor','0-10','pain_nrs')],
    'Hipertermia': [('0800','Termorregulacao','Temperatura Corporal','C','temperature')],
    'Confusao aguda': [('0912','Estado Neurologico: Consciencia','Escala de Coma de Glasgow','score','gcs')],
    'Risco de perfusao tissular periferica ineficaz': [('0401','Estado Circulatorio','Pressao Arterial Sistolica','mmHg','systolic_bp')],
}

# Mapear itemids para indicadores
ITEMID_INDICATOR_MAP = {
    'systolic_bp': [220050,51,442,455,6701,220179,220051,223752],
    'heart_rate': [220045,211,223761],
    'spo2': [220277,646,834,223769,220644],
    'pain_nrs': [223901,222951,228232,227013,226568,228088],
    'temperature': [223761,678,223762,676,227054],
    'gcs': [223901,228412],
}

noc_rows = []
for _, hyp in fact_hypothesis.iterrows():
    if hyp['status'] == 'candidate': continue  # So medir NOC para hipoteses com suporte
    label = hyp['nanda_label']
    if label not in NANDA_NOC_MAP: continue
    
    for noc_code, noc_label, indicator, unit, indicator_key in NANDA_NOC_MAP[label]:
        itemids = ITEMID_INDICATOR_MAP.get(indicator_key, [])
        if not itemids: continue
        
        # Buscar medicoes na janela da admissao
        measurements = ce[(ce['subject_id']==hyp['subject_id']) & (ce['hadm_id']==hyp['hadm_id']) & (ce['itemid'].isin(itemids))]
        if len(measurements) == 0: continue
        
        values = measurements['valuenum'].dropna()
        if len(values) == 0: continue
        
        baseline = values.iloc[0] if len(values) > 0 else None
        followup = values.iloc[-1] if len(values) > 1 else None
        
        # Direcao esperada
        direction_map = {'systolic_bp':'Manter dentro dos limites','heart_rate':'Manter dentro dos limites','spo2':'Aumentar','pain_nrs':'Diminuir','temperature':'Manter dentro dos limites','gcs':'Aumentar'}
        
        noc_rows.append({
            'hypothesis_id': hyp['hypothesis_id'],
            'subject_id': int(hyp['subject_id']),
            'hadm_id': int(hyp['hadm_id']),
            'noc_code': noc_code,
            'noc_label': noc_label,
            'indicator': indicator,
            'unit': unit,
            'baseline_value': baseline,
            'followup_value': followup,
            'n_measurements': len(values),
            'expected_direction': direction_map.get(indicator_key, 'Avaliar'),
            'measurement_window': 'Admissao (todos os registros)',
            'origin_variable': f'chartevents itemid(s): {itemids}',
            'limitation': 'Indicador operacionalizado a partir de sinais vitais; NAO e resultado NOC documentado por enfermeiro'
        })

fact_noc = pd.DataFrame(noc_rows)
if len(fact_noc) > 0:
    fact_noc['noc_measurement_id'] = range(1, len(fact_noc)+1)
    fact_noc.to_sql('fact_noc_measurement', con, index=False)
print(f'  fact_noc_measurement: {len(fact_noc)} registros')

# =========================================================================
# TABELA: fact_nic_observed_proxy (acoes observaveis como proxy)
# =========================================================================
print('Construindo fact_nic_observed_proxy...')
nic_observed = []
emar_c = emar.dropna(subset=['subject_id','hadm_id'])
for _, row in emar_c.iterrows():
    nic_observed.append({
        'subject_id': int(row['subject_id']),
        'hadm_id': int(row['hadm_id']),
        'nic_code_proxy': '2300-PROXY',
        'nic_label_proxy': 'Administracao de Medicamentos (proxy observavel)',
        'action_detail': f'Medicacao administrada: {row["medication"]}',
        'action_type': 'medication_administration',
        'is_nursing_autonomous': 0,
        'limitation': 'Registro de administracao nao distingue prescritor. Pode ser acao medica ou de enfermagem.'
    })

inp_c = inp.dropna(subset=['subject_id','hadm_id','stay_id'])
for _, row in inp_c.iterrows():
    nic_observed.append({
        'subject_id': int(row['subject_id']),
        'hadm_id': int(row['hadm_id']),
        'nic_code_proxy': '4200-PROXY',
        'nic_label_proxy': 'Terapia Intravenosa (proxy observavel)',
        'action_detail': f'Fluido IV: {row.get("ordercategoryname","IV")}',
        'action_type': 'iv_fluid',
        'is_nursing_autonomous': 0,
        'limitation': 'Infusao IV e acao interdisciplinar; nao e exclusivamente intervencao de enfermagem'
    })

fact_nic_observed = pd.DataFrame(nic_observed)
fact_nic_observed['observed_id'] = range(1, len(fact_nic_observed)+1)
fact_nic_observed.to_sql('fact_nic_observed_proxy', con, index=False)
print(f'  fact_nic_observed_proxy: {len(fact_nic_observed)} registros')

# =========================================================================
# TABELA: fact_nic_recommended (intervencoes recomendadas baseadas em NNN linkage)
# =========================================================================
print('Construindo fact_nic_recommended (NNN linkage)...')
nic_recommended = []

# Ligacoes NANDA-NOC-NIC documentadas na literatura
NNN_LINKAGES = [
    ('Debito cardiaco diminuido','0401','4040','Cuidados Cardiacos','Monitorizacao hemodinamica, controle de fluidos','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada de literatura; nao validada no MIMIC-IV'),
    ('Troca de gases prejudicada','0402','3320','Oxigenoterapia','Administracao de oxigenio, monitorizacao de SpO2','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
    ('Dor aguda','2102','1400','Controle da Dor','Avaliacao da dor, administracao de analgesicos','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
    ('Hipertermia','0800','3740','Tratamento da Febre','Monitorizacao de temperatura, medidas de resfriamento','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
    ('Risco de infeccao','0703','6540','Controle de Infeccao','Lavagem das maos, precaucoes padrao, vigilancia','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
    ('Confusao aguda','0912','6440','Manejo do Delirium','Monitorizacao neurologica, ambiente seguro','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
    ('Risco de quedas','1902','6490','Prevencao de Quedas','Avaliacao de risco, ambiente seguro','Moorhead et al., 2024; Butcher et al., 2024','BAIXO','Recomendacao derivada'),
]

for _, hyp in fact_hypothesis.iterrows():
    if hyp['status'] == 'candidate': continue
    for nanda_label, noc_code, nic_code, nic_label, nic_desc, source, confidence_level, limitation in NNN_LINKAGES:
        if nanda_label == hyp['nanda_label']:
            nic_recommended.append({
                'hypothesis_id': hyp['hypothesis_id'],
                'subject_id': int(hyp['subject_id']),
                'hadm_id': int(hyp['hadm_id']),
                'nanda_label': nanda_label,
                'noc_code': noc_code,
                'nic_code': nic_code,
                'nic_label': nic_label,
                'nic_description': nic_desc,
                'source': source,
                'confidence_level': confidence_level,
                'limitation': limitation
            })

fact_nic_rec = pd.DataFrame(nic_recommended)
if len(fact_nic_rec) > 0:
    fact_nic_rec['recommendation_id'] = range(1, len(fact_nic_rec)+1)
    fact_nic_rec.to_sql('fact_nic_recommended', con, index=False)
print(f'  fact_nic_recommended: {len(fact_nic_rec)} registros')

# =========================================================================
# TABELA: nnn_linkage_rules
# =========================================================================
print('Construindo nnn_linkage_rules...')
linkage_rows = []
for (nanda_label, noc_code, nic_code, nic_label, nic_desc, source, conf, lim) in NNN_LINKAGES:
    for d in NANDA_DIAGNOSES:
        if d[2] == nanda_label:
            linkage_rows.append({
                'nanda_code': d[3],
                'nanda_label': nanda_label,
                'nanda_domain': d[0],
                'nanda_class': d[1],
                'noc_code': noc_code,
                'nic_code': nic_code,
                'nic_label': nic_label,
                'rule_description': nic_desc,
                'evidence_type': 'Revisao de literatura',
                'source_reference': source,
                'confidence_level': conf,
                'limitation_note': lim
            })
            break

nnn_linkage = pd.DataFrame(linkage_rows)
nnn_linkage['rule_id'] = range(1, len(nnn_linkage)+1)
nnn_linkage.to_sql('nnn_linkage_rules', con, index=False)
print(f'  nnn_linkage_rules: {len(nnn_linkage)} registros')

# =========================================================================
# DIMENSOES DE REFERENCIA
# =========================================================================
pd.DataFrame({
    'domain_id': range(1,14),
    'domain_name': ['Promocao da Saude','Nutricao','Eliminacao e Troca','Atividade/Repouso','Percepcao/Cognicao','Autopercepcao','Papeis e Relacionamentos','Sexualidade','Enfrentamento/Tolerancia ao Estresse','Principios Vitais','Seguranca/Protecao','Conforto','Crescimento/Desenvolvimento'],
    'nanda_classes': [2,5,4,6,5,2,3,3,3,3,6,3,3]
}).to_sql('dim_nanda_domain', con, index=False)

# Indices
for idx_col in ['subject_id','hadm_id','hypothesis_id','nanda_label']:
    for tbl in ['mapping_nanda_evidence','fact_nanda_hypothesis','fact_noc_measurement','fact_nic_observed_proxy','fact_nic_recommended']:
        try:
            if idx_col in [c[1] for c in con.execute(f'PRAGMA table_info({tbl})')]:
                con.execute(f'CREATE INDEX IF NOT EXISTS idx_{tbl}_{idx_col} ON {tbl}({idx_col})')
        except: pass

con.commit()

# Resumo final
print('\n' + '='*70)
print('BANCO REESTRUTURADO — METODOLOGIA CORRETA')
print('='*70)
for t in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall():
    n = con.execute(f'SELECT COUNT(*) FROM {t[0]}').fetchone()[0]
    print(f'  {t[0]:35s}: {n:>10,}')

size_mb = os.path.getsize(DB)/1e6
print(f'\nBanco: {DB} ({size_mb:.1f} MB)')
print('Metodologia: hipoteses NANDA → indicadores NOC → proxies/recomendacoes NIC')
print('Status: PROVA DE CONCEITO — NAO VALIDADO CLINICAMENTE')
con.close()
