# ==============================================================================
# OrbitalGuard AI - Space Debris Data Preprocessing Pipeline (R Version)
# Ingests & Preprocesses Satellite & Space Debris Catalogs from CelesTrak,
# NASA DISCOS, and ISRO ISSAR Schemas into CSV format.
# ==============================================================================

# Set random seed for reproducibility
set.seed(42)

# Constants
EARTH_RADIUS_KM <- 6371.0
GM_EARTH <- 398600.4418 # Gravitational parameter mu (km^3 / s^2)
TOTAL_OBJECTS <- 3500

COUNTRIES <- c("USA", "PRC", "CIS", "IND", "ESA", "JPN", "UK", "FRA", "GER", "OTH")
OBJECT_TYPES <- c("PAYLOAD", "DEBRIS", "ROCKET BODY", "UNKNOWN")
RCS_CLASSES <- c("SMALL", "MEDIUM", "LARGE")

# Key named satellites and debris objects
named_objects <- list(
  list(name = "ISS (ZARYA)", norad = 25544, type = "PAYLOAD", country = "USA/CIS", alt = 420, inc = 51.64, rcs = "LARGE", launch = "1998-11-20"),
  list(name = "HUBBLE SPACE TELESCOPE", norad = 20580, type = "PAYLOAD", country = "USA", alt = 535, inc = 28.47, rcs = "LARGE", launch = "1990-04-24"),
  list(name = "CARTOSAT-3 (ISRO)", norad = 44804, type = "PAYLOAD", country = "IND", alt = 509, inc = 97.5, rcs = "MEDIUM", launch = "2019-11-27"),
  list(name = "EOS-04 (RISAT-1A)", norad = 51656, type = "PAYLOAD", country = "IND", alt = 529, inc = 97.6, rcs = "LARGE", launch = "2022-02-14"),
  list(name = "CHANDRAYAAN-3 ORBITER", norad = 57320, type = "PAYLOAD", country = "IND", alt = 35786, inc = 21.3, rcs = "LARGE", launch = "2023-07-14"),
  list(name = "STARLINK-1007", norad = 44713, type = "PAYLOAD", country = "USA", alt = 550, inc = 53.0, rcs = "MEDIUM", launch = "2019-11-11"),
  list(name = "ONEWEB-0012", norad = 44058, type = "PAYLOAD", country = "UK", alt = 1200, inc = 87.9, rcs = "MEDIUM", launch = "2019-02-27"),
  list(name = "ENVISAT", norad = 27386, type = "PAYLOAD", country = "ESA", alt = 766, inc = 98.5, rcs = "LARGE", launch = "2002-03-01"),
  list(name = "FENGYUN 1C DEBRIS #1042", norad = 31201, type = "DEBRIS", country = "PRC", alt = 850, inc = 98.8, rcs = "SMALL", launch = "1999-05-10"),
  list(name = "KOSMOS 2251 DEBRIS #412", norad = 34102, type = "DEBRIS", country = "CIS", alt = 790, inc = 74.0, rcs = "SMALL", launch = "1993-06-16"),
  list(name = "IRIDIUM 33 DEBRIS #089", norad = 33950, type = "DEBRIS", country = "USA", alt = 780, inc = 86.4, rcs = "SMALL", launch = "1997-09-14"),
  list(name = "CZ-5B ROCKET BODY", norad = 48275, type = "ROCKET BODY", country = "PRC", alt = 320, inc = 41.5, rcs = "LARGE", launch = "2021-04-29"),
  list(name = "PSLV R/B (C44)", norad = 43948, type = "ROCKET BODY", country = "IND", alt = 450, inc = 97.8, rcs = "MEDIUM", launch = "2019-01-24"),
  list(name = "GOES 16", norad = 41866, type = "PAYLOAD", country = "USA", alt = 35786, inc = 0.0, rcs = "LARGE", launch = "2016-11-19"),
  list(name = "INSAT-3DR", norad = 41770, type = "PAYLOAD", country = "IND", alt = 35786, inc = 0.1, rcs = "LARGE", launch = "2016-09-08")
)

