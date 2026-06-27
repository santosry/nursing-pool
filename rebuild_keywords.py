#!/usr/bin/env python3
# =============================================================================
# rebuild_keywords.py — Inferencia NANDA-I por PALAVRAS-CHAVE MEDICAS + TF-IDF
# =============================================================================
# Metodo hibrido:
# 1. Mapeamento direto por palavras-chave medicas (alta precisao)
# 2. TF-IDF + Cosine Similarity para codigos sem keyword match (fallback)
# 3. Cada mapeamento rotulado como "keyword_match" ou "embedding_fallback"
# =============================================================================
import sqlite3, pandas as pd, numpy as np, os, json, re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from datetime import datetime
from config import BASE_DIR, DB_PATH

BASE = BASE_DIR
DB   = DB_PATH

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip')
    plain = path.replace('.gz','')
    if os.path.exists(plain): return pd.read_csv(plain)
    return pd.read_csv(path)

print('=== INFERENCIA NANDA-I POR PALAVRAS-CHAVE MEDICAS + TF-IDF ===')
print(f'Data: {datetime.now().strftime("%Y-%m-%d %H:%M")}')

patients   = load('hosp/patients.csv.gz')
admissions = load('hosp/admissions.csv.gz')
dx         = load('hosp/diagnoses_icd.csv.gz')
d_icd      = load('hosp/d_icd_diagnoses.csv.gz')
ce         = load('icu/chartevents.csv')
icu        = load('icu/icustays.csv.gz')
emar       = load('hosp/emar.csv.gz')
inp        = load('icu/inputevents.csv')
out        = load('icu/outputevents.csv')

