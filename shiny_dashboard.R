# ==============================================================================
# OrbitalGuard AI - Interactive Space Debris Analytics Dashboard (Shiny + R)
# Libraries: shiny, shinydashboard, plotly, ggplot2, DT, dplyr, scales
# Dataset:   data/space_debris_catalog.csv  (3,500 objects, 20 columns)
# Run with:  shiny::runApp("shiny_dashboard.R")
# ==============================================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(ggplot2)
library(dplyr)
library(DT)
library(scales)

# ──────────────────────────────────────────────────────────────────────────────
# GLOBAL: Load & Preprocess CSV Dataset
# ──────────────────────────────────────────────────────────────────────────────
EARTH_RADIUS_KM <- 6371.0

df_raw <- read.csv("data/space_debris_catalog.csv", stringsAsFactors = FALSE)

df_raw <- df_raw %>%
  mutate(
    mean_alt_km  = (perigee_km + apogee_km) / 2.0,
    # Keplerian ECI Cartesian conversion (Earth radius = 1.0)
    r_units      = 1.0 + (mean_alt_km / EARTH_RADIUS_KM),
    inc_rad      = inclination_deg * pi / 180,
    raan_rad     = raan_deg        * pi / 180,
    argp_rad     = arg_perigee_deg * pi / 180,
    nu_rad       = mean_anomaly_deg * pi / 180,
    u_rad        = argp_rad + nu_rad,
    x_orb        = r_units * cos(u_rad),
    y_orb        = r_units * sin(u_rad),
    X            = x_orb * cos(raan_rad) - y_orb * sin(raan_rad) * cos(inc_rad),
    Y            = x_orb * sin(raan_rad) + y_orb * cos(raan_rad) * cos(inc_rad),
    Z            = y_orb * sin(inc_rad),
    hover_text   = sprintf(
      "<b>%s</b><br>NORAD: #%d<br>Type: %s<br>Nation: %s<br>Orbit: %s<br>Alt: %.0f km<br>Velocity: %.2f km/s<br>Period: %.1f min",
      name, norad_id, object_type, country, orbit_type,
      mean_alt_km, velocity_km_s, period_min
    )
  )

# Colour palette
TYPE_COLORS <- c(
  "PAYLOAD"      = "#00e5ff",
  "DEBRIS"       = "#ff2a6d",
  "ROCKET BODY"  = "#ffb703",
  "UNKNOWN"      = "#8e9bb4"
)

# 3D Earth surface mesh (lat/lon grid)
lat_seq  <- seq(-pi / 2, pi / 2, length.out = 60)
lon_seq  <- seq(0, 2 * pi, length.out = 120)
grd      <- expand.grid(lon = lon_seq, lat = lat_seq)
EARTH_X  <- matrix(cos(grd$lat) * cos(grd$lon), 60, 120, byrow = TRUE)
EARTH_Y  <- matrix(cos(grd$lat) * sin(grd$lon), 60, 120, byrow = TRUE)
EARTH_Z  <- matrix(sin(grd$lat),                60, 120, byrow = TRUE)
ELEVATION <- sin(3 * EARTH_X) * cos(3 * EARTH_Y) + cos(2 * EARTH_Z)

EARTH_CS <- list(
  list(0.00, "#040b1e"), list(0.40, "#0a2356"),
  list(0.58, "#1c4294"), list(0.65, "#2d5a27"),
  list(0.82, "#c47a33"), list(1.00, "#e6f2ff")
)

