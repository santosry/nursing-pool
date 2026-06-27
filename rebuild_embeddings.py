#!/usr/bin/env python3
# =============================================================================
# rebuild_embeddings.py — Inferencia NANDA-I/NOC/NIC por EMBEDDINGS (TF-IDF)
# =============================================================================
# Metodologia: usa similaridade de cosseno entre descricoes ICD-10 (ingles) e 
# descricoes dos dominios/classes NANDA-I para gerar hipoteses diagnosticas 
# baseadas em similaridade semantica, nao em regras manuais arbitrarias.
# =============================================================================
import sqlite3, pandas as pd, numpy as np, os, json
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from datetime import datetime

BASE = r'..\mimic-iv-clinical-database-demo-2.2'
DB   = r'output\nursing_db.sqlite'

def load(p):
    path = os.path.join(BASE, p)
    if p.endswith('.gz') and os.path.exists(path):
        return pd.read_csv(path, compression='gzip')
    plain = path.replace('.gz','')
    if os.path.exists(plain): return pd.read_csv(plain)
    return pd.read_csv(path)

print('=== INFERENCIA NANDA-I POR EMBEDDINGS (TF-IDF + Cosine Similarity) ===')
print(f'Data: {datetime.now().strftime("%Y-%m-%d %H:%M")}')
print()

# Carregar dados
patients   = load('hosp/patients.csv.gz')
admissions = load('hosp/admissions.csv.gz')
dx         = load('hosp/diagnoses_icd.csv.gz')
d_icd      = load('hosp/d_icd_diagnoses.csv.gz')
ce         = load('icu/chartevents.csv')
icu        = load('icu/icustays.csv.gz')
emar       = load('hosp/emar.csv.gz')
inp        = load('icu/inputevents.csv')
out        = load('icu/outputevents.csv')
proc       = load('icu/procedureevents.csv')

# =============================================================================
# DEFINIR DOMINIOS NANDA-I COM DESCRICOES PARA EMBEDDING
# =============================================================================
NANDA_DOMAINS = [
    ('Promocao da Saude','Consciencia sobre bem-estar e estrategias de gestao de saude. Comportamentos de saude, prevencao, autocuidado, educacao em saude, promocao de habitos saudaveis.'),
    ('Nutricao','Ingestao, digestao, absorcao e metabolismo de nutrientes. Desnutricao, obesidade, diabetes, desequilibrio hidroeletrolitico, deficiencia nutricional, alimentacao enteral e parenteral.'),
    ('Eliminacao e Troca','Secrecao e excrecao de residuos corporais. Funcao urinaria, funcao intestinal, insuficiencia renal, constipacao, incontinencia, dialise, ostomias.'),
    ('Atividade/Repouso','Producao, conservacao e equilibrio de energia. Funcao cardiovascular, circulacao, respiracao, oxigenacao, atividade fisica, mobilidade, sono, repouso, fadiga, intolerancia a atividade.'),
    ('Percepcao/Cognicao','Processamento de informacao sensorial e cognitiva. Atencao, orientacao, percepcao, cognicao, comunicacao, estado mental, confusao, delirium, alteracao neurologica, coma.'),
    ('Autopercepcao','Consciencia sobre si mesmo. Autoestima, imagem corporal, identidade pessoal, autoconceito, papel social.'),
    ('Papeis e Relacionamentos','Conexoes entre individuos. Relacoes familiares, papel social, comunicacao interpessoal, isolamento social, luto.'),
    ('Sexualidade','Identidade sexual, funcao reprodutiva, atividade sexual, disfuncao sexual.'),
    ('Enfrentamento/Tolerancia ao Estresse','Resposta a eventos estressantes. Ansiedade, estresse, enfrentamento, adaptacao, choque, trauma psicologico, abuso de substancias.'),
    ('Principios Vitais','Principios, valores e crencas. Espiritualidade, religiao, conflito de valores, sofrimento espiritual.'),
    ('Seguranca/Protecao','Protecao contra perigos e lesoes. Infeccao, sepse, imunidade, defesa, risco de queda, integridade da pele, feridas, termorregulacao, alergia, intoxicacao, violencia.'),
    ('Conforto','Sensacao de bem-estar fisico, mental e social. Dor aguda, dor cronica, nausea, desconforto, sofrimento, mal-estar, sintomas fisicos.'),
    ('Crescimento/Desenvolvimento','Aumento de dimensoes fisicas e maturacao. Desenvolvimento infantil, crescimento pondero-estatural, marcos de desenvolvimento, envelhecimento.'),
]

