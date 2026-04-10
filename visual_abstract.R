# Visual abstract for "Trust in Autonomous Human-Robot Collaboration"
# Elsevier graphical abstract: 1328 x 531 px, 3-panel left-to-right narrative.
#
# Run from project root:
#   Rscript visual_abstract.R
#
# Outputs: visual_abstract.pdf  +  visual_abstract.png  (alongside this script)
# Needs to be a main title (like title of the paper)
# maybe add conclusion could use the highlights?

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(png)
  library(grid)
})

# ---- data ---------------------------------------------------------------
# Theoretical 1–5 → 0–100 rescale (matches the corrected paper; the original
# poster used empirical min/max due to a silently-ignored arg bug in
# scales::rescale — see README/commit notes).
rescale_theo <- function(x, from = c(1, 5), to = c(0, 100)) {
  (x - from[1]) / (from[2] - from[1]) * (to[2] - to[1]) + to[1]
}

d <- readRDS("full_dataset_with_items.rds")
s <- read.csv("data/analysis_output/final_dialogue_summary.csv")
d <- merge(d, s, by = "session_id")
d$exclusions <- ifelse(d$mean_comm_breakdown > 0.6, "exclude", "include")
d$post_trust2 <- rescale_theo(d$post_trust)

d2 <- d[d$exclusions != "exclude", ]
d2$group <- factor(
  d2$group,
  levels = c("CONTROL", "RESPONSIVE"),
  labels = c("Reactive", "Responsive")
)

# ---- palette ------------------------------------------------------------
teal <- "#3a7d7b" # responsive
grey <- "#9aa3a3" # reactive
ink <- "#1f2a2a"
bg <- "#ffffff"

base_theme <- theme_void(base_family = "sans") +
  theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    plot.margin = margin(8, 8, 8, 8)
  )

# ============================================================
# PANEL 1 — STUDY DESIGN
# ============================================================
# Use Misty line art as-is (white linework on black background).
# Note: the source asset images/robot_linework_20190205-1.png is actually an
# AVIF file despite the .png extension, so png::readPNG can't read it. It
# has been re-saved as a proper PNG at images/misty_lineart.png.
misty_img <- png::readPNG("images/misty_lineart.png")
misty_grob <- rasterGrob(misty_img, interpolate = TRUE)

p1 <- ggplot() +
  xlim(0, 10) +
  ylim(0, 10) +
  annotation_custom(
    misty_grob,
    xmin = 3.0,
    xmax = 8.0,
    ymin = 3.8,
    ymax = 8.9
  ) +
  annotate(
    "segment",
    x = 5,
    y = 4.0,
    xend = 2.2,
    yend = 2.0,
    arrow = arrow(length = unit(0.18, "cm"), type = "closed"),
    colour = grey,
    linewidth = 0.9
  ) +
  annotate(
    "segment",
    x = 5,
    y = 4.0,
    xend = 7.8,
    yend = 2.0,
    arrow = arrow(length = unit(0.18, "cm"), type = "closed"),
    colour = teal,
    linewidth = 0.9
  ) +
  annotate(
    "rect",
    xmin = 0.4,
    xmax = 4.0,
    ymin = 0.6,
    ymax = 2.0,
    fill = grey,
    alpha = 0.18,
    colour = grey,
    linewidth = 0.4
  ) +
  annotate(
    "text",
    x = 2.2,
    y = 1.55,
    label = "Reactive",
    fontface = "bold",
    colour = grey,
    size = 3.6
  ) +
  annotate(
    "text",
    x = 2.2,
    y = 0.95,
    label = "task-only replies",
    colour = grey,
    size = 2.5
  ) +
  annotate(
    "rect",
    xmin = 6.0,
    xmax = 9.6,
    ymin = 0.6,
    ymax = 2.0,
    fill = teal,
    alpha = 0.18,
    colour = teal,
    linewidth = 0.4
  ) +
  annotate(
    "text",
    x = 7.8,
    y = 1.55,
    label = "Responsive",
    fontface = "bold",
    colour = teal,
    size = 3.6
  ) +
  annotate(
    "text",
    x = 7.8,
    y = 0.95,
    label = "affect-adaptive",
    colour = teal,
    size = 2.5
  ) +
  annotate(
    "text",
    x = 5,
    y = 9.6,
    label = " ",
    fontface = "bold",
    size = 3.8,
    colour = ink
  ) +
  annotate(
    "text",
    x = 5,
    y = 9.05,
    label = " ",
    size = 2.7,
    colour = ink
  ) +
  base_theme +
  coord_cartesian(expand = FALSE, clip = "off") +
  labs(
    title = "Autonomous robot, two policies",
    subtitle = paste0(
      " ",
      "N = 24 \u00b7 Misty II \u00b7 in-person task"
    )
  ) +
  theme_minimal(base_family = "sans", base_size = 10) +
  theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    panel.grid.major.x = element_blank(),
    #panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(colour = "grey92"),
    axis.title = element_blank(),
    axis.text = element_blank(),
    plot.title = element_text(
      face = "bold",
      size = 11,
      colour = ink,
      hjust = 0.5
    ),
    plot.subtitle = element_text(
      size = 9.5,
      face = 'bold',
      colour = grey,
      hjust = 0.5,
      margin = margin(b = 4)
    ),
    plot.margin = margin(10, 10, 10, 10)
  )

# ============================================================
# PANEL 2 — KEY RESULT (TI-HRC)
# ============================================================
sumd <- aggregate(post_trust2 ~ group, data = d2, FUN = function(x) {
  c(m = mean(x), se = sd(x) / sqrt(length(x)))
})
sumd <- data.frame(
  group = sumd$group,
  m = sumd$post_trust2[, "m"],
  se = sumd$post_trust2[, "se"]
)
sumd$lo <- sumd$m - 1.96 * sumd$se
sumd$hi <- sumd$m + 1.96 * sumd$se

