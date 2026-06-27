# =============================================================================
# preencher_template.py — Preenche o template CONEPE 2026 com o resumo expandido
# preservando 100% da formatação original (fontes, margens, estilos, espaçamento)
# =============================================================================

from docx import Document
from docx.shared import Pt, Inches
import copy, os

TEMPLATE = r"C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\Template_Resumo_Expandido_2026.docx"
OUTPUT = r"C:\Users\oorie\OneDrive\Documentos\TRABALHOS\PROVA DE CONCEITO\Template_Resumo_Expandido_2026.docx"

doc = Document(TEMPLATE)
p = doc.paragraphs

# =========================================================================
# ÍNDICE 0: TÍTULO
# =========================================================================
p[0].text = (
    "Modelo conceitual e prova de conceito computacional para estruturação "
    "de dados de enfermagem em sistemas de informação em saúde com uso do MIMIC-IV"
)

# =========================================================================
# ÍNDICE 1: AUTORES
# =========================================================================
p[1].text = "R.P. Santos1*"

# =========================================================================
# ÍNDICE 2: AFILIAÇÃO
# =========================================================================
p[2].text = "1[Instituição de vínculo — a preencher]"

# =========================================================================
# ÍNDICE 3: E-MAIL
# =========================================================================
p[3].text = "*E-mail do autor correspondente: [email] | ORCID: 0009-0005-6770-2001"

# =========================================================================
# ÍNDICE 4: "Resumo" (heading — manter)
# =========================================================================

# =========================================================================
# ÍNDICE 5: RESUMO (parágrafo único, ≤150 palavras, tamanho 11)
# =========================================================================
p[5].text = (
    "Este estudo propõe um modelo conceitual para estruturação de dados de "
    "enfermagem em sistemas de informação em saúde e desenvolve prova de conceito "
    "computacional utilizando o MIMIC-IV como base clínica de demonstração. "
    "Ressalta-se que o MIMIC-IV não contém registros originais nas classificações "
    "NANDA-I, NIC ou NOC documentados por enfermeiros. O que se constrói é uma "
    "camada derivada e exploratória de mapeamento computacional: variáveis clínicas "
    "existentes (sinais vitais, exames laboratoriais, códigos ICD-10, medicamentos "
    "administrados, fluidos intravenosos) são reorganizadas em uma arquitetura "
    "relacional orientada pelos domínios dessas classificações. O pipeline em R gera "
    "banco SQLite com 9 tabelas (dimensionais e fato) processando 686.893 registros. "
    "Conclui-se que a arquitetura demonstra viabilidade computacional para construir "
    "camada analítica de enfermagem sobre bases clínicas biomédicas, embora requeira "
    "validação por especialistas e testes com dados reais de prontuário de enfermagem."
)

# =========================================================================
# ÍNDICE 6: PALAVRAS-CHAVE
# =========================================================================
p[6].text = (
    "Palavras-chave: Informática em Enfermagem; Terminologias Padronizadas em "
    "Enfermagem; MIMIC-IV; Interoperabilidade; Enfermagem de Precisão."
)

# =========================================================================
# ÍNDICE 7: heading vazio entre keywords e introdução — manter
# =========================================================================