domain_descs = [d[1] for d in NANDA_DOMAINS]

# =============================================================================
# CONSTRUIR DICIONARIO ICD -> DESCRICAO
# =============================================================================
icd_desc_map = {}
for _, row in d_icd.iterrows():
    code = str(row['icd_code']).strip()
    title = str(row['long_title']) if pd.notna(row['long_title']) else ''
    if code and title:
        icd_desc_map[code] = title

print(f'ICD descriptions loaded: {len(icd_desc_map)} codes')

# =============================================================================
# TF-IDF VECTORIZER
# =============================================================================
# Combinar descricoes ICD + NANDA para vocabulario comum
all_texts = list(icd_desc_map.values()) + domain_descs
vectorizer = TfidfVectorizer(stop_words='english', max_features=5000)
tfidf_matrix = vectorizer.fit_transform(all_texts)

# Separar: primeiras N sao ICD, ultimas 13 sao NANDA
icd_vectors = tfidf_matrix[:len(icd_desc_map)]
nanda_vectors = tfidf_matrix[len(icd_desc_map):]

print(f'TF-IDF matrix: {tfidf_matrix.shape}')

# =============================================================================
# CALCULAR SIMILARIDADE E MAPEAR CADA ICD AO DOMINIO NANDA MAIS PROXIMO
# =============================================================================
similarities = cosine_similarity(icd_vectors, nanda_vectors)
best_match_idx = np.argmax(similarities, axis=1)
best_scores = np.max(similarities, axis=1)

icd_codes_list = list(icd_desc_map.keys())
icd_to_nanda = {}
for i, code in enumerate(icd_codes_list):
    domain_idx = best_match_idx[i]
    score = best_scores[i]
    domain_name = NANDA_DOMAINS[domain_idx][0]
    icd_to_nanda[code] = (domain_name, score)

print(f'Mapeamento embedding concluido: {len(icd_to_nanda)} codigos ICD mapeados')
print(f'Score medio: {np.mean(best_scores):.3f} | Score mediano: {np.median(best_scores):.3f}')
print(f'Top 5 dominios por contagem:')
dom_counts = {}
for code, (dom, score) in icd_to_nanda.items():
    dom_counts[dom] = dom_counts.get(dom, 0) + 1
for dom, count in sorted(dom_counts.items(), key=lambda x: -x[1])[:8]:
    print(f'  {dom}: {count}')

# =============================================================================
# RECONSTRUIR BANCO COM INFERENCIA POR EMBEDDINGS
# =============================================================================
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)

# Dim tables
patients[['subject_id','gender','anchor_age','anchor_year']].to_sql('dim_patient', con, index=False)
admissions[['subject_id','hadm_id','admittime','dischtime','admission_type','discharge_location']].to_sql('dim_admission', con, index=False)
icu[['subject_id','hadm_id','stay_id','intime','outtime','first_careunit']].to_sql('dim_icustay', con, index=False)

