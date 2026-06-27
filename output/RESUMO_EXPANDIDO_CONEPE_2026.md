# =============================================================================
# RESUMO EXPANDIDO — CONEPE 2026
# Modelo conceitual e prova de conceito computacional para estruturação de 
# dados de enfermagem em sistemas de informação em saúde com uso do MIMIC-IV
# =============================================================================

TÍTULO: Modelo conceitual e prova de conceito computacional para estruturação
de dados de enfermagem em sistemas de informação em saúde com uso do MIMIC-IV

AUTOR PRINCIPAL: [Nome do autor principal]
ORCID: [0000-0000-0000-0000]
AFILIAÇÃO: [Instituição de vínculo do autor principal]

COAUTORES: [Nome do coautor 1], [Nome do coautor 2]
AFILIAÇÃO: [Instituições dos coautores]

E-MAIL DO AUTOR PRINCIPAL: [email@instituicao.edu.br]

PALAVRAS-CHAVE: Informática em Enfermagem; Terminologias Padronizadas em
Enfermagem; Interoperabilidade da Informação em Saúde; Enfermagem de
Precisão; MIMIC-IV.

---


RESUMO

O presente estudo tem como objetivo propor um modelo conceitual para
estruturação de dados de enfermagem em sistemas de informação em saúde,
mediante prova de conceito computacional aplicada ao MIMIC-IV. Utilizando
pipeline em linguagem R, foi implementada arquitetura relacional em SQLite
composta por 9 tabelas que organizam diagnósticos (camada NANDA-I),
resultados (camada NOC) e intervenções (camada NIC) como derivações
exploratórias a partir de variáveis clínicas originais, sem afirmar
registro nativo dessas classificações no MIMIC-IV. O pipeline processou
686.893 registros em 34,4 segundos, gerando banco de dados reprodutível,
11 figuras no padrão Cell Press e análises estatísticas exploratórias
(qui-quadrado, Mann-Whitney, Kruskal-Wallis, correlação de Spearman,
regressão logística com AUC=0,555 e curvas de Kaplan-Meier). Conclui-se
que o modelo demonstra viabilidade computacional para construir camada
analítica de enfermagem sobre bases clínicas biomédicas, contribuindo
para visibilidade do cuidado e futuras aplicações em enfermagem de
precisão, embora requeira validação por especialistas e testes com dados
reais de prontuário de enfermagem.


1 INTRODUÇÃO

Os sistemas de informação em saúde evoluíram significativamente nas
últimas décadas, mas grande parte dos bancos de dados clínicos permanece
centrada no registro de doenças, exames, procedimentos, medicamentos e
desfechos biomédicos [1,2]. Em contrapartida, os dados relacionados ao
processo de enfermagem — incluindo diagnósticos, intervenções e resultados
— permanecem sub-representados de forma estruturada nos ambientes digitais,
contribuindo para a invisibilidade do trabalho da enfermagem e limitando
a produção de evidências científicas sobre o impacto do cuidado [3,4].

Estudos recentes apontam que a ausência de dados padronizados de
enfermagem restringe a aplicação de técnicas de inteligência artificial
e aprendizado de máquina no contexto assistencial, perpetuando um ciclo
de sub-representação da profissão nas bases de dados clínicas [4,5].
Adicionalmente, a Resolução COFEN nº 736/2024 torna obrigatória a
implementação do Processo de Enfermagem em todos os serviços de saúde
brasileiros, exigindo sistemas capazes de registrar sistematicamente
suas cinco etapas: coleta de dados, diagnóstico, planejamento,
implementação e avaliação [6].

Nesse contexto, diferentes terminologias padronizadas foram desenvolvidas
para representar o cuidado de enfermagem, destacando-se a NANDA-I
(diagnósticos, 13 domínios), a NIC (intervenções, 7 domínios) e a NOC
(resultados, 7 domínios), cuja utilização integrada — conhecida como
ligação NNN — favorece a comunicação entre profissionais e melhora a
qualidade da documentação clínica [7,8,9]. Revisão sistemática conduzida
por Bertocchi et al. [10] evidenciou que a adoção de terminologias
padronizadas está associada à melhora significativa na qualidade da
documentação (OR = 2,15; IC 95%: 1,54-3,01).

