# =============================================================================
# theme_cellpress.R - Tema ggplot2 estilo Cell Press (Cell, Patterns, etc.)
# =============================================================================
# Cores e estilos inspirados nas diretrizes gráficas da Cell Press:
# - Tipografia clean com famílias sans-serif
# - Paleta de cores científicas distintas
# - Gridlines sutis
# - Elementos minimalistas
# =============================================================================

library(ggplot2)

# --- Paleta de Cores Cell Press-like -----------------------------------------
cellpress_colors <- list(

  # Paleta principal - Cores distintas e acessíveis para daltônicos
  main = c(
    "#1F77B4",  # Azul celeste
    "#FF7F0E",  # Laranja
    "#2CA02C",  # Verde
    "#D62728",  # Vermelho
    "#9467BD",  # Roxo
    "#8C564B",  # Marrom
    "#E377C2",  # Rosa
    "#7F7F7F",  # Cinza
    "#BCBD22",  # Verde-oliva
    "#17BECF"   # Ciano
  ),

  # Paleta para grupos (daltônico-friendly, Wong 2011)
  safe = c(
    "#0072B2",  # Azul
    "#E69F00",  # Laranja
    "#009E73",  # Verde-azulado
    "#F0E442",  # Amarelo
    "#56B4E9",  # Azul claro
    "#D55E00",  # Vermelho-alaranjado
    "#CC79A7",  # Magenta
    "#000000"   # Preto
  ),

  # Paleta de gradiente para heatmaps
  gradient_coolwarm = c("#053061", "#2166AC", "#4393C3", "#92C5DE",
                        "#F7F7F7", "#F4A582", "#D6604D", "#B2182B", "#67001F"),

  gradient_blues  = c("#F7FBFF", "#DEEBF7", "#C6DBEF", "#9ECAE1",
                      "#6BAED6", "#4292C6", "#2171B5", "#08519C", "#08306B"),

  gradient_reds   = c("#FFF5F0", "#FEE0D2", "#FCBBA1", "#FC9272",
                      "#FB6A4A", "#EF3B2C", "#CB181D", "#A50F15", "#67000D"),

  # Cores específicas para conceitos de enfermagem
  nanda  = "#D62728",  # Vermelho para diagnósticos
  noc    = "#1F77B4",  # Azul para resultados
  nic    = "#2CA02C"   # Verde para intervenções
)

# --- Função para escala de cores da Cell Press -------------------------------
scale_color_cellpress <- function(palette = "main", ...) {
  pal <- cellpress_colors[[palette]]
  if (is.null(pal)) pal <- cellpress_colors$main
  ggplot2::scale_color_manual(values = pal, ...)
}

scale_fill_cellpress <- function(palette = "main", ...) {
  pal <- cellpress_colors[[palette]]
  if (is.null(pal)) pal <- cellpress_colors$main
  ggplot2::scale_fill_manual(values = pal, ...)
}

# --- Tema Cell Press ---------------------------------------------------------
theme_cellpress <- function(base_size = 11, base_family = "Helvetica") {

  # Fallback se Helvetica não estiver disponível
  if (!base_family %in% sysfonts::font_families()) {
    if ("Arial" %in% sysfonts::font_families()) {
      base_family <- "Arial"
    } else {
      base_family <- "sans"
    }
  }

  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      # Texto
      text = element_text(color = "#333333"),
      plot.title = element_text(size = base_size + 3, face = "bold",
                                hjust = 0, margin = margin(b = 8)),
      plot.subtitle = element_text(size = base_size, hjust = 0,
                                   color = "#555555", margin = margin(b = 12)),
      plot.caption = element_text(size = base_size - 2, hjust = 1,
                                  color = "#888888", margin = margin(t = 10)),

      # Eixos
      axis.title = element_text(size = base_size, color = "#333333"),
      axis.title.x = element_text(margin = margin(t = 8)),
      axis.title.y = element_text(margin = margin(r = 8)),
      axis.text = element_text(size = base_size - 1, color = "#555555"),
      axis.line = element_line(color = "#333333", linewidth = 0.3),
      axis.ticks = element_line(color = "#333333", linewidth = 0.3),
      axis.ticks.length = unit(3, "pt"),

      # Grid
      panel.grid.major = element_line(color = "#E8E8E8", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      panel.border = element_blank(),

      # Legenda
      legend.position = "bottom",
      legend.title = element_text(size = base_size - 1, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      legend.key.size = unit(0.8, "cm"),
      legend.box.spacing = unit(0.3, "cm"),
      legend.margin = margin(t = 4),

      # Facets
      strip.background = element_rect(fill = "#F0F0F0", color = NA),
      strip.text = element_text(size = base_size - 1, face = "bold",
                                margin = margin(t = 2, b = 2)),

      # Margens
      plot.margin = margin(15, 15, 10, 10)
    )
}

# --- Tema Cell Press para violino / boxplot ----------------------------------
theme_cellpress_dense <- function(base_size = 10, base_family = "Helvetica") {
  theme_cellpress(base_size, base_family) +
    theme(
      panel.grid.major.x = element_blank(),
      legend.position = "right",
      legend.key.size = unit(0.5, "cm")
    )
}

# --- Função para salvar figuras no padrão Cell Press -------------------------
save_cellpress_figure <- function(plot, filename, width = 6, height = 4.5,
                                   dpi = 600, format = "pdf", ...) {
  # Formato golden ratio para single column (85mm ≈ 3.35in)
  dir.create(dirname(filename), showWarnings = FALSE, recursive = TRUE)

  ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = format,
    units = "in",
    ...
  )

  message(sprintf("[FIGURE] Salvo: %s (%s)", basename(filename), format))
}

# --- Adicionar letras de painel (A, B, C...) estilo Cell Press ---------------
add_panel_letter <- function(plot, letter, x = -0.03, y = 1.05,
                              size = 5, fontface = "bold") {
  plot +
    annotate("text", x = -Inf, y = Inf, label = letter,
             hjust = -0.5, vjust = 1.5, size = size,
             fontface = fontface, color = "#333333")
}

# --- Nota estatística padrão Cell Press (asteriscos) -------------------------
format_pvalue_cellpress <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.0001) return("****")
  if (p < 0.001)  return("***")
  if (p < 0.01)   return("**")
  if (p < 0.05)   return("*")
  return(sprintf("p=%.3f", p))
}

# --- Verificar / instalar fonte Helvetica (ou usar fallback) -----------------
.onLoad <- function(libname, pkgname) {
  if (requireNamespace("sysfonts", quietly = TRUE)) {
    if (!"Helvetica" %in% sysfonts::font_families()) {
      message("[theme_cellpress] Fonte Helvetica não encontrada. Usando fallback 'sans'.")
    }
  }
}

message("[THEME] Tema Cell Press carregado.")