# =============================================================================
# mapping_nanda_evidence — COM EMBEDDINGS
# =============================================================================
print('\nConstruindo mapping_nanda_evidence (embeddings)...')
evidence_rows = []
for _, row in dx.iterrows():
    code = str(row['icd_code']).strip()
    if code in icd_to_nanda:
        domain, score = icd_to_nanda[code]
        confidence = 'ALTA' if score > 0.4 else 'MEDIA' if score > 0.2 else 'BAIXA'
        evidence_rows.append({
            'subject_id': int(row['subject_id']),
            'hadm_id': int(row['hadm_id']),
            'nanda_domain': domain,
            'evidence_category': 'Condicao associada (embedding)',
            'evidence_source': 'ICD-10',
            'evidence_detail': f'{icd_desc_map.get(code, code)} (ICD-10: {code})',
            'embedding_score': round(float(score), 4),
            'inference_method': 'TF-IDF + Cosine Similarity (DeepSeek-v4-Pro assisted)',
            'limitation': 'Inferencia por similaridade semantica; nao constitui diagnostico de enfermagem confirmado'
        })

# Sinais vitais como caracteristicas definidoras (mantido com limiares)
hr_items = [220045,211,223761]; sbp_items = [220050,51,442,455,6701,220179,220051,223752]
spo2_items = [220277,646,834,223769,220644]; temp_items = [223761,678,223762,676,227054]
pain_items = [223901,222951,228232,227013,226568,228088]; gcs_items = [223901,228412]

for _, row in ce.iterrows():
    itemid, val = row['itemid'], row['valuenum']
    if pd.isna(val): continue
    pid, hid = int(row['subject_id']), int(row['hadm_id'])
    if itemid in hr_items and val > 100:
        evidence_rows.append({'subject_id':pid,'hadm_id':hid,'nanda_domain':'Atividade/Repouso','evidence_category':'Caracteristica definidora','evidence_source':'chartevents','evidence_detail':f'Taquicardia: {val:.0f} bpm','embedding_score':None,'inference_method':'Limiar clinico','limitation':'Evidencia unica; requer avaliacao completa'})
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
print(f'  mapping_nanda_evidence: {len(mapping_evidence)} evidencias')
print(f'  Categorias: {mapping_evidence["evidence_category"].value_counts().to_dict()}')

# =============================================================================
# fact_nanda_hypothesis
# =============================================================================
print('Construindo fact_nanda_hypothesis...')
grouped = mapping_evidence.groupby(['subject_id','hadm_id','nanda_domain'])
hypothesis_rows = []
for (sid, hid, dom), group in grouped:
    evidence_list = group[['evidence_category','evidence_source','evidence_detail']].to_dict('records')
    n_evidence = len(group)
    has_defining = any('Caracteristica definidora' in str(e['evidence_category']) for e in evidence_list)
    has_embedding = any('embedding' in str(e['evidence_category']).lower() for e in evidence_list)
    avg_score = group['embedding_score'].mean() if 'embedding_score' in group.columns else None
    
    if has_defining or has_embedding:
        status = 'rule_supported'
    else:
        status = 'candidate'
    
    hypothesis_rows.append({
        'subject_id': int(sid), 'hadm_id': int(hid),
        'nanda_domain': dom,
        'n_evidence': n_evidence,
        'has_defining_characteristic': int(has_defining),
        'has_embedding_evidence': int(has_embedding),
        'avg_embedding_score': round(float(avg_score), 4) if avg_score and not np.isnan(avg_score) else None,
        'inference_method': 'TF-IDF + Cosine Similarity (DeepSeek-v4-Pro assisted)',
        'status': status,
        'limitation': 'Hipotese gerada por similaridade semantica (embeddings). Nao constitui diagnostico de enfermagem confirmado.'
    })

fact_hypothesis = pd.DataFrame(hypothesis_rows)
fact_hypothesis['hypothesis_id'] = range(1, len(fact_hypothesis)+1)
fact_hypothesis.to_sql('fact_nanda_hypothesis', con, index=False)
print(f'  fact_nanda_hypothesis: {len(fact_hypothesis)} hipoteses')
print(f'  Status: {fact_hypothesis["status"].value_counts().to_dict()}')