# =============================================================================
# DICIONARIO DE PALAVRAS-CHAVE MEDICAS -> DOMINIO NANDA
# Cada entrada: (palavras-chave separadas por |, nome do dominio, confianca)
# =============================================================================
KEYWORD_RULES = [
    # CARDIOVASCULAR / ATIVIDADE-REPOUSO
    ('heart failure|cardiomyopathy|myocardial infarction|coronary artery|angina|atrial fibrillation|arrhythmia|cardiac arrest|cardiogenic shock|pericarditis|endocarditis|valvular heart|ventricular|tachycardia|bradycardia|hypertensive heart|pulmonary heart|aneurysm|aortic|mitral regurgitation|tricuspid|cardiac|congestive heart|left ventricular|right ventricular|systolic|diastolic|ejection fraction|cardiomegaly|cardiorespiratory', 'Atividade/Repouso'),
    # HIPERTENSAO
    ('hypertension|hypertensive|elevated blood pressure|essential hypertension|renovascular hypertension|malignant hypertension', 'Atividade/Repouso'),
    # RESPIRATORIO
    ('respiratory failure|pneumonia|pulmonary|COPD|emphysema|bronchitis|asthma|pleural effusion|pneumothorax|atelectasis|dyspnea|hypoxia|hypoxemia|hypercapnia|mechanical ventilation|respiratory distress|ARDS|pulmonary edema|pulmonary embolism|lung|bronchopulmonary|tracheostomy|ventilator', 'Atividade/Repouso'),
    # RENAL / ELIMINACAO
    ('renal failure|kidney disease|nephritis|nephrotic|nephropathy|acute kidney|chronic kidney|end stage renal|dialysis|renal insufficiency|uremia|azotemia|glomerulonephritis|pyelonephritis|hydronephrosis|renal tubular|urinary tract infection|UTI|cystitis|urinary retention|bladder|urethral|urolithiasis|calculus of kidney|nephrolithiasis|chronic kidney disease', 'Eliminacao e Troca'),
    # GASTROINTESTINAL / ELIMINACAO
    ('gastrointestinal|gastric|duodenal|peptic ulcer|gastritis|gastroenteritis|colitis|Crohn|ulcerative colitis|IBS|irritable bowel|diverticulitis|diverticulosis|appendicitis|peritonitis|bowel obstruction|ileus|volvulus|intussusception|megacolon|constipation|diarrhea|nausea|vomiting|hematemesis|melena|GI bleed|gastrointestinal hemorrhage|esophageal varices|cirrhosis|hepatic failure|liver failure|hepatitis|cholecystitis|cholangitis|pancreatitis|pancreatic|jaundice|ascites|portal hypertension|hepatic encephalopathy|hepatorenal', 'Eliminacao e Troca'),
    # NEUROLOGICO / PERCEPCAO-COGNICAO
    ('cerebrovascular|stroke|CVA|intracranial hemorrhage|subarachnoid|subdural hematoma|epidural hematoma|brain injury|traumatic brain|concussion|cerebral edema|encephalopathy|encephalitis|meningitis|seizure|epilepsy|status epilepticus|convulsion|altered mental status|confusion|delirium|dementia|Alzheimer|cognitive impairment|memory loss|aphasia|dysphasia|hemiplegia|paraplegia|quadriplegia|Guillain-Barre|multiple sclerosis|Parkinson|Huntington|ALS|neuromuscular|neuropathy|myopathy|myasthenia|brain tumor|glioblastoma|meningioma|hydrocephalus', 'Percepcao/Cognicao'),
    # INFECCAO / SEGURANCA-PROTECAO
    ('sepsis|septic shock|bacteremia|fungemia|infection|infective|abscess|cellulitis|necrotizing fasciitis|osteomyelitis|endocarditis infectious|meningitis bacterial|peritonitis|cholecystitis acute|pyelonephritis|empyema|infected|wound infection|surgical site infection|catheter-related|CLABSI|CAUTI|VAP|MRSA|VRE|C. difficile|clostridium difficile|candidiasis|aspergillosis|tuberculosis|HIV|AIDS|immunocompromised|neutropenic|febrile neutropenia|opportunistic infection', 'Seguranca/Protecao'),
    # FERIDAS / SEGURANCA-PROTECAO
    ('wound|ulcer|pressure ulcer|decubitus|bedsore|skin breakdown|skin integrity|burn|thermal injury|trauma|injury|fracture|dislocation|sprain|strain|contusion|laceration|abrasion|penetrating|gunshot|stab wound|fall|accidental fall|poisoning|overdose|toxic effect|adverse effect|complication of|foreign body|asphyxia|drowning|electrocution|hypothermia|hyperthermia|heat stroke|frostbite', 'Seguranca/Protecao'),
    # DOR / CONFORTO
    ('pain|chronic pain|acute pain|neuralgia|neuropathic pain|fibromyalgia|migraine|headache|back pain|neck pain|chest pain|abdominal pain|pelvic pain|phantom limb|complex regional pain|causalgia|postherpetic neuralgia|trigeminal neuralgia|sciatica|arthralgia|myalgia', 'Conforto'),
    # DIABETES / NUTRICAO
    ('diabetes|diabetic|hyperglycemia|hypoglycemia|diabetic ketoacidosis|HHS|hyperosmolar|insulin|glucose intolerance|metabolic syndrome', 'Nutricao'),
    # OBESIDADE / DESNUTRICAO / NUTRICAO
    ('obesity|overweight|morbid obesity|bariatric|malnutrition|undernutrition|protein-calorie|nutritional deficiency|vitamin deficiency|mineral deficiency|anemia|iron deficiency|B12 deficiency|folate deficiency|weight loss|cachexia|wasting|failure to thrive|feeding difficulty|dysphagia|malabsorption|celiac|short bowel|TPN|total parenteral nutrition|enteral nutrition|NG tube|PEG tube|G tube|J tube', 'Nutricao'),
    # ELETROLITOS / NUTRICAO
    ('electrolyte|hyponatremia|hypernatremia|hypokalemia|hyperkalemia|hypocalcemia|hypercalcemia|hypomagnesemia|hypermagnesemia|hypophosphatemia|acidosis|alkalosis|metabolic acidosis|metabolic alkalosis|respiratory acidosis|respiratory alkalosis|dehydration|volume depletion|fluid overload|hypervolemia|hypovolemia', 'Nutricao'),
    # SAUDE MENTAL / PERCEPCAO-COGNICAO ou ENFRENTAMENTO
    ('depression|major depressive|bipolar|mania|schizophrenia|schizoaffective|psychosis|psychotic|hallucination|delusion|anxiety|panic disorder|PTSD|post-traumatic stress|obsessive-compulsive|OCD|personality disorder|borderline personality|substance abuse|substance use disorder|alcohol withdrawal|alcohol intoxication|opioid|overdose|suicidal|suicide attempt|self-harm|psychiatric', 'Enfrentamento/Tolerancia ao Estresse'),
    # CANCER / MULTIPLOS DOMINIOS
    ('malignant neoplasm|cancer|carcinoma|sarcoma|lymphoma|leukemia|myeloma|melanoma|metastasis|metastatic|chemotherapy|radiation therapy|immunotherapy|palliative|hospice|terminal', 'Conforto'),
]

