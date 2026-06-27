# nursing-pool — Modelo Conceitual para Dados de Enfermagem em SII

## Prova de Conceito Computacional — Camada Derivada NANDA-I/NOC/NIC a partir do MIMIC-IV Demo

**Autores:** Ryan de Paulo Santos, Kerolyne Yngredy Rodrigues Santos

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-brightgreen.svg)](https://www.r-project.org/)
[![Status: Prova de Conceito](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()
[![renv](https://img.shields.io/badge/renv-138%20packages-blueviolet.svg)](https://rstudio.github.io/renv/)
[![CITATION](https://img.shields.io/badge/CITATION-CFF-yellow.svg)](./CITATION.cff)

> **AVISO METODOLOGICO**: NANDA-I, NOC e NIC nao sao registros originais do MIMIC-IV. Sao camadas derivadas por mapeamento exploratorio para prova de conceito, sem validacao clinica. Nenhuma hipotese deste banco constitui diagnostico de enfermagem confirmado. Todos os registros requerem validacao por enfermeiro especialista.

> **Modelos de Machine Learning**: Finalidade exclusivamente exploratoria. Desempenho discriminativo proximo ao acaso (AUC < 0,55). Nao utilizar para predicao clinica.

---

## Origem dos Dados

### MIMIC-IV Demo v2.2 (dados reais, acesso livre)

- **URL**: https://physionet.org/content/mimic-iv-demo/2.2/
- **Download**: Arquivo ZIP com diretorios `hosp/` e `icu/`, tabelas em `.csv.gz`
- **Conteudo**: 100 pacientes desidentificados, 275 admissoes, 140 estadias em UTI
- **Acesso**: Livre, sem credenciamento, curso CITI ou Data Use Agreement

### Como acessar o banco de dados

O banco esta em `output/nursing_db.sqlite` (SQLite, 19.7 MB).

**Opcao 1 — Python**:
```python
import sqlite3
con = sqlite3.connect("output/nursing_db.sqlite")
con.execute("SELECT * FROM fact_nanda_hypothesis LIMIT 5").fetchall()
```

**Opcao 2 — R**:
```r
library(DBI); library(RSQLite)
con <- dbConnect(SQLite(), "output/nursing_db.sqlite")
dbGetQuery(con, "SELECT * FROM fact_nanda_hypothesis LIMIT 5")
```

**Opcao 3 — Navegador (GitHub Pages)**:
Acesse https://santosry.github.io/nursing-pool/ para consultar o banco com SQL diretamente no navegador.

**Opcao 4 — DB Browser for SQLite** (gratuito): https://sqlitebrowser.org/

---

## Arquitetura do Banco (v4.0)

### Fluxo metodologico

```
Variaveis MIMIC-IV Demo
  -> mapping_nanda_evidence (evidencias clinicas classificadas)
    -> fact_nanda_hypothesis (hipoteses diagnosticas NANDA-I)
      -> fact_noc_measurement (indicadores NOC vinculados)
        -> fact_nic_observed_proxy (acoes observaveis como proxy)
        -> fact_nic_recommended (recomendacoes por ligacao NNN)
          -> nnn_linkage_rules (regras de ligacao documentadas)
```

### Tabelas (10 tabelas, metodologia correta)

| Tabela | Registros | Funcao |
|:---|:---|:---|
| `dim_patient` | 100 | Pacientes (57 M, 43 F, idade media 62) |
| `dim_admission` | 275 | Admissoes hospitalares |
| `dim_icustay` | 140 | Estadias em UTI |
| `dim_nanda_domain` | 13 | Dominios NANDA-I (Taxonomia II) |
| `mapping_nanda_evidence` | **25.072** | Evidencias classificadas (embeddings + limiares clinicos) |
| `fact_nanda_hypothesis` | **838** | Hipoteses diagnosticas (todas rule_supported) |
| `fact_noc_measurement` | **385** | Indicadores NOC vinculados a hipoteses NANDA |
| `fact_nic_observed_proxy` | **55.233** | Proxies observaveis (medicamentos, fluidos IV) |
| `fact_nic_recommended` | **535** | Intervencoes recomendadas por ligacao NNN |
| `nnn_linkage_rules` | **5** | Regras NANDA-NOC-NIC documentadas com fontes |

### Resultados principais

| Metrica | Valor |
|:---|:---|
| Hipoteses NANDA-I derivadas | 732 (407 rule_supported, 325 candidate) |
| Evidencias classificadas | 15.677 (15.208 caracteristicas definidoras, 469 condicoes associadas) |
| Medicoes NOC vinculadas | 501 (a 4 resultados NOC distintos) |
| Proxies NIC observaveis | 55.233 (medicamentos + fluidos IV) |
| Recomendacoes NIC (NNN) | 310 (7 regras de ligacao) |
| Pacientes com cobertura NNN | 100% |

### Hipoteses NANDA por dominio

| Dominio NANDA-I | Hipoteses |
|:---|:---|
| Atividade/Repouso | 390 |
| Seguranca/Protecao | 145 |
| Nutricao | 93 |
| Eliminacao e Troca | 57 |
| Percepcao/Cognicao | 47 |

---

## Metodologia de Mapeamento

### Esclarecimento metodologico fundamental

O MIMIC-IV **nao contem** diagnosticos de enfermagem registrados segundo NANDA-I, resultados mensurados segundo NOC ou intervencoes codificadas segundo NIC. O MIMIC-IV e um banco de dados clinico centrado no modelo biomedico: codigos ICD-10, sinais vitais, exames laboratoriais, medicamentos administrados e balanco hidrico.

O que este projeto faz e construir uma **camada derivada de inferencia computacional**:

1. **Variaveis do MIMIC-IV** (sinais vitais, ICD-10, exames) sao classificadas como **evidencias parciais** (caracteristicas definidoras, condicoes associadas, fatores de risco)
2. Essas evidencias geram **hipoteses diagnosticas NANDA-I**, nunca diagnosticos confirmados
3. As hipoteses sao vinculadas a **indicadores NOC operacionalizados** a partir de variaveis mensuraveis
4. **Proxies observaveis NIC** (acoes documentadas) e **recomendacoes NIC** (via ligacao NNN) completam a camada

### O que NAO e este projeto

- Nao extrai diagnosticos NANDA-I confirmados do MIMIC-IV
- Nao identifica intervencoes NIC autonomas de enfermagem
- Nao mensura resultados NOC documentados por enfermeiros
- Nao valida clinicamente nenhuma hipotese
- Nao publica conteudo proprietario integral das taxonomias

---

## Como Executar

### Modo com dados reais (MIMIC-IV Demo)
```bash
python3 rebuild_correct.py
```

### Modo sintetico (demonstracao)
```bash
Rscript pipeline.R --mode=synthetic
```

---

## Transparencia e Uso de IA Generativa

**Declaracao conforme Portaria CNPq no 2.664/2026**

Foram utilizadas ferramentas de inteligencia artificial generativa, incluindo
ChatGPT 5.5, DeepSeek-v4-Pro e Grok, para apoio a organizacao metodologica,
revisao textual, depuracao de codigo, auditoria e inferencia de mapeamentos
conceituais entre variaveis clinicas do MIMIC-IV e as terminologias NANDA-I,
NOC e NIC por similaridade semantica. As ferramentas nao substituiram a
interpretacao cientifica dos autores, que permanecem integralmente responsaveis
pelo conteudo final, pela veracidade das informacoes, pela originalidade,
pelas analises, pelas referencias e por eventuais erros ou imprecisoes.

---

## Limitacoes

1. **MIMIC-IV nao contem NANDA-I, NOC e NIC nativos**: todas as camadas sao derivadas
2. **Hipoteses nao validadas**: nenhum registro foi submetido a validacao por enfermeiro especialista
3. **Nenhum diagnostico confirmado**: status "rule_supported" e computacional, nao clinico
4. **Proxies NIC**: medicamentos e fluidos IV nao distinguem acao medica de acao de enfermagem
5. **Amostra limitada**: 100 pacientes (MIMIC-IV Demo)
6. **Terminologias protegidas**: NANDA-I, NIC e NOC sao marcas registradas. Apenas identificadores minimos e referencias bibliograficas sao utilizados
7. **Sem interoperabilidade implementada**: FHIR e openEHR sao apenas referenciais teoricos

---

## Governanca e Compliance

- Dados reais do MIMIC-IV completo NAO sao versionados
- `.gitignore` bloqueia `*.sqlite`, `*.db`, `*.rds`, `*.csv.gz`, `*.parquet`, `mimiciv/`, `physionet/`, `raw/`
- Resumo expandido NAO e versionado no repositorio
- Nenhuma credencial, token ou chave exposta
- `renv.lock` presente (138 pacotes, versoes exatas)

---

## Licenca

MIT License — veja [LICENSE](LICENSE) para detalhes.

---

## Citacao

```bibtex
@software{nursing_pool_2026,
  author       = {Santos, Ryan de Paulo and Santos, Kerolyne Yngredy Rodrigues},
  title        = {nursing-pool: Prova de conceito computacional para estruturacao
                  de dados de enfermagem a partir do MIMIC-IV},
  year         = {2026},
  url          = {https://github.com/santosry/nursing-pool},
  note         = {Prova de conceito. Hipoteses NANDA-I/NOC/NIC derivadas. NAO validado clinicamente.}
}
```
