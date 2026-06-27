#!/usr/bin/env python3
# more_analysis.py — Pirâmide etária + análises estatísticas adicionais
import sqlite3, pandas as pd, numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
import warnings; warnings.filterwarnings('ignore')

DB = 'output/nursing_db.sqlite'
FIG_DIR = 'output/figures'
COLORS = ['#1F77B4','#FF7F0E','#2CA02C','#D62728','#9467BD','#8C564B','#E377C2','#7F7F7F']

con = sqlite3.connect(DB)

def save(name):
    plt.tight_layout()
    plt.savefig(f'{FIG_DIR}/{name}.pdf', bbox_inches='tight')
    plt.savefig(f'{FIG_DIR}/{name}.png', bbox_inches='tight', dpi=150)
    print(f'  [OK] {name}')
    plt.close()

# ============================================================
# FIGURA 5: PIRAMIDE ETARIA (substitui o histograma)
# ============================================================
print('Figura 5: Piramide etaria...')
df = pd.read_sql("SELECT gender, anchor_age FROM dim_patient", con)
df['faixa'] = pd.cut(df['anchor_age'], bins=[18,30,40,50,60,70,80,99], 
                      labels=['18-29','30-39','40-49','50-59','60-69','70-79','80+'])
pivot = df.groupby(['faixa','gender']).size().unstack(fill_value=0)

fig, ax = plt.subplots(figsize=(10,6))
y_pos = range(len(pivot.index))
# Homens para esquerda (negativo)
ax.barh(y_pos, -pivot.get('M', [0]*len(pivot)), height=0.7, color=COLORS[0], alpha=0.85, label='Masculino')
# Mulheres para direita
ax.barh(y_pos, pivot.get('F', [0]*len(pivot)), height=0.7, color=COLORS[3], alpha=0.85, label='Feminino')
ax.set_yticks(y_pos)
ax.set_yticklabels(pivot.index, fontsize=12)
ax.set_xlabel('Numero de Pacientes', fontsize=13)
ax.set_title('Piramide Etaria da Coorte\nMIMIC-IV Demo v2.2 (100 pacientes)', fontsize=14, fontweight='bold')
ax.legend(fontsize=12, loc='lower right')
# Adicionar valores nas barras
for i, (m, f) in enumerate(zip(pivot.get('M',[0]*len(pivot)), pivot.get('F',[0]*len(pivot)))):
    if m > 0: ax.text(-m-0.5, i, str(m), va='center', ha='right', fontsize=11, fontweight='bold', color=COLORS[0])
    if f > 0: ax.text(f+0.3, i, str(f), va='center', ha='left', fontsize=11, fontweight='bold', color=COLORS[3])
ax.axvline(x=0, color='#333', linewidth=0.8)
max_val = max(pivot.max().max(), 1)
ax.set_xlim(-max_val*1.4, max_val*1.4)
# Remover ticks negativos do eixo x
ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: str(abs(int(x)))))
save('Fig5_Piramide_Etaria')

# ============================================================
# ANÁLISE 1: Teste qui-quadrado — gênero vs domínios NANDA
# ============================================================
print('\n=== ANALISE 1: Qui-quadrado Genero vs Dominios NANDA ===')
df_nanda = pd.read_sql("""
    SELECT p.gender, n.nanda_domain 
    FROM fact_nanda n JOIN dim_patient p ON n.subject_id=p.subject_id
    WHERE n.nanda_domain != 'Clinico Geral'
""", con)
top_domains = df_nanda['nanda_domain'].value_counts().head(6).index
results_chi = []
for dom in top_domains:
    has_dom = df_nanda['nanda_domain'] == dom
    male_has = ((df_nanda['gender']=='M') & has_dom).sum()
    female_has = ((df_nanda['gender']=='F') & has_dom).sum()
    male_total = (df_nanda['gender']=='M').sum()
    female_total = (df_nanda['gender']=='F').sum()
    table = [[male_has, male_total-male_has], [female_has, female_total-female_has]]
    chi2, p, dof, _ = stats.chi2_contingency(table)
    results_chi.append({'Dominio': dom, 'Masc_%': round(100*male_has/male_total,1), 
                        'Fem_%': round(100*female_has/female_total,1), 'Chi2': round(chi2,2), 'p': round(p,4)})
    
chi_df = pd.DataFrame(results_chi)
chi_df['p_ajustado'] = np.minimum(1, chi_df['p'] * len(chi_df))
chi_df['Significativo'] = chi_df['p_ajustado'] < 0.05
print(chi_df.to_string(index=False))

