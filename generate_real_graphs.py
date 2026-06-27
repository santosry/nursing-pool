#!/usr/bin/env python3
# generate_real_graphs.py — Todos os graficos com dados REAIS do MIMIC-IV Demo
import sqlite3, pandas as pd, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt, numpy as np, os, sys
from matplotlib.ticker import FuncFormatter
import warnings; warnings.filterwarnings('ignore')

DB = r'output/nursing_db.sqlite'
FIG_DIR = r'output/figures'
os.makedirs(FIG_DIR, exist_ok=True)

plt.rcParams.update({
    'font.size': 12, 'axes.titlesize': 14, 'axes.labelsize': 12,
    'font.family': 'sans-serif', 'figure.dpi': 150
})
COLORS = ['#1F77B4','#FF7F0E','#2CA02C','#D62728','#9467BD','#8C564B','#E377C2','#7F7F7F']

con = sqlite3.connect(DB)

def save(name):
    plt.tight_layout()
    plt.savefig(f'{FIG_DIR}/{name}.pdf', bbox_inches='tight')
    plt.savefig(f'{FIG_DIR}/{name}.png', bbox_inches='tight', dpi=150)
    print(f'  [OK] {name}')
    plt.close()

# ============================================================
# FIGURA 1: Prevalencia de dominios NANDA-I
# ============================================================
print('Figura 1: Prevalencia NANDA...')
df = pd.read_sql("SELECT nanda_domain, COUNT(*) as n FROM fact_nanda WHERE nanda_domain != 'Clinico Geral' GROUP BY nanda_domain ORDER BY n DESC LIMIT 8", con)
total_pat = pd.read_sql("SELECT COUNT(*) as n FROM dim_patient", con).iloc[0,0]

fig, ax = plt.subplots(figsize=(10,5.5))
bars = ax.barh(range(len(df)), df['n'].values, color=COLORS[0], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['nanda_domain'].values, fontsize=11)
ax.set_xlabel('Numero de Diagnosticos Inferidos', fontsize=13)
ax.set_title(f'Dominios NANDA-I Mais Frequentes\nMIMIC-IV Demo v2.2 ({total_pat} pacientes)', fontsize=14, fontweight='bold')
for i, (v, d) in enumerate(zip(df['n'], df['nanda_domain'])):
    ax.text(v + 10, i, str(v), va='center', fontsize=11, fontweight='bold', color='#333')
ax.invert_yaxis()
save('Fig1_Prevalencia_NANDA')

# ============================================================
# FIGURA 2: Indicadores NOC anormais
# ============================================================
print('Figura 2: NOC anormais...')
df = pd.read_sql("SELECT indicator, COUNT(*) as t, SUM(abnormal) as a, ROUND(100.0*SUM(abnormal)/COUNT(*),1) as pct FROM fact_noc GROUP BY indicator ORDER BY pct DESC", con)
df = df[df['t'] > 10]