delta <- round(
  sumd$m[sumd$group == "Responsive"] -
    sumd$m[sumd$group == "Reactive"],
  0
)

p2 <- ggplot() +
  geom_jitter(
    data = d2,
    aes(x = group, y = post_trust2, colour = group),
    width = 0.10,
    height = 0,
    size = 1.6,
    alpha = 0.55
  ) +
  geom_errorbar(
    data = sumd,
    aes(x = group, ymin = lo, ymax = hi, colour = group),
    width = 0.12,
    linewidth = 0.9
  ) +
  geom_point(data = sumd, aes(x = group, y = m, colour = group), size = 3.8) +
  scale_colour_manual(
    values = c("Reactive" = grey, "Responsive" = teal),
    guide = "none"
  ) +
  scale_y_continuous(limits = c(25, 105), breaks = c(25, 50, 75, 100)) +
  labs(
    title = "Responsive Policy Increased Trust",
    subtitle = paste0("+", delta, " points with responsive policy")
  ) +
  theme_minimal(base_family = "sans", base_size = 10) +
  theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(colour = "grey92"),
    axis.title = element_blank(),
    axis.text = element_text(colour = ink, size = 9),
    plot.title = element_text(
      face = "bold",
      size = 11,
      colour = ink,
      hjust = 0.5
    ),
    plot.subtitle = element_text(
      size = 9.5,
      face = 'bold',
      colour = teal,
      hjust = 0.5,
      margin = margin(b = 4)
    ),
    plot.margin = margin(10, 10, 10, 10)
  )

# ============================================================
# PANEL 3 — BOUNDARY CONDITION (schematic, not a fitted model)
# ============================================================
p3 <- ggplot() +
  xlim(0, 10) +
  ylim(0, 10) +
  annotate(
    "text",
    x = 5,
    y = 9.6,
    label = " ",
    fontface = "bold",
    size = 3.8,
    colour = ink
  ) +
  annotate(
    "segment",
    x = 1.2,
    y = 7.2,
    xend = 8.8,
    yend = 4.2,
    colour = teal,
    linewidth = 1.4
  ) +
  annotate(
    "segment",
    x = 1.2,
    y = 4.0,
    xend = 8.8,
    yend = 3.7,
    colour = grey,
    linewidth = 1.4
  ) +
  annotate(
    "text",
    x = 9.0,
    y = 4.5,
    label = "Responsive",
    colour = teal,
    size = 2.8,
    hjust = 1,
    fontface = "bold"
  ) +
  annotate(
    "text",
    x = 9.0,
    y = 3.4,
    label = "Reactive",
    colour = grey,
    size = 2.8,
    hjust = 1,
    fontface = "bold"
  ) +
  annotate(
    "segment",
    x = 1.0,
    y = 2.6,
    xend = 9.2,
    yend = 2.6,
    colour = ink,
    linewidth = 0.4,
    arrow = arrow(length = unit(0.15, "cm"), type = "closed")
  ) +
  annotate(
    "segment",
    x = 1.0,
    y = 2.6,
    xend = 1.0,
    yend = 8.0,
    colour = ink,
    linewidth = 0.4,
    arrow = arrow(length = unit(0.15, "cm"), type = "closed")
  ) +
  annotate(
    "text",
    x = 5.1,
    y = 2.05,
    label = "communication breakdown \u2192",
    size = 2.6,
    colour = ink
  ) +
  annotate(
    "text",
    x = 0.55,
    y = 5.3,
    label = "trust",
    size = 2.6,
    colour = ink,
    angle = 90
  ) +
  annotate(
    "text",
    x = 5,
    y = 1.0,
    label = "Trust gap shrinks as language grounding fails",
    size = 2.7,
    face = "bold",
    colour = ink,
    fontface = "italic"
  ) +
  base_theme +
  coord_cartesian(expand = FALSE, clip = "off") +
  labs(
    title = "\u2026 When Communication Holds",
    subtitle = paste0(
      " ",
      " "
    )
  ) +
  theme_minimal(base_family = "sans", base_size = 10) +
  theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    panel.grid.major.x = element_blank(),
    #panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(colour = "grey92"),
    axis.title = element_blank(),
    axis.text = element_blank(),
    plot.title = element_text(
      face = "bold",
      size = 11,
      colour = ink,
      hjust = 0.5
    ),
    plot.subtitle = element_text(
      size = 9.5,
      face = 'bold',
      colour = ink,
      hjust = 0.5,
      margin = margin(b = 4)
    ),
    plot.margin = margin(10, 10, 10, 10)
  )

# ============================================================
# COMPOSE + EXPORT
# ============================================================
va <- p1 +
  p2 +
  p3 +
  plot_layout(widths = c(1, 1.05, 1)) &
  theme(plot.background = element_rect(fill = bg, colour = NA))


# Elsevier graphical abstract: min 1328 x 531 px @ 300dpi
ggsave(
  "visual_abstract.pdf",
  va,
  width = 1328 / 150,
  height = 531 / 150,
  units = "in",
  device = cairo_pdf
)
ggsave(
  "visual_abstract.png",
  va,
  width = 1328 / 150,
  height = 531 / 150,
  units = "in",
  dpi = 300
)

cat("Wrote visual_abstract.pdf and visual_abstract.png\n")
cat(sprintf(
  "TI-HRC means: Reactive = %.1f, Responsive = %.1f, delta = +%d\n",
  sumd$m[sumd$group == "Reactive"],
  sumd$m[sumd$group == "Responsive"],
  delta
))