# ============================================================
# ANALISE 2: Mann-Whitney — idade vs presenca de dominios NANDA
# ============================================================
print('\n=== ANALISE 2: Mann-Whitney — Idade vs Presenca de Dominios ===')

# Construir dicionario paciente -> set de dominios
df_nanda_simple = pd.read_sql("SELECT subject_id, nanda_domain FROM fact_nanda WHERE nanda_domain != 'Clinico Geral'", con)
pat_domain_dict = {}
for _, row in df_nanda_simple.iterrows():
    sid = int(row['subject_id'])
    if sid not in pat_domain_dict:
        pat_domain_dict[sid] = set()
    pat_domain_dict[sid].add(str(row['nanda_domain']))

df_pat = pd.read_sql("SELECT subject_id, anchor_age, gender FROM dim_patient", con)

for dom in ['Cardiovascular', 'Percepcao/Cognicao', 'Seguranca/Protecao']:
    has_ids = [sid for sid, doms in pat_domain_dict.items() if dom in doms]
    no_ids = [sid for sid in df_pat['subject_id'] if sid not in has_ids]
    ages_has = df_pat[df_pat['subject_id'].isin(has_ids)]['anchor_age']
    ages_no = df_pat[df_pat['subject_id'].isin(no_ids)]['anchor_age']
    if len(ages_has) > 5 and len(ages_no) > 5:
        u, p = stats.mannwhitneyu(ages_has, ages_no, alternative='two-sided')
        print(f'  {dom}: idade media COM={ages_has.mean():.0f} vs SEM={ages_no.mean():.0f} | U={u:.0f} p={p:.4f}')

# ============================================================
# ANÁLISE 3: Correlação Spearman — features numéricas
# ============================================================
print('\n=== ANALISE 3: Correlacao de Spearman ===')
# Construir features por paciente
features = []
for row in con.execute("SELECT subject_id, anchor_age FROM dim_patient").fetchall():
    sid, age = row
    n_nanda = con.execute("SELECT COUNT(*) FROM fact_nanda WHERE subject_id=? AND nanda_domain!='Clinico Geral'", (sid,)).fetchone()[0]
    n_dom = con.execute("SELECT COUNT(DISTINCT nanda_domain) FROM fact_nanda WHERE subject_id=?", (sid,)).fetchone()[0]
    n_noc = con.execute("SELECT COUNT(*) FROM fact_noc WHERE subject_id=?", (sid,)).fetchone()[0]
    n_noc_abn = con.execute("SELECT COUNT(*) FROM fact_noc WHERE subject_id=? AND abnormal=1", (sid,)).fetchone()[0]
    n_nic = con.execute("SELECT COUNT(*) FROM fact_nic WHERE subject_id=?", (sid,)).fetchone()[0]
    n_adm = con.execute("SELECT COUNT(*) FROM dim_admission WHERE subject_id=?", (sid,)).fetchone()[0]
    n_icu = con.execute("SELECT COUNT(*) FROM dim_icustay WHERE subject_id=?", (sid,)).fetchone()[0]
    features.append({'sid':sid,'idade':age,'n_nanda':n_nanda,'n_dominios':n_dom,
                     'n_noc':n_noc,'n_noc_abn':n_noc_abn,'n_nic':n_nic,
                     'n_admissoes':n_adm,'n_icu':n_icu})

feat_df = pd.DataFrame(features)
feat_cols = ['idade','n_nanda','n_dominios','n_noc','n_noc_abn','n_nic','n_admissoes','n_icu']
print('Correlacao de Spearman:')
for c1 in feat_cols:
    for c2 in feat_cols:
        if c1 < c2:
            rho, p = stats.spearmanr(feat_df[c1], feat_df[c2])
            if abs(rho) > 0.3:
                print(f'  {c1} x {c2}: rho={rho:.3f} p={p:.4f} {"***" if p<0.001 else "**" if p<0.01 else "*" if p<0.05 else ""}')

# ============================================================
# ANÁLISE 4: Kruskal-Wallis — NOC anormal por faixa etária
# ============================================================
print('\n=== ANALISE 4: Kruskal-Wallis — Carga NOC anormal por faixa etaria ===')
feat_df['faixa'] = pd.cut(feat_df['idade'], bins=[18,35,50,65,80,99], 
                           labels=['18-34','35-49','50-64','65-79','80+'])