# =============================================================================
# fact_noc_measurement, fact_nic_observed_proxy, fact_nic_recommended, nnn_linkage_rules
# (mantidos da versao anterior com pequenas adaptacoes)
# =============================================================================
# NOC measurements vinculadas a hipoteses
print('Construindo fact_noc_measurement...')
NANDA_NOC_MAP = {
    'Atividade/Repouso': [('0401','Estado Circulatorio','Pressao Arterial Sistolica','mmHg',[220050,51,442,455,6701,220179]),('0401','Estado Circulatorio','Frequencia Cardiaca','bpm',[220045,211,223761])],
    'Seguranca/Protecao': [('0800','Termorregulacao','Temperatura Corporal','C',[223761,678,223762,676])],
    'Conforto': [('2102','Nivel de Dor','Intensidade da Dor','0-10',[223901,222951,228232,227013,226568,228088])],
    'Percepcao/Cognicao': [('0912','Estado Neurologico','Escala de Coma de Glasgow','score',[223901,228412])],
    'Atividade/Repouso': [('0402','Estado Respiratorio','Saturacao de Oxigenio','%',[220277,646,834,223769])],
}

noc_rows = []
for _, hyp in fact_hypothesis.iterrows():
    if hyp['status'] == 'candidate': continue
    dom = hyp['nanda_domain']
    if dom in NANDA_NOC_MAP:
        for noc_code, noc_label, indicator, unit, itemids in NANDA_NOC_MAP[dom]:
            measurements = ce[(ce['subject_id']==hyp['subject_id'])&(ce['hadm_id']==hyp['hadm_id'])&(ce['itemid'].isin(itemids))]
            if len(measurements)==0: continue
            vals = measurements['valuenum'].dropna()
            if len(vals)==0: continue
            noc_rows.append({
                'hypothesis_id': hyp['hypothesis_id'],'subject_id':int(hyp['subject_id']),'hadm_id':int(hyp['hadm_id']),
                'noc_code':noc_code,'noc_label':noc_label,'indicator':indicator,'unit':unit,
                'baseline_value':float(vals.iloc[0]),'followup_value':float(vals.iloc[-1]),
                'n_measurements':len(vals),'expected_direction':'Avaliar','measurement_window':'Admissao',
                'origin_variable':f'chartevents itemids: {itemids}',
                'limitation':'Indicador operacionalizado a partir de sinais vitais; NAO e resultado NOC documentado por enfermeiro'
            })

fact_noc = pd.DataFrame(noc_rows)
if len(fact_noc)>0:
    fact_noc['noc_measurement_id']=range(1,len(fact_noc)+1)
    fact_noc.to_sql('fact_noc_measurement',con,index=False)
print(f'  fact_noc_measurement: {len(fact_noc)} medicoes')

# NIC proxies
print('Construindo fact_nic_observed_proxy...')
nic_obs=[]
for _,row in emar.dropna(subset=['subject_id','hadm_id']).iterrows():
    nic_obs.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code_proxy':'2300-PROXY','nic_label_proxy':'Administracao de Medicamentos (proxy)','action_detail':f'Medicacao: {row["medication"]}','action_type':'medication','is_nursing_autonomous':0,'limitation':'Registro de administracao nao distingue prescritor'})
for _,row in inp.dropna(subset=['subject_id','hadm_id','stay_id']).iterrows():
    nic_obs.append({'subject_id':int(row['subject_id']),'hadm_id':int(row['hadm_id']),'nic_code_proxy':'4200-PROXY','nic_label_proxy':'Terapia Intravenosa (proxy)','action_detail':f'Fluido IV: {row.get("ordercategoryname","IV")}','action_type':'iv_fluid','is_nursing_autonomous':0,'limitation':'Acao interdisciplinar'})
fact_nic_obs=pd.DataFrame(nic_obs)
fact_nic_obs['observed_id']=range(1,len(fact_nic_obs)+1)
fact_nic_obs.to_sql('fact_nic_observed_proxy',con,index=False)
print(f'  fact_nic_observed_proxy: {len(fact_nic_obs)} proxies')

