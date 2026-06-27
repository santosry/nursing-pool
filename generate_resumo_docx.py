# =============================================================================
# generate_resumo_docx.py — Preenche o template CONEPE 2026 preservando formatação
# =============================================================================

from docx import Document
from docx.shared import Pt, Inches
import copy
import os

TEMPLATE = r"C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\Template_Resumo_Expandido_2026.docx"
OUTPUT = r"C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\mimic_nursing_poc\output\RESUMO_EXPANDIDO_CONEPE_2026.docx"

doc = Document(TEMPLATE)

# Mapear parágrafos existentes pelo índice (0-based no python-docx)
paragraphs = doc.paragraphs

# --- TÍTULO (índice 0) ---
paragraphs[0].text = "Modelo conceitual e prova de conceito computacional para estruturação de dados de enfermagem em sistemas de informação em saúde com uso do MIMIC-IV"

# --- AUTORES (índice 1) ---
paragraphs[1].text = "R.P. Santos1*"

# --- AFILIAÇÃO (índice 2) ---
paragraphs[2].text = "1Universidade [NOME DA INSTITUIÇÃO], [CIDADE], [ESTADO]"

# --- EMAIL (índice 3) ---
paragraphs[3].text = "*E-mail do autor correspondente: [email@instituicao.edu.br] | ORCID: 0009-0005-6770-2001"

# --- "Resumo" heading (índice 4) — manter ---

# --- RESUMO (índice 5) — substituir pelo texto real ---
resumo_text = (
    "Este estudo tem como objetivo propor um modelo conceitual para estruturação de dados de enfermagem em "
    "sistemas de informação em saúde e desenvolver prova de conceito computacional utilizando o MIMIC-IV como "
    "base clínica de demonstração. O pipeline implementado em R gera banco relacional SQLite com 9 tabelas "
    "(3 dimensionais e 6 fato) que organizam diagnósticos (camada NANDA-I), resultados (camada NOC) e "
    "intervenções (camada NIC) como derivações exploratórias a partir de variáveis clínicas, sem afirmar "
    "registro nativo dessas classificações no MIMIC-IV. No modo sintético público, o pipeline processou "
    "686.893 registros (2.000 pacientes simulados) em 34,4 segundos. Modelos de aprendizado de máquina foram "
    "testados exclusivamente para avaliar a operacionalidade analítica da base, apresentando desempenho "
    "discriminativo próximo ao acaso (AUC 0,488-0,534), reforçando que a contribuição principal do estudo "
    "está na demonstração de viabilidade computacional, não na predição clínica. Conclui-se que a arquitetura "
    "proposta demonstra viabilidade técnica para construir camada analítica de enfermagem sobre bases "
    "clínicas biomédicas, embora requeira validação por especialistas e testes com dados reais de "
    "prontuário de enfermagem."
)
paragraphs[5].text = resumo_text

# --- PALAVRAS-CHAVE (índice 6) ---
paragraphs[6].text = "Palavras-chave: Informática em Enfermagem; Terminologias Padronizadas em Enfermagem; MIMIC-IV; Interoperabilidade; Enfermagem de Precisão."

