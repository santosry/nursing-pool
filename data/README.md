# Dados publicados do nursing-pool

Esta pasta contem CSVs leves usados pelo site estatico do projeto.

Metodologia atual: camada derivada NANDA-I/NOC/NIC por inferencia computacional hibrida, com regras por palavras-chave clinicas e fallback semantico por embeddings de Transformer biomedico.

NANDA-I, NOC e NIC nao sao registros nativos do MIMIC-IV. As saidas sao hipoteses computacionais exploratorias, nao diagnosticos confirmados.

Tabelas centrais:

| Tabela | Descricao |
|:---|:---|
| `mapping_nanda_evidence.csv` | Evidencias e scores usados para gerar hipoteses NANDA-I |
| `mapping_nanda_candidates.csv` | Top-k candidatos NANDA-I para ICDs sem keyword match |
| `fact_nanda_hypothesis.csv` | Hipoteses NANDA-I derivadas |
| `fact_noc_measurement.csv` | Indicadores NOC operacionalizados |
| `fact_nic_observed_proxy.csv` | Proxies observaveis associados a NIC |
| `fact_nic_recommended.csv` | Recomendacoes NIC por ligacao NNN |
| `nnn_linkage_rules.csv` | Regras documentadas NANDA-NOC-NIC |

Para regenerar:

```bash
pip install -r requirements.txt
python rebuild_transformer_embeddings.py
```

Nao versionar dados brutos protegidos, arquivos `.csv.gz`, bancos `.sqlite` ou credenciais.