# =========================================================================
# ÍNDICE 8: 1. INTRODUÇÃO
# =========================================================================
# O índice 8 contém o texto da introdução
intro = (
    "Os sistemas de informação em saúde evoluíram significativamente, mas grande "
    "parte dos bancos de dados clínicos permanece centrada no registro de doenças, "
    "exames, procedimentos, medicamentos e desfechos biomédicos [1,2]. Em "
    "contrapartida, os dados relacionados ao processo de enfermagem — incluindo "
    "diagnósticos, intervenções e resultados — permanecem sub-representados de forma "
    "estruturada nos ambientes digitais, contribuindo para a invisibilidade do "
    "trabalho da enfermagem [3,4]. A Resolução COFEN nº 736/2024 torna obrigatória "
    "a implementação do Processo de Enfermagem em todos os serviços de saúde "
    "brasileiros [5].\n\n"
    "Esclarecimento metodológico fundamental: o MIMIC-IV [6] é um banco de dados "
    "clínico de terapia intensiva que NÃO contém diagnósticos de enfermagem "
    "registrados segundo a taxonomia NANDA-I, NÃO contém intervenções codificadas "
    "segundo a NIC e NÃO contém resultados mensurados segundo a NOC. O MIMIC-IV "
    "armazena dados típicos de prontuário eletrônico centrado no modelo biomédico: "
    "códigos ICD-10 de diagnósticos médicos, sinais vitais aferidos (frequência "
    "cardíaca, pressão arterial, SpO₂, temperatura), resultados de exames "
    "laboratoriais (creatinina, hemoglobina, glicose, eletrólitos), registros de "
    "administração de medicamentos (eMAR), balanço hídrico (fluidos infundidos, "
    "débito urinário), escalas de avaliação (Glasgow, RASS, Braden) e notas "
    "clínicas textuais. O que este estudo faz — e esta distinção é central para a "
    "validade da proposta — é construir uma camada de inferência computacional que "
    "reorganiza essas variáveis clínicas brutas em uma arquitetura relacional "
    "orientada pelos 13 domínios da NANDA-I [7], pelas 7 classes da NOC [8] e "
    "pelos 7 domínios da NIC [9].\n\n"
    "A inferência NANDA-I opera por duas vias complementares. A primeira via mapeia "
    "códigos ICD-10 para domínios NANDA utilizando tabela de correspondência "
    "conceitual — por exemplo, códigos E40-E46 (desnutrição) são associados ao "
    "domínio Nutrição, códigos I50-I51 (insuficiência cardíaca) ao domínio "
    "Cardiovascular, e códigos A41 (sepse) e J15-J18 (pneumonia) ao domínio "
    "Segurança/Proteção. A segunda via infere diagnósticos a partir de limiares "
    "clínicos: taquicardia documentada (FC > 100 bpm) é mapeada para \"Risco de "
    "débito cardíaco diminuído\", hipoxemia (SpO₂ < 92%) para \"Troca de gases "
    "prejudicada\", GCS ≤ 8 para \"Perfusão tissular cerebral ineficaz\", Braden "
    "≤ 12 para \"Risco de úlcera por pressão\", e dor ≥ 7/10 para \"Dor aguda\". "
    "A inferência NOC deriva indicadores de resultado de variáveis clínicas "
    "seriadas com cálculo de tendências temporais. A inferência NIC deriva "
    "intervenções de registros de administração de medicamentos (eMAR → NIC 2300), "
    "fluidos intravenosos (inputevents → NIC 4200), nutrição enteral (NIC 1056) e "
    "procedimentos documentados (NIC 3540, 0840).\n\n"
    "Este estudo insere-se no contexto da enfermagem de precisão e da saúde digital, "
    "onde a ausência de dados padronizados de enfermagem limita o desenvolvimento "
    "de ferramentas de inteligência artificial e a produção de indicadores sensíveis "
    "à prática profissional [10,11]. A contribuição não está em \"descobrir\" "
    "NANDA/NIC/NOC dentro do MIMIC-IV, mas em demonstrar que é computacionalmente "
    "viável construir uma ponte metodológica entre grandes bases clínicas biomédicas "
    "e uma ontologia operacional de enfermagem baseada em terminologias padronizadas "
    "[12,13]."
)
p[8].text = intro

# =========================================================================
# ÍNDICES 9-21: parágrafos de exemplo do template — limpar
# =========================================================================
for i in [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]:
    if i < len(p):
        p[i].text = ""

# =========================================================================
# ÍNDICE 22: "2. Materiais e Métodos" (heading — manter)
# =========================================================================

# =========================================================================
# ÍNDICE 23: "2.1. Materiais" — limpar
# =========================================================================
p[23].text = ""

