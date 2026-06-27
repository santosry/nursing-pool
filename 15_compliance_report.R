# =============================================================================
# 15_compliance_report.R — Relatorio de Compliance e Governanca
# =============================================================================

suppressPackageStartupMessages({
  library(here)
})

source(here::here("config.R"))

dir.create(here::here("docs"), showWarnings = FALSE, recursive = TRUE)
report_path <- here::here("docs", "compliance_report.md")

# Verificacoes
checks <- list()

# 1. Dados reais versionados?
git_files <- tryCatch(
  system("git ls-files", intern = TRUE),
  error = function(e) character(0)
)
checks$real_data_versioned <- !any(grepl("\\.(csv|csv\\.gz|parquet)$", git_files))

# 2. .gitignore bloqueia dados reais?
gitignore <- readLines(here::here(".gitignore"))
checks$blocks_mimic <- any(grepl("mimiciv/", gitignore)) && any(grepl("physionet/", gitignore))
checks$blocks_csvgz <- any(grepl("\\*\\.csv\\.gz", gitignore))
checks$blocks_raw <- any(grepl("raw/", gitignore))

# 3. Renv presente?
checks$has_renv <- file.exists(here::here("renv.lock"))

# 4. Licenca?
checks$has_license <- file.exists(here::here("LICENSE"))
if (checks$has_license) {
  lic <- readLines(here::here("LICENSE"))
  checks$license_is_mit <- any(grepl("MIT", lic))
}

# 5. CITATION.cff?
checks$has_citation <- file.exists(here::here("CITATION.cff"))

# 6. Dockerfile?
checks$has_docker <- file.exists(here::here("Dockerfile"))

# 7. README?
checks$has_readme <- file.exists(here::here("README.md"))

# 8. .gitignore bloqueia binarios?
checks$blocks_sqlite <- any(grepl("\\*\\.sqlite", gitignore))
checks$blocks_rds <- any(grepl("\\*\\.rds", gitignore))

# 9. Resumo expandido versionado?
checks$abstract_in_git <- any(grepl("resumo_expandido|RESUMO_EXPANDIDO", git_files))

# 10. Credenciais expostas?
checks$no_env_files <- !any(grepl("\\.env$", git_files))
checks$no_tokens <- !any(grepl("\\b(token|key|secret|password)\\b", tolower(paste(git_files, collapse = " "))))

# Gerar relatorio
status_icon <- function(x) if (x) "PASS" else "FAIL"

report <- c(
  "# Relatorio de Compliance e Governanca — nursing-pool",
  "",
  sprintf("Gerado em: %s", as.character(Sys.time())),
  "",
  "## Resumo",
  "",
  sprintf("| Verificacao | Status |",
          "|:---|:---|"),
  sprintf("| Dados reais NAO versionados | %s |", status_icon(checks$real_data_versioned)),
  sprintf("| .gitignore bloqueia mimiciv/ | %s |", status_icon(checks$blocks_mimic)),
  sprintf("| .gitignore bloqueia *.csv.gz | %s |", status_icon(checks$blocks_csvgz)),
  sprintf("| .gitignore bloqueia raw/ | %s |", status_icon(checks$blocks_raw)),
  sprintf("| .gitignore bloqueia *.sqlite | %s |", status_icon(checks$blocks_sqlite)),
  sprintf("| .gitignore bloqueia *.rds | %s |", status_icon(checks$blocks_rds)),
  sprintf("| renv.lock presente | %s |", status_icon(checks$has_renv)),
  sprintf("| Licenca MIT | %s |", status_icon(checks$has_license && checks$license_is_mit)),
  sprintf("| CITATION.cff presente | %s |", status_icon(checks$has_citation)),
  sprintf("| Dockerfile presente | %s |", status_icon(checks$has_docker)),
  sprintf("| README presente | %s |", status_icon(checks$has_readme)),
  sprintf("| Resumo expandido NAO versionado | %s |", status_icon(!checks$abstract_in_git)),
  sprintf("| Sem arquivos .env | %s |", status_icon(checks$no_env_files)),
  sprintf("| Sem tokens expostos | %s |", status_icon(checks$no_tokens)),
  "",
  "## Governanca de Dados",
  "",
  "- Dados reais do MIMIC-IV NAO sao redistribuidos nem versionados neste repositorio",
  "- O modo `--mode=real` requer acesso credenciado ao PhysioNet com DUA assinado",
  "- O MIMIC-IV Demo v2.2 e publico e pode ser baixado sem credenciamento",
  "- Dados sinteticos sao gerados algoritmicamente (semente fixa 20240101)",
  "",
  "## Terminologias Protegidas",
  "",
  "- NANDA-I, NIC e NOC sao marcas registradas de suas respectivas organizacoes",
  "- Este repositorio utiliza apenas identificadores e categorias resumidas de uso permitido",
  "- Definicoes completas e taxonomias integrais NAO sao publicadas",
  "- Consulte as referencias bibliograficas para as obras originais",
  "",
  "## Uso de IA Generativa",
  "",
  "Conforme Portaria CNPq no 2.664/2026, foram utilizadas ferramentas de IA generativa",
  "(ChatGPT 5.5, DeepSeek-v4-Pro, Grok) no apoio a concepcao, organizacao metodologica,",
  "revisao textual, depuracao de codigo e sugestoes de auditoria. As ferramentas nao",
  "sao autoras e nao substituem o julgamento cientifico humano."
)

writeLines(report, report_path)
message(sprintf("Relatorio de compliance salvo: %s", report_path))
