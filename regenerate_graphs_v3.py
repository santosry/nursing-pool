#!/usr/bin/env python3
# regenerate_graphs_v3.py — Graficos atualizados com dominios NANDA Taxonomia II
import sqlite3, pandas as pd, numpy as np
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
import warnings; warnings.filterwarnings('ignore')

DB = 'output/nursing_db.sqlite'
FIG_DIR = 'output/figures'
COLORS = ['#1F77B4','#FF7F0E','#2CA02C','#D62728','#9467BD','#8C564B','#E377C2','#7F7F7F']

con = sqlite3.connect(DB)
plt.rcParams.update({'font.size': 12, 'axes.titlesize': 14, 'axes.labelsize': 12, 'font.family': 'sans-serif', 'figure.dpi': 150})

def save(name):
    plt.tight_layout()
    plt.savefig(f'{FIG_DIR}/{name}.pdf', bbox_inches='tight')
    plt.savefig(f'{FIG_DIR}/{name}.png', bbox_inches='tight', dpi=150)
    print(f'  [OK] {name}')
    plt.close()

# FIG 1: Prevalencia dominios NANDA (Taxonomia II)
print('Fig1: Prevalencia NANDA...')
df = pd.read_sql("SELECT nanda_domain, COUNT(*) as n FROM fact_nanda GROUP BY nanda_domain ORDER BY n DESC LIMIT 10", con)
fig, ax = plt.subplots(figsize=(10,5.5))
ax.barh(range(len(df)), df['n'].values, color=COLORS[0], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['nanda_domain'].values, fontsize=11)
ax.set_xlabel('Diagnosticos Inferidos', fontsize=13)
ax.set_title('Dominios NANDA-I Mais Frequentes (Taxonomia II)\nMIMIC-IV Demo v2.2 — 100 pacientes', fontsize=14, fontweight='bold')
for i, (v, d) in enumerate(zip(df['n'], df['nanda_domain'])):
    ax.text(v+10, i, str(v), va='center', fontsize=11, fontweight='bold', color='#333')
ax.invert_yaxis()
save('Fig1_Prevalencia_NANDA')

# FIG 2: NOC anormais
print('Fig2: NOC...')
df = pd.read_sql("SELECT indicator, COUNT(*) as t, SUM(abnormal) as a, ROUND(100.0*SUM(abnormal)/COUNT(*),1) as pct FROM fact_noc GROUP BY indicator ORDER BY pct DESC", con)
df = df[df['t']>10]
fig, ax = plt.subplots(figsize=(10,5))
colors_bar = [COLORS[3] if x>30 else COLORS[0] for x in df['pct']]
ax.barh(range(len(df)), df['pct'].values, color=colors_bar, height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['indicator'].values, fontsize=11)
ax.set_xlabel('% Medicoes Anormais', fontsize=13)
ax.set_title('Indicadores NOC Fora dos Limites de Referencia', fontsize=14, fontweight='bold')
for i, (p, a, t) in enumerate(zip(df['pct'], df['a'], df['t'])):
    ax.text(p+0.5, i, f'{p}% ({a}/{t})', va='center', fontsize=10, fontweight='bold')
ax.invert_yaxis()
save('Fig2_NOC_Anormais')

# FIG 3: NIC
print('Fig3: NIC...')
df = pd.read_sql("SELECT nic_label, COUNT(*) as n FROM fact_nic GROUP BY nic_label ORDER BY n DESC", con)
fig, ax = plt.subplots(figsize=(10,4.5))
ax.barh(range(len(df)), df['n'].values, color=COLORS[2], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['nic_label'].values, fontsize=11)
ax.set_xlabel('Intervencoes', fontsize=13)
ax.set_title('Intervencoes NIC Derivadas', fontsize=14, fontweight='bold')
for i, v in enumerate(df['n']):
    ax.text(v+200, i, f'{v:,}', va='center', fontsize=11, fontweight='bold')
ax.invert_yaxis()
save('Fig3_Intervencoes_NIC')