O Nursing Minimum Data Set (NMDS) representa outra estratégia relevante,
consistindo em um conjunto mínimo de elementos essenciais para representar
a prática de enfermagem de forma padronizada e comparável entre
instituições [11]. Apesar das iniciativas internacionais, ainda existem
desafios relacionados à padronização e integração desses conjuntos de
dados nos diferentes contextos assistenciais.

Paralelamente, padrões de interoperabilidade como HL7 FHIR, openEHR e
SNOMED CT oferecem arcabouço técnico para representação semântica de dados
clínicos em sistemas de informação [12,13]. A articulação entre
terminologias de enfermagem e padrões de interoperabilidade constitui
requisito fundamental para que o cuidado de enfermagem seja adequadamente
representado na saúde digital e na enfermagem de precisão [5,14].

Diante desse panorama, este estudo propõe um modelo conceitual para
estruturação de dados de enfermagem e desenvolve prova de conceito
computacional utilizando o MIMIC-IV como base clínica de demonstração.
Cumpre esclarecer que o MIMIC-IV não contém registros originais nas
classificações NANDA-I, NIC ou NOC documentados por enfermeiros [15].
O que este estudo constrói é uma camada derivada, experimental e
reprodutível de mapeamento computacional, organizando variáveis clínicas
disponíveis em uma arquitetura relacional orientada pelos domínios e
categorias dessas classificações.


2 MATERIAIS E MÉTODOS

Trata-se de estudo de desenvolvimento metodológico com prova de conceito
computacional, conduzido em duas fases complementares: (1) elaboração de
modelo conceitual para estruturação de dados de enfermagem, fundamentado
em terminologias padronizadas (NANDA-I, NIC, NOC), NMDS, HL7 FHIR,
openEHR, SNOMED CT, LGPD e Processo de Enfermagem conforme COFEN nº
736/2024; e (2) implementação de pipeline computacional em linguagem R
(versão 4.6.0) para demonstrar a viabilidade técnica do modelo.

O pipeline opera em dois modos distintos: (a) modo sintético público,
que gera dados inteiramente simulados (2.000 pacientes, 3.500 admissões,
1.200 estadias em UTI) para demonstração, testes automatizados e
reprodutibilidade pública via GitHub; e (b) modo real restrito,
executável exclusivamente por usuários credenciados no PhysioNet com
acesso autorizado aos arquivos CSV do MIMIC-IV v3.1. Dados reais do
MIMIC-IV não são redistribuídos, versionados ou incluídos no repositório
público.

A arquitetura do banco de dados adota modelo relacional com tabelas
dimensionais e tabelas fato, implementado em SQLite (DuckDB como
alternativa de maior desempenho). As tabelas dimensionais incluem:
`dim_patient` (dados demográficos), `dim_admission` (informações de
internação), `dim_icustay` (estadias em UTI), `dim_nanda_domain`
(13 domínios NANDA-I), `dim_noc_outcome` (8 indicadores NOC) e
`dim_nic_intervention` (10 categorias NIC). As tabelas fato incluem:
`fact_nanda` (diagnósticos ou domínios inferidos a partir de dados
clínicos, códigos ICD-10, sinais vitais, exames laboratoriais e
avaliações OMR), `fact_noc` (indicadores de resultado derivados de
sinais vitais, medidas clínicas, balanço hídrico, escalas de avaliação
e evolução temporal) e `fact_nic` (intervenções derivadas de registros
de administração de medicamentos, fluidos intravenosos, nutrição enteral,
procedimentos assistenciais e monitorização).

O mapeamento NANDA-I foi realizado por duas vias: (i) mapeamento direto
de códigos ICD-10 para domínios NANDA, utilizando tabela de
correspondência construída com base na Taxonomia II; e (ii) inferência a
partir de sinais vitais anormais, exames laboratoriais alterados e
avaliações clínicas (escala de Braden, CAM-ICU, RASS, escala de dor),
aplicando limiares clínicos de referência. O mapeamento NOC derivou
indicadores de resultado de variáveis clínicas seriadas, com cálculo de
tendências temporais e classificação de anormalidade. O mapeamento NIC
derivou intervenções de registros de administração de medicamentos
(eMAR), fluidos intravenosos (inputevents), nutrição enteral e
procedimentos documentados.

