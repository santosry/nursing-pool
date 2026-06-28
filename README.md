# nursing-pool

## Prova de conceito computacional para camada derivada NANDA-I/NOC/NIC a partir do MIMIC-IV Demo

**Autores:** Ryan de Paulo Santos, Kerolyne Yngredy Rodrigues Santos

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status: Proof of Concept](https://img.shields.io/badge/Status-Proof%20of%20Concept-orange.svg)]()

> **Aviso metodologico:** NANDA-I, NOC e NIC nao sao registros nativos do MIMIC-IV. Este projeto gera uma camada exploratoria por inferencia computacional. As saidas sao triagem semantica de hipoteses NANDA-I derivadas, nao diagnosticos de enfermagem confirmados, e nao foram validadas clinicamente.

## Acesso

- Site SQL estatico: https://santosry.github.io/nursing-pool/
- CSVs publicados: https://github.com/santosry/nursing-pool/tree/main/data
- Codigo-fonte: https://github.com/santosry/nursing-pool

## Metodo principal

O pipeline real principal e `rebuild_transformer_embeddings.py`.

O metodo atual e hibrido:

1. **Palavras-chave clinicas:** primeira camada de alta precisao para descricoes ICD com sinais semanticos diretos, como sepse, pneumonia, insuficiencia renal, dor, diabetes ou trauma.
2. **Fallback por Transformer biomedico:** para descricoes ICD sem match por regra, o script gera embeddings da descricao ICD e das descricoes resumidas dos dominios NANDA-I, calcula similaridade por cosseno e seleciona o top-1. O top-k tambem e salvo para auditoria.

O Transformer substitui o antigo fallback por TF-IDF apenas na etapa de similaridade semantica. Regras por palavras-chave, limiares clinicos de sinais vitais e camadas NOC/NIC derivadas continuam separados e auditaveis.

Modelo padrao:

```text
pritamdeka/S-BioBERT-snli-multinli-stsb
```

O script usa `sentence-transformers` quando possivel. Se o modelo escolhido nao for diretamente compativel, usa `transformers` + `torch` com pooling medio.

## Reproducao local

```bash
git clone https://github.com/santosry/nursing-pool.git
cd nursing-pool
pip install -r requirements.txt

# Baixe o MIMIC-IV Demo v2.2 e extraia ao lado do repositorio:
# ../mimic-iv-clinical-database-demo-2.2/

python rebuild_transformer_embeddings.py
```

Opcoes uteis:

```bash
python rebuild_transformer_embeddings.py --base-dir ../mimic-iv-clinical-database-demo-2.2
python rebuild_transformer_embeddings.py --model-name pritamdeka/S-BioBERT-snli-multinli-stsb
python rebuild_transformer_embeddings.py --top-k 5
```

O pipeline gera:

- `output/nursing_db.sqlite`
- `data/*.csv`, usados pelo site estatico

O arquivo `rebuild_keywords.py` permanece apenas como wrapper de compatibilidade e chama o novo pipeline. O `pipeline.R` e legado para modo sintetico; em `--mode=real`, delega ao pipeline Python com Transformer.

## Tabelas principais

| Tabela | Finalidade |
|:---|:---|
| `dim_patient` | Dimensao derivada de pacientes |
| `dim_admission` | Dimensao derivada de admissoes |
| `dim_icustay` | Dimensao derivada de estadias em UTI |
| `dim_nanda_domain` | Dominios NANDA-I resumidos |
| `mapping_nanda_evidence` | Evidencias operacionais e semanticas usadas na hipotese |
| `mapping_nanda_candidates` | Top-k candidatos NANDA-I para ICDs sem keyword match |
| `fact_nanda_hypothesis` | Hipoteses computacionais NANDA-I derivadas |
| `fact_noc_measurement` | Indicadores NOC operacionalizados por variaveis observaveis |
| `fact_nic_observed_proxy` | Proxies observaveis de acoes associadas a NIC |
| `fact_nic_recommended` | Recomendacoes NIC por ligacao NNN documentada |
| `nnn_linkage_rules` | Regras de ligacao NANDA-NOC-NIC |

Campos de auditoria em `mapping_nanda_evidence`:

- `subject_id`
- `hadm_id`
- `nanda_domain`
- `evidence_category`
- `evidence_source`
- `evidence_detail`
- `semantic_score`
- `inference_method`
- `model_name`
- `rank_position`
- `limitation`

Campos principais em `mapping_nanda_candidates`:

- `icd_code`
- `icd_description`
- `candidate_domain`
- `similarity_score`
- `rank_position`
- `model_name`
- `accepted_as_top1`

## Sinais vitais e evidencias operacionais

O projeto preserva limiares clinicos para taquicardia, hipotensao, hipoxemia, febre, dor intensa e GCS baixo. Esses sinais sao tratados como caracteristicas definidoras ou evidencias operacionais. Eles nao confirmam diagnostico NANDA-I.

## Site estatico

O site em `docs/index.html` carrega CSVs de `data/` e permite consultas simples sobre as tabelas publicadas. Ele inclui a nota metodologica:

> NANDA-I, NOC e NIC sao camadas derivadas por inferencia computacional, nao registros nativos do MIMIC-IV.

## Testes

```bash
pytest
```

Os testes minimos verificam importacao do novo script, ordenacao do ranking por similaridade, prioridade do keyword match e retorno de dominio NANDA-I valido no fallback semantico.

## Governanca de dados

Nao versionar:

- dados brutos protegidos;
- arquivos `.csv.gz` do MIMIC-IV;
- bancos `.sqlite` ou `.db`;
- credenciais, tokens ou chaves;
- artefatos pesados gerados localmente.

O `.gitignore` bloqueia esses arquivos. Os CSVs leves em `data/` sao exports publicados para o GitHub Pages.

## Limitacoes

1. MIMIC-IV Demo nao contem NANDA-I, NOC ou NIC nativos.
2. As hipoteses NANDA-I sao exploratorias e nao validadas clinicamente.
3. Similaridade por Transformer ranqueia proximidade textual, nao confirma julgamento clinico.
4. Proxies NIC nao distinguem prescritor, executor ou autonomia da acao.
5. Indicadores NOC sao operacionalizacoes computacionais, nao registros NOC documentados por enfermeiros.
6. O uso de NANDA-I/NOC/NIC e limitado a identificadores e descricoes resumidas para fins cientificos e de interoperabilidade.

## Auditoria metodologica

Veja `docs/transformer_method_audit.md` para detalhes sobre o modelo, tabelas alteradas, limites e plano de validacao futura com especialistas de enfermagem.

## Licenca

MIT License. Veja `LICENSE`.