# FIG 4: Top medicamentos
print('Fig4: Medicamentos...')
df = pd.read_sql("SELECT intervention_type, COUNT(*) as n FROM fact_nic WHERE nic_code='2300' AND intervention_type NOT LIKE '%nan%' GROUP BY intervention_type ORDER BY n DESC LIMIT 10", con)
df['med'] = df['intervention_type'].str.replace('Medicacao: ', '')
fig, ax = plt.subplots(figsize=(10,5))
ax.barh(range(len(df)), df['n'].values, color=COLORS[2], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['med'].values, fontsize=10)
ax.set_xlabel('Administracoes', fontsize=13)
ax.set_title('Medicamentos Mais Administrados (NIC 2300)', fontsize=14, fontweight='bold')
for i, v in enumerate(df['n']):
    ax.text(v+10, i, f'{v:,}', va='center', fontsize=10, fontweight='bold')
ax.invert_yaxis()
save('Fig4_Top_Medicamentos')

# FIG 5: Piramide etaria 
print('Fig5: Piramide...')
df = pd.read_sql("SELECT gender, anchor_age FROM dim_patient", con)
df['faixa'] = pd.cut(df['anchor_age'], bins=[18,30,40,50,60,70,80,99], labels=['18-29','30-39','40-49','50-59','60-69','70-79','80+'])
pivot = df.groupby(['faixa','gender']).size().unstack(fill_value=0)
fig, ax = plt.subplots(figsize=(10,6))
y_pos = range(len(pivot.index))
ax.barh(y_pos, -pivot.get('M',[0]*len(pivot)), height=0.7, color=COLORS[0], alpha=0.85, label='Masculino')
ax.barh(y_pos, pivot.get('F',[0]*len(pivot)), height=0.7, color=COLORS[3], alpha=0.85, label='Feminino')
ax.set_yticks(y_pos)
ax.set_yticklabels(pivot.index, fontsize=12)
ax.set_xlabel('Numero de Pacientes', fontsize=13)
ax.set_title('Piramide Etaria — MIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
ax.legend(fontsize=12, loc='lower right')
for i, (m, f) in enumerate(zip(pivot.get('M',[0]*len(pivot)), pivot.get('F',[0]*len(pivot)))):
    if m>0: ax.text(-m-0.5, i, str(m), va='center', ha='right', fontsize=11, fontweight='bold', color=COLORS[0])
    if f>0: ax.text(f+0.3, i, str(f), va='center', ha='left', fontsize=11, fontweight='bold', color=COLORS[3])
ax.axvline(x=0, color='#333', linewidth=0.8)
max_val = max(pivot.max().max(), 1)
ax.set_xlim(-max_val*1.4, max_val*1.4)
ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: str(abs(int(x)))))
save('Fig5_Piramide_Etaria')

# FIG 6: SHAP/Importancia (Random Forest)
print('Fig6: Importancia...')
query = """
SELECT p.subject_id, p.gender, p.anchor_age,
  (SELECT COUNT(*) FROM fact_nanda WHERE subject_id=p.subject_id) as n_nanda,
  (SELECT COUNT(DISTINCT nanda_domain) FROM fact_nanda WHERE subject_id=p.subject_id) as n_dominios,
  (SELECT COUNT(*) FROM fact_noc WHERE subject_id=p.subject_id AND abnormal=1) as n_noc_abn,
  (SELECT COUNT(*) FROM fact_nic WHERE subject_id=p.subject_id) as n_nic,
  (SELECT COUNT(*) FROM dim_admission WHERE subject_id=p.subject_id) as n_adm,
  (SELECT COUNT(*) FROM dim_icustay WHERE subject_id=p.subject_id) as n_icu
FROM dim_patient p
"""
feat_df = pd.read_sql(query, con)
feat_df['genero_M'] = (feat_df['gender']=='M').astype(int)
feat_cols = ['anchor_age','genero_M','n_nanda','n_dominios','n_noc_abn','n_nic','n_adm','n_icu']
X = feat_df[feat_cols].values
y = (feat_df['n_noc_abn'] > feat_df['n_noc_abn'].median()).astype(int)

from sklearn.ensemble import RandomForestClassifier
rf = RandomForestClassifier(n_estimators=200, max_depth=4, random_state=20240101)
rf.fit(X, y)
importances = rf.feature_importances_
idx = np.argsort(importances)