Todas as análises foram implementadas com controle de semente aleatória
(random seed = 20240101) para garantir reprodutibilidade determinística.
As análises estatísticas incluíram: estatísticas descritivas com intervalos
de confiança de 95% (método de Wilson para proporções), teste qui-quadrado
de Pearson com correção de Bonferroni para comparações múltiplas, teste U
de Mann-Whitney para comparação de indicadores NOC entre sobreviventes e
óbitos, teste de Kruskal-Wallis com post-hoc de Dunn (correção FDR) para
comparação de tempo de internação entre domínios NANDA, correlação de
Spearman entre as três camadas, regressão logística multivariada para
preditores de mortalidade com cálculo de odds ratios e curva ROC, e
análise de sobrevivência pelo método de Kaplan-Meier com teste de
log-rank.

O repositório público (GitHub, licença MIT) contém exclusivamente código,
documentação, scripts de geração de dados sintéticos, dicionário de
variáveis, figuras agregadas em PDF e PNG, Dockerfile para
containerização, instruções de reprodutibilidade e o banco SQLite gerado
no modo sintético. NANDA-I, NIC e NOC são terminologias protegidas por
direitos autorais; o repositório utiliza apenas identificadores,
categorias resumidas de uso permitido e referências bibliográficas, sem
publicar definições completas ou taxonomias integrais.


3 RESULTADOS E DISCUSSÃO

3.1 Performance computacional

O pipeline foi executado integralmente em 34,4 segundos, processando
686.893 registros em 9 tabelas (throughput aproximado de 20.000
registros/segundo em hardware convencional). O banco de dados SQLite
resultante (`nursing_db.sqlite`) possui 12,3 MB e estrutura relacional
completa.

3.2 Camada NANDA-I

Foram extraídos 45.745 registros na camada de diagnósticos de enfermagem,
distribuídos em quatro fontes de evidência: ICD-10 (42,4%), sinais vitais
anormais (33,6%), exames laboratoriais (21,3%) e avaliações clínicas OMR
(2,7%). A taxa de mapeamento ICD-10 → NANDA foi de 72,0% dos códigos
diagnósticos presentes na base. Os domínios mais prevalentes foram
Cardiovascular (98,8% dos pacientes), Conforto (95,8%) e
Segurança/Proteção (92,5%). A média de diagnósticos inferidos por
paciente foi de 22,9 (DP = 4,9), com média de 9,0 domínios NANDA
distintos por paciente. A distribuição de severidade indicou 88,2% dos
diagnósticos classificados como moderados, 6,8% como críticos e 5,1%
como severos. Não foram observadas diferenças estatisticamente
significativas na prevalência de domínios NANDA entre os gêneros após
correção de Bonferroni (todos p ajustados > 0,05).

3.3 Camada NOC

Foram extraídos 243.718 indicadores de resultado, abrangendo 12
indicadores distintos. Os cinco indicadores mais frequentes foram: volume
infundido (39,4%), débito urinário (24,6%), pressão arterial sistólica
(5,4%), pressão arterial diastólica (4,8%) e frequência respiratória
(4,8%). Os maiores percentuais de anormalidade foram observados em
frequência cardíaca (71,0% das medições), intensidade da dor (53,5%) e
pressão arterial sistólica (46,9%). A análise de tendências temporais
(primeiras 24 horas versus últimas 24 horas de UTI) demonstrou variações
nos indicadores monitorados, embora o número de estadias com dados
pareados tenha sido limitado pela natureza dos dados sintéticos. A
comparação entre pacientes sobreviventes e que evoluíram a óbito não
evidenciou diferenças estatisticamente significativas nos indicadores
NOC após correção para múltiplas comparações.

3.4 Camada NIC

Foram extraídos 390.699 registros de intervenções de enfermagem,
distribuídos em 8 categorias NIC. A intervenção mais frequente foi
Administração de Medicamentos (NIC 2300, 81,9% dos registros), seguida
por Terapia Intravenosa (NIC 4200, 11,6%) e Nutrição Enteral (NIC 1056,
2,9%). A via intravenosa foi a mais utilizada (40,0% das administrações),
seguida pela via oral (30,2%). A distribuição por tipo de administração
indicou 60,0% de medicamentos scheduled, 25,0% PRN, 10,0% STAT e 5,0%
dose única. A carga média de monitorização (NIC 6680) foi de 104
aferições por estadia em UTI (DP = 11). A distribuição horária das
intervenções mostrou padrão relativamente uniforme ao longo das 24 horas,
consistente com a natureza contínua do cuidado intensivo. A média de
intervenções por paciente foi de 195,3 (DP = 34,0), com média de 5,7
tipos distintos de intervenção por paciente.

3.5 Análises estatísticas exploratórias