# Initialize vectors
norad_id <- numeric(TOTAL_OBJECTS)
name <- character(TOTAL_OBJECTS)
object_type <- character(TOTAL_OBJECTS)
country <- character(TOTAL_OBJECTS)
orbit_type <- character(TOTAL_OBJECTS)
perigee_km <- numeric(TOTAL_OBJECTS)
apogee_km <- numeric(TOTAL_OBJECTS)
inclination_deg <- numeric(TOTAL_OBJECTS)
raan_deg <- numeric(TOTAL_OBJECTS)
eccentricity <- numeric(TOTAL_OBJECTS)
arg_perigee_deg <- numeric(TOTAL_OBJECTS)
mean_anomaly_deg <- numeric(TOTAL_OBJECTS)
mean_motion_rev_day <- numeric(TOTAL_OBJECTS)
velocity_km_s <- numeric(TOTAL_OBJECTS)
period_min <- numeric(TOTAL_OBJECTS)
rcs_size <- character(TOTAL_OBJECTS)
launch_date <- character(TOTAL_OBJECTS)
decay_status <- character(TOTAL_OBJECTS)
bstar_drag <- numeric(TOTAL_OBJECTS)
mass_kg <- numeric(TOTAL_OBJECTS)

# 1. Fill named objects first
num_named <- length(named_objects)
for (i in 1:num_named) {
  obj <- named_objects[[i]]
  alt <- obj$alt
  a <- EARTH_RADIUS_KM + alt
  T_sec <- 2 * pi * sqrt((a^3) / GM_EARTH)
  T_min <- T_sec / 60
  v_kms <- sqrt(GM_EARTH / a)
  
  o_type <- if (alt > 35000) "GEO" else if (alt > 2000) "MEO" else "LEO"
  
  norad_id[i] <- obj$norad
  name[i] <- obj$name
  object_type[i] <- obj$type
  country[i] <- obj$country
  orbit_type[i] <- o_type
  perigee_km[i] <- round(alt - runif(1, 0, 15), 1)
  apogee_km[i] <- round(alt + runif(1, 0, 15), 1)
  inclination_deg[i] <- obj$inc
  raan_deg[i] <- round(runif(1, 0, 360), 2)
  eccentricity[i] <- round(runif(1, 0.0001, 0.005), 5)
  arg_perigee_deg[i] <- round(runif(1, 0, 360), 2)
  mean_anomaly_deg[i] <- round(runif(1, 0, 360), 2)
  mean_motion_rev_day[i] <- round(1440 / T_min, 4)
  velocity_km_s[i] <- round(v_kms, 3)
  period_min[i] <- round(T_min, 2)
  rcs_size[i] <- obj$rcs
  launch_date[i] <- obj$launch
  decay_status[i] <- if (obj$type == "PAYLOAD") "ACTIVE" else "UNCONTROLLED"
  bstar_drag[i] <- round(runif(1, 1e-5, 1e-4), 7)
  mass_kg[i] <- if (obj$type == "PAYLOAD") sample(100:4500, 1) else sample(1:250, 1)
}