# Construir dicionario ICD -> descricao
icd_desc_map = {}
for _, row in d_icd.iterrows():
    code = str(row['icd_code']).strip()
    title = str(row['long_title']) if pd.notna(row['long_title']) else ''
    if code and title:
        icd_desc_map[code] = title.lower()

print(f'ICD descriptions: {len(icd_desc_map)} codes')
print(f'Keyword rules: {len(KEYWORD_RULES)}')

# =============================================================================
# MAPEAMENTO: keyword match primeiro, embedding fallback depois
# =============================================================================
icd_to_nanda = {}
keyword_matches = 0
embedding_matches = 0
no_match = 0

# Passo 1: Keyword matching
for code, desc in icd_desc_map.items():
    matched = False
    for pattern, domain in KEYWORD_RULES:
        if re.search(pattern, desc, re.IGNORECASE):
            icd_to_nanda[code] = (domain, 'keyword_match', 1.0)
            keyword_matches += 1
            matched = True
            break
    if not matched:
        no_match += 1

print(f'Keyword matches: {keyword_matches} | Unmatched: {no_match}')

# Passo 2: TF-IDF fallback for unmatched codes
unmatched_codes = [code for code in icd_desc_map if code not in icd_to_nanda]
if unmatched_codes:
    NANDA_DOMAINS = [
        ('Promocao da Saude','Health promotion, wellness, self-care, health education.'),
        ('Nutricao','Nutrition, malnutrition, obesity, diabetes, electrolyte, metabolism, feeding, fluid balance.'),
        ('Eliminacao e Troca','Renal failure, kidney, urinary, bowel, gastrointestinal, liver, dialysis, ostomy, constipation, diarrhea.'),
        ('Atividade/Repouso','Cardiovascular, heart failure, arrhythmia, hypertension, respiratory, pneumonia, COPD, oxygenation, circulation, sleep, fatigue, activity.'),
        ('Percepcao/Cognicao','Neurological, stroke, seizure, confusion, delirium, coma, brain injury, encephalopathy, cognitive, memory.'),
        ('Autopercepcao','Self-concept, self-esteem, body image, personal identity.'),
        ('Papeis e Relacionamentos','Family, social, relationships, caregiving, bereavement, grief.'),
        ('Sexualidade','Sexual, reproductive, sexually transmitted.'),
        ('Enfrentamento/Tolerancia ao Estresse','Anxiety, depression, stress, coping, substance abuse, PTSD, psychiatric, bipolar, schizophrenia.'),
        ('Principios Vitais','Spiritual, religious, values, beliefs.'),
        ('Seguranca/Protecao','Infection, sepsis, wound, ulcer, burn, trauma, injury, fall, poisoning, allergy, bleeding, hemorrhage, immunity.'),
        ('Conforto','Pain, chronic pain, nausea, discomfort, symptoms, suffering, palliative, cancer, malignancy.'),
        ('Crescimento/Desenvolvimento','Growth, development, developmental, failure to thrive.'),
    ]
    
    unmatched_descs = [icd_desc_map[c] for c in unmatched_codes]
    domain_descs = [d[1] for d in NANDA_DOMAINS]
    all_texts = unmatched_descs + domain_descs
    
    vectorizer = TfidfVectorizer(stop_words='english', max_features=3000)
    tfidf_matrix = vectorizer.fit_transform(all_texts)
    icd_vecs = tfidf_matrix[:len(unmatched_descs)]
    nanda_vecs = tfidf_matrix[len(unmatched_descs):]
    
    similarities = cosine_similarity(icd_vecs, nanda_vecs)
    best_idx = np.argmax(similarities, axis=1)
    best_scores = np.max(similarities, axis=1)
    
    for i, code in enumerate(unmatched_codes):
        domain = NANDA_DOMAINS[best_idx[i]][0]
        score = float(best_scores[i])
        icd_to_nanda[code] = (domain, 'embedding_fallback', score)
        embedding_matches += 1

