# =============================================================================
# NYC Rat Sightings — Exploratory & Statistical Analysis
# Author : Abdul Gadiru Sannoh
# Updated: 2025
# =============================================================================

# ── 0. Dependencies ───────────────────────────────────────────────────────────

pkgs <- c("tidyverse", "lubridate", "ggplot2", "sf",
          "scales", "patchwork", "ggridges", "viridis")
invisible(lapply(pkgs, library, character.only = TRUE))

dir.create("plots", showWarnings = FALSE)

# Consistent colour palette keyed to borough
BOROUGH_COLORS <- c(
  "Brooklyn"      = "#E63946",
  "Manhattan"     = "#457B9D",
  "Queens"        = "#2A9D8F",
  "Bronx"         = "#E9C46A",
  "Staten Island" = "#F4A261"
)

# Shared ggplot2 theme
theme_rat <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.title      = element_text(face = "bold", size = base_size + 2, hjust = 0),
      plot.subtitle   = element_text(color = "grey40", hjust = 0, margin = margin(b = 8)),
      plot.caption    = element_text(color = "grey55", size = 9, hjust = 1),
      panel.grid.minor = element_blank(),
      axis.title      = element_text(size = base_size - 1),
      legend.position = "right"
    )
}

save_plot <- function(filename, width = 9, height = 6, dpi = 180) {
  ggsave(file.path("plots", filename), width = width, height = height,
         dpi = dpi, bg = "white")
}

# ── 1. Load & Validate ────────────────────────────────────────────────────────

raw <- read_csv("Rat_Sightings.csv", show_col_types = FALSE)
cat(sprintf("Raw rows: %s | Columns: %d\n", scales::comma(nrow(raw)), ncol(raw)))

# ── 2. Clean & Engineer Features ──────────────────────────────────────────────

rats <- raw %>%
  rename_with(~ str_to_lower(str_replace_all(., "\\s+", "_"))) %>%
  mutate(
    created_date  = mdy_hms(created_date),
    closed_date   = mdy_hms(closed_date),
    year          = year(created_date),
    month         = month(created_date, label = TRUE, abbr = TRUE),
    quarter       = paste0("Q", quarter(created_date)),
    day_of_week   = wday(created_date, label = TRUE, abbr = TRUE),
    hour          = hour(created_date),
    resolution_days = as.numeric(difftime(closed_date, created_date, units = "days")),
    borough       = str_to_title(borough),
    location_type = str_to_title(location_type)
  ) %>%
  filter(
    !is.na(borough), borough != "Unspecified",
    !is.na(latitude), !is.na(longitude),
    between(latitude,  40.4,  41.0),
    between(longitude, -74.3, -73.7),
    year >= 2010
  ) %>%
  distinct()

cat(sprintf("Clean rows: %s | Years: %d–%d\n",
            scales::comma(nrow(rats)), min(rats$year), max(rats$year)))

# ── 3. Borough Overview ───────────────────────────────────────────────────────

borough_counts <- rats %>%
  count(borough, name = "sightings") %>%
  mutate(
    pct   = sightings / sum(sightings),
    label = sprintf("%s\n(%s%%)", scales::comma(sightings), round(pct * 100, 1))
  ) %>%
  arrange(desc(sightings))

