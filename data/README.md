# CSVs publicados do nursing-pool

Esta pasta contém CSVs leves exportados do banco SQLite para consulta no GitHub Pages.

Os arquivos representam uma camada computacional derivada, exploratória e não validada clinicamente. O MIMIC-IV Demo não contém NANDA-I, NOC ou NIC nativos documentados por enfermeiros.

## Tabelas centrais

| Tabela | Interpretação segura |
|:---|:---|
| `mapping_nanda_evidence.csv` | Evidências operacionais ou semânticas com método, escore, modelo e limitação |
| `mapping_nanda_candidates.csv` | Candidatos top-k para auditoria do fallback Transformer |
| `fact_nanda_hypothesis.csv` | Hipóteses computacionais NANDA-I |
| `fact_noc_measurement.csv` | Indicadores NOC operacionalizados por variáveis observáveis |
| `fact_nic_observed_proxy.csv` | Proxies observáveis de intervenções NIC |
| `fact_nic_recommended.csv` | Recomendações NIC derivadas por regras NNN |
| `nnn_linkage_rules.csv` | Regras documentadas de ligação NANDA-NOC-NIC |

## Contagens da versão atual

- Evidências: 25.072
- Candidatos top-k: 1.998
- Hipóteses computacionais NANDA-I: 1.629
- Indicadores NOC operacionalizados: 685
- Proxies observáveis de intervenções NIC: 55.233
- Recomendações NIC derivadas por regras NNN: 1.365

## Reproduzir os CSVs

```bash
pip install -r requirements.txt
python rebuild_transformer_embeddings.py
```

Não versionar dados brutos protegidos, arquivos `.csv.gz`, bancos `.sqlite`, `.db` ou credenciais.
