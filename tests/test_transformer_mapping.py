import importlib


def test_script_imports_without_loading_model():
    module = importlib.import_module("rebuild_transformer_embeddings")
    assert module.DEFAULT_MODEL_NAME


def test_similarity_ranking_is_sorted():
    module = importlib.import_module("rebuild_transformer_embeddings")
    embedder = module.HashEmbedder()
    ranking = module.rank_nanda_domains(
        "acute respiratory failure with hypoxemia",
        embedder=embedder,
        top_k=5,
    )
    scores = [row["similarity_score"] for row in ranking]
    assert scores == sorted(scores, reverse=True)
    assert [row["rank_position"] for row in ranking] == [1, 2, 3, 4, 5]


def test_keyword_match_still_has_priority():
    module = importlib.import_module("rebuild_transformer_embeddings")
    assert module.keyword_match("acute kidney failure") == "Eliminacao e Troca"
    assert module.keyword_match("severe sepsis with shock") == "Seguranca/Protecao"


def test_transformer_fallback_returns_valid_nanda_domain_for_unmatched_text():
    module = importlib.import_module("rebuild_transformer_embeddings")
    embedder = module.HashEmbedder()
    assert module.keyword_match("rare metabolic storage condition") is None
    ranking = module.rank_nanda_domains(
        "rare metabolic storage condition",
        embedder=embedder,
        top_k=1,
    )
    valid_domains = {domain.name for domain in module.NANDA_DOMAINS}
    assert ranking[0]["candidate_domain"] in valid_domains
    assert ranking[0]["accepted_as_top1"] == 1