# =========================================================================
# ÍNDICE 24: texto materiais (placeholder) — substituir
# =========================================================================
metodos = (
    "Trata-se de estudo de desenvolvimento metodológico com prova de conceito "
    "computacional. O pipeline foi implementado em R 4.6.0, operando em dois modos "
    "distintos com propósitos e restrições diferentes.\n\n"
    "Modo sintético público: gera dados inteiramente simulados (2.000 pacientes, "
    "3.500 admissões, 1.200 estadias em UTI) utilizando distribuições paramétricas "
    "independentes. Este modo permite demonstração, testes automatizados e "
    "reprodutibilidade pública via GitHub (licença MIT). Os dados simulados mimetizam "
    "a estrutura das tabelas MIMIC-IV (chartevents, labevents, inputevents, "
    "outputevents, emar, diagnoses_icd, prescriptions, omr, procedureevents), mas "
    "não representam complexidade clínica real.\n\n"
    "Modo real restrito: executável exclusivamente por usuários credenciados no "
    "PhysioNet (https://physionet.org/content/mimiciv/) com acesso autorizado aos "
    "arquivos CSV do MIMIC-IV v3.1. O processo de acesso exige: (a) cadastro no "
    "PhysioNet; (b) conclusão do curso \"CITI Data or Specimens Only Research\" "
    "com certificação válida; (c) submissão de formulário de solicitação de acesso "
    "descrevendo o uso pretendido dos dados; (d) assinatura do Data Use Agreement "
    "(DUA) que proíbe redistribuição dos dados e exige compromisso de não "
    "reidentificação de pacientes. Após aprovação (tipicamente 2-5 dias úteis), "
    "os arquivos CSV são disponibilizados para download. O pipeline é então "
    "executado com `Rscript pipeline.R --mode=real --data_dir=/caminho/mimic-iv`. "
    "Dados reais do MIMIC-IV JAMAIS são redistribuídos, versionados ou incluídos "
    "no repositório público — o `.gitignore` bloqueia qualquer arquivo `.csv.gz`, "
    "`.parquet` ou diretório `mimiciv/`, `physionet/`, `raw/`.\n\n"
    "A arquitetura do banco adota modelo relacional implementado em SQLite (DuckDB "
    "como alternativa de maior desempenho). As tabelas dimensionais incluem: "
    "dim_patient (dados demográficos), dim_admission (informações de internação), "
    "dim_icustay (estadias em UTI), dim_nanda_domain (13 domínios NANDA-I), "
    "dim_noc_outcome (8 indicadores NOC) e dim_nic_intervention (10 categorias NIC). "
    "As tabelas fato incluem: fact_nanda (diagnósticos inferidos — cada linha "
    "representa uma associação entre uma admissão e um domínio NANDA, com a "
    "evidência clínica que a originou), fact_noc (resultados derivados — cada "
    "linha representa uma medição de indicador com valor, unidade e classificação "
    "de anormalidade) e fact_nic (intervenções derivadas — cada linha representa "
    "uma ação de cuidado inferida a partir de registros assistenciais).\n\n"
    "Todas as análises foram implementadas com semente fixa (20240101) garantindo "
    "reprodutibilidade determinística. As análises estatísticas incluíram: "
    "estatísticas descritivas com IC 95% (método de Wilson), teste qui-quadrado "
    "com correção de Bonferroni, teste U de Mann-Whitney, teste de Kruskal-Wallis "
    "com post-hoc de Dunn (correção FDR), correlação de Spearman, regressão "
    "logística multivariada e análise de Kaplan-Meier. Como etapa complementar "
    "exploratória — sem finalidade clínica ou preditiva validada — foram testados "
    "quatro algoritmos de aprendizado de máquina para avaliar a operacionalidade "
    "analítica da base. O repositório público (GitHub, licença MIT) contém código, "
    "documentação, Dockerfile, renv.lock com 138 pacotes e instruções de "
    "reprodutibilidade, sem dados reais de pacientes."
)
p[24].text = metodos

# =========================================================================
# ÍNDICE 25: "2.2. Metodologia" — limpar
# =========================================================================
p[25].text = ""

# =========================================================================
# ÍNDICE 26: vazio — manter
# =========================================================================

# =========================================================================
# ÍNDICE 27: "3. Resultados e Discussão" (heading — manter, índice 27 é o texto)
# =========================================================================