fig, ax = plt.subplots(figsize=(9,4.5))
ax.barh(range(len(feat_cols)), importances[idx], color=COLORS[0], height=0.6, alpha=0.85)
ax.set_yticks(range(len(feat_cols)))
ax.set_yticklabels([feat_cols[i] for i in idx], fontsize=11)
ax.set_xlabel('Importancia (Random Forest)', fontsize=13)
ax.set_title('Contribuicao das Variaveis — Desfecho NOC Anormal', fontsize=13, fontweight='bold')
for i, v in enumerate(importances[idx]):
    ax.text(v+0.002, i, f'{v:.3f}', va='center', fontsize=10, fontweight='bold')
ax.set_xlim(0, max(importances)*1.3)
plt.figtext(0.5, -0.02, 'IMPORTANTE: importancia preditiva NAO implica causalidade. Analise exploratoria.', ha='center', fontsize=9, style='italic', color='#666')
save('Fig6_SHAP_Importancia')

# FIG 7: NANDA por classe e dominio (heatmap simplificado)
print('Fig7: Heatmap NANDA dominio x classe...')
df_hm = pd.read_sql("SELECT nanda_domain, nanda_class, COUNT(*) as n FROM fact_nanda GROUP BY nanda_domain, nanda_class ORDER BY n DESC", con)
top_domains = df_hm.groupby('nanda_domain')['n'].sum().nlargest(6).index
df_hm = df_hm[df_hm['nanda_domain'].isin(top_domains)]
pivot_hm = df_hm.pivot_table(values='n', index='nanda_domain', columns='nanda_class', fill_value=0)

fig, ax = plt.subplots(figsize=(12,5))
im = ax.imshow(pivot_hm.values, cmap='Blues', aspect='auto')
ax.set_xticks(range(len(pivot_hm.columns)))
ax.set_yticks(range(len(pivot_hm.index)))
ax.set_xticklabels(pivot_hm.columns, fontsize=9, rotation=45, ha='right')
ax.set_yticklabels(pivot_hm.index, fontsize=11)
for i in range(len(pivot_hm.index)):
    for j in range(len(pivot_hm.columns)):
        v = pivot_hm.values[i,j]
        if v > 0:
            ax.text(j, i, str(int(v)), ha='center', va='center', fontsize=9, fontweight='bold',
                    color='white' if v > pivot_hm.values.max()/2 else '#333')
plt.colorbar(im, ax=ax, shrink=0.8)
ax.set_title('Diagnosticos NANDA-I por Dominio e Classe (Taxonomia II)', fontsize=14, fontweight='bold')
save('Fig7_NANDA_Dominio_Classe')

# FIG 8: NANDA por faixa etaria (substitui o radar)
print('Fig8: NANDA por idade...')
df_n = pd.read_sql("""
SELECT p.anchor_age, n.nanda_domain FROM fact_nanda n JOIN dim_patient p ON n.subject_id=p.subject_id
""", con)
df_n['faixa'] = pd.cut(df_n['anchor_age'], bins=[18,35,50,65,80,99], labels=['18-34','35-49','50-64','65-79','80+'])
top5 = df_n['nanda_domain'].value_counts().head(5).index
df_n = df_n[df_n['nanda_domain'].isin(top5)]
pivot_age = df_n.groupby(['faixa','nanda_domain']).size().unstack(fill_value=0)
pivot_pct = pivot_age.div(pivot_age.sum(axis=1), axis=0)*100

fig, ax = plt.subplots(figsize=(10,5))
x = np.arange(len(pivot_pct.index))
width = 0.15
for i, dom in enumerate(pivot_pct.columns):
    ax.bar(x+i*width, pivot_pct[dom], width, label=dom, alpha=0.85, color=COLORS[i%8])
ax.set_xticks(x+width*2)
ax.set_xticklabels(pivot_pct.index, fontsize=11)
ax.set_ylabel('% dos Diagnosticos na Faixa', fontsize=12)
ax.set_title('Distribuicao dos Dominios NANDA-I por Faixa Etaria', fontsize=14, fontweight='bold')
ax.legend(fontsize=8, loc='upper right')
save('Fig8_NANDA_Idade')

