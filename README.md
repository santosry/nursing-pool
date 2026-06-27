# 🏥 Modelo Conceitual para Estruturação de Dados de Enfermagem em SII

## Prova de Conceito Computacional — Pipeline MIMIC-IV → NANDA/NOC/NIC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R ≥ 4.4](https://img.shields.io/badge/R-%E2%89%A5%204.4-brightgreen.svg)](https://www.r-project.org/)
[![DOI](https://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXX-blue.svg)](https://doi.org/)

> **Projeto acadêmico vinculado à revisão integrativa:** _"Modelo conceitual para estruturação de dados de enfermagem em sistemas de informação em saúde: fundamentado em terminologias padronizadas e evidências científicas."_

---

## ⚠️ Aviso Importante — Dados Sintéticos vs. Dados Reais

> **Este pipeline NÃO inventa dados clínicos.** Os dados gerados no modo `--mode=synthetic` são **inteiramente simulados** para fins de demonstração computacional, não contendo nenhuma informação real de pacientes.

| Modo | Origem dos Dados | Finalidade |
|:---|:---|:---|
| `synthetic` | Gerador algorítmico (`synthetic_data.R`) | Demonstração, teste, validação do pipeline |
| `real` | MIMIC-IV via PhysioNet (acesso credenciado) | Pesquisa com dados clínicos reais |

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

Este projeto é **open source** (MIT License). Contribuições são bem-vindas:

1. Fork o repositório
2. Crie uma branch (`git checkout -b feature/nova-funcionalidade`)
3. Commit (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

---

## 📄 Licença

MIT License — veja [LICENSE](LICENSE) para detalhes.

---

## ✍️ Citação

Se usar este pipeline em sua pesquisa, por favor cite:

```
@software{mimic_nursing_poc_2026,
  title        = {Pipeline MIMIC-IV → NANDA/NOC/NIC: Prova de Conceito para Enfermagem de Precisão},
  year         = {2026},
  url          = {https://github.com/seu-usuario/mimic-nursing-poc},
  note         = {Modelo conceitual para estruturação de dados de enfermagem}
}
```