# =========================================================================
# ÍNDICE 28: texto resultados (placeholder) — substituir
# =========================================================================
resultados = (
    "O pipeline foi executado integralmente em 34,4 segundos (modo sintético), "
    "processando 686.893 registros em 9 tabelas, com throughput aproximado de "
    "20.000 registros/segundo em hardware convencional. O banco SQLite gerado "
    "(nursing_db.sqlite) possui 12,3 MB e estrutura relacional completa.\n\n"
    "Camada NANDA-I: foram gerados 45.745 registros de diagnósticos inferidos, "
    "distribuídos em quatro fontes de evidência: mapeamento ICD-10 (42,4%), sinais "
    "vitais anormais (33,6%), exames laboratoriais alterados (21,3%) e avaliações "
    "clínicas OMR (2,7%). A taxa de mapeamento ICD-10 → domínios NANDA foi de "
    "72,0% dos códigos diagnósticos presentes na base. Os domínios mais prevalentes "
    "foram Cardiovascular (98,8% dos pacientes), Conforto (95,8%) e "
    "Segurança/Proteção (92,5%). A média de diagnósticos inferidos por paciente "
    "foi de 22,9 (DP = 4,9), com média de 9,0 domínios NANDA distintos por "
    "paciente.\n\n"
    "Camada NOC: foram gerados 243.718 indicadores de resultado, abrangendo 12 "
    "indicadores distintos. Os maiores percentuais de anormalidade foram observados "
    "em frequência cardíaca (71,0% das medições acima de 100 bpm), intensidade da "
    "dor (53,5% com NRS ≥ 7) e pressão arterial sistólica (46,9% fora dos limites "
    "de referência). A correlação de Spearman entre o número de diagnósticos NANDA "
    "e o número de indicadores NOC anormais foi positiva (ρ = 0,414; p < 0,0001), "
    "sugerindo coerência estrutural entre as camadas derivadas — embora este "
    "achado deva ser interpretado como evidência preliminar de consistência interna "
    "do mapeamento, não como validação clínica.\n\n"
    "Camada NIC: foram gerados 390.699 registros de intervenções derivadas, "
    "distribuídos em 8 categorias NIC. A intervenção mais frequente foi "
    "Administração de Medicamentos (NIC 2300, 81,9% dos registros), seguida por "
    "Terapia Intravenosa (NIC 4200, 11,6%) e Nutrição Enteral (NIC 1056, 2,9%). "
    "A via intravenosa foi a mais utilizada (40,0%), seguida pela via oral (30,2%).\n\n"
    "Modelos de aprendizado de máquina: os quatro algoritmos testados — "
    "exclusivamente para avaliar a operacionalidade analítica da base, sem "
    "finalidade clínica — apresentaram desempenho discriminativo próximo ao acaso: "
    "regressão logística (AUC = 0,515), GLM LASSO (AUC = 0,502), Random Forest "
    "(AUC = 0,472) e XGBoost (AUC = 0,588). A ausência de sinal preditivo é "
    "esperada para dados sintéticos gerados sem estrutura causal e não invalida "
    "a prova de conceito — ao contrário, reforça que a contribuição principal do "
    "estudo está na demonstração da viabilidade computacional da arquitetura "
    "relacional proposta, não na capacidade preditiva dos modelos.\n\n"
    "A principal contribuição deste estudo consiste na construção de uma ponte "
    "metodológica entre grandes bases de dados clínicos — tradicionalmente "
    "organizadas em torno de doenças, exames, procedimentos e medicamentos — e "
    "uma ontologia operacional de enfermagem. Esta infraestrutura é potencialmente "
    "aplicável a: (a) aumento da visibilidade do cuidado de enfermagem nos sistemas "
    "de informação; (b) produção de indicadores sensíveis à prática profissional; "
    "(c) auditoria de qualidade do cuidado; e (d) base para futuras aplicações de "
    "inteligência artificial em enfermagem de precisão."
)
# O índice do texto de resultados pode variar. Vamos localizar após o heading.
resultados_heading_idx = None
for i, para in enumerate(p):
    if "Resultados e Discussão" in para.text and i > 25:
        resultados_heading_idx = i
        break

if resultados_heading_idx:
    # O texto de resultados é o próximo parágrafo após o heading
    texto_idx = resultados_heading_idx + 1
    if texto_idx < len(p):
        p[texto_idx].text = resultados

# =========================================================================
# ÍNDICE 29+: "4. Conclusões"
# =========================================================================
conclusoes = (
    "O objetivo foi alcançado em nível de prova de conceito. O trabalho demonstrou "
    "viabilidade computacional de estruturar dados clínicos em uma arquitetura "
    "relacional orientada à enfermagem, composta por 9 tabelas que organizam "
    "diagnósticos (camada NANDA-I inferida), resultados (camada NOC derivada) e "
    "intervenções (camada NIC derivada) como mapeamentos exploratórios a partir de "
    "variáveis originalmente presentes em bases clínicas biomédicas. A principal "
    "contribuição é a construção de infraestrutura metodológica para enfermagem de "
    "precisão, oferecendo base para futuras aplicações de IA e indicadores sensíveis "
    "à prática profissional. Reafirma-se que NANDA-I, NIC e NOC não são registros "
    "originais do MIMIC-IV — constituem uma camada derivada, experimental e "
    "reprodutível que necessita validação por especialistas antes de qualquer "
    "extensão para uso assistencial."
)
# Localizar heading "Conclusões"
for i, para in enumerate(p):
    if "Conclusões" in para.text and i > 30:
        conc_heading_idx = i
        texto_idx = i + 1
        if texto_idx < len(p):
            p[texto_idx].text = conclusoes
        break