print(f'Embedding fallback matches: {embedding_matches}')
print(f'Total mapped: {len(icd_to_nanda)}')

# =============================================================================
# RECONSTRUIR BANCO
# =============================================================================
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)

patients[['subject_id','gender','anchor_age','anchor_year']].to_sql('dim_patient', con, index=False)
admissions[['subject_id','hadm_id','admittime','dischtime','admission_type','discharge_location']].to_sql('dim_admission', con, index=False)
icu[['subject_id','hadm_id','stay_id','intime','outtime','first_careunit']].to_sql('dim_icustay', con, index=False)

# mapping_nanda_evidence
print('\nConstruindo mapping_nanda_evidence...')
evidence_rows = []
for _, row in dx.iterrows():
    code = str(row['icd_code']).strip()
    if code in icd_to_nanda:
        domain, method, score = icd_to_nanda[code]
        evidence_rows.append({
            'subject_id': int(row['subject_id']),
            'hadm_id': int(row['hadm_id']),
            'nanda_domain': domain,
            'evidence_category': 'Condicao associada' if method == 'keyword_match' else 'Condicao associada (embedding)',
            'evidence_source': 'ICD-10',
            'evidence_detail': f'{icd_desc_map.get(code, code)} (ICD-10: {code})',
            'embedding_score': round(score, 4) if method != 'keyword_match' else 1.0,
            'inference_method': f'Keyword match' if method == 'keyword_match' else 'TF-IDF + Cosine Similarity',
            'limitation': 'Inferencia por regra computacional; nao constitui diagnostico de enfermagem confirmado'
        })

# Sinais vitais
hr_items=[220045,211,223761]; sbp_items=[220050,51,442,455,6701,220179]; spo2_items=[220277,646,834,223769]
temp_items=[223761,678,223762,676]; pain_items=[223901,222951,228232,227013,226568,228088]; gcs_items=[223901,228412]
for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    pid, hid = int(row['subject_id']), int(row['hadm_id'])
    if itemid in hr_items and val > 100:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Taquicardia: {val:.0f} bpm','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})
    elif itemid in sbp_items and val < 90:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Hipotensao: {val:.0f} mmHg','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})
    elif itemid in spo2_items and val < 92:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Hipoxemia: SpO2 {val:.0f}%','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})
    elif itemid in temp_items and val > 38.0:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Seguranca/Protecao','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Febre: {val:.1f}C','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})
    elif itemid in pain_items and val >= 7:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Conforto','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Dor intensa: {val:.0f}/10','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})
    elif itemid in gcs_items and val <= 8:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Percepcao/Cognicao','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Coma: GCS {val:.0f}','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica'})

mapping_evidence = pd.DataFrame(evidence_rows)
mapping_evidence['evidence_id'] = range(1, len(mapping_evidence)+1)
mapping_evidence.to_sql('mapping_nanda_evidence', con, index=False)

# fact_nanda_hypothesis
grouped = mapping_evidence.groupby(['subject_id','hadm_id','nanda_domain'])
hypothesis_rows = []
for (sid, hid, dom), group in grouped:
    n_evidence = len(group)
    has_defining = any('Caracteristica definidora' in str(e) for e in group['evidence_category'])
    has_keyword = 'keyword_match' in str(group['inference_method'].iloc[0]) if 'inference_method' in group.columns else False
    status = 'rule_supported' if (has_defining or has_keyword) else 'candidate'
    hypothesis_rows.append({
        'subject_id': int(sid), 'hadm_id': int(hid),
        'nanda_domain': dom, 'n_evidence': n_evidence,
        'has_defining_characteristic': int(has_defining),
        'has_keyword_match': int(has_keyword),
        'inference_method': 'Keyword rules + TF-IDF fallback (DeepSeek-v4-Pro assisted)',
        'status': status,
        'limitation': 'Hipotese gerada por regras computacionais. Nao constitui diagnostico de enfermagem confirmado.'
    })