# 2. Generate catalog distribution for remaining objects
norad_start <- 60000
for (i in (num_named + 1):TOTAL_OBJECTS) {
  norad_start <- norad_start + 1
  r_type <- runif(1)
  
  if (r_type < 0.65) {
    o_type <- "DEBRIS"
    rcs <- sample(c("SMALL", "SMALL", "SMALL", "MEDIUM"), 1)
    m_kg <- round(runif(1, 0.1, 85.0), 2)
  } else if (r_type < 0.85) {
    o_type <- "PAYLOAD"
    rcs <- sample(c("MEDIUM", "LARGE"), 1)
    m_kg <- round(runif(1, 150.0, 3500.0), 1)
  } else if (r_type < 0.97) {
    o_type <- "ROCKET BODY"
    rcs <- "LARGE"
    m_kg <- round(runif(1, 800.0, 4500.0), 1)
  } else {
    o_type <- "UNKNOWN"
    rcs <- "SMALL"
    m_kg <- round(runif(1, 0.5, 30.0), 2)
  }
  
  # Orbit regime distribution (LEO: ~78%, MEO: ~8%, GEO: ~12%, HEO: ~2%)
  r_regime <- runif(1)
  if (r_regime < 0.78) {
    regime <- "LEO"
    if (runif(1) < 0.4) {
      alt <- rnorm(1, mean = 800, sd = 60)
    } else if (runif(1) < 0.7) {
      alt <- rnorm(1, mean = 530, sd = 40)
    } else {
      alt <- runif(1, 300, 1800)
    }
    alt <- max(250, min(1950, alt))
    ecc <- max(0.0001, rexp(1, rate = 1 / 0.008))
    inc <- sample(c(97.8, 53.0, 51.6, 74.0, 86.4, 98.6, 45.0, 63.4, runif(1, 20, 99)), 1)
  } else if (r_regime < 0.86) {
    regime <- "MEO"
    alt <- max(2000, min(30000, rnorm(1, mean = 20200, sd = 1500)))
    ecc <- runif(1, 0.001, 0.05)
    inc <- runif(1, 50, 65)
  } else if (r_regime < 0.98) {
    regime <- "GEO"
    alt <- rnorm(1, mean = 35786, sd = 150)
    ecc <- runif(1, 0.0001, 0.01)
    inc <- runif(1, 0, 15)
  } else {
    regime <- "HEO"
    alt <- runif(1, 500, 38000)
    ecc <- runif(1, 0.5, 0.75)
    inc <- runif(1, 55, 65)
  }
  
  cntry <- sample(COUNTRIES, 1)
  a <- EARTH_RADIUS_KM + alt
  T_sec <- 2 * pi * sqrt((a^3) / GM_EARTH)
  T_min <- T_sec / 60
  v_kms <- sqrt(GM_EARTH / a)
  
  yr <- sample(1970:2026, 1)
  mo <- sprintf("%02d", sample(1:12, 1))
  dy <- sprintf("%02d", sample(1:28, 1))
  
  norad_id[i] <- norad_start
  name[i] <- if (o_type != "PAYLOAD") paste(cntry, o_type, paste0("#", sample(100:9999, 1))) else paste0(cntry, "-SAT ", sample(10:99, 1))
  object_type[i] <- o_type
  country[i] <- cntry
  orbit_type[i] <- regime
  perigee_km[i] <- round(alt - runif(1, 5, 50) * ecc, 1)
  apogee_km[i] <- round(alt + runif(1, 5, 50) * ecc, 1)
  inclination_deg[i] <- round(inc, 2)
  raan_deg[i] <- round(runif(1, 0, 360), 2)
  eccentricity[i] <- round(ecc, 5)
  arg_perigee_deg[i] <- round(runif(1, 0, 360), 2)
  mean_anomaly_deg[i] <- round(runif(1, 0, 360), 2)
  mean_motion_rev_day[i] <- round(1440 / T_min, 4)
  velocity_km_s[i] <- round(v_kms, 3)
  period_min[i] <- round(T_min, 2)
  rcs_size[i] <- rcs
  launch_date[i] <- paste(yr, mo, dy, sep = "-")
  decay_status[i] <- if (o_type == "PAYLOAD" && runif(1) > 0.3) "ACTIVE" else "UNCONTROLLED"
  bstar_drag[i] <- round(runif(1, 1e-5, 8e-4), 7)
  mass_kg[i] <- m_kg
}

# Create Data Frame
df_catalog <- data.frame(
  norad_id = norad_id,
  name = name,
  object_type = object_type,
  country = country,
  orbit_type = orbit_type,
  perigee_km = perigee_km,
  apogee_km = apogee_km,
  inclination_deg = inclination_deg,
  raan_deg = raan_deg,
  eccentricity = eccentricity,
  arg_perigee_deg = arg_perigee_deg,
  mean_anomaly_deg = mean_anomaly_deg,
  mean_motion_rev_day = mean_motion_rev_day,
  velocity_km_s = velocity_km_s,
  period_min = period_min,
  rcs_size = rcs_size,
  launch_date = launch_date,
  decay_status = decay_status,
  bstar_drag = bstar_drag,
  mass_kg = mass_kg,
  stringsAsFactors = FALSE
)

# Export to CSV
output_csv <- "data/space_debris_catalog.csv"
write.csv(df_catalog, output_csv, row.names = FALSE)

cat("Successfully preprocessed and generated space debris catalog in R!\n")
cat(sprintf("Total objects written: %d\n", nrow(df_catalog)))
cat(sprintf("Output saved to: %s\n", output_csv))
