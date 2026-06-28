#!/usr/bin/env python3
"""
Rebuild the nursing-pool SQLite database with hybrid NANDA-I semantic triage.

Method:
1. High-precision clinical keyword rules.
2. Biomedical Transformer embeddings as semantic fallback for unmatched ICD
   descriptions.

The generated NANDA-I, NOC and NIC layers are computational hypotheses only.
They are not native MIMIC-IV records and are not clinically validated diagnoses.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, Protocol

import numpy as np
import pandas as pd

from config import BASE_DIR, DATA_DIR, DB_PATH, ITEM_IDS, THRESHOLDS


DEFAULT_MODEL_NAME = "pritamdeka/S-BioBERT-snli-multinli-stsb"
DEFAULT_TOP_K = 3
LIMITATION_TEXT = (
    "Triagem semantica de hipotese NANDA-I derivada por inferencia "
    "computacional; nao validada clinicamente; nao constitui diagnostico "
    "de enfermagem confirmado."
)


@dataclass(frozen=True)
class NandaDomain:
    name: str
    description: str


NANDA_DOMAINS: tuple[NandaDomain, ...] = (
    NandaDomain("Promocao da Saude", "Health promotion, wellness, self-care, preventive health behavior, health education, readiness to improve health."),
    NandaDomain("Nutricao", "Nutrition, malnutrition, obesity, diabetes, glucose, electrolyte, metabolism, feeding, fluid balance, dehydration."),
    NandaDomain("Eliminacao e Troca", "Renal failure, kidney disease, urinary problems, bowel function, gastrointestinal disease, liver disease, dialysis, constipation, diarrhea."),
    NandaDomain("Atividade/Repouso", "Cardiovascular disease, heart failure, arrhythmia, hypertension, respiratory disease, pneumonia, COPD, oxygenation, circulation, sleep, fatigue, activity intolerance."),
    NandaDomain("Percepcao/Cognicao", "Neurological disease, stroke, seizure, confusion, delirium, coma, brain injury, encephalopathy, cognition, memory, sensory perception."),
    NandaDomain("Autopercepcao", "Self-concept, self-esteem, body image, personal identity, psychological perception of self."),
    NandaDomain("Papeis e Relacionamentos", "Family roles, social interaction, relationships, caregiving, bereavement, grief, social support."),
    NandaDomain("Sexualidade", "Sexual health, reproduction, pregnancy, sexually transmitted disease, reproductive function."),
    NandaDomain("Enfrentamento/Tolerancia ao Estresse", "Anxiety, depression, stress, coping, substance use, PTSD, psychiatric disorder, bipolar disorder, schizophrenia."),
    NandaDomain("Principios Vitais", "Spirituality, values, beliefs, religion, meaning, moral distress."),
    NandaDomain("Seguranca/Protecao", "Infection, sepsis, wound, ulcer, burn, trauma, injury, fall, poisoning, allergy, bleeding, hemorrhage, immunity, safety."),
    NandaDomain("Conforto", "Pain, chronic pain, nausea, discomfort, symptom burden, suffering, palliative care, cancer, malignancy."),
    NandaDomain("Crescimento/Desenvolvimento", "Growth, development, developmental delay, failure to thrive, maturation."),
)


# Medical keyword rules are intentionally broad and transparent. They remain the
# first layer because exact clinical signals are easier to audit than embeddings.
KEYWORD_RULES: tuple[tuple[str, str], ...] = (
    ("heart failure|cardiomyopathy|myocardial infarction|coronary artery|angina|atrial fibrillation|arrhythmia|cardiac arrest|cardiogenic shock|pericarditis|endocarditis|valvular heart|ventricular|tachycardia|bradycardia|hypertensive heart|pulmonary heart|aneurysm|aortic|mitral regurgitation|tricuspid|cardiac|congestive heart|left ventricular|right ventricular|systolic|diastolic|ejection fraction|cardiomegaly|cardiorespiratory", "Atividade/Repouso"),
    ("hypertension|hypertensive|elevated blood pressure|essential hypertension|renovascular hypertension|malignant hypertension", "Atividade/Repouso"),
    ("respiratory failure|pneumonia|pulmonary|COPD|emphysema|bronchitis|asthma|pleural effusion|pneumothorax|atelectasis|dyspnea|hypoxia|hypoxemia|hypercapnia|mechanical ventilation|respiratory distress|ARDS|pulmonary edema|pulmonary embolism|lung|bronchopulmonary|tracheostomy|ventilator", "Atividade/Repouso"),
    ("renal failure|kidney disease|nephritis|nephrotic|nephropathy|acute kidney|chronic kidney|end stage renal|dialysis|renal insufficiency|uremia|azotemia|glomerulonephritis|pyelonephritis|hydronephrosis|renal tubular|urinary tract infection|UTI|cystitis|urinary retention|bladder|urethral|urolithiasis|calculus of kidney|nephrolithiasis|chronic kidney disease", "Eliminacao e Troca"),
    ("gastrointestinal|gastric|duodenal|peptic ulcer|gastritis|gastroenteritis|colitis|Crohn|ulcerative colitis|IBS|irritable bowel|diverticulitis|diverticulosis|appendicitis|peritonitis|bowel obstruction|ileus|volvulus|intussusception|megacolon|constipation|diarrhea|nausea|vomiting|hematemesis|melena|GI bleed|gastrointestinal hemorrhage|esophageal varices|cirrhosis|hepatic failure|liver failure|hepatitis|cholecystitis|cholangitis|pancreatitis|pancreatic|jaundice|ascites|portal hypertension|hepatic encephalopathy|hepatorenal", "Eliminacao e Troca"),
    ("cerebrovascular|stroke|CVA|intracranial hemorrhage|subarachnoid|subdural hematoma|epidural hematoma|brain injury|traumatic brain|concussion|cerebral edema|encephalopathy|encephalitis|meningitis|seizure|epilepsy|status epilepticus|convulsion|altered mental status|confusion|delirium|dementia|Alzheimer|cognitive impairment|memory loss|aphasia|dysphasia|hemiplegia|paraplegia|quadriplegia|Guillain-Barre|multiple sclerosis|Parkinson|Huntington|ALS|neuromuscular|neuropathy|myopathy|myasthenia|brain tumor|glioblastoma|meningioma|hydrocephalus", "Percepcao/Cognicao"),
    ("sepsis|septic shock|bacteremia|fungemia|infection|infective|abscess|cellulitis|necrotizing fasciitis|osteomyelitis|endocarditis infectious|meningitis bacterial|peritonitis|cholecystitis acute|pyelonephritis|empyema|infected|wound infection|surgical site infection|catheter-related|CLABSI|CAUTI|VAP|MRSA|VRE|C. difficile|clostridium difficile|candidiasis|aspergillosis|tuberculosis|HIV|AIDS|immunocompromised|neutropenic|febrile neutropenia|opportunistic infection", "Seguranca/Protecao"),
    ("wound|ulcer|pressure ulcer|decubitus|bedsore|skin breakdown|skin integrity|burn|thermal injury|trauma|injury|fracture|dislocation|sprain|strain|contusion|laceration|abrasion|penetrating|gunshot|stab wound|fall|accidental fall|poisoning|overdose|toxic effect|adverse effect|complication of|foreign body|asphyxia|drowning|electrocution|hypothermia|hyperthermia|heat stroke|frostbite", "Seguranca/Protecao"),
    ("pain|chronic pain|acute pain|neuralgia|neuropathic pain|fibromyalgia|migraine|headache|back pain|neck pain|chest pain|abdominal pain|pelvic pain|phantom limb|complex regional pain|causalgia|postherpetic neuralgia|trigeminal neuralgia|sciatica|arthralgia|myalgia", "Conforto"),
    ("diabetes|diabetic|hyperglycemia|hypoglycemia|diabetic ketoacidosis|HHS|hyperosmolar|insulin|glucose intolerance|metabolic syndrome", "Nutricao"),
    ("obesity|overweight|morbid obesity|bariatric|malnutrition|undernutrition|protein-calorie|nutritional deficiency|vitamin deficiency|mineral deficiency|anemia|iron deficiency|B12 deficiency|folate deficiency|weight loss|cachexia|wasting|failure to thrive|feeding difficulty|dysphagia|malabsorption|celiac|short bowel|TPN|total parenteral nutrition|enteral nutrition|NG tube|PEG tube|G tube|J tube", "Nutricao"),
    ("electrolyte|hyponatremia|hypernatremia|hypokalemia|hyperkalemia|hypocalcemia|hypercalcemia|hypomagnesemia|hypermagnesemia|hypophosphatemia|acidosis|alkalosis|metabolic acidosis|metabolic alkalosis|respiratory acidosis|respiratory alkalosis|dehydration|volume depletion|fluid overload|hypervolemia|hypovolemia", "Nutricao"),
    ("depression|major depressive|bipolar|mania|schizophrenia|schizoaffective|psychosis|psychotic|hallucination|delusion|anxiety|panic disorder|PTSD|post-traumatic stress|obsessive-compulsive|OCD|personality disorder|borderline personality|substance abuse|substance use disorder|alcohol withdrawal|alcohol intoxication|opioid|overdose|suicidal|suicide attempt|self-harm|psychiatric", "Enfrentamento/Tolerancia ao Estresse"),
    ("malignant neoplasm|cancer|carcinoma|sarcoma|lymphoma|leukemia|myeloma|melanoma|metastasis|metastatic|chemotherapy|radiation therapy|immunotherapy|palliative|hospice|terminal", "Conforto"),
)


class TextEmbedder(Protocol):
    model_name: str

    def encode(self, texts: list[str]) -> np.ndarray:
        ...


class SentenceTransformerEmbedder:
    def __init__(self, model_name: str) -> None:
        from sentence_transformers import SentenceTransformer

        self.model_name = model_name
        self.model = SentenceTransformer(model_name)

    def encode(self, texts: list[str]) -> np.ndarray:
        return np.asarray(
            self.model.encode(texts, convert_to_numpy=True, show_progress_bar=False),
            dtype=np.float32,
        )


class MeanPoolingTransformerEmbedder:
    def __init__(self, model_name: str) -> None:
        import torch
        from transformers import AutoModel, AutoTokenizer

        self.model_name = model_name
        self.torch = torch
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.model.eval()

    def encode(self, texts: list[str]) -> np.ndarray:
        vectors: list[np.ndarray] = []
        with self.torch.no_grad():
            for text in texts:
                encoded = self.tokenizer(
                    text,
                    padding=True,
                    truncation=True,
                    max_length=256,
                    return_tensors="pt",
                )
                output = self.model(**encoded)
                mask = encoded["attention_mask"].unsqueeze(-1).expand(output.last_hidden_state.size()).float()
                pooled = (output.last_hidden_state * mask).sum(1) / mask.sum(1).clamp(min=1e-9)
                vectors.append(pooled.squeeze(0).cpu().numpy())
        return np.asarray(vectors, dtype=np.float32)


class HashEmbedder:
    """Small deterministic embedder used only for tests and offline smoke checks."""

    model_name = "deterministic-hash-test-embedder"

    def __init__(self, dimensions: int = 128) -> None:
        self.dimensions = dimensions

    def encode(self, texts: list[str]) -> np.ndarray:
        matrix = np.zeros((len(texts), self.dimensions), dtype=np.float32)
        for row, text in enumerate(texts):
            for token in re.findall(r"[a-z0-9]+", text.lower()):
                digest = hashlib.md5(token.encode("utf-8")).digest()
                col = int.from_bytes(digest[:4], "little") % self.dimensions
                sign = 1.0 if digest[4] % 2 == 0 else -1.0
                matrix[row, col] += sign
        return matrix


def build_embedder(model_name: str, allow_test_hash: bool = False) -> TextEmbedder:
    if allow_test_hash or model_name == HashEmbedder.model_name:
        return HashEmbedder()
    try:
        return SentenceTransformerEmbedder(model_name)
    except Exception as exc:
        print(f"[WARN] sentence-transformers failed for {model_name}: {exc}")
        print("[WARN] Falling back to transformers mean pooling.")
        return MeanPoolingTransformerEmbedder(model_name)


def cosine_similarity_matrix(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    left_norm = left / np.clip(np.linalg.norm(left, axis=1, keepdims=True), 1e-12, None)
    right_norm = right / np.clip(np.linalg.norm(right, axis=1, keepdims=True), 1e-12, None)
    return left_norm @ right_norm.T


def keyword_match(description: str) -> str | None:
    for pattern, domain in KEYWORD_RULES:
        if re.search(pattern, description or "", re.IGNORECASE):
            return domain
    return None


def rank_nanda_domains(
    icd_description: str,
    embedder: TextEmbedder,
    top_k: int = DEFAULT_TOP_K,
    domains: Iterable[NandaDomain] = NANDA_DOMAINS,
) -> list[dict[str, object]]:
    domain_list = list(domains)
    texts = [icd_description] + [domain.description for domain in domain_list]
    vectors = embedder.encode(texts)
    scores = cosine_similarity_matrix(vectors[:1], vectors[1:]).ravel()
    order = np.argsort(scores)[::-1][:top_k]
    return [
        {
            "candidate_domain": domain_list[idx].name,
            "similarity_score": float(scores[idx]),
            "rank_position": rank,
            "model_name": embedder.model_name,
            "accepted_as_top1": int(rank == 1),
        }
        for rank, idx in enumerate(order, start=1)
    ]


def load_csv(base_dir: str | Path, relative_path: str) -> pd.DataFrame:
    path = Path(base_dir) / relative_path
    if path.suffix == ".gz" and path.exists():
        return pd.read_csv(path, compression="gzip", low_memory=False)
    plain = Path(str(path).replace(".gz", ""))
    if plain.exists():
        return pd.read_csv(plain, low_memory=False)
    return pd.read_csv(path, low_memory=False)


def normalize_icd_descriptions(d_icd: pd.DataFrame) -> dict[str, str]:
    descriptions: dict[str, str] = {}
    for _, row in d_icd.iterrows():
        code = str(row["icd_code"]).strip()
        title = str(row.get("long_title", "") or "").strip()
        if code and title and title.lower() != "nan":
            descriptions[code] = title.lower()
    return descriptions


def build_icd_mapping(
    icd_desc_map: dict[str, str],
    embedder: TextEmbedder,
    top_k: int,
) -> tuple[dict[str, dict[str, object]], pd.DataFrame]:
    mapping: dict[str, dict[str, object]] = {}
    candidate_rows: list[dict[str, object]] = []

    unmatched: list[tuple[str, str]] = []
    for code, description in icd_desc_map.items():
        domain = keyword_match(description)
        if domain:
            mapping[code] = {
                "domain": domain,
                "score": 1.0,
                "method": "keyword_match",
                "model_name": None,
                "rank_position": 1,
            }
        else:
            unmatched.append((code, description))

    for code, description in unmatched:
        ranked = rank_nanda_domains(description, embedder=embedder, top_k=top_k)
        for candidate in ranked:
            candidate_rows.append(
                {
                    "icd_code": code,
                    "icd_description": description,
                    **candidate,
                }
            )
        top = ranked[0]
        mapping[code] = {
            "domain": top["candidate_domain"],
            "score": top["similarity_score"],
            "method": "transformer_embedding_fallback",
            "model_name": top["model_name"],
            "rank_position": top["rank_position"],
        }

    return mapping, pd.DataFrame(candidate_rows)


def build_mapping_evidence(
    dx: pd.DataFrame,
    ce: pd.DataFrame,
    icd_desc_map: dict[str, str],
    icd_to_nanda: dict[str, dict[str, object]],
) -> pd.DataFrame:
    evidence_rows: list[dict[str, object]] = []
    for _, row in dx.iterrows():
        code = str(row["icd_code"]).strip()
        mapped = icd_to_nanda.get(code)
        if not mapped:
            continue
        method = str(mapped["method"])
        evidence_rows.append(
            {
                "subject_id": int(row["subject_id"]),
                "hadm_id": int(row["hadm_id"]),
                "nanda_domain": mapped["domain"],
                "evidence_category": "Condicao associada",
                "evidence_source": "ICD",
                "evidence_detail": f"{icd_desc_map.get(code, code)} (ICD: {code})",
                "semantic_score": round(float(mapped["score"]), 4),
                "inference_method": method,
                "model_name": mapped["model_name"],
                "rank_position": int(mapped["rank_position"]),
                "limitation": LIMITATION_TEXT,
            }
        )

    for _, row in ce.iterrows():
        itemid = row.get("itemid")
        value = row.get("valuenum")
        if pd.isna(itemid) or pd.isna(value) or pd.isna(row.get("hadm_id")):
            continue
        itemid = int(itemid)
        value = float(value)
        pid = int(row["subject_id"])
        hid = int(row["hadm_id"])

        event = None
        if itemid in ITEM_IDS["heart_rate"] and value > THRESHOLDS["heart_rate_high"]:
            event = ("Atividade/Repouso", f"Taquicardia: {value:.0f} bpm")
        elif itemid in ITEM_IDS["systolic_bp"] and value < THRESHOLDS["systolic_low"]:
            event = ("Atividade/Repouso", f"Hipotensao: {value:.0f} mmHg")
        elif itemid in ITEM_IDS["spo2"] and value < THRESHOLDS["spo2_low"]:
            event = ("Atividade/Repouso", f"Hipoxemia: SpO2 {value:.0f}%")
        elif itemid in ITEM_IDS["temperature"] and value > THRESHOLDS["temp_high"]:
            event = ("Seguranca/Protecao", f"Febre: {value:.1f} C")
        elif itemid in ITEM_IDS["pain"] and value >= THRESHOLDS["pain_high"]:
            event = ("Conforto", f"Dor intensa: {value:.0f}/10")
        elif itemid in ITEM_IDS["gcs"] and value <= THRESHOLDS["gcs_low"]:
            event = ("Percepcao/Cognicao", f"GCS baixo: {value:.0f}")

        if event:
            domain, detail = event
            evidence_rows.append(
                {
                    "subject_id": pid,
                    "hadm_id": hid,
                    "nanda_domain": domain,
                    "evidence_category": "Caracteristica definidora operacional",
                    "evidence_source": "chartevents",
                    "evidence_detail": detail,
                    "semantic_score": None,
                    "inference_method": "clinical_threshold",
                    "model_name": None,
                    "rank_position": None,
                    "limitation": (
                        "Sinal vital usado como evidencia operacional; nao "
                        "constitui diagnostico de enfermagem confirmado."
                    ),
                }
            )

    mapping_evidence = pd.DataFrame(evidence_rows)
    mapping_evidence.insert(0, "evidence_id", range(1, len(mapping_evidence) + 1))
    return mapping_evidence


def build_fact_hypothesis(mapping_evidence: pd.DataFrame, model_name: str) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    grouped = mapping_evidence.groupby(["subject_id", "hadm_id", "nanda_domain"], dropna=False)
    for (sid, hid, domain), group in grouped:
        methods = set(group["inference_method"].astype(str))
        has_defining = group["evidence_category"].astype(str).str.contains("Caracteristica").any()
        has_keyword = "keyword_match" in methods
        status = "rule_supported" if (has_defining or has_keyword) else "candidate"
        score_series = pd.to_numeric(group["semantic_score"], errors="coerce").dropna()
        rows.append(
            {
                "subject_id": int(sid),
                "hadm_id": int(hid),
                "nanda_domain": domain,
                "n_evidence": int(len(group)),
                "has_defining_characteristic": int(has_defining),
                "has_keyword_match": int(has_keyword),
                "best_semantic_score": float(score_series.max()) if len(score_series) else None,
                "inference_method": f"keyword rules + biomedical Transformer fallback ({model_name})",
                "status": status,
                "limitation": "Hipotese computacional exploratoria; nao validada clinicamente; nao e diagnostico confirmado.",
            }
        )
    fact = pd.DataFrame(rows)
    fact.insert(0, "hypothesis_id", range(1, len(fact) + 1))
    return fact


def build_fact_noc(fact_hypothesis: pd.DataFrame, ce: pd.DataFrame) -> pd.DataFrame:
    nanda_noc_map = {
        "Atividade/Repouso": [
            ("0401", "Estado Circulatorio", "PA Sistolica", "mmHg", ITEM_IDS["systolic_bp"]),
            ("0401", "Estado Circulatorio", "FC", "bpm", ITEM_IDS["heart_rate"]),
            ("0402", "Estado Respiratorio", "SpO2", "%", ITEM_IDS["spo2"]),
        ],
        "Seguranca/Protecao": [("0800", "Termorregulacao", "Temperatura", "C", ITEM_IDS["temperature"])],
        "Conforto": [("2102", "Nivel de Dor", "Dor NRS", "0-10", ITEM_IDS["pain"])],
        "Percepcao/Cognicao": [("0912", "Estado Neurologico", "GCS", "score", ITEM_IDS["gcs"])],
    }
    rows: list[dict[str, object]] = []
    for _, hyp in fact_hypothesis.iterrows():
        if hyp["status"] == "candidate":
            continue
        for noc_code, noc_label, indicator, unit, itemids in nanda_noc_map.get(hyp["nanda_domain"], []):
            measurements = ce[
                (ce["subject_id"] == hyp["subject_id"])
                & (ce["hadm_id"] == hyp["hadm_id"])
                & (ce["itemid"].isin(itemids))
            ]
            values = measurements["valuenum"].dropna()
            if values.empty:
                continue
            rows.append(
                {
                    "hypothesis_id": int(hyp["hypothesis_id"]),
                    "subject_id": int(hyp["subject_id"]),
                    "hadm_id": int(hyp["hadm_id"]),
                    "noc_code": noc_code,
                    "noc_label": noc_label,
                    "indicator": indicator,
                    "unit": unit,
                    "baseline_value": float(values.iloc[0]),
                    "followup_value": float(values.iloc[-1]),
                    "n_measurements": int(len(values)),
                    "expected_direction": "Avaliar",
                    "measurement_window": "Admissao",
                    "origin_variable": "chartevents",
                    "limitation": "Indicador operacionalizado; nao e NOC documentado por enfermeiro.",
                }
            )
    fact = pd.DataFrame(rows)
    if not fact.empty:
        fact.insert(0, "noc_measurement_id", range(1, len(fact) + 1))
    return fact


def build_nic_tables(fact_hypothesis: pd.DataFrame, emar: pd.DataFrame, inp: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    observed_rows: list[dict[str, object]] = []
    for _, row in emar.dropna(subset=["subject_id", "hadm_id"]).iterrows():
        observed_rows.append(
            {
                "subject_id": int(row["subject_id"]),
                "hadm_id": int(row["hadm_id"]),
                "nic_code_proxy": "2300-PROXY",
                "nic_label_proxy": "Adm. Medicamentos (proxy)",
                "action_detail": str(row.get("medication", "")),
                "action_type": "medication",
                "is_nursing_autonomous": 0,
                "limitation": "Registro nao distingue prescritor nem confirma intervencao NIC.",
            }
        )
    for _, row in inp.dropna(subset=["subject_id", "hadm_id", "stay_id"]).iterrows():
        observed_rows.append(
            {
                "subject_id": int(row["subject_id"]),
                "hadm_id": int(row["hadm_id"]),
                "nic_code_proxy": "4200-PROXY",
                "nic_label_proxy": "Terapia IV (proxy)",
                "action_detail": str(row.get("ordercategoryname", "IV")),
                "action_type": "iv_fluid",
                "is_nursing_autonomous": 0,
                "limitation": "Acao interdisciplinar observavel; nao confirma intervencao NIC autonoma.",
            }
        )
    fact_nic_observed = pd.DataFrame(observed_rows)
    if not fact_nic_observed.empty:
        fact_nic_observed.insert(0, "observed_id", range(1, len(fact_nic_observed) + 1))

    links = [
        ("Atividade/Repouso", "0401", "4040", "Cuidados Cardiacos", "Monitorizacao hemodinamica", "Moorhead et al., 2024"),
        ("Seguranca/Protecao", "0800", "3740", "Tratamento da Febre", "Monitorizacao temperatura", "Moorhead et al., 2024"),
        ("Conforto", "2102", "1400", "Controle da Dor", "Avaliacao/manejo da dor", "Moorhead et al., 2024"),
        ("Percepcao/Cognicao", "0912", "6440", "Manejo do Delirium", "Monitorizacao neurologica", "Moorhead et al., 2024"),
        ("Atividade/Repouso", "0402", "3320", "Oxigenoterapia", "Administracao O2", "Moorhead et al., 2024"),
        ("Nutricao", "1004", "1100", "Manejo Nutricional", "Suporte nutricional", "Moorhead et al., 2024"),
        ("Eliminacao e Troca", "0503", "0590", "Manejo Eliminacao", "Monitorizacao urinaria", "Moorhead et al., 2024"),
    ]

    recommended_rows: list[dict[str, object]] = []
    supported = fact_hypothesis[fact_hypothesis["status"] != "candidate"]
    for _, hyp in supported.iterrows():
        for nanda, noc_code, nic_code, nic_label, nic_desc, source in links:
            if nanda == hyp["nanda_domain"]:
                recommended_rows.append(
                    {
                        "hypothesis_id": int(hyp["hypothesis_id"]),
                        "subject_id": int(hyp["subject_id"]),
                        "hadm_id": int(hyp["hadm_id"]),
                        "nanda_domain": nanda,
                        "noc_code": noc_code,
                        "nic_code": nic_code,
                        "nic_label": nic_label,
                        "nic_description": nic_desc,
                        "source": source,
                        "confidence_level": "BAIXO",
                        "limitation": "Recomendacao por ligacao NNN; nao validada no MIMIC-IV.",
                    }
                )
    fact_nic_recommended = pd.DataFrame(recommended_rows)
    if not fact_nic_recommended.empty:
        fact_nic_recommended.insert(0, "recommendation_id", range(1, len(fact_nic_recommended) + 1))

    linkage = pd.DataFrame(
        [
            {
                "nanda_domain": nanda,
                "noc_code": noc_code,
                "nic_code": nic_code,
                "nic_label": nic_label,
                "rule_description": nic_desc,
                "source_reference": source,
                "inference_method": "literature_linkage_rule",
                "confidence_level": "BAIXO",
                "limitation_note": "Regra derivada de literatura; requer validacao clinica.",
            }
            for nanda, noc_code, nic_code, nic_label, nic_desc, source in links
        ]
    )
    linkage.insert(0, "rule_id", range(1, len(linkage) + 1))
    return fact_nic_observed, fact_nic_recommended, linkage


def write_table(con: sqlite3.Connection, name: str, df: pd.DataFrame) -> None:
    df.to_sql(name, con, index=False, if_exists="replace")


def export_sqlite_tables_to_csv(con: sqlite3.Connection, data_dir: str | Path) -> None:
    Path(data_dir).mkdir(parents=True, exist_ok=True)
    tables = [row[0] for row in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    for table in tables:
        df = pd.read_sql_query(f'SELECT * FROM "{table}"', con)
        df.to_csv(Path(data_dir) / f"{table}.csv", index=False)


def rebuild_database(
    base_dir: str | Path = BASE_DIR,
    db_path: str | Path = DB_PATH,
    data_dir: str | Path = DATA_DIR,
    model_name: str = DEFAULT_MODEL_NAME,
    top_k: int = DEFAULT_TOP_K,
    export_csv: bool = True,
    test_embedder: bool = False,
) -> None:
    print("=== HYBRID NANDA-I SEMANTIC TRIAGE: KEYWORDS + BIOMEDICAL TRANSFORMER ===")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"Model: {model_name}")

    base_dir = Path(base_dir)
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)

    patients = load_csv(base_dir, "hosp/patients.csv.gz")
    admissions = load_csv(base_dir, "hosp/admissions.csv.gz")
    dx = load_csv(base_dir, "hosp/diagnoses_icd.csv.gz")
    d_icd = load_csv(base_dir, "hosp/d_icd_diagnoses.csv.gz")
    ce = load_csv(base_dir, "icu/chartevents.csv")
    icu = load_csv(base_dir, "icu/icustays.csv.gz")
    emar = load_csv(base_dir, "hosp/emar.csv.gz")
    inp = load_csv(base_dir, "icu/inputevents.csv")

    embedder = build_embedder(model_name, allow_test_hash=test_embedder)
    all_icd_desc = normalize_icd_descriptions(d_icd)
    observed_codes = {str(code).strip() for code in dx["icd_code"].dropna().unique()}
    icd_desc_map = {code: desc for code, desc in all_icd_desc.items() if code in observed_codes}
    icd_to_nanda, candidates = build_icd_mapping(icd_desc_map, embedder=embedder, top_k=top_k)
    mapping_evidence = build_mapping_evidence(dx, ce, icd_desc_map, icd_to_nanda)
    fact_hypothesis = build_fact_hypothesis(mapping_evidence, embedder.model_name)
    fact_noc = build_fact_noc(fact_hypothesis, ce)
    fact_nic_observed, fact_nic_recommended, linkage = build_nic_tables(fact_hypothesis, emar, inp)

    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    try:
        write_table(con, "dim_patient", patients[["subject_id", "gender", "anchor_age", "anchor_year"]])
        write_table(con, "dim_admission", admissions[["subject_id", "hadm_id", "admittime", "dischtime", "admission_type", "discharge_location"]])
        write_table(con, "dim_icustay", icu[["subject_id", "hadm_id", "stay_id", "intime", "outtime", "first_careunit"]])
        write_table(con, "dim_nanda_domain", pd.DataFrame({"domain_id": range(1, len(NANDA_DOMAINS) + 1), "domain_name": [d.name for d in NANDA_DOMAINS]}))
        write_table(con, "mapping_nanda_candidates", candidates)
        write_table(con, "mapping_nanda_evidence", mapping_evidence)
        write_table(con, "fact_nanda_hypothesis", fact_hypothesis)
        write_table(con, "fact_noc_measurement", fact_noc)
        write_table(con, "fact_nic_observed_proxy", fact_nic_observed)
        write_table(con, "fact_nic_recommended", fact_nic_recommended)
        write_table(con, "nnn_linkage_rules", linkage)

        clinical_tables = [
            ("patients", "hosp/patients.csv.gz"),
            ("admissions", "hosp/admissions.csv.gz"),
            ("diagnoses_icd", "hosp/diagnoses_icd.csv.gz"),
            ("d_icd_diagnoses", "hosp/d_icd_diagnoses.csv.gz"),
            ("chartevents", "icu/chartevents.csv"),
            ("icustays", "icu/icustays.csv.gz"),
            ("labevents", "hosp/labevents.csv"),
            ("d_labitems", "hosp/d_labitems.csv.gz"),
            ("microbiologyevents", "hosp/microbiologyevents.csv.gz"),
            ("emar", "hosp/emar.csv.gz"),
            ("emar_detail", "hosp/emar_detail.csv"),
            ("prescriptions", "hosp/prescriptions.csv"),
            ("pharmacy", "hosp/pharmacy.csv.gz"),
            ("poe", "hosp/poe.csv.gz"),
            ("poe_detail", "hosp/poe_detail.csv.gz"),
            ("procedures_icd", "hosp/procedures_icd.csv.gz"),
            ("d_icd_procedures", "hosp/d_icd_procedures.csv.gz"),
            ("d_hcpcs", "hosp/d_hcpcs.csv.gz"),
            ("hcpcsevents", "hosp/hcpcsevents.csv.gz"),
            ("drgcodes", "hosp/drgcodes.csv.gz"),
            ("inputevents", "icu/inputevents.csv"),
            ("outputevents", "icu/outputevents.csv"),
            ("procedureevents", "icu/procedureevents.csv"),
            ("ingredientevents", "icu/ingredientevents.csv.gz"),
            ("datetimeevents", "icu/datetimeevents.csv.gz"),
            ("caregiver", "icu/caregiver.csv"),
            ("d_items", "icu/d_items.csv"),
            ("omr", "hosp/omr.csv"),
            ("transfers", "hosp/transfers.csv"),
            ("provider", "hosp/provider.csv.gz"),
            ("services", "hosp/services.csv"),
        ]
        for table_name, relative_path in clinical_tables:
            try:
                write_table(con, table_name, load_csv(base_dir, relative_path))
            except FileNotFoundError as exc:
                print(f"[WARN] Missing clinical table {relative_path}: {exc}")

        con.commit()
        if export_csv:
            export_sqlite_tables_to_csv(con, data_dir)

        print("\nGenerated tables:")
        for table_name, count in con.execute("SELECT name, 0 FROM sqlite_master WHERE type='table' ORDER BY name"):
            n = con.execute(f'SELECT COUNT(*) FROM "{table_name}"').fetchone()[0]
            print(f"  {table_name:35s}: {n:>10,}")
    finally:
        con.close()

    keyword_count = sum(1 for item in icd_to_nanda.values() if item["method"] == "keyword_match")
    fallback_count = sum(1 for item in icd_to_nanda.values() if item["method"] == "transformer_embedding_fallback")
    print(f"\nKeyword matches: {keyword_count}")
    print(f"Transformer fallback matches: {fallback_count}")
    print(f"Database: {db_path}")
    print("Done.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Rebuild nursing-pool with Transformer semantic fallback.")
    parser.add_argument("--base-dir", default=BASE_DIR, help="MIMIC-IV Demo directory containing hosp/ and icu/.")
    parser.add_argument("--db-path", default=DB_PATH, help="SQLite database output path.")
    parser.add_argument("--data-dir", default=DATA_DIR, help="CSV export directory used by the static site.")
    parser.add_argument("--model-name", default=os.getenv("NURSING_POOL_MODEL", DEFAULT_MODEL_NAME), help="Biomedical Transformer model name.")
    parser.add_argument("--top-k", type=int, default=DEFAULT_TOP_K, help="Number of NANDA-I candidates to audit per unmatched ICD description.")
    parser.add_argument("--no-export-csv", action="store_true", help="Skip CSV export to data/.")
    parser.add_argument("--test-embedder", action="store_true", help="Use deterministic local embedder for smoke tests only.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rebuild_database(
        base_dir=args.base_dir,
        db_path=args.db_path,
        data_dir=args.data_dir,
        model_name=args.model_name,
        top_k=args.top_k,
        export_csv=not args.no_export_csv,
        test_embedder=args.test_embedder,
    )


if __name__ == "__main__":
    main()