p_borough <- ggplot(borough_counts,
                    aes(x = reorder(borough, sightings), y = sightings, fill = borough)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(aes(label = scales::comma(sightings)), hjust = -0.1, size = 3.5) +
  coord_flip(clip = "off") +
  scale_fill_manual(values = BOROUGH_COLORS) +
  scale_y_continuous(labels = scales::comma,
                     expand = expansion(mult = c(0, 0.18))) +
  labs(
    title    = "Rat Sightings by Borough",
    subtitle = "Cumulative 311 complaints, 2010–present",
    x = NULL, y = "Number of Sightings",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat()

print(p_borough)
save_plot("01_borough_sightings.png", width = 9, height = 5)

# ── 4. Yearly Trends with Annotations ────────────────────────────────────────

yearly <- rats %>%
  count(year, borough, name = "sightings")

peak_year <- yearly %>%
  group_by(borough) %>%
  slice_max(sightings, n = 1)

p_yearly <- ggplot(yearly, aes(x = year, y = sightings, color = borough, group = borough)) +
  geom_line(linewidth = 1.1, alpha = 0.9) +
  geom_point(size = 2.2) +
  ggrepel::geom_text_repel(
    data = peak_year,
    aes(label = scales::comma(sightings)),
    size = 2.8, show.legend = FALSE, nudge_y = 200
  ) +
  scale_color_manual(values = BOROUGH_COLORS) +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = seq(2010, 2025, 2)) +
  labs(
    title    = "Annual Rat Sighting Trends by Borough",
    subtitle = "Peak values labelled per borough",
    x = "Year", y = "Annual Sightings", color = "Borough",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat()

print(p_yearly)
save_plot("02_yearly_trends.png", width = 11, height = 6)

# ── 5. Seasonal Heatmap (Month × Borough) ────────────────────────────────────

seasonal <- rats %>%
  count(month, borough, name = "sightings")

p_heat <- ggplot(seasonal, aes(x = month, y = fct_rev(borough), fill = sightings)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = scales::comma(sightings, accuracy = 1)),
            size = 2.8, color = "white", fontface = "bold") +
  scale_fill_viridis_c(option = "inferno", labels = scales::comma, direction = -1) +
  labs(
    title    = "Seasonal Rat Activity: Month × Borough Heatmap",
    subtitle = "Darker = more sightings; summer months drive peak activity",
    x = "Month", y = NULL, fill = "Sightings",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat() +
  theme(legend.position = "bottom",
        legend.key.width = unit(2, "cm"))

print(p_heat)
save_plot("03_seasonal_heatmap.png", width = 12, height = 5)

# ── 6. Day-of-Week & Hour-of-Day Patterns ────────────────────────────────────

dow <- rats %>% count(day_of_week, name = "sightings")
hod <- rats %>% count(hour, name = "sightings")

p_dow <- ggplot(dow, aes(x = day_of_week, y = sightings)) +
  geom_col(fill = "#457B9D") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Sightings by Day of Week", x = NULL, y = "Sightings") +
  theme_rat(base_size = 11)

p_hod <- ggplot(hod, aes(x = hour, y = sightings)) +
  geom_area(fill = "#E63946", alpha = 0.7) +
  geom_line(color = "#c0392b", linewidth = 0.8) +
  scale_x_continuous(breaks = seq(0, 23, 4),
                     labels = sprintf("%02d:00", seq(0, 23, 4))) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Sightings by Hour of Day", x = "Hour", y = "Sightings") +
  theme_rat(base_size = 11)

p_temporal <- p_dow + p_hod +
  plot_annotation(
    title    = "Temporal Patterns in Rat Sighting Reports",
    subtitle = "Reports peak mid-week and during daytime hours",
    caption  = "Source: NYC Open Data 311 Service Requests",
    theme    = theme(plot.title = element_text(face = "bold", size = 15))
  )

print(p_temporal)
save_plot("04_temporal_patterns.png", width = 13, height = 5)

# ── 7. Top Location Types ─────────────────────────────────────────────────────

top_locs <- rats %>%
  count(location_type, name = "sightings") %>%
  slice_max(sightings, n = 12) %>%
  mutate(pct = sightings / sum(rats$location_type != "") * 100)

p_locs <- ggplot(top_locs, aes(x = reorder(location_type, sightings),
                                y = sightings, fill = sightings)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(sightings)), hjust = -0.1, size = 3.2) +
  coord_flip(clip = "off") +
  scale_fill_viridis_c(option = "magma", direction = -1) +
  scale_y_continuous(labels = scales::comma,
                     expand = expansion(mult = c(0, 0.18))) +
  labs(
    title    = "Top 12 Location Types for Rat Sightings",
    subtitle = "Residential buildings dominate; mixed-use zones a close second",
    x = NULL, y = "Number of Sightings",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat()

print(p_locs)
save_plot("05_top_locations.png", width = 10, height = 6)

# ── 8. Resolution Time Distribution ──────────────────────────────────────────

res_clean <- rats %>%
  filter(!is.na(resolution_days), between(resolution_days, 0, 90))

p_res <- ggplot(res_clean, aes(x = resolution_days, y = fct_rev(borough),
                                fill = borough)) +
  ggridges::geom_density_ridges(alpha = 0.75, scale = 1.4,
                                 quantile_lines = TRUE, quantiles = 2) +
  scale_fill_manual(values = BOROUGH_COLORS) +
  scale_x_continuous(breaks = seq(0, 90, 15)) +
  labs(
    title    = "Case Resolution Time by Borough",
    subtitle = "Median resolution time shown; shorter = more responsive city service",
    x = "Days to Close", y = NULL,
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat() +
  theme(legend.position = "none")

print(p_res)
save_plot("06_resolution_time.png", width = 10, height = 6)

# ── 9. YoY Growth Rate ────────────────────────────────────────────────────────

yoy <- rats %>%
  count(year, name = "sightings") %>%
  mutate(yoy_pct = (sightings / lag(sightings) - 1) * 100) %>%
  filter(!is.na(yoy_pct))

p_yoy <- ggplot(yoy, aes(x = year, y = yoy_pct,
                          fill = yoy_pct > 0)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_hline(yintercept = 0, linewidth = 0.6, color = "grey30") +
  scale_fill_manual(values = c("TRUE" = "#E63946", "FALSE" = "#457B9D")) +
  scale_x_continuous(breaks = seq(2011, 2025, 2)) +
  scale_y_continuous(labels = scales::label_percent(scale = 1)) +
  labs(
    title    = "Year-over-Year Change in Rat Sightings",
    subtitle = "Red = increase, Blue = decrease vs. prior year",
    x = "Year", y = "YoY Change (%)",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_rat()

print(p_yoy)
save_plot("07_yoy_growth.png", width = 10, height = 5)

# ── 10. Geospatial Density Map ────────────────────────────────────────────────

rats_sf <- st_as_sf(rats, coords = c("longitude", "latitude"), crs = 4326)

p_map <- ggplot(rats_sf) +
  stat_density_2d_filled(
    data = rats %>% select(longitude, latitude),
    aes(x = longitude, y = latitude, fill = after_stat(level)),
    geom = "polygon", contour_var = "ndensity", bins = 14, alpha = 0.85
  ) +
  geom_sf(aes(color = borough), alpha = 0.05, size = 0.1) +
  scale_fill_viridis_d(option = "inferno", direction = -1) +
  scale_color_manual(values = BOROUGH_COLORS) +
  coord_sf(xlim = c(-74.26, -73.70), ylim = c(40.49, 40.92)) +
  labs(
    title    = "Geospatial Density of NYC Rat Sightings",
    subtitle = "Kernel density contours reveal high-infestation corridors",
    fill = "Density\n(relative)", color = "Borough",
    caption  = "Source: NYC Open Data 311 Service Requests"
  ) +
  theme_void(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold", size = 15, margin = margin(b = 4)),
    plot.subtitle = element_text(color = "grey40"),
    legend.position = "right"
  )

print(p_map)
save_plot("08_geospatial_density.png", width = 9, height = 11)

# ── 11. Summary Statistics Table ─────────────────────────────────────────────

summary_tbl <- rats %>%
  group_by(borough) %>%
  summarise(
    sightings       = n(),
    pct_of_total    = round(n() / nrow(rats) * 100, 1),
    peak_year       = year[which.max(tabulate(match(year, unique(year))))],
    peak_month      = as.character(month[which.max(tabulate(match(month, unique(month))))]),
    median_res_days = round(median(resolution_days, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(sightings))

cat("\n╔══════════════════════════════════════════════════════════════╗\n")
cat(  "║           NYC RAT SIGHTINGS — SUMMARY STATISTICS            ║\n")
cat(  "╚══════════════════════════════════════════════════════════════╝\n\n")
cat(sprintf("  Total clean records : %s\n", scales::comma(nrow(rats))))
cat(sprintf("  Date range          : %s → %s\n",
            format(min(rats$created_date), "%b %Y"),
            format(max(rats$created_date), "%b %Y")))
cat(sprintf("  Boroughs covered    : %d\n\n", n_distinct(rats$borough)))
print(summary_tbl)
cat("\nPlots saved to ./plots/\n")