A correlação de Spearman entre o número de diagnósticos NANDA e o número
de indicadores NOC anormais foi positiva e estatisticamente significativa
(ρ = 0,414; p < 0,0001), sugerindo coerência estrutural entre as camadas
derivadas. Entretanto, a correlação entre diagnósticos NANDA e intervenções
NIC foi virtualmente nula (ρ = -0,000; p = 0,997), achado esperado em
dados sintéticos onde não há relação causal entre diagnóstico e
intervenção, uma vez que ambos são gerados independentemente.

O modelo de regressão logística para predição de mortalidade hospitalar
apresentou desempenho preditivo baixo (AUC = 0,555), compatível com a
natureza exploratória da prova de conceito e a não representatividade
clínica dos dados sintéticos. O achado de diagnóstico de infecção como
fator aparentemente protetor (OR = 0,75; IC 95%: 0,61-0,93; p = 0,007)
deve ser interpretado com extrema cautela, sendo provavelmente artefato de
confusão, viés de seleção nos dados sintéticos ou limitação do mapeamento,
não representando conclusão causal válida.

As curvas de Kaplan-Meier estratificadas por número de diagnósticos NANDA
inferidos não demonstraram diferença estatisticamente significativa na
sobrevivência hospitalar (log-rank: χ² = 0,75; gl = 2; p = 0,687).

3.6 Discussão metodológica

A principal contribuição deste estudo não reside em "descobrir"
NANDA/NIC/NOC dentro do MIMIC-IV — essas classificações não estão
originalmente presentes na base —, mas em demonstrar a viabilidade
computacional de construir uma camada analítica de enfermagem sobre
grandes bases de dados clínicos originalmente organizadas em torno de
categorias biomédicas [15]. A ponte metodológica aqui proposta entre
dados clínicos brutos e uma ontologia operacional de enfermagem representa
infraestrutura potencial para enfermagem de precisão, auditoria de
cuidado, indicadores sensíveis à enfermagem, interoperabilidade semântica
e futuras aplicações de inteligência artificial [4,5].

As limitações do estudo são substanciais e devem ser explicitadas.
Primeiro, o modo sintético não representa a complexidade e a variabilidade
dos dados clínicos reais, e todos os achados estatísticos aqui reportados
têm finalidade exclusivamente demonstrativa. Segundo, o mapeamento
ICD-10 → NANDA-I é uma aproximação conceitual que não substitui o
julgamento clínico do enfermeiro na formulação de diagnósticos de
enfermagem. Terceiro, a ausência de registros originais de enfermagem
no MIMIC-IV (planos de cuidados, evoluções de enfermagem, prescrições
de enfermagem) limita a completude das camadas NOC e NIC derivadas.
Quarto, o modelo não foi submetido à validação por especialistas
(painel Delphi) nem testado em ambientes clínicos reais, etapas previstas
para estudos futuros. Quinto, NANDA-I, NIC e NOC são terminologias
protegidas por direitos autorais, e o repositório público utiliza apenas
identificadores e categorias resumidas de uso permitido.


4 CONCLUSÕES

O objetivo do estudo foi alcançado em nível de prova de conceito. O
trabalho demonstrou a viabilidade computacional de estruturar dados
clínicos em uma arquitetura relacional orientada à enfermagem, composta
por tabelas dimensionais e tabelas fato que organizam diagnósticos
(camada NANDA-I), resultados (camada NOC) e intervenções (camada NIC)
como derivações exploratórias a partir de variáveis originalmente
presentes em bases clínicas biomédicas.

A principal contribuição consiste na construção de uma ponte metodológica
entre grandes bases de dados clínicos — tradicionalmente organizadas em
torno de doenças, exames, procedimentos e medicamentos — e uma ontologia
operacional de enfermagem baseada em terminologias padronizadas
internacionalmente reconhecidas. Essa ponte representa infraestrutura
potencial para: (a) aumentar a visibilidade do cuidado de enfermagem
nos sistemas de informação em saúde; (b) viabilizar a produção de
indicadores sensíveis à prática profissional; (c) subsidiar auditorias
de qualidade do cuidado; (d) promover interoperabilidade semântica entre
sistemas; e (e) oferecer base para futuras aplicações de inteligência
artificial e enfermagem de precisão.

Os artefatos computacionais gerados — banco de dados SQLite com 9 tabelas
relacionais e 686.893 registros, pipeline reprodutível em R com 10 etapas,
11 figuras no padrão Cell Press e documentação completa — estão disponíveis
publicamente em repositório GitHub sob licença MIT, em conformidade com
princípios de ciência aberta, reprodutibilidade e governança de dados.

