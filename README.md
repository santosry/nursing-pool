# 🏥 Modelo Conceitual para Estruturação de Dados de Enfermagem em SII

## Prova de Conceito Computacional — Pipeline MIMIC-IV → NANDA/NOC/NIC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-brightgreen.svg)](https://www.r-project.org/)
[![Status: Prova de Conceito](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()
[![renv](https://img.shields.io/badge/renv-138%20packages-blueviolet.svg)](https://rstudio.github.io/renv/)
[![DOI](https://img.shields.io/badge/CITATION-CFF-yellow.svg)](./CITATION.cff)

> **Projeto acadêmico vinculado à revisão integrativa:** _"Modelo conceitual para estruturação de dados de enfermagem em sistemas de informação em saúde: fundamentado em terminologias padronizadas e evidências científicas."_

> **Aviso**: Este projeto é uma **prova de conceito computacional**. Os modelos preditivos aqui implementados têm AUC < 0.55 em dados sintéticos e **não são válidos para uso clínico**. NANDA-I, NIC e NOC são camadas derivadas por mapeamento exploratório — **não são registros originais do MIMIC-IV**.

O **MIMIC-IV não contém registros nas classificações NANDA-I/NOC/NIC nativamente.** O pipeline faz o **mapeamento conceitual** entre dados clínicos existentes (sinais vitais, exames, medicamentos, diagnósticos ICD-10) e os conceitos das terminologias de enfermagem — exatamente a lacuna que este projeto de pesquisa visa preencher.

---

## 🎯 Objetivo

Propor e demonstrar um **modelo conceitual para estruturação de dados de enfermagem** em sistemas de informação em saúde, fundamentado em:

- **NANDA-I** (diagnósticos) — 13 domínios, Taxonomia II
- **NOC** (resultados) — 7 domínios, 32 classes  
- **NIC** (intervenções) — 7 domínios, 30 classes
- **NMDS** (conjunto mínimo de dados)
- **HL7 FHIR** / **openEHR** / **SNOMED CT** (interoperabilidade)

Em consonância com:
- Resolução COFEN nº 736/2024 (Processo de Enfermagem)
- LGPD (Lei nº 13.709/2018)
- Portaria GM/MS nº 2.073/2011 (SNOMED CT)

---

## 📁 Estrutura do Projeto

```
mimic_nursing_poc/
├── README.md                     # Documentação
├── LICENSE                       # MIT License
├── pipeline.R                    # 🚀 Orquestrador principal (10 etapas)
├── config.R                      # Configuração de paths e parâmetros
├── theme_cellpress.R             # Tema ggplot2 estilo Cell Press
├── synthetic_data.R              # Gerador de dados sintéticos (POC)
├── requirements.R                # Instalação de dependências
├── Dockerfile                    # Containerização
│
├── 01_data_access.R              # Carregamento + auditoria de integridade
├── 02_nursing_mapping.R          # Mapeamento NANDA/NOC/NIC → MIMIC-IV
├── 03_nanda_diagnostics.R        # Diagnósticos de Enfermagem NANDA-I
├── 04_noc_outcomes.R             # Resultados de Enfermagem NOC
├── 05_nic_interventions.R        # Intervenções de Enfermagem NIC
├── 06_nursing_db.R               # Banco SQLite/DuckDB relacional
├── 07_statistical_analysis.R     # Análises estatísticas completas
├── 08_visualization.R            # Gráficos estilo Cell Press
├── 09_audit.R                    # Auditoria linha a linha
├── 10_benchmark.R                # Benchmarks de performance
│
└── output/                       # Resultados (gerado na execução)
    ├── nursing_db.sqlite
    ├── nanda_diagnostics.csv
    ├── noc_outcomes.csv
    ├── nic_interventions.csv
    ├── statistical_results.rds
    ├── audit_report.rds
    ├── benchmark_results.csv
    └── figures/                  # PDFs estilo Cell Press
```

---

## 🔬 Metodologia de Mapeamento

### Estratégia de Extração

O pipeline segue a seguinte lógica de mapeamento (sem inventar dados):

| Fonte MIMIC-IV | Evidência Real | Mapeamento NANDA/NOC/NIC |
|:---|:---|:---|
| `chartevents` (FC > 100 bpm) | Taquicardia documentada | **NANDA:** "Risco de débito cardíaco diminuído" |
| `chartevents` (SpO₂ < 92%) | Hipoxemia documentada | **NANDA:** "Troca de gases prejudicada" |
| `chartevents` (GCS ≤ 8) | Coma documentado | **NANDA:** "Perfusão tissular cerebral ineficaz" |
| `omr` (Braden ≤ 12) | Risco de UP documentado | **NANDA:** "Risco de úlcera por pressão" |
| `labevents` (Albumina < 3.5) | Desnutrição laboratorial | **NANDA:** "Nutrição desequilibrada" |
| `emar` + `emar_detail` | Administração de medicamentos | **NIC 2300:** "Administração de Medicamentos" |
| `inputevents` (Fluidos IV) | Infusão IV documentada | **NIC 4200:** "Terapia Intravenosa" |
| `procedureevents` (Curativos) | Cuidados com feridas | **NIC 3540:** "Prevenção de Úlcera por Pressão" |
| `chartevents` (Sinais vitais) | Aferições seriadas | **NOC 0802:** "Estado dos Sinais Vitais" |
| `outputevents` (Diurese) | Débito urinário | **NOC 0601:** "Equilíbrio Hídrico" |

### Raciocínio Clínico

O mapeamento é baseado nas ligações NANDA-NOC-NIC (NNN) documentadas na literatura:
- Bertocchi et al. (2023) — Impacto das terminologias padronizadas (J Nursing Scholarship)
- Rodríguez-Suárez et al. (2023) — Efetividade do processo NNN (Healthcare)
- Aleandri, Scalorbi, Pirazzini (2022) — Planos eletrônicos NNN (Int J Nursing Knowledge)

---

## 🚀 Execução

### Pré-requisitos

```r
# Instalar dependências
Rscript requirements.R
```

### Modo Demonstração (Prova de Conceito)

```bash
# Dados sintéticos — NÃO contém informações reais de pacientes
Rscript pipeline.R --mode=synthetic
```

### Modo Pesquisa (Requer Acesso PhysioNet)

```bash
# Requer credenciamento: https://physionet.org/content/mimiciv/
Rscript pipeline.R --mode=real --data_dir=/caminho/mimic-iv-3.1
```

### Docker (Portabilidade Máxima)

```bash
docker build -t mimic-nursing-poc .
docker run --rm -v $(pwd)/output:/app/output mimic-nursing-poc
```

---

## 📊 Análises Implementadas

| Análise | Método | Output |
|:---|:---|:---|
| Descritivas (± IC 95%) | Wilson score interval | Prevalência NANDA por domínio |
| Teste χ² | Pearson + Bonferroni | Diferenças por gênero |
| Mann-Whitney U | Wilcoxon rank-sum | Indicadores NOC × mortalidade |
| Kruskal-Wallis | + Dunn post-hoc (FDR) | LOS por domínio NANDA |
| Correlação | Spearman ρ | NANDA × NIC × NOC |
| Regressão Logística | GLM binomial + OR + AUC | Preditores de mortalidade |
| Sobrevivência | Kaplan-Meier + log-rank | Curvas estratificadas |

---

## 🖼️ Visualizações (Cell Press)

Todas as figuras seguem padrão Cell Press (Cell, Patterns, Med):
- **Figura 1A:** Prevalência NANDA por domínio (bar + IC 95%)
- **Figura 1B:** Heatmap de co-ocorrência de domínios NANDA
- **Figura 2A:** Distribuição de indicadores NOC (violin + boxplot)
- **Figura 2B:** Proporção de indicadores NOC anormais
- **Figura 3A:** Volume de intervenções NIC
- **Figura 3B:** Distribuição temporal (turnos de enfermagem)
- **Figura 4:** Curvas de Kaplan-Meier
- **Figura 5A:** Odds Ratios (Forest plot)
- **Figura 5B:** Curva ROC
- **Figura S1:** LOS por domínio NANDA
- **Figura S2:** Correlação NANDA × NIC (scatter + regressão)

---

## 📚 Referências

1. Herdman, T.H., Kamitsuru, S., Lopes, C.T. (2024). **NANDA International Nursing Diagnoses 2024-2026.** 13th ed. Thieme.
2. Butcher, H.K. et al. (2024). **Nursing Interventions Classification (NIC).** 8th ed. Elsevier.
3. Moorhead, S. et al. (2024). **Nursing Outcomes Classification (NOC).** 7th ed. Elsevier.
4. Johnson, A.E.W. et al. (2023). MIMIC-IV, a freely accessible electronic health record dataset. **Scientific Data**, 10, 31.
5. COFEN (2024). **Resolução nº 736/2024** — Implementação do Processo de Enfermagem.
6. Benson, T., Grieve, G. (2021). **Principles of Health Interoperability: FHIR, HL7 and SNOMED CT.** 4th ed. Springer.
7. Kalra, D., Beale, T., Heard, S. (2005). The openEHR Foundation. **Stud Health Technol Inform**, 115, 153-173.

---

## 👥 Como Contribuir

---

## 🤖 Transparência e Uso de IA Generativa

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

## ⚠️ Limitações Conhecidas

1. **Dados sintéticos**: Os dados do modo synthetic NÃO representam complexidade clínica real.
   Correlações, prevalências e associações são artefatos do gerador aleatório.
2. **Vazamento temporal**: `los_days` é usado como preditor nos modelos ML — isto é
   metodologicamente inválido para predição prospectiva. A análise deve ser interpretada
   como exploratória retrospectiva.
3. **Sem validação clínica**: O mapeamento ICD-10 → NANDA-I não foi validado por
   especialistas. NENHUM resultado deste pipeline deve ser interpretado como evidência
   clínica.
4. **Modelos não preditivos**: Todos os modelos ML apresentam AUC < 0.55 em dados
   sintéticos, desempenho insuficiente para qualquer aplicação clínica.
5. **FHIR/openEHR**: Apenas referencial teórico. O pipeline não implementa APIs FHIR
   nem arquétipos openEHR.
6. **Terminologias protegidas**: NANDA-I, NIC e NOC são marcas registradas. Este
   repositório utiliza apenas identificadores e categorias resumidas de uso permitido.

---

## 📄 Licença

MIT License — veja [LICENSE](LICENSE) para detalhes.

---

## ✍️ Citação

Se usar este pipeline em sua pesquisa, por favor cite:

```
@software{nursing_pool_2026,
  title        = {nursing-pool: Modelo conceitual e prova de conceito computacional
                  para estruturação de dados de enfermagem em SII com MIMIC-IV},
  year         = {2026},
  url          = {https://github.com/santosry/nursing-pool},
  note         = {Prova de conceito. NÃO validado para uso clínico.}
}
```