fact_hypothesis = pd.DataFrame(hypothesis_rows)
fact_hypothesis['hypothesis_id'] = range(1, len(fact_hypothesis)+1)
fact_hypothesis.to_sql('fact_nanda_hypothesis', con, index=False)

# NOC measurements
NANDA_NOC_MAP = {
    'Atividade/Repouso': [('0401','Estado Circulatorio','PA Sistolica','mmHg',sbp_items),('0401','Estado Circulatorio','FC','bpm',hr_items),('0402','Estado Respiratorio','SpO2','%',spo2_items)],
    'Seguranca/Protecao': [('0800','Termorregulacao','Temperatura','C',temp_items)],
    'Conforto': [('2102','Nivel de Dor','Dor NRS','0-10',pain_items)],
    'Percepcao/Cognicao': [('0912','Estado Neurologico','GCS','score',gcs_items)],
}
noc_rows=[]
for _, hyp in fact_hypothesis.iterrows():
    if hyp['status']=='candidate': continue
    dom=hyp['nanda_domain']
    if dom in NANDA_NOC_MAP:
        for noc_code,noc_label,indicator,unit,itemids in NANDA_NOC_MAP[dom]:
            meas=ce[(ce['subject_id']==hyp['subject_id'])&(ce['hadm_id']==hyp['hadm_id'])&(ce['itemid'].isin(itemids))]
            if len(meas)==0: continue
            vals=meas['valuenum'].dropna()
            if len(vals)==0: continue
            noc_rows.append({'hypothesis_id':hyp['hypothesis_id'],'subject_id':int(hyp['subject_id']),'hadm_id':int(hyp['hadm_id']),'noc_code':noc_code,'noc_label':noc_label,'indicator':indicator,'unit':unit,'baseline_value':float(vals.iloc[0]),'followup_value':float(vals.iloc[-1]),'n_measurements':len(vals),'expected_direction':'Avaliar','measurement_window':'Admissao','origin_variable':f'chartevents','limitation':'Indicador operacionalizado de sinais vitais; NAO e NOC documentado por enfermeiro'})
fact_noc=pd.DataFrame(noc_rows)
if len(fact_noc)>0: fact_noc['noc_measurement_id']=range(1,len(fact_noc)+1); fact_noc.to_sql('fact_noc_measurement',con,index=False)

# NIC proxies
nic_obs=[]
for _,row in emar.dropna(subset=['subject_id','hadm_id']).iterrows():
    nic_obs.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code_proxy':'2300-PROXY','nic_label_proxy':'Adm. Medicamentos (proxy)','action_detail': str(row['medication']),'action_type':'medication','is_nursing_autonomous':0,'limitation':'Registro nao distingue prescritor'})
for _,row in inp.dropna(subset=['subject_id','hadm_id','stay_id']).iterrows():
    nic_obs.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code_proxy':'4200-PROXY','nic_label_proxy':'Terapia IV (proxy)','action_detail': str(row.get('ordercategoryname','IV')),'action_type':'iv_fluid','is_nursing_autonomous':0,'limitation':'Acao interdisciplinar'})
fact_nic_obs=pd.DataFrame(nic_obs); fact_nic_obs['observed_id']=range(1,len(fact_nic_obs)+1); fact_nic_obs.to_sql('fact_nic_observed_proxy',con,index=False)

