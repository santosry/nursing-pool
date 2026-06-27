# Dados do Banco de Enfermagem — nursing-pool v4.0

Banco de dados relacional de enfermagem construido a partir do MIMIC-IV Demo v2.2 (100 pacientes reais).

**Metodologia**: Hipoteses diagnosticas NANDA-I derivadas por regras computacionais, indicadores NOC operacionalizados e proxies/recomendacoes NIC. NENHUM diagnostico confirmado. Todos requerem validacao por enfermeiro especialista.

## Tabelas

| Tabela | Registros | Descricao |
|:---|:---|:---|
| dim_patient | 100 | Pacientes |
| dim_admission | 275 | Admissoes |
| dim_icustay | 140 | Estadias em UTI |
| dim_nanda_domain | 13 | Dominios NANDA-I (Taxonomia II) |
| mapping_nanda_evidence | 15.677 | Evidencias classificadas |
| fact_nanda_hypothesis | 732 | Hipoteses NANDA-I (status: candidate/rule_supported) |
| fact_noc_measurement | 501 | Indicadores NOC vinculados a hipoteses |
| fact_nic_observed_proxy | 55.233 | Proxies observaveis (medicamentos, fluidos IV) |
| fact_nic_recommended | 310 | Recomendacoes NIC por ligacao NNN |
| nnn_linkage_rules | 7 | Regras de ligacao NANDA-NOC-NIC |

## Como visualizar

1. Clique em qualquer arquivo .csv acima para ver no GitHub
2. Para consultas SQL, acesse https://santosry.github.io/nursing-pool/
3. Para consultas locais, baixe nursing_db.sqlite e abra com DB Browser for SQLite (gratis)
