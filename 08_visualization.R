# =============================================================================
# 08_visualization.R - Gráficos Estilo Cell Press para Dados de Enfermagem
# =============================================================================
# Etapa 8: Visualizações no padrão Cell Press. Todos os rótulos em português.
# Salva em PDF (vetorial) e PNG (raster, 300 DPI) para publicação.
# =============================================================================

source(here::here("theme_cellpress.R"))

# --- Helper para salvar em múltiplos formatos ---
salvar_figura <- function(plot, nome, width = 8, height = 5.5, dpi = 300) {
  dir.create(PATHS$figures_dir, showWarnings = FALSE, recursive = TRUE)
  pdf_path <- file.path(PATHS$figures_dir, paste0(nome, ".pdf"))
  png_path <- file.path(PATHS$figures_dir, paste0(nome, ".png"))

  ggsave(pdf_path, plot = plot, width = width, height = height,
         device = "pdf", units = "in")
  ggsave(png_path, plot = plot, width = width, height = height,
         dpi = dpi, units = "in")

  message(sprintf("  [FIGURA] %s → PDF + PNG", nome))
}

# =============================================================================
# FIGURA 1A — Prevalência de Domínios NANDA-I (com IC 95%)
# =============================================================================
fig1a_prevalencia_nanda <- function(nanda, n_total = NULL) {

  if (is.null(n_total)) {
    n_total <- attr(nanda, "n_patients")
    if (is.null(n_total)) n_total <- nanda[, uniqueN(subject_id)]
  }

  prev_data <- nanda[, .(
    n = uniqueN(subject_id),
    prevalencia = round(100 * uniqueN(subject_id) / n_total, 1)
  ), by = nanda_domain][order(-prevalencia)]

  # IC 95% (Wilson)
  prev_data[, ci_lower := NA_real_]
  prev_data[, ci_upper := NA_real_]
  for (i in seq_len(nrow(prev_data))) {
    ci <- prop.test(prev_data$n[i], n_total, correct = FALSE)$conf.int
    prev_data[i, ci_lower := 100 * ci[1]]
    prev_data[i, ci_upper := 100 * ci[2]]
  }

  prev_data <- head(prev_data, 8)

  p <- ggplot(prev_data, aes(x = reorder(nanda_domain, prevalencia),
                              y = prevalencia)) +
    geom_col(fill = cellpress_colors$nanda, width = 0.7, alpha = 0.85) +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2,
                  color = "#333333", linewidth = 0.5) +
    geom_text(aes(label = paste0(prevalencia, "%")),
              hjust = -0.2, size = 4.5, color = "#444444", fontface = "bold") +
    coord_flip() +
    labs(
      title    = "Prevalência de Domínios NANDA-I na Coorte",
      subtitle = paste0("Domínios mais frequentes (n = ", n_total,
                        " pacientes) | Barras: IC 95% (Wilson)"),
      x        = NULL,
      y        = "Prevalência (%)",
      caption  = "Fonte: Camada derivada NANDA-I × MIMIC-IV (prova de conceito)"
    ) +
    theme_cellpress(base_size = 13) +
    expand_limits(y = max(prev_data$ci_upper) * 1.18)

  salvar_figura(p, "Fig1A_Prevalencia_NANDA", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 1B — Heatmap de Co-ocorrência de Domínios NANDA
# =============================================================================
fig1b_heatmap_nanda <- function(nanda) {

  if ("hadm_id" %in% names(nanda)) {
    patient_domains <- nanda[, .(domains = list(unique(nanda_domain))),
                             by = hadm_id]
  } else if ("subject_id" %in% names(nanda)) {
    patient_domains <- nanda[, .(domains = list(unique(nanda_domain))),
                             by = subject_id]
  } else return(NULL)

  top_domains <- nanda[, .N, by = nanda_domain][order(-N)][1:8, nanda_domain]
  top_domains <- top_domains[!is.na(top_domains)]
  if (length(top_domains) < 2) return(NULL)

  n_patients <- nrow(patient_domains)
  cooccur <- matrix(0, nrow = length(top_domains), ncol = length(top_domains))
  rownames(cooccur) <- top_domains
  colnames(cooccur) <- top_domains

  for (i in seq_along(top_domains)) {
    for (j in seq_along(top_domains)) {
      if (i == j) {
        cooccur[i, j] <- 1
      } else {
        n_both <- sum(sapply(patient_domains$domains,
                             function(x) all(c(top_domains[i], top_domains[j]) %in% x)))
        cooccur[i, j] <- n_both / n_patients
      }
    }
  }

  heatmap_data <- reshape2::melt(cooccur,
                                 varnames = c("Domínio 1", "Domínio 2"),
                                 value.name = "Coocorrencia")
  heatmap_data <- as.data.table(heatmap_data)

  p <- ggplot(heatmap_data, aes(x = `Domínio 1`, y = `Domínio 2`,
                                 fill = Coocorrencia)) +
    geom_tile() +
    geom_text(aes(label = scales::percent(Coocorrencia, accuracy = 0.1)),
              size = 3.5,
              color = ifelse(heatmap_data$Coocorrencia > 0.5, "white", "#333333")) +
    scale_fill_gradientn(colors = cellpress_colors$gradient_blues,
                         name = "Co-ocorrência") +
    labs(
      title    = "Matriz de Co-ocorrência de Domínios NANDA-I",
      subtitle = "Frequência relativa de co-ocorrência em uma mesma admissão",
      x        = NULL, y = NULL,
      caption  = "Prova de conceito — camada derivada NANDA-I × MIMIC-IV"
    ) +
    theme_cellpress(base_size = 12) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
      axis.text.y = element_text(size = 10),
      legend.position = "right",
      legend.title = element_text(size = 10),
      panel.grid.major = element_blank()
    )

  salvar_figura(p, "Fig1B_Heatmap_NANDA", width = 7, height = 6)
  p
}