groups = [feat_df[feat_df['faixa']==f]['n_noc_abn'].values for f in feat_df['faixa'].cat.categories]
h, p = stats.kruskal(*groups)
print(f'  Kruskal-Wallis: H={h:.2f} p={p:.4f}')
for f in feat_df['faixa'].cat.categories:
    vals = feat_df[feat_df['faixa']==f]['n_noc_abn']
    print(f'  {f}: media={vals.mean():.0f} mediana={vals.median():.0f} n={len(vals)}')

# ============================================================
# ANÁLISE 5: Top diagnosticos NANDA por faixa etaria
# ============================================================
print('\n=== ANALISE 5: Top diagnosticos por faixa etaria ===')
df_nanda2 = pd.read_sql("""
    SELECT p.anchor_age, n.nanda_domain, n.nanda_label
    FROM fact_nanda n JOIN dim_patient p ON n.subject_id=p.subject_id
    WHERE n.nanda_domain != 'Clinico Geral'
""", con)
df_nanda2['faixa'] = pd.cut(df_nanda2['anchor_age'], bins=[18,35,50,65,80,99],
                             labels=['18-34','35-49','50-64','65-79','80+'])
for faixa in ['18-34','35-49','50-64','65-79','80+']:
    subset = df_nanda2[df_nanda2['faixa']==faixa]
    top = subset['nanda_label'].value_counts().head(3)
    print(f'  {faixa}: {", ".join([f"{k}({v})" for k,v in top.items()])}')

# ============================================================
# FIGURA: Boxplot — carga NOC anormal por faixa etaria
# ============================================================
print('\nFigura: Boxplot NOC anormal por faixa...')
fig, ax = plt.subplots(figsize=(8,5))
data_by_faixa = [feat_df[feat_df['faixa']==f]['n_noc_abn'].values for f in feat_df['faixa'].cat.categories]
bp = ax.boxplot(data_by_faixa, patch_artist=True)
ax.set_xticklabels(feat_df['faixa'].cat.categories, fontsize=11)
for patch, color in zip(bp['boxes'], COLORS[:len(data_by_faixa)]):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)
ax.set_xlabel('Faixa Etaria', fontsize=13)
ax.set_ylabel('Numero de Indicadores NOC Anormais', fontsize=13)
ax.set_title('Carga de Anormalidade NOC por Faixa Etaria\nMIMIC-IV Demo v2.2', fontsize=14, fontweight='bold')
save('Fig9_NOC_Anormal_Idade')

# ============================================================
# FIGURA: Radar/Spider — perfil NANDA por genero
# ============================================================
print('Figura: Perfil NANDA por genero...')
pivot_gen = df_nanda.groupby(['gender','nanda_domain']).size().unstack(fill_value=0)
# Normalizar por genero
pivot_pct = pivot_gen.div(pivot_gen.sum(axis=1), axis=0) * 100
top6 = pivot_pct.max().nlargest(6).index
pivot_radar = pivot_pct[top6]

angles = np.linspace(0, 2*np.pi, len(top6), endpoint=False).tolist()
angles += angles[:1]  # Fechar

fig, ax = plt.subplots(figsize=(7,7), subplot_kw=dict(polar=True))
for gen, color, label in [('M', COLORS[0], 'Masculino'), ('F', COLORS[3], 'Feminino')]:
    values = pivot_radar.loc[gen].values.tolist()
    values += values[:1]
    ax.fill(angles, values, alpha=0.25, color=color)
    ax.plot(angles, values, color=color, linewidth=2, label=label)

ax.set_xticks(angles[:-1])
ax.set_xticklabels(top6, fontsize=10)
ax.set_title('Perfil de Dominios NANDA-I por Genero\n(% dos diagnosticos de cada grupo)', fontsize=13, fontweight='bold', pad=20)
ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
save('Fig10_Radar_NANDA_Genero')

print('\n=== RESUMO ESTATISTICO ===')
print(f'Pacientes: {len(feat_df)}')
print(f'Idade: media={feat_df["idade"].mean():.0f} dp={feat_df["idade"].std():.0f} mediana={feat_df["idade"].median():.0f}')
print(f'NANDA/paciente: media={feat_df["n_nanda"].mean():.0f} dp={feat_df["n_nanda"].std():.0f}')
print(f'NIC/paciente: media={feat_df["n_nic"].mean():.0f} dp={feat_df["n_nic"].std():.0f}')
print(f'NOC anormal/paciente: media={feat_df["n_noc_abn"].mean():.0f} dp={feat_df["n_noc_abn"].std():.0f}')

# Salvar analises em CSV
chi_df.to_csv('output/analise_chi2_genero.csv', index=False)
feat_df.to_csv('output/analise_features_pacientes.csv', index=False)

con.close()
print('\nTabelas salvas em output/')
