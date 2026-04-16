# NYC Rat Sightings Analysis
# Author: Abdul Gadiru Sannoh

library(tidyverse)
library(lubridate)
library(ggplot2)
library(sf)

# ── Load Data ─────────────────────────────────────────────────────────────────

rat_data <- read_csv("Rat_Sightings.csv")

# ── Clean Data ────────────────────────────────────────────────────────────────

rats <- rat_data %>%
  rename_with(tolower) %>%
  rename_with(~ str_replace_all(., " ", "_")) %>%
  mutate(
    created_date = mdy_hms(created_date),
    year         = year(created_date),
    month        = month(created_date, label = TRUE),
    borough      = str_to_title(borough),
    location_type = str_to_title(location_type)
  ) %>%
  filter(
    !is.na(borough),
    borough != "Unspecified",
    !is.na(latitude),
    !is.na(longitude),
    between(latitude,  40.4, 41.0),
    between(longitude, -74.3, -73.7)
  ) %>%
  distinct()

# ── 1. Sightings by Borough ───────────────────────────────────────────────────

borough_counts <- rats %>%
  count(borough, name = "sightings") %>%
  arrange(desc(sightings))

ggplot(borough_counts, aes(x = reorder(borough, sightings), y = sightings, fill = borough)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "NYC Rat Sightings by Borough",
    x     = NULL,
    y     = "Number of Sightings"
  ) +
  theme_minimal(base_size = 13)

ggsave("plots/borough_sightings.png", width = 8, height = 5, dpi = 150)

# ── 2. Yearly Trends ──────────────────────────────────────────────────────────

yearly_trends <- rats %>%
  count(year, borough, name = "sightings") %>%
  filter(year >= 2010, year <= year(Sys.Date()))

ggplot(yearly_trends, aes(x = year, y = sightings, color = borough, group = borough)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = scales::pretty_breaks()) +
  labs(
    title  = "Yearly Rat Sighting Trends by Borough",
    x      = "Year",
    y      = "Sightings",
    color  = "Borough"
  ) +
  theme_minimal(base_size = 13)

ggsave("plots/yearly_trends.png", width = 10, height = 6, dpi = 150)

# ── 3. Top Location Types ─────────────────────────────────────────────────────

top_locations <- rats %>%
  count(location_type, name = "sightings") %>%
  slice_max(sightings, n = 10)

ggplot(top_locations, aes(x = reorder(location_type, sightings), y = sightings)) +
  geom_col(fill = "#c0392b") +
  coord_flip() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Top 10 Location Types for Rat Sightings",
    x     = NULL,
    y     = "Number of Sightings"
  ) +
  theme_minimal(base_size = 13)

ggsave("plots/top_locations.png", width = 9, height = 6, dpi = 150)

# ── 4. Geospatial Map ─────────────────────────────────────────────────────────

rats_sf <- st_as_sf(rats, coords = c("longitude", "latitude"), crs = 4326)

ggplot(rats_sf) +
  geom_sf(aes(color = borough), alpha = 0.3, size = 0.2, show.legend = TRUE) +
  labs(
    title  = "Spatial Distribution of NYC Rat Sightings",
    color  = "Borough"
  ) +
  theme_void(base_size = 13) +
  guides(color = guide_legend(override.aes = list(size = 3, alpha = 1)))

ggsave("plots/nyc_map.png", width = 8, height = 10, dpi = 150)

# ── 5. Summary Stats ──────────────────────────────────────────────────────────

cat("\n=== Summary ===\n")
cat("Total sightings:", nrow(rats), "\n")
cat("Date range:", format(min(rats$created_date), "%Y-%m-%d"),
    "to", format(max(rats$created_date), "%Y-%m-%d"), "\n\n")
print(borough_counts)
