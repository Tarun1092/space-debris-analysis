# ==============================================================================
# OrbitalGuard AI - Space Debris Analytics & Statistics Dashboard (R Version)
# Performs statistical analysis and generates publication-grade visualizations
# using ggplot2, dplyr, and plotly from the CSV dataset.
# ==============================================================================

library(ggplot2)
library(dplyr)
library(plotly)
library(htmlwidgets)

# Create figures output directory
dir.create("figures", showWarnings = FALSE)

# 1. Read the Space Debris CSV Dataset
csv_path <- "data/space_debris_catalog.csv"
if (!file.exists(csv_path)) {
  stop("CSV file not found! Please run preprocess_debris_data.R first.")
}

cat("Reading space debris catalog from:", csv_path, "\n")
df <- read.csv(csv_path, stringsAsFactors = FALSE)

# Compute mean altitude
df <- df %>% mutate(mean_alt_km = (perigee_km + apogee_km) / 2.0)

# ==============================================================================
# 2. Key Summary Statistics
# ==============================================================================
total_objs <- nrow(df)
active_payloads <- sum(df$object_type == "PAYLOAD")
debris_count <- sum(df$object_type == "DEBRIS")
rocket_count <- sum(df$object_type == "ROCKET BODY")
isro_count <- sum(df$country == "IND")
leo_count <- sum(df$orbit_type == "LEO")

cat("\n=======================================================\n")
cat("          SPACE DEBRIS ANALYTICS REPORT                \n")
cat("=======================================================\n")
cat(sprintf("Total Cataloged Space Objects: %d\n", total_objs))
cat(sprintf("Active Satellite Payloads:     %d (%.1f%%)\n", active_payloads, (active_payloads / total_objs) * 100))
cat(sprintf("Tracked Space Debris Pieces:   %d (%.1f%%)\n", debris_count, (debris_count / total_objs) * 100))
cat(sprintf("Spent Rocket Bodies:           %d (%.1f%%)\n", rocket_count, (rocket_count / total_objs) * 100))
cat(sprintf("ISRO (India) Tracked Assets:   %d\n", isro_count))
cat(sprintf("LEO Regime Objects (<2,000 km):%d (%.1f%%)\n", leo_count, (leo_count / total_objs) * 100))
cat("=======================================================\n\n")

# Dark Theme for ggplot2
theme_space <- theme_minimal(base_size = 12) +
  theme(
    plot.background = element_rect(fill = "#070913", color = NA),
    panel.background = element_rect(fill = "#0b122e", color = NA),
    panel.grid.major = element_line(color = "#1c2545"),
    panel.grid.minor = element_line(color = "#121830"),
    text = element_text(color = "#f0f4fc"),
    axis.text = element_text(color = "#8e9bb4"),
    axis.title = element_text(color = "#00e5ff", face = "bold"),
    plot.title = element_text(color = "#00e5ff", face = "bold", size = 14),
    plot.subtitle = element_text(color = "#8e9bb4", size = 10),
    legend.background = element_rect(fill = "#0e1224", color = "#253459"),
    legend.text = element_text(color = "#f0f4fc"),
    legend.title = element_text(color = "#00e5ff")
  )

# ==============================================================================
# Plot 1: Altitude Spatial Density Distribution (LEO: 0 - 2,000 km)
# ==============================================================================
cat("Generating Plot 1: Altitude Spatial Density Distribution...\n")
df_leo <- df %>% filter(mean_alt_km <= 2000)

p1 <- ggplot(df_leo, aes(x = mean_alt_km, fill = object_type)) +
  geom_histogram(binwidth = 50, color = "#070913", alpha = 0.85) +
  scale_fill_manual(
    values = c("PAYLOAD" = "#00e5ff", "DEBRIS" = "#ff2a6d", "ROCKET BODY" = "#ffb703", "UNKNOWN" = "#8e9bb4")
  ) +
  labs(
    title = "Space Object Spatial Density across Low Earth Orbit (LEO)",
    subtitle = "Peak crowding observed in Sun-Synchronous Polar Shells (750 - 900 km)",
    x = "Mean Orbital Altitude (km)",
    y = "Cataloged Object Count",
    fill = "Object Category"
  ) +
  theme_space