# NIC recommended
nic_rec=[]
NNN_LINKS=[('Atividade/Repouso','0401','4040','Cuidados Cardiacos','Monitorizacao hemodinamica','Moorhead et al.,2024'),('Seguranca/Protecao','0800','3740','Tratamento da Febre','Monitorizacao temperatura','Moorhead et al.,2024'),('Conforto','2102','1400','Controle da Dor','Avaliacao/manejo da dor','Moorhead et al.,2024'),('Percepcao/Cognicao','0912','6440','Manejo do Delirium','Monitorizacao neurologica','Moorhead et al.,2024'),('Atividade/Repouso','0402','3320','Oxigenoterapia','Administracao O2','Moorhead et al.,2024'),('Nutricao','1004','1100','Manejo Nutricional','Suporte nutricional','Moorhead et al.,2024'),('Eliminacao e Troca','0503','0590','Manejo Eliminacao','Monitorizacao urinaria','Moorhead et al.,2024')]
for _,hyp in fact_hypothesis.iterrows():
    if hyp['status']=='candidate': continue
    for nanda,noc_code,nic_code,nic_label,nic_desc,source in NNN_LINKS:
        if nanda==hyp['nanda_domain']:
            nic_rec.append({'hypothesis_id':hyp['hypothesis_id'],'subject_id':int(hyp['subject_id']),'hadm_id':int(hyp['hadm_id']),'nanda_domain':nanda,'noc_code':noc_code,'nic_code':nic_code,'nic_label':nic_label,'nic_description':nic_desc,'source':source,'confidence_level':'BAIXO','limitation':'Recomendacao derivada de literatura; nao validada no MIMIC-IV'})
fact_nic_rec=pd.DataFrame(nic_rec)
if len(fact_nic_rec)>0: fact_nic_rec['recommendation_id']=range(1,len(fact_nic_rec)+1); fact_nic_rec.to_sql('fact_nic_recommended',con,index=False)

# Linkage rules
linkage_rows=[]
for nanda,noc_code,nic_code,nic_label,nic_desc,source in NNN_LINKS:
    linkage_rows.append({'nanda_domain':nanda,'noc_code':noc_code,'nic_code':nic_code,'nic_label':nic_label,'rule_description':nic_desc,'source_reference':source,'inference_method':'Keyword rules (DeepSeek-v4-Pro assisted)','confidence_level':'BAIXO','limitation_note':'Regra derivada de literatura; requer validacao clinica'})
nnn_link=pd.DataFrame(linkage_rows); nnn_link['rule_id']=range(1,len(nnn_link)+1); nnn_link.to_sql('nnn_linkage_rules',con,index=False)

# dim_nanda_domain
nanda_names=[d[0] for d in [('Promocao da Saude',''),('Nutricao',''),('Eliminacao e Troca',''),('Atividade/Repouso',''),('Percepcao/Cognicao',''),('Autopercepcao',''),('Papeis e Relacionamentos',''),('Sexualidade',''),('Enfrentamento/Tolerancia ao Estresse',''),('Principios Vitais',''),('Seguranca/Protecao',''),('Conforto',''),('Crescimento/Desenvolvimento','')]]
pd.DataFrame({'domain_id':range(1,14),'domain_name':nanda_names}).to_sql('dim_nanda_domain',con,index=False)

con.commit()

# Summary
print('\n' + '='*65)
print('BANCO — PALAVRAS-CHAVE MEDICAS + TF-IDF FALLBACK')
print('='*65)
for t in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall():
    n = con.execute(f'SELECT COUNT(*) FROM {t[0]}').fetchone()[0]
    print(f'  {t[0]:35s}: {n:>10,}')

print(f'\nMetodo: {keyword_matches} keyword matches + {embedding_matches} embedding fallbacks')
print(f'Taxa de cobertura por keyword: {100*keyword_matches/len(icd_desc_map):.1f}%')

# Quality check: top domains
print('\nTop dominios (hipoteses):')
for row in con.execute('SELECT nanda_domain, COUNT(*) FROM fact_nanda_hypothesis GROUP BY nanda_domain ORDER BY COUNT(*) DESC LIMIT 8').fetchall():
    print(f'  {row[0]:35s}: {row[1]:>5}')

size_mb=os.path.getsize(DB)/1e6
print(f'\nBanco: {DB} ({size_mb:.1f} MB)')
con.close()
print('PRONTO.')