# FIG 9: Boxplot NOC anormal por faixa
print('Fig9: Boxplot NOC...')
feat_df['faixa'] = pd.cut(feat_df['anchor_age'], bins=[18,35,50,65,80,99], labels=['18-34','35-49','50-64','65-79','80+'])
data_by_faixa = [feat_df[feat_df['faixa']==f]['n_noc_abn'].values for f in feat_df['faixa'].cat.categories]
fig, ax = plt.subplots(figsize=(8,5))
bp = ax.boxplot(data_by_faixa, patch_artist=True)
ax.set_xticklabels(feat_df['faixa'].cat.categories, fontsize=11)
for patch, color in zip(bp['boxes'], COLORS[:len(data_by_faixa)]):
    patch.set_facecolor(color); patch.set_alpha(0.7)
ax.set_xlabel('Faixa Etaria', fontsize=13)
ax.set_ylabel('Indicadores NOC Anormais', fontsize=13)
ax.set_title('Carga de Anormalidade NOC por Faixa Etaria', fontsize=14, fontweight='bold')
save('Fig9_NOC_Anormal_Idade')

# FIG 10: Barras agrupadas — Top diagnosticos NANDA por genero
print('Fig10: NANDA por genero...')
df_gen = pd.read_sql("""
SELECT p.gender, n.nanda_domain, n.nanda_label FROM fact_nanda n JOIN dim_patient p ON n.subject_id=p.subject_id
""", con)
top_dom = df_gen['nanda_domain'].value_counts().head(6).index
df_gen = df_gen[df_gen['nanda_domain'].isin(top_dom)]
pivot_gen = df_gen.groupby(['nanda_domain','gender']).size().unstack(fill_value=0)
# Normalizar
pivot_norm = pivot_gen.div(pivot_gen.sum(axis=1), axis=0)*100

fig, ax = plt.subplots(figsize=(10,5))
x = np.arange(len(pivot_norm.index))
w = 0.35
ax.bar(x-w/2, pivot_norm.get('M',[0]*len(pivot_norm)), w, label='Masculino', color=COLORS[0], alpha=0.85)
ax.bar(x+w/2, pivot_norm.get('F',[0]*len(pivot_norm)), w, label='Feminino', color=COLORS[3], alpha=0.85)
ax.set_xticks(x)
ax.set_xticklabels(pivot_norm.index, fontsize=10, rotation=20, ha='right')
ax.set_ylabel('% dos Diagnosticos', fontsize=13)
ax.set_title('Distribuicao dos Dominios NANDA-I por Genero', fontsize=14, fontweight='bold')
ax.legend(fontsize=12)
for i in range(len(pivot_norm)):
    m = pivot_norm.get('M',[0]*len(pivot_norm)).iloc[i] if 'M' in pivot_norm.columns else 0
    f = pivot_norm.get('F',[0]*len(pivot_norm)).iloc[i] if 'F' in pivot_norm.columns else 0
    if m > 0: ax.text(i-w/2, m+1, f'{m:.0f}%', ha='center', fontsize=9, fontweight='bold')
    if f > 0: ax.text(i+w/2, f+1, f'{f:.0f}%', ha='center', fontsize=9, fontweight='bold')
save('Fig10_NANDA_Genero')

# Resumo
df_resumo = pd.read_sql("""
SELECT 
  (SELECT COUNT(*) FROM dim_patient) as pacientes,
  (SELECT COUNT(*) FROM fact_nanda) as nanda,
  (SELECT COUNT(*) FROM fact_noc) as noc,
  (SELECT COUNT(*) FROM fact_nic) as nic,
  (SELECT COUNT(DISTINCT nanda_domain) FROM fact_nanda) as dominios,
  (SELECT COUNT(DISTINCT nanda_class) FROM fact_nanda) as classes
""", con)
print(f"\nGraficos gerados: {len([f for f in __import__('os').listdir(FIG_DIR) if f.endswith('.pdf')])} PDFs")
con.close()