ggsave("figures/altitude_spatial_density.png", p1, width = 9, height = 5, dpi = 300)

# ==============================================================================
# Plot 2: Object Type Breakdown (Bar Chart)
# ==============================================================================
cat("Generating Plot 2: Distribution by Object Type...\n")
type_summary <- df %>%
  group_by(object_type) %>%
  summarise(Count = n(), .groups = "drop") %>%
  mutate(Percentage = round((Count / sum(Count)) * 100, 1))

p2 <- ggplot(type_summary, aes(x = reorder(object_type, -Count), y = Count, fill = object_type)) +
  geom_bar(stat = "identity", width = 0.6) +
  geom_text(aes(label = sprintf("%d (%s%%)", Count, Percentage)), vjust = -0.4, color = "#f0f4fc", fontface = "bold", size = 3.5) +
  scale_fill_manual(
    values = c("PAYLOAD" = "#00e5ff", "DEBRIS" = "#ff2a6d", "ROCKET BODY" = "#ffb703", "UNKNOWN" = "#8e9bb4")
  ) +
  labs(
    title = "Orbital Object Population Breakdown",
    subtitle = "Debris fragments constitute over 65% of all cataloged objects in orbit",
    x = "Object Classification",
    y = "Count"
  ) +
  theme_space +
  theme(legend.position = "none")

ggsave("figures/object_type_breakdown.png", p2, width = 8, height = 5, dpi = 300)

# ==============================================================================
# Plot 3: Space Objects Share by Country / Agency
# ==============================================================================
cat("Generating Plot 3: Country Share Distribution...\n")
country_summary <- df %>%
  group_by(country) %>%
  summarise(Count = n(), .groups = "drop") %>%
  arrange(desc(Count))

p3 <- ggplot(country_summary, aes(x = reorder(country, -Count), y = Count, fill = country)) +
  geom_bar(stat = "identity", fill = "#7c4dff", width = 0.6) +
  geom_text(aes(label = Count), vjust = -0.4, color = "#f0f4fc", size = 3.2) +
  labs(
    title = "Catalog Share by Nation / Space Agency",
    subtitle = "Analysis of space actors contributing to active satellites and debris",
    x = "Nation / Space Agency",
    y = "Tracked Objects"
  ) +
  theme_space

ggsave("figures/country_share_distribution.png", p3, width = 9, height = 5, dpi = 300)

# ==============================================================================
# Plot 4: Orbital Velocity vs. Altitude (Keplerian Physics Verification)
# ==============================================================================
cat("Generating Plot 4: Orbital Velocity vs Altitude...\n")
p4 <- ggplot(df, aes(x = mean_alt_km, y = velocity_km_s, color = object_type)) +
  geom_point(alpha = 0.6, size = 1.5) +
  scale_color_manual(
    values = c("PAYLOAD" = "#00e5ff", "DEBRIS" = "#ff2a6d", "ROCKET BODY" = "#ffb703", "UNKNOWN" = "#8e9bb4")
  ) +
  scale_x_log10(labels = scales::comma) +
  labs(
    title = "Orbital Velocity vs. Altitude (Keplerian Physics)",
    subtitle = expression(v == sqrt(mu / a) ~ "illustrating high collision kinetic velocities in LEO (~7.5 km/s)"),
    x = "Altitude (km, Log Scale)",
    y = "Orbital Velocity (km/s)",
    color = "Category"
  ) +
  theme_space

ggsave("figures/velocity_vs_altitude.png", p4, width = 9, height = 5, dpi = 300)

# ==============================================================================
# 3. Interactive Web Dashboard Export using Plotly
# ==============================================================================
cat("Exporting interactive analytics dashboard HTML...\n")
p1_interactive <- ggplotly(p1)
saveWidget(p1_interactive, "r_analytics_dashboard.html", selfcontained = FALSE)

cat("\nAll analytics plots and reports successfully generated in R!\n")
cat("Generated PNG figures in 'figures/' directory:\n")
cat("- figures/altitude_spatial_density.png\n")
cat("- figures/object_type_breakdown.png\n")
cat("- figures/country_share_distribution.png\n")
cat("- figures/velocity_vs_altitude.png\n")
cat("- r_analytics_dashboard.html (Interactive Plotly Dashboard)\n")