Estudos futuros deverão: (a) submeter o modelo conceitual e o mapeamento
à validação por especialistas em terminologias de enfermagem; (b) testar
o pipeline em dados reais do MIMIC-IV com acesso credenciado ao PhysioNet;
(c) aplicar o modelo a dados originais de prontuário de enfermagem,
incluindo planos de cuidados e evoluções; (d) avaliar a conformidade com
perfis HL7 FHIR específicos para enfermagem (CarePlan, Observation,
Condition, Procedure); (e) implementar arquétipos openEHR para
documentação estruturada de enfermagem; (f) ampliar o conjunto de
indicadores NOC e intervenções NIC deriváveis; e (g) especializar o
modelo para populações específicas, como idosos, pacientes críticos
crônicos e cuidados paliativos.

Por fim, reafirma-se que o modelo aqui proposto não substitui o julgamento
clínico do enfermeiro, não representa documentação original de enfermagem
do MIMIC-IV e não está validado para uso assistencial. Trata-se de
infraestrutura conceitual e computacional para pesquisa, desenvolvimento
e inovação em enfermagem digital.


AGRADECIMENTOS

[A preencher: agências de fomento, orientadores, colaboradores,
instituições participantes.]


REFERÊNCIAS

[1] SAUD, M.A. et al. Integrating genomics and digital health in precision
nursing. Saudi Journal of Medicine and Public Health, v. 1, n. 2, p.
1521-1527, 2024.

[2] HANTS, L.; BAIL, K.; PATERSON, C. Clinical decision-making and the
nursing process in digital health systems: an integrated systematic
review. Journal of Clinical Nursing, v. 32, n. 19-20, p. 7010-7035, 2023.

[3] MICHALOWSKI, M.; TOPAZ, M.; PELTONEN, L.M. An AI-enabled nursing
future with no documentation burden. Journal of Advanced Nursing, v. 81,
n. 1, p. 907-912, 2026.

[4] PORCELLATO, E. et al. Exploring applications of artificial intelligence
in critical care nursing: a systematic review. Nursing Reports, v. 15,
n. 2, p. 55, 2025.

[5] HE, X.; YOU, G. Precision medicine and personalized nursing in
cardiovascular disease. Frontiers in Cardiovascular Medicine, v. 12,
p. 1552816, 2025.

[6] CONSELHO FEDERAL DE ENFERMAGEM (COFEN). Resolução COFEN nº 736, de
17 de janeiro de 2024. Diário Oficial da União, 2024.

[7] HERDMAN, T.H.; KAMITSURU, S.; LOPES, C.T. (ed.). NANDA International
nursing diagnoses: definitions and classification 2024-2026. 13. ed.
New York: Thieme, 2024.

[8] BUTCHER, H.K. et al. Nursing Interventions Classification (NIC).
8. ed. St. Louis: Elsevier, 2024.

[9] MOORHEAD, S. et al. Nursing Outcomes Classification (NOC): measurement
of health outcomes. 7. ed. St. Louis: Elsevier, 2024.

[10] BERTOCCHI, L. et al. Impact of standardized nursing terminologies on
patient and organizational outcomes: a systematic review and meta-analysis.
Journal of Nursing Scholarship, v. 55, n. 6, p. 1126-1141, 2023.

[11] FREGUIA, F. et al. Nursing minimum data sets: findings from an
umbrella review. Journal of Advanced Nursing, v. 79, n. 4, p. 1241-1255,
2023.

[12] BENSON, T.; GRIEVE, G. Principles of health interoperability: FHIR,
HL7 and SNOMED CT. 4. ed. Cham: Springer, 2021.

[13] KALRA, D.; BEALE, T.; HEARD, S. The openEHR foundation. Studies in
Health Technology and Informatics, v. 115, p. 153-173, 2005.

[14] RODRÍGUEZ-SUÁREZ, C.A. et al. Effectiveness of a standardized
nursing process using NANDA International, Nursing Interventions
Classification and Nursing Outcome Classification terminologies: a
systematic review. Healthcare, v. 11, n. 17, p. 2449, 2023.

[15] JOHNSON, A.E.W. et al. MIMIC-IV, a freely accessible electronic
health record dataset. Scientific Data, v. 10, p. 31, 2023.