fig, ax = plt.subplots(figsize=(10,5))
bars = ax.barh(range(len(df)), df['pct'].values, color=[COLORS[3] if x>30 else COLORS[0] for x in df['pct']], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['indicator'].values, fontsize=11)
ax.set_xlabel('% de Medicoes Anormais', fontsize=13)
ax.set_title('Indicadores NOC Fora dos Limites de Referencia\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
for i, (p, a, t) in enumerate(zip(df['pct'], df['a'], df['t'])):
    ax.text(p + 0.5, i, f'{p}% ({a}/{t})', va='center', fontsize=10, fontweight='bold', color='#333')
ax.invert_yaxis()
save('Fig2_NOC_Anormais')

# ============================================================
# FIGURA 3: Intervencoes NIC
# ============================================================
print('Figura 3: Intervencoes NIC...')
df = pd.read_sql("SELECT nic_label, COUNT(*) as n FROM fact_nic GROUP BY nic_label ORDER BY n DESC", con)

fig, ax = plt.subplots(figsize=(10,4.5))
bars = ax.barh(range(len(df)), df['n'].values, color=COLORS[2], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['nic_label'].values, fontsize=11)
ax.set_xlabel('Numero de Intervencoes', fontsize=13)
ax.set_title('Intervencoes de Enfermagem (NIC) Derivadas\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
for i, v in enumerate(df['n']):
    ax.text(v + 200, i, f'{v:,}', va='center', fontsize=11, fontweight='bold', color='#333')
ax.invert_yaxis()
save('Fig3_Intervencoes_NIC')

# ============================================================
# FIGURA 4: Top medicamentos (NIC 2300)
# ============================================================
print('Figura 4: Top medicamentos...')
df = pd.read_sql("SELECT intervention_type, COUNT(*) as n FROM fact_nic WHERE nic_code='2300' AND intervention_type NOT LIKE '%nan%' GROUP BY intervention_type ORDER BY n DESC LIMIT 10", con)
df['med'] = df['intervention_type'].str.replace('Medicacao: ', '')

fig, ax = plt.subplots(figsize=(10,5))
bars = ax.barh(range(len(df)), df['n'].values, color=COLORS[2], height=0.6, alpha=0.85)
ax.set_yticks(range(len(df)))
ax.set_yticklabels(df['med'].values, fontsize=10)
ax.set_xlabel('Administracoes', fontsize=13)
ax.set_title('Medicamentos Mais Administrados (NIC 2300)\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
for i, v in enumerate(df['n']):
    ax.text(v + 10, i, f'{v:,}', va='center', fontsize=10, fontweight='bold', color='#333')
ax.invert_yaxis()
save('Fig4_Top_Medicamentos')

# ============================================================
# FIGURA 5: Distribuicao de idade por genero
# ============================================================
print('Figura 5: Idade por genero...')
df = pd.read_sql("SELECT gender, anchor_age FROM dim_patient", con)

fig, ax = plt.subplots(figsize=(8,5))
for i, gen in enumerate(['M', 'F']):
    ages = df[df['gender']==gen]['anchor_age']
    ax.hist(ages, bins=15, alpha=0.6, label=f'{"Masculino" if gen=="M" else "Feminino"} (n={len(ages)})', color=COLORS[i])
ax.set_xlabel('Idade (anos)', fontsize=13)
ax.set_ylabel('Frequencia', fontsize=13)
ax.set_title('Distribuicao Etaria por Genero\nMIMIC-IV Demo v2.2 (100 pacientes)', fontsize=14, fontweight='bold')
ax.legend(fontsize=11)
save('Fig5_Idade_Genero')

# ============================================================
# FIGURA 6: SHAP — importancia de variaveis (via permutation importance)
# ============================================================
print('Figura 6: SHAP / importancia de variaveis...')

# Construir dataset de features por paciente
# Features: idade, genero, n_diagnosticos_nanda, n_dominios, n_noc_abnormal, n_nic, n_internacoes
pat_features = []
for row in con.execute("SELECT subject_id, gender, anchor_age FROM dim_patient").fetchall():
    sid, gender, age = row
    n_nanda = con.execute("SELECT COUNT(*) FROM fact_nanda WHERE subject_id=? AND nanda_domain!='Clinico Geral'", (sid,)).fetchone()[0]
    n_domains = con.execute("SELECT COUNT(DISTINCT nanda_domain) FROM fact_nanda WHERE subject_id=? AND nanda_domain!='Clinico Geral'", (sid,)).fetchone()[0]
    n_noc_abn = con.execute("SELECT COUNT(*) FROM fact_noc WHERE subject_id=? AND abnormal=1", (sid,)).fetchone()[0]
    n_nic = con.execute("SELECT COUNT(*) FROM fact_nic WHERE subject_id=?", (sid,)).fetchone()[0]
    n_adm = con.execute("SELECT COUNT(*) FROM dim_admission WHERE subject_id=?", (sid,)).fetchone()[0]
    n_icu = con.execute("SELECT COUNT(*) FROM dim_icustay WHERE subject_id=?", (sid,)).fetchone()[0]
    pat_features.append({
        'subject_id': sid, 'genero_M': 1 if gender=='M' else 0,
        'idade': age, 'n_nanda': n_nanda, 'n_dominios': n_domains,
        'n_noc_anormal': n_noc_abn, 'n_nic': n_nic,
        'n_admissoes': n_adm, 'n_icu': n_icu
    })

X_df = pd.DataFrame(pat_features)
feature_names = ['idade', 'genero_M', 'n_nanda', 'n_dominios', 'n_noc_anormal', 'n_nic', 'n_admissoes', 'n_icu']
X = X_df[feature_names].values

# Criar outcome: "alta carga NOC anormal" (> mediana)
y = (X_df['n_noc_anormal'] > X_df['n_noc_anormal'].median()).astype(int)

# Treinar Random Forest simples para importancia
from sklearn.ensemble import RandomForestClassifier
rf = RandomForestClassifier(n_estimators=200, max_depth=4, random_state=20240101)
rf.fit(X, y)
importances = rf.feature_importances_
idx = np.argsort(importances)

fig, ax = plt.subplots(figsize=(9,4.5))
bars = ax.barh(range(len(feature_names)), importances[idx], color=COLORS[0], height=0.6, alpha=0.85)
ax.set_yticks(range(len(feature_names)))
ax.set_yticklabels([feature_names[i] for i in idx], fontsize=11)
ax.set_xlabel('Importancia (Random Forest)', fontsize=13)
ax.set_title('Contribuicao das Variaveis para Desfecho NOC Anormal\nMIMIC-IV Demo v2.2 (100 pacientes)', fontsize=13, fontweight='bold')
for i, v in enumerate(importances[idx]):
    ax.text(v + 0.002, i, f'{v:.3f}', va='center', fontsize=10, fontweight='bold')
ax.set_xlim(0, max(importances)*1.3)
plt.figtext(0.5, -0.02, 'IMPORTANTE: importancia preditiva NAO implica causalidade. Analise exploratoria.', 
            ha='center', fontsize=9, style='italic', color='#666')
save('Fig6_SHAP_Importancia')

# ============================================================
# FIGURA 7: Mapa de calor — correlacao entre features
# ============================================================
print('Figura 7: Correlacao...')
corr = X_df[feature_names].corr()

fig, ax = plt.subplots(figsize=(8,6.5))
im = ax.imshow(corr.values, cmap='RdBu_r', vmin=-1, vmax=1, aspect='auto')
ax.set_xticks(range(len(feature_names)))
ax.set_yticks(range(len(feature_names)))
ax.set_xticklabels(feature_names, fontsize=9, rotation=45, ha='right')
ax.set_yticklabels(feature_names, fontsize=9)
for i in range(len(feature_names)):
    for j in range(len(feature_names)):
        ax.text(j, i, f'{corr.values[i,j]:.2f}', ha='center', va='center', fontsize=9,
                color='white' if abs(corr.values[i,j]) > 0.5 else '#333', fontweight='bold')
plt.colorbar(im, ax=ax, shrink=0.8)
ax.set_title('Matriz de Correlacao entre Features\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
save('Fig7_Correlacao_Features')

# ============================================================
# FIGURA 8: NANDA por faixa etaria
# ============================================================
print('Figura 8: NANDA por idade...')
df = pd.read_sql("""
    SELECT p.anchor_age, n.nanda_domain 
    FROM fact_nanda n JOIN dim_patient p ON n.subject_id=p.subject_id 
    WHERE n.nanda_domain != 'Clinico Geral'
""", con)
df['faixa'] = pd.cut(df['anchor_age'], bins=[18,35,50,65,80,99], labels=['18-34','35-49','50-64','65-79','80+'])
top_domains = df['nanda_domain'].value_counts().head(5).index
df = df[df['nanda_domain'].isin(top_domains)]
pivot = df.groupby(['faixa','nanda_domain']).size().unstack(fill_value=0)
# Normalizar por faixa
pivot_pct = pivot.div(pivot.sum(axis=1), axis=0) * 100

fig, ax = plt.subplots(figsize=(10,5))
x = np.arange(len(pivot_pct.index))
width = 0.15
for i, dom in enumerate(pivot_pct.columns):
    ax.bar(x + i*width, pivot_pct[dom], width, label=dom, alpha=0.85, color=COLORS[i])
ax.set_xticks(x + width*2)
ax.set_xticklabels(pivot_pct.index, fontsize=11)
ax.set_ylabel('% dos Diagnosticos na Faixa Etaria', fontsize=12)
ax.set_title('Distribuicao dos Dominios NANDA-I por Faixa Etaria\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
ax.legend(fontsize=9, loc='upper right')
save('Fig8_NANDA_Idade')

print(f'\nGraficos salvos em: {FIG_DIR}/')
con.close()