# =============================================================================
# FIGURA 2A — Distribuição de Indicadores NOC (Violin + Boxplot)
# =============================================================================
fig2a_violin_noc <- function(noc) {

  top_indicators <- noc[, .N, by = indicator][order(-N)][1:5, indicator]
  plot_data <- noc[indicator %in% top_indicators]

  p <- ggplot(plot_data, aes(x = indicator, y = value, fill = indicator)) +
    geom_violin(alpha = 0.6, linewidth = 0.3) +
    geom_boxplot(width = 0.15, alpha = 0.4, outlier.size = 0.7,
                 outlier.alpha = 0.3) +
    scale_fill_cellpress("safe") +
    labs(
      title    = "Distribuição dos Indicadores NOC Mais Frequentes",
      subtitle = "Violin plot + boxplot (mediana, IQR, outliers) — 5 indicadores principais",
      x        = "Indicador NOC",
      y        = "Valor (unidades nativas de cada indicador)",
      caption  = "Prova de conceito — camada derivada NOC × MIMIC-IV"
    ) +
    theme_cellpress(base_size = 13) +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 20, hjust = 1, size = 11))

  salvar_figura(p, "Fig2A_Violin_NOC", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 2B — Percentual de Indicadores NOC Anormais
# =============================================================================
fig2b_noc_anormais <- function(noc) {

  abnormal_data <- noc[, .(
    n_total = .N,
    n_anormal = sum(abnormal, na.rm = TRUE),
    pct = round(100 * sum(abnormal, na.rm = TRUE) / .N, 1)
  ), by = noc_label][order(-pct)]

  abnormal_data <- head(abnormal_data, 7)

  p <- ggplot(abnormal_data, aes(x = reorder(noc_label, pct), y = pct)) +
    geom_col(aes(fill = pct), width = 0.7) +
    geom_text(aes(label = paste0(pct, "%")),
              hjust = -0.2, size = 5, color = "#444444", fontface = "bold") +
    scale_fill_gradientn(colors = cellpress_colors$gradient_reds[4:9],
                         guide = "none") +
    coord_flip() +
    labs(
      title    = "Proporção de Indicadores NOC Fora dos Limites de Referência",
      subtitle = "Percentual de medições anormais por resultado NOC monitorado",
      x        = NULL,
      y        = "Medições Anormais (%)",
      caption  = "Valores anormais definidos por limiares clínicos de enfermagem"
    ) +
    theme_cellpress(base_size = 13) +
    expand_limits(y = max(abnormal_data$pct) * 1.2)

  salvar_figura(p, "Fig2B_NOC_Anormais", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 3A — Distribuição de Intervenções NIC
# =============================================================================
fig3a_barras_nic <- function(nic) {

  nic_data <- nic[, .(
    n_intervencoes = .N,
    n_pacientes = uniqueN(subject_id)
  ), by = nic_label][order(-n_intervencoes)]
  nic_data <- head(nic_data, 7)

  p <- ggplot(nic_data, aes(x = reorder(nic_label, n_intervencoes),
                             y = n_intervencoes)) +
    geom_col(fill = cellpress_colors$nic, width = 0.7, alpha = 0.85) +
    geom_text(aes(label = scales::comma(n_intervencoes)),
              hjust = -0.1, size = 4.5, color = "#444444", fontface = "bold") +
    coord_flip() +
    labs(
      title    = "Volume Total de Intervenções de Enfermagem (NIC)",
      subtitle = "Número de eventos de intervenção registrados por categoria NIC",
      x        = NULL,
      y        = "Número de Eventos de Intervenção",
      caption  = "Prova de conceito — camada derivada NIC × MIMIC-IV"
    ) +
    theme_cellpress(base_size = 13) +
    expand_limits(y = max(nic_data$n_intervencoes) * 1.18)

  salvar_figura(p, "Fig3A_Intervencoes_NIC", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 3B — Intervenções NIC por Turno de Enfermagem
# =============================================================================
fig3b_turnos_nic <- function(nic) {

  if (!"charttime" %in% names(nic)) return(NULL)

  nic_time <- copy(nic[!is.na(charttime)])
  nic_time[, hora := hour(charttime)]
  nic_time[, turno := fcase(
    hora >= 7 & hora < 15,  "Manhã (7h-15h)",
    hora >= 15 & hora < 23, "Tarde (15h-23h)",
    default =                "Noite (23h-7h)"
  )]

  # Total por hora e categoria
  hora_data <- nic_time[, .N, by = .(hora, nic_label)]
  hora_data[, pct := 100 * N / sum(N), by = nic_label]

  p <- ggplot(hora_data, aes(x = hora, y = pct, color = nic_label,
                               group = nic_label)) +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    scale_color_cellpress("safe") +
    scale_x_continuous(breaks = seq(0, 23, 3),
                       labels = paste0(seq(0, 23, 3), "h")) +
    labs(
      title    = "Distribuição Temporal das Intervenções de Enfermagem",
      subtitle = "Percentual do total de intervenções por hora do dia e categoria NIC",
      x        = "Hora do Dia",
      y        = "Intervenções (%)",
      color    = "Categoria NIC",
      caption  = "Turnos: Manhã (7-15h), Tarde (15-23h), Noite (23-7h)"
    ) +
    theme_cellpress(base_size = 12) +
    theme(legend.position = "bottom", legend.box = "vertical",
          legend.text = element_text(size = 9))

  salvar_figura(p, "Fig3B_Turnos_NIC", width = 9, height = 6)
  p
}

# =============================================================================
# FIGURA 4 — Kaplan-Meier: Sobrevivência × Carga Diagnóstica NANDA
# =============================================================================
fig4_km_sobrevivencia <- function(surv_data, km_fit) {

  if (is.null(surv_data) || is.null(km_fit)) return(NULL)
  library(survival)
  library(survminer)

  actual_strata <- gsub("dx_group=", "", names(km_fit$strata))
  n_strata <- length(actual_strata)

  p <- ggsurvplot(
    km_fit,
    data = surv_data,
    risk.table = TRUE,
    risk.table.height = 0.25,
    pval = TRUE,
    pval.coord = c(0.1, 0.15),
    conf.int = TRUE,
    conf.int.alpha = 0.12,
    palette = cellpress_colors$safe[1:n_strata],
    xlab = "Tempo de Internação (dias)",
    ylab = "Probabilidade de Sobrevivência",
    title = "Sobrevivência Hospitalar por Carga de Diagnósticos de Enfermagem",
    subtitle = "Curvas de Kaplan-Meier estratificadas — Prova de Conceito",
    legend.title = "Diagnósticos NANDA inferidos",
    legend.labs = actual_strata,
    ggtheme = theme_cellpress(base_size = 12),
    risk.table.y.text = TRUE
  )

  pdf_path <- file.path(PATHS$figures_dir, "Fig4_KM_Sobrevivencia.pdf")
  png_path <- file.path(PATHS$figures_dir, "Fig4_KM_Sobrevivencia.png")
  pdf(pdf_path, width = 9, height = 6.5)
  print(p)
  dev.off()
  # PNG via ggsurvplot não funciona diretamente, salvamos como PDF e convertemos depois
  message("  [FIGURA] Fig4_KM_Sobrevivencia → PDF")

  p
}

# =============================================================================
# FIGURA 5A — Razões de Chance (Odds Ratios) do Modelo Logístico
# =============================================================================
fig5a_odds_ratios <- function(or_data) {

  if (is.null(or_data) || nrow(or_data) <= 1) return(NULL)

  or_plot <- or_data[-1, ]
  or_plot$Variable <- gsub("genderM", "Sexo Masculino",
    gsub("anchor_age", "Idade (por ano)",
    gsub("n_dx", "Nº Diagnósticos NANDA",
    gsub("has_nutritionTRUE", "Diagnóstico Nutricional",
    gsub("has_infectionTRUE", "Diagnóstico de Infecção",
    gsub("has_cardiacTRUE", "Diagnóstico Cardiovascular",
    gsub("has_cognitionTRUE", "Diagnóstico Cognitivo",
    or_plot$Variable)))))))

  p <- ggplot(or_plot, aes(x = OR, y = reorder(Variable, OR))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "#999999",
               linewidth = 0.6) +
    geom_point(size = 4, color = cellpress_colors$nanda) +
    geom_errorbarh(aes(xmin = CI_lower, xmax = CI_upper),
                   height = 0.25, linewidth = 1, color = "#333333") +
    geom_text(aes(label = sprintf("%.2f", OR)), vjust = -1.2, size = 4.5,
              fontface = "bold") +
    scale_x_log10() +
    labs(
      title    = "Preditores de Mortalidade Hospitalar",
      subtitle = "Odds Ratios ajustados — Regressão Logística Multivariada (exploratório)",
      x        = "Odds Ratio (escala logarítmica)",
      y        = NULL,
      caption  = "OR > 1: maior chance de óbito. Barras: IC 95%. Prova de conceito — NÃO validado clinicamente."
    ) +
    theme_cellpress(base_size = 13)

  salvar_figura(p, "Fig5A_OddsRatios", width = 8, height = 5)
  p
}

# =============================================================================
# FIGURA 5B — Curva ROC do Modelo Logístico
# =============================================================================
fig5b_curva_roc <- function(roc_obj, auc_val) {

  if (is.null(roc_obj)) return(NULL)
  library(pROC)

  roc_data <- data.table(
    especificidade = rev(roc_obj$specificities),
    sensibilidade  = rev(roc_obj$sensitivities)
  )

  p <- ggplot(roc_data, aes(x = 1 - especificidade, y = sensibilidade)) +
    geom_ribbon(aes(ymin = 0, ymax = sensibilidade),
                fill = cellpress_colors$nanda, alpha = 0.12) +
    geom_line(color = cellpress_colors$nanda, linewidth = 1) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed",
                color = "#999999", linewidth = 0.6) +
    annotate("text", x = 0.72, y = 0.12,
             label = sprintf("AUC = %.3f\n(desempenho baixo —\nuso demonstrativo)", auc_val),
             size = 4, fontface = "bold", color = "#333333", hjust = 0) +
    labs(
      title    = "Curva ROC — Modelo Preditivo de Mortalidade",
      subtitle = "Performance discriminativa dos diagnósticos NANDA derivados",
      x        = "1 — Especificidade",
      y        = "Sensibilidade",
      caption  = "AUC < 0.60: modelo NÃO adequado para uso clínico. Fins demonstrativos exclusivamente."
    ) +
    coord_fixed() +
    theme_cellpress(base_size = 13)

  salvar_figura(p, "Fig5B_CurvaROC", width = 6, height = 6)
  p
}

# =============================================================================
# FIGURA 6 (NOVA) — Distribuição de Diagnósticos NANDA por Faixa Etária
# =============================================================================
fig6_nanda_idade <- function(nanda) {

  if (!"anchor_age" %in% names(nanda)) return(NULL)

  nanda[, faixa_etaria := cut(anchor_age,
    breaks = c(18, 35, 50, 65, 80, 99),
    labels = c("18-34", "35-49", "50-64", "65-79", "80+"),
    include.lowest = TRUE)]

  top_domains <- nanda[, .N, by = nanda_domain][order(-N)][1:5, nanda_domain]
  plot_data <- nanda[nanda_domain %in% top_domains]

  age_data <- plot_data[, .(
    dx_por_paciente = .N / uniqueN(subject_id)
  ), by = .(faixa_etaria, nanda_domain)]

  p <- ggplot(age_data, aes(x = faixa_etaria, y = dx_por_paciente,
                             fill = nanda_domain)) +
    geom_col(position = "dodge", width = 0.7, alpha = 0.85) +
    scale_fill_cellpress("safe") +
    labs(
      title    = "Diagnósticos NANDA-I por Paciente em Cada Faixa Etária",
      subtitle = "Média de diagnósticos inferidos por paciente por faixa etária",
      x        = "Faixa Etária (anos)",
      y        = "Diagnósticos por Paciente",
      fill     = "Domínio NANDA-I",
      caption  = "Prova de conceito — camada derivada NANDA-I × MIMIC-IV"
    ) +
    theme_cellpress(base_size = 13) +
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5, size = 11))

  salvar_figura(p, "Fig6_NANDA_Idade", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 7 (NOVA) — Top Medicamentos Administrados (NIC 2300)
# =============================================================================
fig7_top_medicamentos <- function(nic) {

  if (!"medication" %in% names(nic)) return(NULL)

  med_data <- nic[nic_code == "2300", .(
    administracoes = .N,
    pacientes = uniqueN(subject_id)
  ), by = medication][order(-administracoes)][1:12]

  p <- ggplot(med_data, aes(x = reorder(medication, administracoes),
                             y = administracoes)) +
    geom_col(fill = "#2CA02C", width = 0.7, alpha = 0.85) +
    geom_text(aes(label = scales::comma(administracoes)),
              hjust = -0.1, size = 4.5, color = "#444444", fontface = "bold") +
    coord_flip() +
    labs(
      title    = "Medicamentos Mais Administrados — NIC 2300",
      subtitle = "Total de administrações registradas (eMAR) — 12 principais fármacos",
      x        = NULL,
      y        = "Número de Administrações",
      caption  = "NIC 2300 = Administração de Medicamentos. Prova de conceito."
    ) +
    theme_cellpress(base_size = 13) +
    expand_limits(y = max(med_data$administracoes) * 1.15)

  salvar_figura(p, "Fig7_Top_Medicamentos", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA 8 (NOVA) — Vias de Administração
# =============================================================================
fig8_vias_administracao <- function(nic) {

  if (!"route" %in% names(nic)) return(NULL)

  via_data <- nic[nic_code == "2300", .N, by = route][order(-N)]

  p <- ggplot(via_data, aes(x = reorder(route, N), y = N, fill = route)) +
    geom_col(width = 0.6, alpha = 0.85) +
    geom_text(aes(label = paste0(scales::comma(N), " (",
                                 round(100*N/sum(N), 1), "%)")),
              hjust = -0.1, size = 4.5, color = "#444444", fontface = "bold") +
    scale_fill_cellpress("safe") +
    coord_flip() +
    labs(
      title    = "Distribuição das Vias de Administração de Medicamentos",
      subtitle = "NIC 2300 — Administração de Medicamentos",
      x        = "Via de Administração",
      y        = "Número de Administrações",
      caption  = "IV = Intravenosa; PO = Oral; SC = Subcutânea; IM = Intramuscular; NG = Nasogástrica"
    ) +
    theme_cellpress(base_size = 13) +
    theme(legend.position = "none") +
    expand_limits(y = max(via_data$N) * 1.2)

  salvar_figura(p, "Fig8_Vias_Administracao", width = 8, height = 5)
  p
}

# =============================================================================
# FIGURA 9 (NOVA) — Balanço Hídrico Agregado por Paciente
# =============================================================================
fig9_balanco_hidrico <- function(noc) {

  bh_data <- noc[indicator %in% c("Volume Infundido", "Débito Urinário")]

  if (nrow(bh_data) == 0) return(NULL)

  # Agregar por stay
  balanco <- bh_data[, .(
    total_infundido = sum(value[indicator == "Volume Infundido"], na.rm = TRUE),
    total_debito = sum(value[indicator == "Débito Urinário"], na.rm = TRUE)
  ), by = stay_id]

  balanco[, balanco_liquido := total_infundido - total_debito]
  balanco <- balanco[!is.na(balanco_liquido) & !is.infinite(balanco_liquido)]

  p <- ggplot(balanco, aes(x = balanco_liquido)) +
    geom_histogram(fill = cellpress_colors$noc, bins = 50, alpha = 0.8,
                   color = "white", linewidth = 0.2) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "#D62728",
               linewidth = 0.8) +
    labs(
      title    = "Distribuição do Balanço Hídrico por Estadia em UTI",
      subtitle = "Volume total infundido — débito urinário total (mL)",
      x        = "Balanço Hídrico Líquido (mL)",
      y        = "Número de Estadia em UTI",
      caption  = "Valores positivos: balanço positivo. Linha tracejada: equilíbrio."
    ) +
    theme_cellpress(base_size = 13)

  salvar_figura(p, "Fig9_Balanco_Hidrico", width = 8, height = 5)
  p
}

# =============================================================================
# FIGURA 10 (NOVA) — Correlação NANDA × NIC por Paciente (Bubble)
# =============================================================================
fig10_correlacao_nanda_nic <- function(nanda, nic) {

  if (nrow(nanda) == 0 || nrow(nic) == 0) return(NULL)

  nanda_pac <- nanda[, .(n_dx = .N, n_dominios = uniqueN(nanda_domain)),
                      by = subject_id]
  nic_pac <- nic[, .(n_interv = .N, n_tipos = uniqueN(nic_label)),
                 by = subject_id]

  corr_data <- merge(nanda_pac, nic_pac, by = "subject_id")

  rho <- cor(corr_data$n_dx, corr_data$n_interv, method = "spearman")

  p <- ggplot(corr_data, aes(x = n_dx, y = n_interv)) +
    geom_point(alpha = 0.3, size = 2.5, color = cellpress_colors$safe[1]) +
    geom_smooth(method = "lm", se = TRUE, color = cellpress_colors$nanda,
                fill = cellpress_colors$nanda, alpha = 0.1, linewidth = 1) +
    annotate("text", x = max(corr_data$n_dx) * 0.65,
             y = max(corr_data$n_interv) * 0.92,
             label = sprintf("ρ de Spearman = %.3f\n(p = %.4f)", rho,
                             cor.test(corr_data$n_dx, corr_data$n_interv,
                                      method = "spearman")$p.value),
             size = 4.5, fontface = "bold", color = "#333333", hjust = 0) +
    labs(
      title    = "Correlação entre Diagnósticos (NANDA) e Intervenções (NIC)",
      subtitle = "Cada ponto = 1 paciente | Linha azul: regressão linear com IC 95%",
      x        = "Número de Diagnósticos NANDA-I (inferidos)",
      y        = "Número de Intervenções NIC (derivadas)",
      caption  = "Correlação fraca: evidência preliminar de coerência estrutural, não validação clínica."
    ) +
    theme_cellpress(base_size = 13)

  salvar_figura(p, "Fig10_Correlacao_NANDA_NIC", width = 8, height = 6)
  p
}

# =============================================================================
# FIGURA S1 — Tempo de Internação por Domínio NANDA (Boxplot)
# =============================================================================
figS1_los_nanda <- function(nanda) {

  if (!"los_days" %in% names(nanda)) return(NULL)

  los_data <- nanda[!is.na(los_days) & los_days > 0 & los_days < 60]
  top_domains <- los_data[, .N, by = nanda_domain][order(-N)][1:6, nanda_domain]
  los_data <- los_data[nanda_domain %in% top_domains]

  p <- ggplot(los_data, aes(x = nanda_domain, y = los_days,
                             fill = nanda_domain)) +
    geom_boxplot(outlier.size = 0.6, outlier.alpha = 0.3,
                 alpha = 0.7, width = 0.6) +
    scale_fill_cellpress("safe") +
    labs(
      title    = "Tempo de Internação por Domínio NANDA-I",
      subtitle = "Distribuição do LOS (dias) — Excluídos LOS > 60 dias",
      x        = "Domínio NANDA-I",
      y        = "Tempo de Internação (dias)",
      caption  = "LOS = Length of Stay. Boxplot: mediana, IQR, outliers."
    ) +
    theme_cellpress(base_size = 13) +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 25, hjust = 1, size = 11))

  salvar_figura(p, "FigS1_LOS_NANDA", width = 9, height = 5.5)
  p
}

# =============================================================================
# FIGURA S2 — Mapa de Calor: Severidade NANDA × Faixa Etária
# =============================================================================
figS2_severidade_idade <- function(nanda) {

  if (!all(c("anchor_age", "severity") %in% names(nanda))) return(NULL)

  nanda[, faixa_etaria := cut(anchor_age,
    breaks = c(18, 35, 50, 65, 80, 99),
    labels = c("18-34", "35-49", "50-64", "65-79", "80+"),
    include.lowest = TRUE)]

  sev_data <- nanda[, .N, by = .(faixa_etaria, severity)]
  sev_data[, pct := 100 * N / sum(N), by = faixa_etaria]

  p <- ggplot(sev_data, aes(x = faixa_etaria, y = severity, fill = pct)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = paste0(round(pct, 1), "%")), size = 4.5,
              fontface = "bold") +
    scale_fill_gradientn(colors = cellpress_colors$gradient_reds[2:8],
                         name = "% dentro\nda faixa") +
    labs(
      title    = "Distribuição da Severidade dos Diagnósticos NANDA por Faixa Etária",
      subtitle = "Percentual dentro de cada faixa etária",
      x        = "Faixa Etária (anos)",
      y        = "Severidade do Diagnóstico",
      caption  = "Prova de conceito — camada derivada NANDA-I × MIMIC-IV"
    ) +
    theme_cellpress(base_size = 13) +
    theme(legend.position = "right", panel.grid.major = element_blank())

  salvar_figura(p, "FigS2_Severidade_Idade", width = 8, height = 4.5)
  p
}

# =============================================================================
# GERADOR PRINCIPAL — Todas as Figuras
# =============================================================================
gerar_todas_figuras <- function(nanda, noc, nic, stat_results = NULL) {

  message("[FIGURAS] Gerando todas as visualizações (PDF + PNG)...")
  dir.create(PATHS$figures_dir, showWarnings = FALSE, recursive = TRUE)

  # Principais
  fig1a_prevalencia_nanda(nanda)
  fig1b_heatmap_nanda(nanda)
  fig2a_violin_noc(noc)
  fig2b_noc_anormais(noc)
  fig3a_barras_nic(nic)
  fig3b_turnos_nic(nic)

  # Sobrevivência
  if (!is.null(stat_results$survival)) {
    fig4_km_sobrevivencia(stat_results$survival$surv_data,
                          stat_results$survival$km_fit)
  }

  # Regressão
  if (!is.null(stat_results$logistic)) {
    fig5a_odds_ratios(stat_results$logistic$odds_ratios)
    fig5b_curva_roc(stat_results$logistic$roc, stat_results$logistic$auc)
  }

  # Novas figuras
  fig6_nanda_idade(nanda)
  fig7_top_medicamentos(nic)
  fig8_vias_administracao(nic)
  fig9_balanco_hidrico(noc)
  fig10_correlacao_nanda_nic(nanda, nic)

  # Suplementares
  figS1_los_nanda(nanda)
  figS2_severidade_idade(nanda)

  n_arquivos <- length(list.files(PATHS$figures_dir, pattern = "\\.(pdf|png)$"))
  message(sprintf("[FIGURAS] %d arquivos gerados em: %s", n_arquivos, PATHS$figures_dir))
}

# Executar se chamado diretamente
if (sys.nframe() == 0) {
  source(here::here("config.R"))
  source(here::here("02_nursing_mapping.R"))
  source(here::here("03_nanda_diagnostics.R"))
  source(here::here("04_noc_outcomes.R"))
  source(here::here("05_nic_interventions.R"))

  data <- readRDS(file.path(PATHS$cache_dir, "loaded_data.rds"))
  nanda <- extract_nanda_diagnostics(data)
  nanda <- process_nanda_diagnostics(nanda, data)
  noc <- extract_noc_outcomes(data)
  noc <- process_noc_outcomes(noc, data)
  nic <- extract_nic_interventions(data)
  nic <- process_nic_interventions(nic, data)

  gerar_todas_figuras(nanda, noc, nic)
}
