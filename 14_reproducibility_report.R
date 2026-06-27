# =============================================================================
# 14_reproducibility_report.R — Relatorio de Reprodutibilidade Computacional
# =============================================================================
# Gera docs/reproducibility_report.md com ambiente, versoes e instrucoes

suppressPackageStartupMessages({
  library(here)
  library(data.table)
})

source(here::here("config.R"))

dir.create(here::here("docs"), showWarnings = FALSE, recursive = TRUE)
report_path <- here::here("docs", "reproducibility_report.md")

# Capturar informacao do ambiente
si <- sessionInfo()
r_version <- R.version.string
os_info <- paste(Sys.info()[c("sysname", "release", "version")], collapse = " ")
date_run <- as.character(Sys.time())

# Pacotes carregados
loaded_pkgs <- names(si$otherPkgs)
if (is.null(loaded_pkgs)) loaded_pkgs <- names(si$loadedOnly)

# Versoes de pacotes criticos
critical_pkgs <- c("data.table", "ggplot2", "RSQLite", "DBI", "duckdb",
                   "survival", "survminer", "pROC", "xgboost", "ranger",
                   "glmnet", "shapviz", "fastshap", "reshape2", "scales",
                   "here", "lubridate", "FSA")
pkg_versions <- sapply(critical_pkgs, function(p) {
  tryCatch(as.character(packageVersion(p)), error = function(e) "NOT INSTALLED")
})

# Verificar renv
has_renv <- file.exists(here::here("renv.lock"))
renv_status <- if (has_renv) {
  lock_lines <- length(readLines(here::here("renv.lock")))
  sprintf("Presente (%d linhas, %d pacotes)", lock_lines, 
          length(grep("Package:", readLines(here::here("renv.lock")))))
} else {
  "AUSENTE — necessario para reproducibilidade"
}

# Verificar Docker
has_docker <- file.exists(here::here("Dockerfile"))
docker_status <- if (has_docker) "Dockerfile presente" else "AUSENTE"

# Verificar Git
git_commit <- tryCatch(
  system("git rev-parse --short HEAD", intern = TRUE),
  error = function(e) "nao disponivel"
)

# Gerar relatorio
report <- c(
  "# Relatorio de Reprodutibilidade Computacional — nursing-pool",
  "",
  sprintf("Gerado em: %s", date_run),
  "",
  "## Ambiente",
  "",
  sprintf("- **R**: %s", r_version),
  sprintf("- **Sistema Operacional**: %s", os_info),
  sprintf("- **Git commit**: %s", git_commit),
  "",
  "## Gerenciador de Ambiente",
  "",
  sprintf("- **renv**: %s", renv_status),
  sprintf("- **Docker**: %s", docker_status),
  "",
  "## Pacotes Criticos",
  "",
  "| Pacote | Versao |",
  "|:---|:---|"
)

for (pkg in names(pkg_versions)) {
  report <- c(report, sprintf("| %s | %s |", pkg, pkg_versions[pkg]))
}

report <- c(report, "",
  "## Instrucoes para Reproducao",
  "",
  "### Via renv",
  "",
  "```r",
  "renv::restore()",
  "source('pipeline.R')",
  "```",
  "",
  "### Via Docker",
  "",
  "```bash",
  "docker build -t mimic-nursing-poc .",
  "docker run --rm -v $(pwd)/output:/app/output mimic-nursing-poc",
  "```",
  "",
  "### Dados Reais (MIMIC-IV Demo)",
  "",
  "```bash",
  "Rscript pipeline.R --mode=real --data_dir=../mimic-iv-clinical-database-demo-2.2",
  "```",
  "",
  "### Dados Sinteticos (Demonstracao)",
  "",
  "```bash",
  "Rscript pipeline.R --mode=synthetic",
  "```",
  "",
  "## Notas",
  "",
  "- Pipeline testado com dados do MIMIC-IV Demo v2.2 (100 pacientes reais)",
  "- Modo sintetico usa 2.000 pacientes simulados com semente fixa (20240101)",
  "- Dados reais do MIMIC-IV completo requerem acesso credenciado via PhysioNet"
)

writeLines(report, report_path)
message(sprintf("Relatorio de reprodutibilidade salvo: %s", report_path))