# ──────────────────────────────────────────────────────────────────────────────
# CUSTOM CSS – dark space theme
# ──────────────────────────────────────────────────────────────────────────────
DARK_CSS <- "
/* ── Body & Layout ─────────────────────────────── */
body, .content-wrapper, .main-footer, .main-sidebar,
.sidebar, .left-side { background:#070913 !important; color:#f0f4fc !important; }

/* ── Sidebar ────────────────────────────────────── */
.skin-blue .main-sidebar { background:#0b122e !important; }
.skin-blue .sidebar a     { color:#8e9bb4 !important; }
.skin-blue .sidebar-menu > li.active > a,
.skin-blue .sidebar-menu > li:hover  > a { background:#1a2550 !important; color:#00e5ff !important; }

/* ── Header ─────────────────────────────────────── */
.skin-blue .main-header .navbar,
.skin-blue .main-header .logo  { background:#0b122e !important; border-bottom:1px solid #1e2d5a; }
.skin-blue .main-header .logo  { color:#00e5ff !important; font-weight:800; letter-spacing:1px; }

/* ── Info-Boxes ─────────────────────────────────── */
.info-box            { background:#111a3a !important; border-radius:8px; }
.info-box-icon       { border-radius:8px 0 0 8px; }
.info-box-content    { color:#f0f4fc; }
.info-box-number     { color:#00e5ff !important; font-size:22px; font-weight:700; }
.info-box-text       { color:#8e9bb4 !important; }

/* ── Box Cards ───────────────────────────────────── */
.box                 { background:#111a3a !important; border-top:3px solid #00e5ff !important;
                       border-radius:8px; color:#f0f4fc; }
.box-header          { background:#0e1530 !important; border-bottom:1px solid #1e2d5a; }
.box-title           { color:#00e5ff !important; font-weight:700; }
.box-body            { background:#111a3a !important; }

/* ── Inputs ─────────────────────────────────────── */
.form-control, select { background:#0b122e !important; color:#f0f4fc !important;
                         border:1px solid #253460 !important; border-radius:4px; }
.selectize-input, .selectize-dropdown { background:#0b122e !important; color:#f0f4fc !important; }
.selectize-dropdown-content .option:hover { background:#1a2550 !important; }
.irs-bar, .irs-bar-edge  { background:#00e5ff !important; border-color:#00e5ff !important; }
.irs-single, .irs-to, .irs-from { background:#00e5ff !important; color:#070913 !important; }
.irs-grid-text { color:#8e9bb4 !important; }
.irs-min, .irs-max { color:#8e9bb4 !important; background:#0b122e !important; }

/* ── Tabs ────────────────────────────────────────── */
.nav-tabs > li > a   { background:#0b122e; color:#8e9bb4; border-color:#1e2d5a; }
.nav-tabs > li.active > a { background:#1a2550; color:#00e5ff; border-bottom-color:#1a2550; }

/* ── DataTable ───────────────────────────────────── */
.dataTables_wrapper  { color:#f0f4fc; }
table.dataTable thead th { background:#0e1530 !important; color:#00e5ff !important;
                            border-bottom:1px solid #1e2d5a !important; }
table.dataTable tbody tr { background:#111a3a !important; color:#f0f4fc; }
table.dataTable tbody tr:hover { background:#1a2550 !important; }
.dataTables_info, .dataTables_length, .dataTables_filter { color:#8e9bb4 !important; }
.paginate_button { background:#0b122e !important; color:#8e9bb4 !important; border-radius:4px; }
.paginate_button.current { background:#00e5ff !important; color:#070913 !important; }

/* ── Misc ────────────────────────────────────────── */
label { color:#8e9bb4 !important; }
h4    { color:#00e5ff !important; }
"

# ──────────────────────────────────────────────────────────────────────────────
# UI
# ──────────────────────────────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = "blue",

  # ── Header ──
  dashboardHeader(
    title = HTML("<i class='fa fa-satellite-dish'></i>&nbsp; OrbitalGuard AI"),
    titleWidth = 280
  ),

  # ── Sidebar ──
  dashboardSidebar(
    width = 280,
    tags$head(tags$style(HTML(DARK_CSS))),

    sidebarMenu(
      menuItem("3D Earth Globe",      tabName = "tab_globe",     icon = icon("globe")),
      menuItem("Debris Analytics",    tabName = "tab_analytics", icon = icon("chart-bar")),
      menuItem("Orbital Data Table",  tabName = "tab_table",     icon = icon("table")),
      menuItem("Orbit Distribution",  tabName = "tab_orbit",     icon = icon("circle-notch"))
    ),

    hr(style = "border-color:#1e2d5a;"),
    tags$div(style = "padding:0 15px;",
      tags$h5(style = "color:#00e5ff; font-weight:700;",
              icon("sliders"), " Filters"),

      # Altitude Slider
      sliderInput("alt_range", "Altitude Range (km)",
                  min = 200, max = 36000, value = c(200, 36000),
                  step = 100, sep = ","),

      # Object Type
      checkboxGroupInput("obj_types", "Object Type",
        choices  = c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN"),
        selected = c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN")
      ),

      # Orbit Regime
      selectInput("orbit_regime", "Orbit Regime",
        choices  = c("ALL", "LEO", "MEO", "GEO", "HEO"),
        selected = "ALL"
      ),

      # Country
      selectInput("country_filter", "Nation / Agency",
        choices  = c("ALL", sort(unique(df_raw$country))),
        selected = "ALL"
      ),

      tags$div(style = "margin-top:8px;",
        actionButton("btn_reset", "Reset Filters",
                     icon = icon("undo"),
                     style = "background:#1a2550; color:#00e5ff; border:1px solid #00e5ff;
                              width:100%; border-radius:4px;")
      )
    )
  ),

  # ── Body ──
  dashboardBody(
    tags$style(HTML(DARK_CSS)),

    tabItems(

      # ================================================================
      # TAB 1: 3D EARTH GLOBE
      # ================================================================
      tabItem(tabName = "tab_globe",
        fluidRow(
          infoBoxOutput("ib_total",    width = 3),
          infoBoxOutput("ib_debris",   width = 3),
          infoBoxOutput("ib_payloads", width = 3),
          infoBoxOutput("ib_rockets",  width = 3)
        ),
        fluidRow(
          box(
            title = HTML("<i class='fa fa-earth-americas'></i>  Interactive 3D Earth & Debris Globe"),
            width = 12, solidHeader = TRUE,
            plotlyOutput("globe_3d", height = "620px")
          )
        ),
        fluidRow(
          box(
            title = HTML("<i class='fa fa-circle-info'></i>  How to Interact"),
            width = 12, solidHeader = TRUE, collapsible = TRUE, collapsed = TRUE,
            tags$ul(style = "color:#8e9bb4; line-height:2.2;",
              tags$li(HTML("<b style='color:#00e5ff'>Drag</b> to rotate the globe.")),
              tags$li(HTML("<b style='color:#00e5ff'>Scroll</b> to zoom in / out.")),
              tags$li(HTML("<b style='color:#00e5ff'>Hover</b> over any point to see satellite / debris details.")),
              tags$li(HTML("<b style='color:#00e5ff'>Click legend</b> entries to toggle object categories.")),
              tags$li(HTML("Use the <b style='color:#00e5ff'>sidebar filters</b> to refine altitude, type, and country."))
            )
          )
        )
      ),

      # ================================================================
      # TAB 2: ANALYTICS CHARTS
      # ================================================================
      tabItem(tabName = "tab_analytics",
        fluidRow(
          box(
            title = HTML("<i class='fa fa-chart-column'></i>  Altitude Spatial Density (LEO ≤ 2,000 km)"),
            width = 8, solidHeader = TRUE,
            plotlyOutput("chart_altitude", height = "350px")
          ),
          box(
            title = HTML("<i class='fa fa-chart-pie'></i>  Object Type Distribution"),
            width = 4, solidHeader = TRUE,
            plotlyOutput("chart_type_pie", height = "350px")
          )
        ),
        fluidRow(
          box(
            title = HTML("<i class='fa fa-globe-asia'></i>  Objects by Nation / Agency"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_country", height = "350px")
          ),
          box(
            title = HTML("<i class='fa fa-bolt'></i>  Orbital Velocity vs. Altitude (Keplerian)"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_velocity", height = "350px")
          )
        ),
        fluidRow(
          box(
            title = HTML("<i class='fa fa-compass'></i>  Inclination Distribution by Object Type"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_inclination", height = "320px")
          ),
          box(
            title = HTML("<i class='fa fa-weight-hanging'></i>  Mass Distribution by Orbit Regime"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_mass", height = "320px")
          )
        )
      ),

      # ================================================================
      # TAB 3: ORBITAL DATA TABLE
      # ================================================================
      tabItem(tabName = "tab_table",
        fluidRow(
          box(
            title = HTML("<i class='fa fa-database'></i>  Space Object Catalog (CSV Dataset)"),
            width = 12, solidHeader = TRUE,
            DTOutput("catalog_table")
          )
        )
      ),

      # ================================================================
      # TAB 4: ORBIT REGIME SUMMARY
      # ================================================================
      tabItem(tabName = "tab_orbit",
        fluidRow(
          box(
            title = HTML("<i class='fa fa-layer-group'></i>  Objects per Orbit Regime"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_regime_bar", height = "340px")
          ),
          box(
            title = HTML("<i class='fa fa-chart-pie'></i>  Regime Percentage Share"),
            width = 6, solidHeader = TRUE,
            plotlyOutput("chart_regime_pie", height = "340px")
          )
        ),
        fluidRow(
          box(
            title = HTML("<i class='fa fa-satellite'></i>  Period vs. Altitude (Kepler's 3rd Law)"),
            width = 12, solidHeader = TRUE,
            plotlyOutput("chart_period_alt", height = "370px")
          )
        )
      )
    )
  )
)

# ──────────────────────────────────────────────────────────────────────────────
# SERVER
# ──────────────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # ── Reactive: Filtered Dataset ──────────────────────────────────────────────
  df_filtered <- reactive({
    d <- df_raw %>%
      filter(
        mean_alt_km >= input$alt_range[1],
        mean_alt_km <= input$alt_range[2],
        object_type %in% input$obj_types
      )
    if (input$orbit_regime != "ALL")
      d <- d %>% filter(orbit_type == input$orbit_regime)
    if (input$country_filter != "ALL")
      d <- d %>% filter(country == input$country_filter)
    d
  })

  # ── Reset Filters ────────────────────────────────────────────────────────────
  observeEvent(input$btn_reset, {
    updateSliderInput(session, "alt_range", value = c(200, 36000))
    updateCheckboxGroupInput(session, "obj_types",
      selected = c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN"))
    updateSelectInput(session, "orbit_regime", selected = "ALL")
    updateSelectInput(session, "country_filter", selected = "ALL")
  })

  # ── Info Boxes ────────────────────────────────────────────────────────────────
  output$ib_total <- renderInfoBox({
    infoBox("Tracked Objects", format(nrow(df_filtered()), big.mark = ","),
            icon = icon("globe"), color = "light-blue", fill = TRUE)
  })
  output$ib_debris <- renderInfoBox({
    n <- sum(df_filtered()$object_type == "DEBRIS")
    infoBox("Space Debris", format(n, big.mark = ","),
            icon = icon("triangle-exclamation"), color = "red", fill = TRUE)
  })
  output$ib_payloads <- renderInfoBox({
    n <- sum(df_filtered()$object_type == "PAYLOAD")
    infoBox("Active Satellites", format(n, big.mark = ","),
            icon = icon("satellite"), color = "aqua", fill = TRUE)
  })
  output$ib_rockets <- renderInfoBox({
    n <- sum(df_filtered()$object_type == "ROCKET BODY")
    infoBox("Rocket Bodies", format(n, big.mark = ","),
            icon = icon("rocket"), color = "yellow", fill = TRUE)
  })

  # ── 3D Globe ─────────────────────────────────────────────────────────────────
  output$globe_3d <- renderPlotly({
    d <- df_filtered()

    fig <- plot_ly() %>%
      # Earth surface
      add_surface(
        x = EARTH_X, y = EARTH_Y, z = EARTH_Z,
        surfacecolor = ELEVATION,
        colorscale   = EARTH_CS,
        showscale    = FALSE,
        name         = "Earth Globe",
        hoverinfo    = "none",
        opacity      = 0.98,
        lighting     = list(ambient = 0.8, diffuse = 0.9, specular = 0.2)
      )

    # Add one trace per object type
    for (otype in c("PAYLOAD", "ROCKET BODY", "DEBRIS", "UNKNOWN")) {
      sub <- d %>% filter(object_type == otype)
      if (nrow(sub) == 0) next
      # ISRO assets shown bigger within PAYLOAD trace
      if (otype == "PAYLOAD") {
        non_isro <- sub %>% filter(country != "IND")
        isro     <- sub %>% filter(country == "IND")
        if (nrow(non_isro) > 0)
          fig <- fig %>% add_trace(
            data = non_isro, x = ~X, y = ~Y, z = ~Z,
            type = "scatter3d", mode = "markers",
            marker = list(size = 3.5, color = TYPE_COLORS["PAYLOAD"], opacity = 0.85),
            name = sprintf("Satellites (%d)", nrow(non_isro)),
            text = ~hover_text, hoverinfo = "text"
          )
        if (nrow(isro) > 0)
          fig <- fig %>% add_trace(
            data = isro, x = ~X, y = ~Y, z = ~Z,
            type = "scatter3d", mode = "markers",
            marker = list(size = 5.5, color = "#ff9933", symbol = "diamond", opacity = 0.98),
            name = sprintf("ISRO Assets (%d)", nrow(isro)),
            text = ~hover_text, hoverinfo = "text"
          )
      } else {
        fig <- fig %>% add_trace(
          data = sub, x = ~X, y = ~Y, z = ~Z,
          type = "scatter3d", mode = "markers",
          marker = list(size = if (otype == "ROCKET BODY") 4 else 2.5,
                        color = TYPE_COLORS[otype], opacity = 0.82),
          name = sprintf("%s (%d)", otype, nrow(sub)),
          text = ~hover_text, hoverinfo = "text"
        )
      }
    }

    fig %>% layout(
      paper_bgcolor = "#070913",
      scene = list(
        xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        zaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        bgcolor = "#070913",
        aspectmode = "data",
        camera = list(eye = list(x = 1.5, y = 1.5, z = 1.2))
      ),
      legend = list(
        font = list(color = "#f0f4fc", size = 11),
        bgcolor = "rgba(11,18,46,0.85)",
        bordercolor = "#253459", borderwidth = 1
      ),
      margin = list(l = 0, r = 0, t = 0, b = 0)
    )
  })

  # ── Analytics: Altitude Density ──────────────────────────────────────────────
  output$chart_altitude <- renderPlotly({
    d <- df_filtered() %>% filter(mean_alt_km <= 2000)
    if (nrow(d) == 0) return(NULL)

    plot_ly(d, x = ~mean_alt_km, color = ~object_type, colors = TYPE_COLORS,
            type = "histogram", nbinsx = 40,
            marker = list(line = list(color = "#070913", width = 0.5))) %>%
      layout(
        barmode = "stack",
        xaxis   = list(title = "Mean Altitude (km)", color = "#8e9bb4",
                       gridcolor = "#1c2545", zerolinecolor = "#1c2545"),
        yaxis   = list(title = "Object Count", color = "#8e9bb4",
                       gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        legend = list(font = list(color = "#f0f4fc"), bgcolor = "rgba(0,0,0,0)"),
        font   = list(color = "#f0f4fc")
      )
  })

  # ── Analytics: Type Donut ────────────────────────────────────────────────────
  output$chart_type_pie <- renderPlotly({
    d <- df_filtered() %>% count(object_type)
    plot_ly(d, labels = ~object_type, values = ~n, type = "pie", hole = 0.5,
            marker = list(colors = unname(TYPE_COLORS[d$object_type]),
                          line = list(color = "#070913", width = 1.5))) %>%
      layout(
        paper_bgcolor = "#111a3a",
        legend = list(font = list(color = "#f0f4fc"), bgcolor = "rgba(0,0,0,0)"),
        font   = list(color = "#f0f4fc"),
        margin = list(t = 20, b = 10)
      )
  })

  # ── Analytics: Country Bar ───────────────────────────────────────────────────
  output$chart_country <- renderPlotly({
    d <- df_filtered() %>% count(country) %>% arrange(desc(n)) %>% head(12)
    plot_ly(d, x = ~reorder(country, n), y = ~n, type = "bar",
            marker = list(color = "#7c4dff",
                          line = list(color = "#070913", width = 0.5))) %>%
      layout(
        xaxis   = list(title = "Nation / Agency", color = "#8e9bb4",
                       gridcolor = "#1c2545"),
        yaxis   = list(title = "Tracked Objects", color = "#8e9bb4",
                       gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        font   = list(color = "#f0f4fc"),
        margin = list(b = 80)
      )
  })

  # ── Analytics: Velocity vs Altitude ─────────────────────────────────────────
  output$chart_velocity <- renderPlotly({
    d <- df_filtered() %>% sample_n(min(nrow(.), 1500))
    plot_ly(d, x = ~mean_alt_km, y = ~velocity_km_s, color = ~object_type,
            colors = TYPE_COLORS, type = "scatter", mode = "markers",
            marker = list(size = 4, opacity = 0.7),
            text = ~hover_text, hoverinfo = "text") %>%
      layout(
        xaxis = list(title = "Altitude (km)", type = "log",
                     color = "#8e9bb4", gridcolor = "#1c2545"),
        yaxis = list(title = "Velocity (km/s)", color = "#8e9bb4",
                     gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        legend = list(font = list(color = "#f0f4fc"), bgcolor = "rgba(0,0,0,0)"),
        font  = list(color = "#f0f4fc")
      )
  })

  # ── Analytics: Inclination Box ───────────────────────────────────────────────
  output$chart_inclination <- renderPlotly({
    d <- df_filtered()
    plot_ly(d, x = ~object_type, y = ~inclination_deg, color = ~object_type,
            colors = TYPE_COLORS, type = "box",
            line = list(color = "#f0f4fc")) %>%
      layout(
        xaxis = list(title = "Object Type", color = "#8e9bb4"),
        yaxis = list(title = "Inclination (deg)", color = "#8e9bb4",
                     gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        showlegend = FALSE,
        font = list(color = "#f0f4fc")
      )
  })

  # ── Analytics: Mass Violin ───────────────────────────────────────────────────
  output$chart_mass <- renderPlotly({
    d <- df_filtered() %>% filter(mass_kg > 0)
    plot_ly(d, x = ~orbit_type, y = ~mass_kg, color = ~orbit_type,
            type = "box",
            colors = c(LEO = "#00e5ff", MEO = "#7c4dff",
                       GEO = "#ffd700", HEO = "#ff9933")) %>%
      layout(
        xaxis = list(title = "Orbit Regime", color = "#8e9bb4"),
        yaxis = list(title = "Mass (kg, log)", type = "log",
                     color = "#8e9bb4", gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        showlegend = FALSE,
        font = list(color = "#f0f4fc")
      )
  })

  # ── Data Table ───────────────────────────────────────────────────────────────
  output$catalog_table <- renderDT({
    d <- df_filtered() %>%
      select(norad_id, name, object_type, country, orbit_type,
             perigee_km, apogee_km, inclination_deg, velocity_km_s,
             period_min, rcs_size, launch_date, decay_status, mass_kg)

    datatable(d,
      options = list(
        pageLength = 15,
        scrollX    = TRUE,
        dom        = "Bfrtip",
        buttons    = c("csv", "excel"),
        columnDefs = list(list(className = "dt-center", targets = "_all"))
      ),
      extensions = "Buttons",
      rownames   = FALSE,
      class      = "display compact"
    ) %>%
      formatStyle("object_type",
        backgroundColor = styleEqual(
          c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN"),
          c("#003344", "#3a0022", "#332500", "#1e2245")
        ),
        color = styleEqual(
          c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN"),
          c("#00e5ff", "#ff2a6d", "#ffb703", "#8e9bb4")
        ),
        fontWeight = "bold"
      ) %>%
      formatRound(c("perigee_km", "apogee_km", "velocity_km_s",
                    "period_min", "inclination_deg"), 1) %>%
      formatStyle(columns = 1:14, color = "#f0f4fc", backgroundColor = "#111a3a")
  })

  # ── Orbit Tab: Regime Bar ────────────────────────────────────────────────────
  output$chart_regime_bar <- renderPlotly({
    d <- df_filtered() %>% count(orbit_type) %>% arrange(desc(n))
    plot_ly(d, x = ~orbit_type, y = ~n,
            type  = "bar",
            color = ~orbit_type,
            colors = c(LEO = "#00e5ff", MEO = "#7c4dff",
                       GEO = "#ffd700", HEO = "#ff9933"),
            text  = ~n, textposition = "outside") %>%
      layout(
        xaxis = list(title = "Orbit Regime", color = "#8e9bb4"),
        yaxis = list(title = "Count", color = "#8e9bb4",
                     gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        showlegend = FALSE,
        font = list(color = "#f0f4fc")
      )
  })

  output$chart_regime_pie <- renderPlotly({
    d <- df_filtered() %>% count(orbit_type)
    plot_ly(d, labels = ~orbit_type, values = ~n, type = "pie",
            hole = 0.45,
            marker = list(
              colors = c("#00e5ff", "#7c4dff", "#ffd700", "#ff9933"),
              line   = list(color = "#070913", width = 1.5)
            )) %>%
      layout(
        paper_bgcolor = "#111a3a",
        legend = list(font = list(color = "#f0f4fc"), bgcolor = "rgba(0,0,0,0)"),
        font   = list(color = "#f0f4fc")
      )
  })

  # ── Orbit Tab: Period vs Altitude ────────────────────────────────────────────
  output$chart_period_alt <- renderPlotly({
    d <- df_filtered() %>% sample_n(min(nrow(.), 2000))
    theo_alt <- seq(200, 36000, 200)
    theo_per <- (2 * pi * sqrt(((6371 + theo_alt)^3) / 398600.4418)) / 60
    theory   <- data.frame(alt = theo_alt, period = theo_per)

    plot_ly() %>%
      add_trace(data = d, x = ~mean_alt_km, y = ~period_min,
                color = ~object_type, colors = TYPE_COLORS,
                type = "scatter", mode = "markers",
                marker = list(size = 3.5, opacity = 0.65),
                name = "Catalog Objects",
                text = ~hover_text, hoverinfo = "text") %>%
      add_trace(data = theory, x = ~alt, y = ~period,
                type = "scatter", mode = "lines",
                line = list(color = "#ffffff", width = 2, dash = "dash"),
                name = "Kepler's 3rd Law (theory)") %>%
      layout(
        xaxis = list(title = "Altitude (km)", color = "#8e9bb4",
                     gridcolor = "#1c2545", type = "log"),
        yaxis = list(title = "Orbital Period (min)", color = "#8e9bb4",
                     gridcolor = "#1c2545"),
        paper_bgcolor = "#111a3a", plot_bgcolor = "#111a3a",
        legend = list(font = list(color = "#f0f4fc"), bgcolor = "rgba(0,0,0,0)"),
        font   = list(color = "#f0f4fc")
      )
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# RUN
# ──────────────────────────────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
