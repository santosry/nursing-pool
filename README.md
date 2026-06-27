# Modelo Conceitual para Estruturação de Dados de Enfermagem em SII

## Prova de Conceito Computacional -- Pipeline MIMIC-IV para NANDA/NOC/NIC

**Autores:** Ryan de Paulo Santos, Kerolyne Yngredy Rodrigues Santos

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-brightgreen.svg)](https://www.r-project.org/)
[![Status: Prova de Conceito](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()
[![renv](https://img.shields.io/badge/renv-138%20packages-blueviolet.svg)](https://rstudio.github.io/renv/)
[![CITATION](https://img.shields.io/badge/CITATION-CFF-yellow.svg)](./CITATION.cff)

> **Aviso**: Este projeto é uma **prova de conceito computacional**. NANDA-I, NIC e NOC são camadas derivadas por mapeamento exploratório -- **não são registros originais do MIMIC-IV**. Nenhum resultado deste pipeline deve ser interpretado como evidência clínica validada.

> **Modelos de Machine Learning**: Todos os algoritmos implementados têm finalidade **exclusivamente exploratória e retrospectiva**. Não há validação prospectiva. Os modelos não devem ser utilizados para predição clínica.

---

## Origem dos Dados

### MIMIC-IV Demo v2.2 (dados reais, acesso livre)

Os dados utilizados são do **MIMIC-IV Clinical Database Demo v2.2**, disponível publicamente no PhysioNet sem necessidade de credenciamento, curso CITI ou assinatura de Data Use Agreement:

- **URL**: https://physionet.org/content/mimic-iv-demo/2.2/
- **Formato**: Arquivo ZIP contendo diretórios `hosp/` e `icu/` com tabelas em `.csv.gz`
- **Pasta local**: `mimic-iv-clinical-database-demo-2.2/`
- **Conteúdo**: 100 pacientes desidentificados, 275 admissões, 140 estadias em UTI

O download foi realizado diretamente pelo painel "Files" do PhysioNet, selecionando todos os arquivos dos módulos `hosp` e `icu` no formato ZIP. O banco de dados SQLite resultante está disponível neste repositório em `output/nursing_db.sqlite`.

**Importante**: O MIMIC-IV não contém registros nas classificações NANDA-I, NIC ou NOC documentados por enfermeiros. O que este projeto faz é construir uma **camada derivada de inferência computacional** que reorganiza variáveis clínicas existentes (sinais vitais, códigos ICD-10, exames laboratoriais, administração de medicamentos, fluidos intravenosos) em uma arquitetura relacional orientada pelos domínios dessas classificações.

### Como acessar o banco de dados

O banco está em `output/nursing_db.sqlite` (SQLite, 19.8 MB). NÃO é necessário baixar nenhum software adicional nem criar conta:

**Opção 1 -- Python** (já instalado no seu computador):
```python
import sqlite3
con = sqlite3.connect("output/nursing_db.sqlite")
con.execute("SELECT * FROM fact_nanda LIMIT 5").fetchall()
```

**Opção 2 -- R** (já instalado no seu computador):
```r
library(DBI); library(RSQLite)
con <- dbConnect(SQLite(), "output/nursing_db.sqlite")
dbGetQuery(con, "SELECT * FROM fact_nanda LIMIT 5")
```

**Opção 3 -- DB Browser for SQLite** (grátis, interface gráfica):
https://sqlitebrowser.org/

### Dados do MIMIC-IV Demo v2.2

| Tabela | Registros | Descrição |
|:---|:---|:---|
| patients | 100 | Dados demográficos (57 M, 43 F, idade média 62 anos) |
| admissions | 275 | Admissões hospitalares (mortalidade 0%) |
| icustays | 140 | Estadias em UTI |
| chartevents | 668.862 | Sinais vitais e avaliações |
| diagnoses_icd | 4.506 | Diagnósticos ICD-10 (1.472 códigos únicos) |
| labevents | 107.727 | Exames laboratoriais |
| emar | 35.835 | Administrações de medicamentos (470 fármacos) |
| inputevents | 20.404 | Fluidos intravenosos (3.773,5 L) |
| outputevents | 9.362 | Débito urinário (1.319,3 L) |

---

## Resultados do Banco de Enfermagem

### Banco gerado (dados reais, 100 pacientes)

| Tabela | Registros | Conteúdo |
|:---|:---|:---|
| `dim_patient` | 100 | Pacientes (57 M, 43 F, idade média 62) |
| `dim_admission` | 275 | Admissões hospitalares |
| `dim_icustay` | 140 | Estadias em UTI |
| `fact_nanda` | **22.628** | Diagnósticos NANDA-I inferidos |
| `fact_noc` | **86.038** | Resultados NOC derivados |
| `fact_nic` | **56.701** | Intervenções NIC derivadas |
| `dim_nanda_domain` | 13 | Domínios NANDA-I |
| `dim_noc_outcome` | 8 | Indicadores NOC |
| `dim_nic_intervention` | 10 | Categorias NIC |

### Domínios NANDA-I mais frequentes

| Domínio | Diagnósticos inferidos |
|:---|:---|
| Cardiovascular | 11.689 |
| Percepção/Cognição | 5.432 |
| Segurança/Proteção | 3.213 |
| Atividade/Repouso | 684 |
| Nutrição | 381 |
| Eliminação | 107 |
| Conforto | 39 |

### Indicadores NOC anormais

| Indicador | % Anormal |
|:---|:---|
| Pressão Arterial Sistólica | 41,9% |
| Temperatura Corporal | 35,5% |
| Frequência Cardíaca | 29,3% |
| Saturação de Oxigênio | 4,4% |

### Intervenções NIC derivadas

| Intervenção | Eventos |
|:---|:---|
| Administração de Medicamentos (NIC 2300) | 34.829 |
| Terapia Intravenosa (NIC 4200) | 20.404 |
| Cuidados com Pele (NIC 3540) | 1.468 |

---

## Metodologia de Mapeamento

### Estratégia de Inferência

O pipeline constrói camadas derivadas por duas vias:

**Via 1: Mapeamento ICD-10 para domínios NANDA-I**

| Prefixo ICD-10 | Domínio NANDA-I | Exemplos |
|:---|:---|:---|
| E40-E46 | Nutrição | Desnutrição |
| I10-I51 | Cardiovascular | Hipertensão, Insuficiência cardíaca |
| A41, J15-J18 | Segurança/Proteção | Sepse, Pneumonia |
| N17-N19 | Eliminação | Insuficiência renal |
| F05, G93 | Percepção/Cognição | Delirium, Encefalopatia |
| R52, M79 | Conforto | Dor |

**Via 2: Inferência por limiares clínicos**

| Evidência no MIMIC-IV | Limiar | Diagnóstico NANDA-I inferido |
|:---|:---|:---|
| Frequência Cardíaca | > 100 bpm | Risco de débito cardíaco diminuído |
| SpO2 | < 92% | Troca de gases prejudicada |
| GCS | <= 8 | Perfusão tissular cerebral ineficaz |
| Dor (NRS) | >= 7 | Dor aguda |
| Temperatura | > 38.0°C | Hipertermia |

---

## Figuras Geradas (dados reais)

| Figura | Conteúdo |
|:---|:---|
| Fig1 | Prevalência de domínios NANDA-I |
| Fig2 | Indicadores NOC anormais (%) |
| Fig3 | Volume de intervenções NIC |
| Fig4 | Top 10 medicamentos (NIC 2300) |
| Fig5 | Distribuição etária por gênero |
| Fig6 | Importância de variáveis (SHAP/Random Forest) |
| Fig7 | Matriz de correlação entre features |
| Fig8 | NANDA-I por faixa etária |

---

## Transparência e Uso de IA Generativa

**Declaração conforme Portaria CNPq nº 2.664/2026**

Os autores declaram que foram utilizadas ferramentas de inteligência artificial
generativa no apoio à concepção, organização metodológica, revisão textual,
depuração de código, geração de sugestões de auditoria e melhoria da clareza
do manuscrito e da documentação computacional. As ferramentas utilizadas foram
ChatGPT 5.5, DeepSeek-v4-Pro e Grok. As ferramentas não foram indicadas como
autoras, não substituíram a interpretação científica humana, não realizaram
coleta independente de dados e não isentam os autores da responsabilidade
integral pelo conteúdo final, pela veracidade das informações, pela
originalidade, pelas análises, pelas referências e por eventuais erros ou
imprecisões.

---

## Limitações Conhecidas

1. **Dados reais limitados**: O MIMIC-IV Demo contém apenas 100 pacientes.
2. **Mortalidade zero no Demo**: Não é possível realizar análise de desfechos graves.
3. **Sem validação clínica**: O mapeamento ICD-10 para NANDA-I não foi validado por especialistas.
4. **NANDA-I, NIC e NOC não são nativos do MIMIC-IV**: Constituem camada derivada experimental.
5. **Terminologias protegidas**: NANDA-I, NIC e NOC são marcas registradas. Este repositório utiliza apenas identificadores e categorias resumidas de uso permitido.

---

## Licença

MIT License -- veja [LICENSE](LICENSE) para detalhes.

---

## Citação

```bibtex
@software{nursing_pool_2026,
  author       = {Santos, Ryan de Paulo and Santos, Kerolyne Yngredy Rodrigues},
  title        = {nursing-pool: Modelo conceitual e prova de conceito computacional
                  para estruturação de dados de enfermagem em SII com MIMIC-IV},
  year         = {2026},
  url          = {https://github.com/santosry/nursing-pool},
  note         = {Prova de conceito. NÃO validado para uso clínico.}
}
```
