# Modelo Conceitual para Estruturacao de Dados de Enfermagem em SII

## Prova de Conceito Computacional -- Pipeline MIMIC-IV a NANDA/NOC/NIC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-brightgreen.svg)](https://www.r-project.org/)
[![Status: Prova de Conceito](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()
[![renv](https://img.shields.io/badge/renv-138%20packages-blueviolet.svg)](https://rstudio.github.io/renv/)
[![CITATION](https://img.shields.io/badge/CITATION-CFF-yellow.svg)](./CITATION.cff)

> **Aviso**: Este projeto e uma **prova de conceito computacional**. NANDA-I, NIC e NOC sao camadas derivadas por mapeamento exploratorio — **nao sao registros originais do MIMIC-IV**. Nenhum resultado deste pipeline deve ser interpretado como evidencia clinica validada.

> **Modelos de Machine Learning**: Todos os algoritmos implementados (XGBoost, Random Forest, GLM LASSO, Regressao Logistica) tem finalidade **exclusivamente exploratoria e retrospectiva**. Nao ha validacao prospectiva. Os modelos nao devem ser utilizados para predicao clinica. AUC < 0.60 em todos os cenarios testados.

---

## Origem dos Dados

### MIMIC-IV Demo v2.2 (dados reais, acesso livre)

Os dados utilizados neste projeto sao do **MIMIC-IV Clinical Database Demo v2.2**, disponivel publicamente no PhysioNet sem necessidade de credenciamento, curso CITI ou assinatura de Data Use Agreement:

- **URL**: https://physionet.org/content/mimic-iv-demo/2.2/
- **Formato**: Arquivo ZIP contendo diretorios `hosp/` e `icu/` com tabelas em `.csv.gz`
- **Pasta local**: `mimic-iv-clinical-database-demo-2.2/`
- **Conteudo**: 100 pacientes desidentificados, 275 admissoes, 140 estadias em UTI

O download foi realizado diretamente pelo painel "Files" do PhysioNet, selecionando todos os arquivos dos modulos `hosp` e `icu`. O pipeline foi executado com:

```bash
Rscript pipeline.R --mode=real --data_dir=../mimic-iv-clinical-database-demo-2.2
```

**Importante**: O MIMIC-IV nao contem registros nas classificacoes NANDA-I, NIC ou NOC documentados por enfermeiros. O que este projeto faz e construir uma **camada derivada de inferencia computacional** que reorganiza variaveis clinicas existentes (sinais vitais, codigos ICD-10, exames laboratoriais, administracao de medicamentos, fluidos intravenosos) em uma arquitetura relacional orientada pelos dominios dessas classificacoes.

### Dados sumarizados do MIMIC-IV Demo v2.2

| Tabela | Registros | Descricao |
|:---|:---|:---|
| patients | 100 | Dados demograficos (57 M, 43 F, idade media 62 anos) |
| admissions | 275 | Admissoes hospitalares (mortalidade 0%) |
| icustays | 140 | Estadias em UTI |
| chartevents | 668.862 | Sinais vitais e avaliacoes |
| diagnoses_icd | 4.506 | Diagnosticos ICD-10 (1.472 codigos unicos) |
| labevents | 107.727 | Exames laboratoriais |
| emar | 35.835 | Administracoes de medicamentos (470 farmacos) |
| inputevents | 20.404 | Fluidos intravenosos (3.773,5 L) |
| outputevents | 9.362 | Debito urinario (1.319,3 L) |

---

## Objetivo

Propor e demonstrar um **modelo conceitual para estruturacao de dados de enfermagem** em sistemas de informacao em saude, fundamentado em:

- **NANDA-I** (diagnosticos) -- 13 dominios, Taxonomia II
- **NOC** (resultados) -- 7 dominios, 32 classes  
- **NIC** (intervencoes) -- 7 dominios, 30 classes
- **NMDS** (conjunto minimo de dados)
- **HL7 FHIR** / **openEHR** / **SNOMED CT** (interoperabilidade)

Em consonancia com:
- Resolucao COFEN no 736/2024 (Processo de Enfermagem)
- LGPD (Lei no 13.709/2018)

---

## Estrutura do Projeto

```
mimic_nursing_poc/
├── README.md                     # Documentacao
├── LICENSE                       # MIT License
├── CITATION.cff                  # Citacao academica
├── pipeline.R                    # Orquestrador principal (10 etapas)
├── config.R                      # Configuracao de paths, thresholds, ITEM_IDS
├── theme_cellpress.R             # Tema ggplot2 estilo Cell Press
├── synthetic_data.R              # Gerador de dados sinteticos (POC)
├── requirements.R                # Instalacao de dependencias
├── Dockerfile                    # Containerizacao
├── renv.lock                     # Ambiente R reprodutivel (138 pacotes)
│
├── 01_data_access.R              # Carregamento + auditoria de integridade
├── 02_nursing_mapping.R          # Mapeamento NANDA/NOC/NIC para MIMIC-IV
├── 03_nanda_diagnostics.R        # Diagnosticos de Enfermagem NANDA-I
├── 04_noc_outcomes.R             # Resultados de Enfermagem NOC
├── 05_nic_interventions.R        # Intervencoes de Enfermagem NIC
├── 06_nursing_db.R               # Banco SQLite/DuckDB relacional
├── 07_statistical_analysis.R     # Analises estatisticas
├── 08_visualization.R            # Graficos
├── 09_audit.R                    # Auditoria linha a linha
├── 10_benchmark.R                # Benchmarks de performance
├── 11_ml_outcomes.R              # Modelos preditivos (exploratorio)
├── 12_shap_explainability.R      # Explicabilidade SHAP
├── 13_group_contribution.R       # Contribuicao por bloco conceitual
│
├── docs/                         # Documentacao complementar
│   ├── RELATORIO_AUDITORIA_METODOLOGICA.md
│   └── software_versions.md
│
└── output/                       # Resultados (gerado na execucao)
    └── figures/                  # Graficos PDF e PNG
```

---

## Metodologia de Mapeamento

### Estrategia de Inferencia

O MIMIC-IV **nao contem** registros nas classificacoes NANDA-I, NIC ou NOC. O pipeline constroi camadas derivadas por duas vias:

**Via 1: Mapeamento ICD-10 para dominios NANDA-I**

| Prefixo ICD-10 | Dominio NANDA-I | Exemplos |
|:---|:---|:---|
| E40-E46 | Nutricao | Desnutricao |
| I10-I51 | Cardiovascular | Hipertensao, Insuficiencia cardiaca |
| A41, J15-J18 | Seguranca/Protecao | Sepse, Pneumonia |
| N17-N19 | Eliminacao | Insuficiencia renal |
| F05, G93 | Percepcao/Cognicao | Delirium, Encefalopatia |
| R52, M79 | Conforto | Dor |

**Via 2: Inferencia por limiares clinicos**

| Evidencia no MIMIC-IV | Limiar | Diagnostico NANDA-I inferido |
|:---|:---|:---|
| Heart Rate (chartevents) | > 100 bpm | Risco de debito cardiaco diminuido |
| SpO2 (chartevents) | < 92% | Troca de gases prejudicada |
| GCS (chartevents) | <= 8 | Perfusao tissular cerebral ineficaz |
| Braden (omr) | <= 12 | Risco de ulcera por pressao |
| NRS Dor (chartevents) | >= 7 | Dor aguda |
| Temperatura (chartevents) | > 38.0 C | Hipertermia |
| Albumina (labevents) | < 3.5 g/dL | Nutricao desequilibrada |

### Camadas Derivadas

| Camada | Origem no MIMIC-IV | Classificacao |
|:---|:---|:---|
| **NANDA-I** | ICD-10 + sinais vitais anormais + labs alterados + OMR | 13 dominios |
| **NOC** | Sinais vitais seriados + balanco hidrico + escalas | 8 indicadores |
| **NIC** | eMAR + inputevents + procedureevents | 10 categorias |

---

## Execucao

### Modo com dados reais (MIMIC-IV Demo)

```bash
# 1. Baixar MIMIC-IV Demo de https://physionet.org/content/mimic-iv-demo/2.2/
# 2. Extrair ZIP para ../mimic-iv-clinical-database-demo-2.2/
# 3. Executar:
Rscript pipeline.R --mode=real --data_dir=../mimic-iv-clinical-database-demo-2.2
```

### Modo sintetico (demonstracao)

```bash
Rscript pipeline.R --mode=synthetic
```

### Docker

```bash
docker build -t mimic-nursing-poc .
docker run --rm -v $(pwd)/output:/app/output mimic-nursing-poc
```

---

## Resultados com Dados Reais (MIMIC-IV Demo v2.2)

| Metrica | Valor |
|:---|:---|
| Pacientes processados | 100 |
| Admissões | 275 |
| ICU stays | 140 |
| Chartevents processados | 668.862 |
| Diagnósticos ICD-10 | 4.506 (1.472 códigos únicos) |
| Mapeamento ICD-10 a NANDA | 45,3% dos códigos |
| Administracoes de medicamentos | 35.835 (470 fármacos) |
| Fluidos IV | 20.404 eventos (3.773,5 L) |
| Débito urinário | 9.362 eventos (1.319,3 L) |

---

## Analises Implementadas

| Analise | Metodo |
|:---|:---|
| Descritivas com IC 95% | Wilson score interval |
| Teste Chi-quadrado | Pearson + Bonferroni |
| Mann-Whitney U | Wilcoxon rank-sum |
| Correlacao | Spearman |
| Regressao Logistica | GLM binomial + OR + AUC |
| Machine Learning (exploratorio) | XGBoost, Random Forest, GLM LASSO |
| SHAP | fastshap + shapviz |
| Contribuicao por bloco | Permutation importance + |SHAP| |

---

## Transparencia e Uso de IA Generativa

**Declaracao conforme Portaria CNPq no 2.664/2026**

Os autores declaram que foram utilizadas ferramentas de inteligencia artificial
generativa no apoio a concepcao, organizacao metodologica, revisao textual,
depuracao de codigo, geracao de sugestoes de auditoria e melhoria da clareza
do manuscrito e da documentacao computacional. As ferramentas utilizadas foram
ChatGPT 5.5, DeepSeek-v4-Pro e Grok. As ferramentas nao foram indicadas como
autoras, nao substituiram a interpretacao cientifica humana, nao realizaram
coleta independente de dados e nao isentam os autores da responsabilidade
integral pelo conteudo final, pela veracidade das informacoes, pela
originalidade, pelas analises, pelas referencias e por eventuais erros ou
imprecisoes.

---

## Limitacoes Conhecidas

1. **Dados reais limitados**: O MIMIC-IV Demo contem apenas 100 pacientes.
   O MIMIC-IV completo (~350.000 admissoes) requer acesso credenciado via PhysioNet.
2. **Mortalidade zero no Demo**: Nao e possivel realizar analise de desfechos graves
   com a coorte Demo.
3. **Sem validacao clinica**: O mapeamento ICD-10 para NANDA-I nao foi validado por
   especialistas. NENHUM resultado deve ser interpretado como evidencia clinica.
4. **NANDA-I, NIC e NOC nao sao nativos do MIMIC-IV**: Constituem camada derivada
   experimental que necessita validacao externa.
5. **FHIR/openEHR**: Apenas referencial teorico. O pipeline nao implementa APIs.
6. **Terminologias protegidas**: NANDA-I, NIC e NOC sao marcas registradas. Este
   repositorio utiliza apenas identificadores e categorias resumidas de uso permitido.

---

## Licenca

MIT License -- veja [LICENSE](LICENSE) para detalhes.

---

## Citacao

Se usar este pipeline em sua pesquisa:

```
@software{nursing_pool_2026,
  title        = {nursing-pool: Modelo conceitual e prova de conceito computacional
                  para estruturacao de dados de enfermagem em SII com MIMIC-IV},
  year         = {2026},
  url          = {https://github.com/santosry/nursing-pool},
  note         = {Prova de conceito. NAO validado para uso clinico.}
}
```

---

## Auditoria e Status

- **Auditoria metodologica**: [RELATORIO_AUDITORIA_METODOLOGICA.md](docs/RELATORIO_AUDITORIA_METODOLOGICA.md)
- **Compliance**: [compliance_report.md](docs/compliance_report.md) (gerado via `15_compliance_report.R`)
- **Reprodutibilidade**: [reproducibility_report.md](docs/reproducibility_report.md) (gerado via `14_reproducibility_report.R`)
- **Software versions**: [software_versions.md](docs/software_versions.md)

**Status do revisor (Grok, 27/06/2026)**: Aprovado com ressalvas menores. Pronto para submissao apos correcoes minimas.