# --- 1. INTRODUÇÃO (índice 8) — substituir placeholder ---
intro = (
    "Os sistemas de informação em saúde evoluíram significativamente nas últimas décadas, mas grande parte "
    "dos bancos de dados clínicos permanece centrada no registro de doenças, exames, procedimentos, "
    "medicamentos e desfechos biomédicos [1,2]. Em contrapartida, os dados relacionados ao processo de "
    "enfermagem — incluindo diagnósticos, intervenções e resultados — permanecem sub-representados de forma "
    "estruturada nos ambientes digitais, contribuindo para a invisibilidade do trabalho da enfermagem e "
    "limitando a produção de evidências científicas sobre o impacto do cuidado [3,4].\n\n"
    "Estudos recentes apontam que a ausência de dados padronizados de enfermagem restringe a aplicação de "
    "técnicas de inteligência artificial e aprendizado de máquina no contexto assistencial, perpetuando um "
    "ciclo de sub-representação da profissão nas bases de dados clínicas [4,5]. A Resolução COFEN nº 736/2024 "
    "torna obrigatória a implementação do Processo de Enfermagem em todos os serviços de saúde brasileiros, "
    "exigindo sistemas capazes de registrar sistematicamente suas cinco etapas [6].\n\n"
    "Nesse contexto, terminologias padronizadas como NANDA-I (diagnósticos), NIC (intervenções) e NOC "
    "(resultados) foram desenvolvidas para representar o cuidado de enfermagem, e sua utilização integrada "
    "— ligação NNN — favorece a comunicação entre profissionais [7,8,9]. Revisão sistemática conduzida por "
    "Bertocchi et al. [10] evidenciou que a adoção de terminologias padronizadas está associada à melhora "
    "significativa na qualidade da documentação (OR = 2,15; IC 95%: 1,54-3,01). O Nursing Minimum Data Set "
    "(NMDS) e padrões de interoperabilidade como HL7 FHIR, openEHR e SNOMED CT oferecem arcabouço técnico "
    "para representação semântica de dados clínicos [11,12,13].\n\n"
    "Este estudo propõe um modelo conceitual para estruturação de dados de enfermagem e desenvolve prova de "
    "conceito computacional utilizando o MIMIC-IV [14] como base clínica de demonstração. Cumpre esclarecer "
    "que o MIMIC-IV não contém registros originais nas classificações NANDA-I, NIC ou NOC documentados por "
    "enfermeiros. O que se constrói é uma camada derivada, experimental e reprodutível de mapeamento "
    "computacional, organizando variáveis clínicas disponíveis em uma arquitetura relacional orientada pelos "
    "domínios dessas classificações."
)
paragraphs[8].text = intro

# --- 2. MATERIAIS E MÉTODOS (índice 24, subseções em 23,25) ---
# Remover conteúdo das subseções do template e substituir pela seção unificada
metodos = (
    "Trata-se de estudo de desenvolvimento metodológico com prova de conceito computacional. O pipeline foi "
    "implementado em R 4.6.0, operando em dois modos: (a) modo sintético público (2.000 pacientes, 3.500 "
    "admissões, 1.200 estadias em UTI) para demonstração e reprodutibilidade via GitHub; e (b) modo real "
    "restrito, executável exclusivamente por usuários credenciados no PhysioNet com acesso ao MIMIC-IV v3.1. "
    "Dados reais não são redistribuídos ou versionados no repositório público.\n\n"
    "A arquitetura do banco adota modelo relacional com tabelas dimensionais (dim_patient, dim_admission, "
    "dim_icustay, dim_nanda_domain, dim_noc_outcome, dim_nic_intervention) e tabelas fato (fact_nanda, "
    "fact_noc, fact_nic). O mapeamento NANDA-I foi realizado por duas vias: (i) mapeamento direto de códigos "
    "ICD-10 para domínios NANDA; e (ii) inferência a partir de sinais vitais anormais, exames laboratoriais "
    "alterados e avaliações clínicas (Braden, GCS, RASS, dor). O mapeamento NOC derivou indicadores de "
    "resultado de variáveis clínicas seriadas com cálculo de tendências temporais. O mapeamento NIC derivou "
    "intervenções de registros de administração de medicamentos (eMAR), fluidos intravenosos, nutrição "
    "enteral e procedimentos documentados.\n\n"
    "Todas as análises foram implementadas com semente fixa (20240101) para reprodutibilidade determinística. "
    "As análises estatísticas incluíram: estatísticas descritivas com IC 95% (Wilson), teste qui-quadrado "
    "com correção de Bonferroni, teste U de Mann-Whitney, teste de Kruskal-Wallis com post-hoc de Dunn "
    "(correção FDR), correlação de Spearman, regressão logística multivariada com odds ratios e curva ROC, "
    "e análise de sobrevivência pelo método de Kaplan-Meier com teste de log-rank. Como etapa complementar "
    "exploratória, foram testados quatro algoritmos de aprendizado de máquina (regressão logística, GLM "
    "com penalização LASSO, Random Forest e XGBoost) exclusivamente para avaliar a operacionalidade "
    "analítica da base, sem finalidade clínica ou preditiva validada. O repositório público (GitHub, "
    "licença MIT) contém código, documentação, scripts de geração de dados sintéticos, figuras agregadas, "
    "Dockerfile, renv.lock com 138 pacotes e instruções de reprodutibilidade."
)
paragraphs[24].text = metodos
# Limpar subseções do template (índices 23 e 25)
if len(paragraphs) > 25:
    paragraphs[23].text = ""
    paragraphs[25].text = ""

