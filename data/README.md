# Dados do Banco de Enfermagem

Banco de dados relacionais de enfermagem construido a partir do MIMIC-IV Demo v2.2.

## Formatos disponiveis

- **nursing_db_dump.sql**: dump SQL completo (texto, visivel no GitHub)
- **.csv**: cada tabela exportada individualmente
- **nursing_db.sqlite** (em output/): banco SQLite binario para consultas

## Tabelas

| Tabela | Registros | Descricao |
|:---|:---|:---|
| dim_patient | 100 | Pacientes |
| dim_admission | 275 | Admissoes |
| dim_icustay | 140 | UTI |
| fact_nanda | 22628 | Diagnosticos NANDA-I |
| fact_noc | 86038 | Resultados NOC |
| fact_nic | 56701 | Intervencoes NIC |
| dim_nanda_domain | 13 | Dominios NANDA |
| dim_noc_outcome | 8 | Indicadores NOC |
| dim_nic_intervention | 10 | Categorias NIC |

## Como visualizar

1. Clique em qualquer arquivo .csv ou .sql acima para ver no GitHub
2. Para consultas SQL, baixe nursing_db.sqlite e abra com DB Browser for SQLite (gratis)
