# capture_template.R - Lê estrutura do template .docx para injetar conteúdo sem quebrar formatação
library(officer)
doc <- read_docx("C:/Users/oorie/OneDrive/Documentos/TRABALHOS/PROVA DE CONCEITO/Template_Resumo_Expandido_2026.docx")
doc_summary <- docx_summary(doc)
print(head(doc_summary, 40))
cat("\n--- styles ---\n")
print(styles_info(doc))