# NIC recommended + linkage rules
nic_rec=[]
NNN=[
    ('Atividade/Repouso','0401','4040','Cuidados Cardiacos','Monitorizacao hemodinamica','Moorhead et al.,2024;Butcher et al.,2024'),
    ('Seguranca/Protecao','0800','3740','Tratamento da Febre','Monitorizacao de temperatura','Moorhead et al.,2024'),
    ('Conforto','2102','1400','Controle da Dor','Avaliacao e manejo da dor','Moorhead et al.,2024;Butcher et al.,2024'),
    ('Percepcao/Cognicao','0912','6440','Manejo do Delirium','Monitorizacao neurologica','Moorhead et al.,2024'),
    ('Atividade/Repouso','0402','3320','Oxigenoterapia','Administracao de oxigenio','Moorhead et al.,2024'),
]
for _,hyp in fact_hypothesis.iterrows():
    if hyp['status']=='candidate': continue
    for nanda,noc_code,nic_code,nic_label,nic_desc,source in NNN:
        if nanda==hyp['nanda_domain']:
            nic_rec.append({'hypothesis_id':hyp['hypothesis_id'],'subject_id':int(hyp['subject_id']),'hadm_id':int(hyp['hadm_id']),'nanda_label':nanda,'noc_code':noc_code,'nic_code':nic_code,'nic_label':nic_label,'nic_description':nic_desc,'source':source,'confidence_level':'BAIXO','limitation':'Recomendacao derivada de literatura; nao validada no MIMIC-IV'})
fact_nic_rec=pd.DataFrame(nic_rec)
if len(fact_nic_rec)>0:
    fact_nic_rec['recommendation_id']=range(1,len(fact_nic_rec)+1)
    fact_nic_rec.to_sql('fact_nic_recommended',con,index=False)
print(f'  fact_nic_recommended: {len(fact_nic_rec)} recomendacoes')

# linkage rules
linkage_rows=[]
for nanda,noc_code,nic_code,nic_label,nic_desc,source in NNN:
    linkage_rows.append({'nanda_domain':nanda,'noc_code':noc_code,'nic_code':nic_code,'nic_label':nic_label,'rule_description':nic_desc,'source_reference':source,'inference_method':'TF-IDF + Cosine Similarity (DeepSeek-v4-Pro assisted)','confidence_level':'BAIXO','limitation_note':'Regra derivada de literatura; requer validacao clinica'})
nnn_link=pd.DataFrame(linkage_rows)
nnn_link['rule_id']=range(1,len(nnn_link)+1)
nnn_link.to_sql('nnn_linkage_rules',con,index=False)
print(f'  nnn_linkage_rules: {len(nnn_link)} regras')

# dim_nanda_domain
pd.DataFrame({'domain_id':range(1,14),'domain_name':[d[0] for d in NANDA_DOMAINS],'embedding_description':[d[1] for d in NANDA_DOMAINS]}).to_sql('dim_nanda_domain',con,index=False)

con.commit()

# Resumo
print('\n'+'='*65)
print('BANCO RECONSTRUIDO — INFERENCIA POR EMBEDDINGS (TF-IDF)')
print('='*65)
for t in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall():
    n = con.execute(f'SELECT COUNT(*) FROM {t[0]}').fetchone()[0]
    print(f'  {t[0]:35s}: {n:>10,}')

print(f'\nMetodo: TF-IDF + Cosine Similarity (DeepSeek-v4-Pro assisted)')
print(f'ICD descriptions: {len(icd_desc_map)} | ICD-to-NANDA mappings: {len(icd_to_nanda)}')
print(f'Scores: mean={np.mean(best_scores):.3f} median={np.median(best_scores):.3f}')
size_mb = os.path.getsize(DB)/1e6
print(f'Banco: {DB} ({size_mb:.1f} MB)')
con.close()
print('PRONTO.')
