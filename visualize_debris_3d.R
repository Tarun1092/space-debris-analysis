# ==============================================================================
# OrbitalGuard AI - 3D Earth & Space Debris Interactive Visualizer (R Version)
# Reads the CSV catalog and renders an interactive 3D Earth Globe with 
# orbiting satellites, space debris, and spent rocket bodies using Plotly in R.
# ==============================================================================

library(plotly)
library(dplyr)
library(htmlwidgets)

# 1. Read the Space Debris CSV Dataset
csv_path <- "data/space_debris_catalog.csv"
if (!file.exists(csv_path)) {
  stop("CSV file not found! Please run preprocess_debris_data.R first.")
}

cat("Reading space debris catalog from:", csv_path, "\n")
df <- read.csv(csv_path, stringsAsFactors = FALSE)
cat(sprintf("Loaded %d tracked space objects.\n", nrow(df)))

# 2. Physics: Convert Keplerian Orbital Elements to 3D Cartesian Coordinates
EARTH_RADIUS_KM <- 6371.0

# Calculate mean altitude and scaled radial distance
df <- df %>%
  mutate(
    mean_alt_km = (perigee_km + apogee_km) / 2.0,
    r_units = 1.0 + (mean_alt_km / EARTH_RADIUS_KM), # Earth radius = 1.0
    
    # Angles in Radians
    inc_rad = inclination_deg * (pi / 180.0),
    raan_rad = raan_deg * (pi / 180.0),
    argp_rad = arg_perigee_deg * (pi / 180.0),
    mean_anom_rad = mean_anomaly_deg * (pi / 180.0),
    u_rad = argp_rad + mean_anom_rad,
    
    # Orbital Plane Coordinates
    x_orb = r_units * cos(u_rad),
    y_orb = r_units * sin(u_rad),
    
    # Rotate to Earth-Centered Inertial (ECI) 3D Cartesian Coordinates
    x = x_orb * cos(raan_rad) - y_orb * sin(raan_rad) * cos(inc_rad),
    y = x_orb * sin(raan_rad) + y_orb * cos(raan_rad) * cos(inc_rad),
    z = y_orb * sin(inc_rad)
  )

# Format Hover Tooltip Text
df <- df %>%
  mutate(
    hover_text = sprintf(
      "<b>%s</b><br>NORAD ID: #%d<br>Type: %s<br>Nation: %s<br>Orbit: %s<br>Altitude: %.1f km<br>Velocity: %.2f km/s<br>Period: %.1f min",
      name, norad_id, object_type, country, orbit_type, mean_alt_km, velocity_km_s, period_min
    )
  )

# 3. Generate 3D Earth Surface Sphere Mesh
lat_seq <- seq(-pi / 2, pi / 2, length.out = 60)
lon_seq <- seq(0, 2 * pi, length.out = 120)

grid <- expand.grid(lon = lon_seq, lat = lat_seq)
earth_x <- matrix(cos(grid$lat) * cos(grid$lon), nrow = 60, ncol = 120, byrow = TRUE)
earth_y <- matrix(cos(grid$lat) * sin(grid$lon), nrow = 60, ncol = 120, byrow = TRUE)
earth_z <- matrix(sin(grid$lat), nrow = 60, ncol = 120, byrow = TRUE)

# Realistic earth ocean/continent altitude texture matrix
elevation <- sin(3 * earth_x) * cos(3 * earth_y) + cos(2 * earth_z)

# 4. Build 3D Plotly Figure
fig <- plot_ly()

# Trace 1: 3D Earth Globe Surface
earth_colorscale <- list(
  list(0.00, "#040b1e"), # Deep Ocean
  list(0.40, "#0a2356"), # Shallow Waters
  list(0.55, "#1c4294"), # Coastal Shelf
  list(0.65, "#2d5a27"), # Vegetation Landmass
  list(0.85, "#c47a33"), # Deserts
  list(1.00, "#e6f2ff")  # Polar Ice
)

