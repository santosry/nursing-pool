# =============================================================================
# requirements.R - Instalação de Dependências do Pipeline
# =============================================================================
# Executar uma vez para instalar todos os pacotes R necessários.
# Compatível com Windows, Linux e macOS.
# =============================================================================

# Função auxiliar para instalar pacotes silenciosamente
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("[INSTALL] Instalando %s...", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  } else {
    message(sprintf("[OK] %s já instalado.", pkg))
  }
}

# --- Pacotes CRAN -----------------------------------------------------------
cran_packages <- c(
  # Core
  "here",
  "data.table",
  "lubridate",

  # Banco de dados
  "RSQLite",
  "DBI",
  "duckdb",

  # Estatística
  "survival",
  "survminer",
  "pROC",
  "FSA",

  # Visualização
  "ggplot2",
  "scales",
  "reshape2",

  # Utilitários
  "sysfonts"
)

message("[INSTALL] Instalando pacotes CRAN...")
for (pkg in cran_packages) {
  install_if_missing(pkg)
}

# --- Pacotes GitHub (se necessário) -----------------------------------------
# duckdb pode ser instalado do CRAN nas versões recentes
# Se falhar, usar:
# if (!requireNamespace("duckdb", quietly = TRUE)) {
#   install.packages("duckdb", repos = "https://duckdb.r-universe.dev")
# }

message("\n[INSTALL] Todas as dependências instaladas com sucesso!")
message("[INSTALL] Pipeline pronto para execução.")
message("[INSTALL] Execute: Rscript pipeline.R")
