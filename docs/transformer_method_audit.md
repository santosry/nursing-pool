# Auditoria metodologica: fallback semantico por Transformer

## O que foi alterado

O pipeline principal para dados reais foi padronizado em `rebuild_transformer_embeddings.py`. A camada NANDA-I agora usa um metodo hibrido:

1. regras por palavras-chave clinicas para mapeamentos de alta precisao;
2. embeddings de Transformer biomedico como fallback semantico para descricoes ICD sem correspondencia por regra.

O fallback TF-IDF foi removido do metodo principal. O arquivo `rebuild_keywords.py` permanece apenas como wrapper de compatibilidade e delega para o novo script.

## Modelo Transformer

Modelo padrao: `pritamdeka/S-BioBERT-snli-multinli-stsb`.

O script tenta carregar o modelo com `sentence-transformers`. Se o modelo escolhido pelo usuario nao for diretamente compativel com `sentence-transformers`, o script usa `transformers` e `torch` com pooling medio dos tokens.

## Tabelas modificadas ou criadas

- `mapping_nanda_evidence`: agora registra `semantic_score`, `inference_method`, `model_name` e `rank_position`.
- `mapping_nanda_candidates`: nova tabela auxiliar com top-k candidatos NANDA-I por ICD sem keyword match.
- `fact_nanda_hypothesis`: registra o metodo hibrido e mantem o status como hipotese computacional.
- `fact_noc_measurement`, `fact_nic_observed_proxy`, `fact_nic_recommended` e `nnn_linkage_rules`: preservadas como camadas derivadas, com linguagem de limitacao.

## Como reproduzir

```bash
pip install -r requirements.txt
python rebuild_transformer_embeddings.py --base-dir ../mimic-iv-clinical-database-demo-2.2
```

O script gera `output/nursing_db.sqlite` e exporta as tabelas para `data/*.csv`, que sao usadas pelo site estatico.

Para um smoke test sem baixar modelo:

```bash
python rebuild_transformer_embeddings.py --test-embedder
```

Esse modo e apenas para verificacao tecnica local, nao para resultados cientificos.

## Limitacoes remanescentes

- O MIMIC-IV Demo nao contem diagnosticos NANDA-I, resultados NOC ou intervencoes NIC nativos.
- As saidas sao triagem semantica de hipoteses NANDA-I derivadas, nao diagnosticos confirmados.
- Embeddings ranqueiam proximidade semantica textual, mas nao validam adequacao clinica.
- Sinais vitais sao tratados como evidencias operacionais ou caracteristicas definidoras, nunca como confirmacao diagnostica.
- Proxies NIC baseados em medicamentos e fluidos IV nao distinguem prescritor, execucao de enfermagem ou autonomia profissional.
- O uso de dominios NANDA-I e propositalmente resumido para evitar republicacao de conteudo proprietario.

## Validacao futura recomendada

1. Amostrar ICDs mapeados por keyword e por Transformer.
2. Solicitar revisao independente por especialistas de enfermagem.
3. Medir concordancia interavaliadores para dominio NANDA-I candidato.
4. Definir limiares de aceitacao para `semantic_score` por dominio.
5. Registrar falsos positivos por dominio e ajustar regras/descricoes.
6. Repetir a auditoria em MIMIC-IV completo apenas em ambiente autorizado, sem versionar dados brutos.