# =========================================================================
# AGRADECIMENTOS
# =========================================================================
for i, para in enumerate(p):
    if "Agradecimentos" in para.text and i > 35:
        agradecimentos_idx = i
        if i + 1 < len(p):
            p[i + 1].text = (
                "Agradecimentos (a preencher conforme orientação do congresso "
                "e agências de fomento).\n\n"
                "Declaração de uso de IA generativa (Portaria CNPq nº 2.664/2026): "
                "Foram utilizadas ferramentas de inteligência artificial generativa "
                "(ChatGPT 5.5, DeepSeek-v4-Pro, Grok) no apoio à concepção, "
                "organização metodológica, revisão textual, depuração de código e "
                "sugestões de auditoria. As ferramentas não são autoras, não "
                "substituíram o julgamento científico humano e não isentam os "
                "autores da responsabilidade integral pelo conteúdo final."
            )
        break

# =========================================================================
# REFERÊNCIAS
# =========================================================================
for i, para in enumerate(p):
    if "Referências" in para.text and i > 42:
        ref_idx = i
        if i + 1 < len(p):
            p[i + 1].text = (
                "[1] SAUD, M.A. et al. Integrating genomics and digital health in "
                "precision nursing. Saudi J. Med. Public Health, v. 1, n. 2, p. "
                "1521-1527, 2024.\n"
                "[2] HANTS, L.; BAIL, K.; PATERSON, C. Clinical decision-making "
                "and the nursing process in digital health systems. J. Clin. Nurs., "
                "v. 32, n. 19-20, p. 7010-7035, 2023.\n"
                "[3] MICHALOWSKI, M.; TOPAZ, M.; PELTONEN, L.M. An AI-enabled "
                "nursing future with no documentation burden. J. Adv. Nurs., v. "
                "81, n. 1, p. 907-912, 2026.\n"
                "[4] PORCELLATO, E. et al. Exploring applications of artificial "
                "intelligence in critical care nursing. Nurs. Rep., v. 15, n. 2, "
                "p. 55, 2025.\n"
                "[5] CONSELHO FEDERAL DE ENFERMAGEM. Resolução COFEN nº 736, de "
                "17 de janeiro de 2024. Diário Oficial da União, 2024.\n"
                "[6] JOHNSON, A.E.W. et al. MIMIC-IV, a freely accessible "
                "electronic health record dataset. Sci. Data, v. 10, p. 31, 2023.\n"
                "[7] HERDMAN, T.H.; KAMITSURU, S.; LOPES, C.T. (ed.). NANDA "
                "International nursing diagnoses: definitions and classification "
                "2024-2026. 13. ed. New York: Thieme, 2024.\n"
                "[8] MOORHEAD, S. et al. Nursing Outcomes Classification (NOC). "
                "7. ed. St. Louis: Elsevier, 2024.\n"
                "[9] BUTCHER, H.K. et al. Nursing Interventions Classification "
                "(NIC). 8. ed. St. Louis: Elsevier, 2024.\n"
                "[10] HE, X.; YOU, G. Precision medicine and personalized nursing "
                "in cardiovascular disease. Front. Cardiovasc. Med., v. 12, p. "
                "1552816, 2025.\n"
                "[11] RODRÍGUEZ-SUÁREZ, C.A. et al. Effectiveness of a "
                "standardized nursing process using NANDA, NIC and NOC "
                "terminologies. Healthcare, v. 11, n. 17, p. 2449, 2023.\n"
                "[12] BENSON, T.; GRIEVE, G. Principles of health "
                "interoperability: FHIR, HL7 and SNOMED CT. 4. ed. Cham: "
                "Springer, 2021.\n"
                "[13] FREGUIA, F. et al. Nursing minimum data sets: findings from "
                "an umbrella review. J. Adv. Nurs., v. 79, n. 4, p. 1241-1255, "
                "2023."
            )
        break

# Salvar
doc.save(OUTPUT)
print(f"✅ Template preenchido: {OUTPUT}")
print(f"   Tamanho: {os.path.getsize(OUTPUT):,} bytes")
