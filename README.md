# nursing-pool — Modelo Conceitual para Dados de Enfermagem em SII

## Prova de Conceito Computacional — Camada Derivada NANDA-I/NOC/NIC a partir do MIMIC-IV Demo

**Autores:** Ryan de Paulo Santos, Kerolyne Yngredy Rodrigues Santos

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-brightgreen.svg)](https://www.r-project.org/)
[![Status: Prova de Conceito](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()
[![renv](https://img.shields.io/badge/renv-138%20packages-blueviolet.svg)](https://rstudio.github.io/renv/)
[![CITATION](https://img.shields.io/badge/CITATION-CFF-yellow.svg)](./CITATION.cff)

> **AVISO METODOLÓGICO**: NANDA-I, NOC e NIC não são registros originais do MIMIC-IV. São camadas derivadas por mapeamento exploratório para prova de conceito, sem validação clínica. Nenhuma hipótese deste banco constitui diagnóstico de enfermagem confirmado.

---

## Como Acessar os Dados

### Opção 1 — Página Web SQL (navegador, sem instalação)

Acesse **https://santosry.github.io/nursing-pool/** para consultar o banco com SQL diretamente no navegador. A página carrega as 41 tabelas e oferece botões de exemplos prontos. Nenhuma instalação necessária.

### Opção 2 — Visualizar CSVs (GitHub)

Todos os CSVs estão disponíveis em: https://github.com/santosry/nursing-pool/tree/main/data

Clique em qualquer arquivo `.csv` para visualizar a tabela diretamente no GitHub.

### Opção 3 — Baixar o banco SQLite

O banco SQLite é gerado localmente após execução do pipeline. Para recriá-lo:

```bash
git clone https://github.com/santosry/nursing-pool.git
cd nursing-pool

# Baixar MIMIC-IV Demo de https://physionet.org/content/mimic-iv-demo/2.2/
# Extrair para ../mimic-iv-clinical-database-demo-2.2/

# Gerar camada NANDA-NOC-NIC
python3 rebuild_keywords.py

# Adicionar tabelas clínicas
python3 add_clinical_tables.py
```

Depois abra `output/nursing_db.sqlite` com:
- **Python**: `import sqlite3; con = sqlite3.connect("output/nursing_db.sqlite")`
- **R**: `library(DBI); library(RSQLite); con <- dbConnect(SQLite(), "output/nursing_db.sqlite")`
- **DB Browser for SQLite** (grátis): https://sqlitebrowser.org/

### Opção 4 — Modo sintético R (demonstração)

```bash
Rscript pipeline.R --mode=synthetic
```

---

## Origem dos Dados

### MIMIC-IV Demo v2.2 (dados reais, acesso livre)

- **URL**: https://physionet.org/content/mimic-iv-demo/2.2/
- **Download**: Arquivo ZIP com diretórios `hosp/` e `icu/`, tabelas em `.csv.gz`
- **Conteúdo**: 100 pacientes desidentificados, 275 admissões, 140 estadias em UTI
- **Acesso**: Livre, sem credenciamento, curso CITI ou Data Use Agreement

---

## Arquitetura do Banco (v4.1)

### Fluxo metodológico

```
Variáveis do MIMIC-IV Demo
  -> Palavras-chave médicas + TF-IDF (triagem semântica)
    -> mapping_nanda_evidence (evidências clínicas classificadas)
      -> fact_nanda_hypothesis (hipóteses diagnósticas NANDA-I)
        -> fact_noc_measurement (indicadores NOC vinculados)
          -> fact_nic_observed_proxy (proxies observáveis)
          -> fact_nic_recommended (recomendações por ligação NNN)
            -> nnn_linkage_rules (regras de ligação documentadas)
```

### Tabelas (41 tabelas: 10 de enfermagem + 31 clínicas)

| Tabela | Registros | Função |
|:---|:---|:---|
| `dim_patient` | 100 | Pacientes (57 M, 43 F, idade média 62) |
| `dim_admission` | 275 | Admissões hospitalares |
| `dim_icustay` | 140 | Estadias em UTI |
| `dim_nanda_domain` | 13 | Domínios NANDA-I (Taxonomia II) |
| `mapping_nanda_evidence` | 19.286 | Evidências classificadas (keyword + limiares) |
| `fact_nanda_hypothesis` | 1.646 | Hipóteses diagnósticas (todas rule_supported) |
| `fact_noc_measurement` | 609 | Indicadores NOC vinculados a hipóteses |
| `fact_nic_observed_proxy` | 55.233 | Proxies observáveis (medicamentos, fluidos IV) |
| `fact_nic_recommended` | 491 | Intervenções recomendadas por ligação NNN |
| `nnn_linkage_rules` | 7 | Regras NANDA-NOC-NIC documentadas |

### Tabelas clínicas originais do MIMIC-IV Demo

| Tabela | Registros | Conteúdo |
|:---|:---|:---|
| `chartevents` | 668.862 | Sinais vitais e avaliações |
| `labevents` | 107.727 | Exames laboratoriais |
| `d_labitems` | 1.622 | Referência de exames |
| `microbiologyevents` | 2.899 | Culturas microbiológicas |
| `emar` | 35.835 | Administração de medicamentos |
| `emar_detail` | 72.018 | Detalhes de administração |
| `prescriptions` | 18.087 | Prescrições médicas |
| `pharmacy` | 15.306 | Farmácia |
| `poe` | 45.154 | Ordens médicas (Provider Order Entry) |
| `poe_detail` | 3.795 | Detalhes de ordens |
| `diagnoses_icd` | 4.506 | Diagnósticos ICD-10 |
| `d_icd_diagnoses` | 109.775 | Descrições de diagnósticos ICD |
| `procedures_icd` | 722 | Procedimentos ICD |
| `d_icd_procedures` | 85.257 | Referência de procedimentos |
| `hcpcsevents` | 61 | Eventos HCPCS |
| `d_hcpcs` | 89.200 | Referência HCPCS |
| `drgcodes` | 454 | Códigos DRG |
| `inputevents` | 20.404 | Fluidos intravenosos |
| `outputevents` | 9.362 | Débito urinário |
| `procedureevents` | 1.468 | Procedimentos em UTI |
| `ingredientevents` | 25.728 | Componentes de infusão |
| `datetimeevents` | 15.280 | Eventos com data em UTI |
| `caregiver` | 15.468 | Cuidadores UTI |
| `d_items` | 4.014 | Referência de itens UTI |
| `omr` | 2.964 | Avaliações clínicas (Online Medical Record) |
| `patients` | 100 | Dados originais de pacientes |
| `admissions` | 275 | Dados originais de admissões |
| `icustays` | 140 | Dados originais de UTI |
| `services` | 319 | Serviços hospitalares |
| `transfers` | 1.190 | Transferências |
| `provider` | 40.508 | Profissionais de saúde |

### Resultados principais

| Métrica | Valor |
|:---|:---|
| Hipóteses NANDA-I derivadas | 1.646 (todas rule_supported) |
| Evidências classificadas | 19.286 (keyword rules + limiares) |
| Medições NOC vinculadas | 609 |
| Proxies NIC observáveis | 55.233 |
| Recomendações NIC (NNN) | 491 |
| Cobertura keyword | 59,3% dos códigos ICD |

---

## Metodologia de Mapeamento

### Esclarecimento metodológico fundamental

O MIMIC-IV **não contém** diagnósticos de enfermagem registrados segundo NANDA-I, resultados mensurados segundo NOC ou intervenções codificadas segundo NIC. O MIMIC-IV é um banco de dados clínico centrado no modelo biomédico.

O que este projeto faz é construir uma **camada derivada de inferência computacional** utilizando **palavras-chave médicas + TF-IDF** como mecanismo exploratório de **triagem semântica** para sugerir domínios NANDA-I candidatos. A similaridade textual **não confirma diagnóstico** — apenas ranqueia candidatos. Sinais vitais anormais são usados como características definidoras adicionais. **NENHUM diagnóstico de enfermagem é confirmado.**

### O que NÃO é este projeto

- Não extrai diagnósticos NANDA-I confirmados do MIMIC-IV
- Não identifica intervenções NIC autônomas de enfermagem
- Não mensura resultados NOC documentados por enfermeiros
- Não valida clinicamente nenhuma hipótese
- Não publica conteúdo proprietário integral das taxonomias

---

## Transparência e Uso de IA Generativa

**Declaração conforme Portaria CNPq nº 2.664/2026**

Foram utilizadas ferramentas de inteligência artificial generativa, incluindo
ChatGPT 5.5, DeepSeek-v4-Pro e Grok, para apoio à organização metodológica,
revisão textual, depuração de código, auditoria e inferência de mapeamentos
conceituais entre variáveis clínicas do MIMIC-IV e as terminologias NANDA-I,
NOC e NIC por similaridade semântica. As ferramentas não substituíram a
interpretação científica dos autores, que permanecem integralmente responsáveis
pelo conteúdo final, pela veracidade das informações, pela originalidade,
pelas análises, pelas referências e por eventuais erros ou imprecisões.

---

## Limitações

1. **MIMIC-IV não contém NANDA-I, NOC e NIC nativos**: todas as camadas são derivadas
2. **Hipóteses não validadas**: nenhum registro foi submetido a validação por enfermeiro especialista
3. **Nenhum diagnóstico confirmado**: status "rule_supported" é computacional, não clínico
4. **Proxies NIC**: medicamentos e fluidos IV não distinguem ação médica de ação de enfermagem
5. **Amostra limitada**: 100 pacientes (MIMIC-IV Demo)
6. **Terminologias protegidas**: NANDA-I, NIC e NOC são marcas registradas. Apenas identificadores mínimos e referências bibliográficas são utilizados
7. **Sem interoperabilidade implementada**: FHIR e openEHR são apenas referenciais teóricos
8. **Inferência por similaridade textual**: o mapeamento por palavras-chave e TF-IDF é um mecanismo de triagem, não de diagnóstico

---

## Governança e Compliance

- Dados reais do MIMIC-IV completo NÃO são versionados
- `.gitignore` bloqueia `*.sqlite`, `*.db`, `*.rds`, `*.csv.gz`, `*.parquet`, `mimiciv/`, `physionet/`, `raw/`
- Resumo expandido NÃO é versionado no repositório
- Nenhuma credencial, token ou chave exposta
- `renv.lock` presente (138 pacotes, versões exatas)

---

## Licença

MIT License — veja [LICENSE](LICENSE) para detalhes.

---

## Citação

```bibtex
@software{nursing_pool_2026,
  author       = {Santos, Ryan de Paulo and Santos, Kerolyne Yngredy Rodrigues},
  title        = {nursing-pool: Prova de conceito computacional para estruturação
                  de dados de enfermagem a partir do MIMIC-IV},
  year         = {2026},
  url          = {https://github.com/santosry/nursing-pool},
  note         = {Prova de conceito. Hipóteses NANDA-I/NOC/NIC derivadas. NÃO validado clinicamente.}
}
```