fig <- fig %>%
  add_surface(
    x = earth_x,
    y = earth_y,
    z = earth_z,
    surfacecolor = elevation,
    colorscale = earth_colorscale,
    showscale = FALSE,
    name = "Earth (Radius = 6,371 km)",
    hoverinfo = "none",
    opacity = 0.98,
    lighting = list(ambient = 0.8, diffuse = 0.9, specular = 0.2)
  )

# Subset objects by category
df_satellites <- df %>% filter(object_type == "PAYLOAD" & country != "IND")
df_isro <- df %>% filter(country == "IND")
df_debris <- df %>% filter(object_type == "DEBRIS")
df_rockets <- df %>% filter(object_type == "ROCKET BODY")

# Trace 2: Active Satellites (Cyan)
if (nrow(df_satellites) > 0) {
  fig <- fig %>%
    add_trace(
      data = df_satellites,
      x = ~x, y = ~y, z = ~z,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 3.5, color = "#00e5ff", opacity = 0.85),
      name = sprintf("Active Satellites (%d)", nrow(df_satellites)),
      text = ~hover_text,
      hoverinfo = "text"
    )
}

# Trace 3: ISRO Assets (Orange Beacon)
if (nrow(df_isro) > 0) {
  fig <- fig %>%
    add_trace(
      data = df_isro,
      x = ~x, y = ~y, z = ~z,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 5.0, color = "#ff9933", symbol = "diamond", opacity = 0.95),
      name = sprintf("ISRO Assets (%d)", nrow(df_isro)),
      text = ~hover_text,
      hoverinfo = "text"
    )
}

# Trace 4: Space Debris (Neon Pink / Red)
if (nrow(df_debris) > 0) {
  fig <- fig %>%
    add_trace(
      data = df_debris,
      x = ~x, y = ~y, z = ~z,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 2.5, color = "#ff2a6d", opacity = 0.80),
      name = sprintf("Space Debris (%d)", nrow(df_debris)),
      text = ~hover_text,
      hoverinfo = "text"
    )
}

# Trace 5: Spent Rocket Bodies (Amber Yellow)
if (nrow(df_rockets) > 0) {
  fig <- fig %>%
    add_trace(
      data = df_rockets,
      x = ~x, y = ~y, z = ~z,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 3.8, color = "#ffb703", opacity = 0.90),
      name = sprintf("Spent Rocket Bodies (%d)", nrow(df_rockets)),
      text = ~hover_text,
      hoverinfo = "text"
    )
}

# 5. Styling & 3D Camera Layout
fig <- fig %>%
  layout(
    title = list(
      text = "<b>OrbitalGuard AI: 3D Earth Space Debris Visualizer (R Version)</b><br><sup>Visualizing Satellites & Space Debris from CSV Dataset</sup>",
      font = list(color = "#00e5ff", size = 18, family = "sans-serif")
    ),
    paper_bgcolor = "#070913",
    plot_bgcolor = "#070913",
    scene = list(
      xaxis = list(visible = FALSE, showgrid = FALSE),
      yaxis = list(visible = FALSE, showgrid = FALSE),
      zaxis = list(visible = FALSE, showgrid = FALSE),
      bgcolor = "#070913",
      aspectmode = "data",
      camera = list(
        eye = list(x = 1.6, y = 1.6, z = 1.2)
      )
    ),
    legend = list(
      font = list(color = "#f0f4fc", size = 12),
      bgcolor = "rgba(14, 18, 36, 0.85)",
      bordercolor = "rgba(64, 93, 148, 0.5)",
      borderwidth = 1
    )
  )

# 6. Save Interactive HTML Widget
output_html <- "r_debris_globe_3d.html"
cat("Saving interactive 3D Earth Globe widget to:", output_html, "\n")
saveWidget(fig, output_html, selfcontained = FALSE)

cat("Successfully generated 3D Earth visualizer!\n")
cat("Open", output_html, "in your web browser to view the interactive 3D globe.\n")