# --- 3. RESULTADOS E DISCUSSÃO (índice 27) ---
resultados = (
    "O pipeline foi executado integralmente em 34,4 segundos, processando 686.893 registros em 9 tabelas "
    "(throughput aproximado de 20.000 registros/segundo). A camada NANDA-I gerou 45.745 diagnósticos "
    "derivados, distribuídos em quatro fontes de evidência: ICD-10 (42,4%), sinais vitais anormais (33,6%), "
    "exames laboratoriais (21,3%) e avaliações clínicas (2,7%). A taxa de mapeamento ICD-10 → NANDA foi de "
    "72,0%. Os domínios mais prevalentes foram Cardiovascular (98,8%), Conforto (95,8%) e Segurança/Proteção "
    "(92,5%). A média de diagnósticos inferidos por paciente foi de 22,9 (DP = 4,9), com 9,0 domínios "
    "distintos por paciente.\n\n"
    "A camada NOC gerou 243.718 indicadores de resultado, abrangendo 12 indicadores. Os maiores percentuais "
    "de anormalidade foram observados em frequência cardíaca (71,0%), intensidade da dor (53,5%) e pressão "
    "arterial sistólica (46,9%). A camada NIC gerou 390.699 registros de intervenções em 8 categorias, "
    "com predomínio de Administração de Medicamentos (NIC 2300, 81,9%) e Terapia Intravenosa (NIC 4200, "
    "11,6%). A análise de correlação de Spearman entre diagnósticos NANDA e indicadores NOC anormais foi "
    "positiva (ρ = 0,414; p < 0,0001), sugerindo coerência estrutural entre as camadas derivadas.\n\n"
    "Os modelos de aprendizado de máquina apresentaram desempenho discriminativo próximo ao acaso em todos "
    "os algoritmos testados: regressão logística (AUC = 0,515), GLM LASSO (AUC = 0,502), Random Forest "
    "(AUC = 0,488) e XGBoost (AUC = 0,534). Estes resultados reforçam que a contribuição principal do "
    "estudo não está na predição clínica, mas na demonstração da viabilidade computacional de uma "
    "arquitetura relacional para dados derivados de enfermagem. A ausência de sinal preditivo é esperada "
    "para dados sintéticos gerados sem estrutura causal e não invalida a prova de conceito.\n\n"
    "A principal contribuição deste estudo consiste na construção de uma ponte metodológica entre grandes "
    "bases de dados clínicos — tradicionalmente organizadas em torno de doenças, exames, procedimentos e "
    "medicamentos — e uma ontologia operacional de enfermagem baseada em terminologias padronizadas. "
    "As limitações incluem: dados exclusivamente sintéticos, mapeamento sem validação por especialistas, "
    "ausência de registros originais de enfermagem no MIMIC-IV e desempenho preditivo insuficiente para "
    "uso clínico."
)
paragraphs[27].text = resultados

# --- 4. CONCLUSÕES (índice 29) ---
conclusoes = (
    "O objetivo foi alcançado em nível de prova de conceito. O trabalho demonstrou viabilidade computacional "
    "de estruturar dados clínicos em uma arquitetura relacional orientada à enfermagem, composta por 9 "
    "tabelas que organizam diagnósticos (camada NANDA-I), resultados (camada NOC) e intervenções (camada "
    "NIC) como derivações exploratórias a partir de variáveis originalmente presentes em bases clínicas "
    "biomédicas. A principal contribuição é a construção de infraestrutura metodológica para aumentar a "
    "visibilidade do cuidado de enfermagem nos sistemas de informação em saúde, subsidiar auditorias de "
    "qualidade e oferecer base para futuras aplicações em enfermagem de precisão. Estudos futuros deverão "
    "submeter o mapeamento à validação por especialistas, testar o modelo em dados reais do MIMIC-IV com "
    "acesso credenciado ao PhysioNet, aplicar o pipeline a dados originais de prontuário de enfermagem e "
    "avaliar a conformidade com perfis HL7 FHIR e arquétipos openEHR para documentação estruturada de "
    "enfermagem."
)
paragraphs[29].text = conclusoes

# --- AGRADECIMENTOS (índice 31) ---
paragraphs[31].text = (
    "Agradecimentos (a preencher conforme orientação do congresso e agências de fomento)."
)

# --- REFERÊNCIAS (índice 33) ---
referencias = (
    "[1] SAUD, M.A. et al. Integrating genomics and digital health in precision nursing. Saudi Journal of Medicine and Public Health, v. 1, n. 2, p. 1521-1527, 2024.\n"
    "[2] HANTS, L.; BAIL, K.; PATERSON, C. Clinical decision-making and the nursing process in digital health systems: an integrated systematic review. Journal of Clinical Nursing, v. 32, n. 19-20, p. 7010-7035, 2023.\n"
    "[3] MICHALOWSKI, M.; TOPAZ, M.; PELTONEN, L.M. An AI-enabled nursing future with no documentation burden. Journal of Advanced Nursing, v. 81, n. 1, p. 907-912, 2026.\n"
    "[4] PORCELLATO, E. et al. Exploring applications of artificial intelligence in critical care nursing: a systematic review. Nursing Reports, v. 15, n. 2, p. 55, 2025.\n"
    "[5] HE, X.; YOU, G. Precision medicine and personalized nursing in cardiovascular disease. Frontiers in Cardiovascular Medicine, v. 12, p. 1552816, 2025.\n"
    "[6] CONSELHO FEDERAL DE ENFERMAGEM. Resolução COFEN nº 736, de 17 de janeiro de 2024. Diário Oficial da União, 2024.\n"
    "[7] HERDMAN, T.H.; KAMITSURU, S.; LOPES, C.T. (ed.). NANDA International nursing diagnoses: definitions and classification 2024-2026. 13. ed. New York: Thieme, 2024.\n"
    "[8] BUTCHER, H.K. et al. Nursing Interventions Classification (NIC). 8. ed. St. Louis: Elsevier, 2024.\n"
    "[9] MOORHEAD, S. et al. Nursing Outcomes Classification (NOC): measurement of health outcomes. 7. ed. St. Louis: Elsevier, 2024.\n"
    "[10] BERTOCCHI, L. et al. Impact of standardized nursing terminologies on patient and organizational outcomes: a systematic review and meta-analysis. Journal of Nursing Scholarship, v. 55, n. 6, p. 1126-1141, 2023.\n"
    "[11] FREGUIA, F. et al. Nursing minimum data sets: findings from an umbrella review. Journal of Advanced Nursing, v. 79, n. 4, p. 1241-1255, 2023.\n"
    "[12] BENSON, T.; GRIEVE, G. Principles of health interoperability: FHIR, HL7 and SNOMED CT. 4. ed. Cham: Springer, 2021.\n"
    "[13] KALRA, D.; BEALE, T.; HEARD, S. The openEHR foundation. Studies in Health Technology and Informatics, v. 115, p. 153-173, 2005.\n"
    "[14] JOHNSON, A.E.W. et al. MIMIC-IV, a freely accessible electronic health record dataset. Scientific Data, v. 10, p. 31, 2023."
)
paragraphs[33].text = referencias

# --- Nota sobre IA generativa (índice 32, após agradecimentos) ---
# Inserir nota de rodapé nos agradecimentos
ia_note = (
    "Declaração de uso de IA generativa (Portaria CNPq nº 2.664/2026): Foram utilizadas ferramentas de "
    "inteligência artificial generativa (ChatGPT 5.5, DeepSeek-v4-Pro, Grok) no apoio à concepção, "
    "organização metodológica, revisão textual, depuração de código e sugestões de auditoria. As "
    "ferramentas não são autoras, não substituíram o julgamento científico humano e não isentam os "
    "autores da responsabilidade integral pelo conteúdo final."
)
paragraphs[32].text = ia_note

# --- Remover parágrafos extras de exemplo que sobraram (equações, tabela exemplo) ---
# Limpar parágrafos de exemplo (índices 10-21, 34-49)
for i in [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]:
    if i < len(paragraphs):
        paragraphs[i].text = ""

# Salvar
doc.save(OUTPUT)
print(f"Resumo expandido salvo em: {OUTPUT}")
print(f"Tamanho: {os.path.getsize(OUTPUT):,} bytes")
