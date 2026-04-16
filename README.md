# NYC Rat Sightings Data Analysis
# Author: Abdul Gadiru Sannoh
# Consolidated R script reconstructed from project report

# =========================
# 1. Install / Load Packages
# =========================
options(repos = c(CRAN = "https://cran.rstudio.com/"))

required_packages <- c("tidyverse", "lubridate", "sf")
installed <- rownames(installed.packages())

for (pkg in required_packages) {
  if (!pkg %in% installed) {
    install.packages(pkg)
  }
}

library(tidyverse)
library(lubridate)
library(sf)
library(ggplot2)
library(dplyr)

# Create output folder if it does not exist
if (!dir.exists("output")) {
  dir.create("output")
}

# =========================
# 2. Load Dataset
# =========================
rats_data <- read_csv("A1_sightings.csv", na = c("", "NA", "N/A"), show_col_types = FALSE)

# =========================
# 3. Data Cleaning
# =========================
rats_data <- rats_data %>%
  mutate(
    created_date = mdy_hms(`Created Date`)
  ) %>%
  drop_na(created_date) %>%
  mutate(
    year = year(created_date),
    month = month(created_date),
    day = day(created_date),
    weekday = wday(created_date, label = TRUE, abbr = FALSE),
    borough = str_to_title(Borough),
    location_type = str_to_title(`Location Type`)
  ) %>%
  replace_na(list(location_type = "Unknown")) %>%
  filter(!is.na(borough)) %>%
  drop_na(Latitude, Longitude) %>%
  mutate(
    latitude = as.numeric(Latitude),
    longitude = as.numeric(Longitude)
  ) %>%
  distinct()

# Save cleaned file
write_csv(rats_data, "Cleaned_A1_sightings.csv")

# =========================
# 4. Rat Sightings by Borough
# =========================
borough_summary <- rats_data %>%
  group_by(borough) %>%
  summarise(total_sightings = n(), .groups = "drop")

borough_plot <- borough_summary %>%
  ggplot(aes(x = reorder(borough, -total_sightings), y = total_sightings, fill = borough)) +
  geom_bar(stat = "identity") +
  labs(
    title = "Rat Sightings by Borough",
    x = "Borough",
    y = "Total Sightings"
  ) +
  theme_minimal()

print(borough_plot)

ggsave(filename = "output/A1(1).png", plot = borough_plot, width = 10, height = 7, dpi = 300)
ggsave(filename = "output/A1(1).pdf", plot = borough_plot, width = 10, height = 7)

# =========================
# 5. Yearly Rat Sightings by Borough
# =========================
borough_trends <- rats_data %>%
  group_by(year, borough) %>%
  summarise(total_sightings = n(), .groups = "drop")

yearly_borough_plot <- ggplot(borough_trends, aes(x = borough, y = total_sightings, fill = borough)) +
  geom_bar(stat = "identity") +
  facet_wrap(~year) +
  labs(
    title = "Yearly Rat Sightings by Borough",
    subtitle = "Compare boroughs per year instead of using a line graph",
    x = "Borough",
    y = "Total Sightings"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(yearly_borough_plot)

ggsave(filename = "output/A1(2).png", plot = yearly_borough_plot, width = 10, height = 7, dpi = 300)
ggsave(filename = "output/A1 (2).pdf", plot = yearly_borough_plot, width = 10, height = 7)

# =========================
# 6. Top 7 Rat Sightings by Location Type (2014–2017)
# =========================
rats_filtered <- rats_data %>%
  filter(year >= 2014 & year <= 2017)

top7_locations <- rats_filtered %>%
  group_by(year, location_type) %>%
  summarise(total_sightings = n(), .groups = "drop") %>%
  arrange(year, desc(total_sightings)) %>%
  group_by(year) %>%
  slice_head(n = 7) %>%
  ungroup()

top_locations_plot <- ggplot(
  top7_locations,
  aes(x = total_sightings, y = reorder(location_type, total_sightings))
) +
  geom_bar(stat = "identity", fill = "grey") +
  facet_wrap(~year) +
  labs(
    title = "Top 7 Rat Sightings by Location Type (2014-2017)",
    x = "Total Sightings",
    y = "Location Type"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold", size = 12),
    axis.text.y = element_text(size = 8)
  )

print(top_locations_plot)

ggsave(filename = "output/A1(3).png", plot = top_locations_plot, width = 10, height = 7, dpi = 300)
ggsave(filename = "output/A1(3).pdf", plot = top_locations_plot, width = 10, height = 7)

# =========================
# 7. New York State Map with Rat Sightings
# =========================
# Make sure the shapefile folder exists in your working directory:
# cb_2018_us_state_20m/cb_2018_us_state_20m.shp

us_states <- st_read("cb_2018_us_state_20m/cb_2018_us_state_20m.shp", quiet = TRUE)

ny_state <- us_states %>%
  filter(NAME == "New York")

rats_sf <- rats_data %>%
  drop_na(longitude, latitude) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

state_map_plot <- ggplot() +
  geom_sf(data = ny_state, fill = "grey80", color = "black") +
  geom_sf(data = rats_sf, color = "red", alpha = 0.5, size = 0.7) +
  labs(
    title = "Rat Sightings in New York",
    subtitle = "Red points indicate locations of rat sightings",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal()

print(state_map_plot)

ggsave(filename = "output/A1(4).png", plot = state_map_plot, width = 10, height = 7, dpi = 300)
ggsave(filename = "output/A1 (4).pdf", plot = state_map_plot, width = 10, height = 7)

# =========================
# 8. Improved NYC Rat Sightings Map
# =========================
rats_sf <- rats_sf %>%
  mutate(
    latitude = st_coordinates(.)[, 2],
    longitude = st_coordinates(.)[, 1]
  )

nyc_rats <- rats_sf %>%
  filter(
    latitude > 40.4 & latitude < 41.0,
    longitude > -74.3 & longitude < -73.6
  )

nyc_rat_map <- ggplot() +
  geom_sf(data = ny_state, fill = "grey80", color = "black", alpha = 0.5) +
  geom_sf(data = nyc_rats, color = "red", alpha = 0.6, size = 1.5) +
  labs(
    title = "NYC Rat Sightings - Improved Visualization",
    subtitle = "Red points indicate rat complaint locations in New York City",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, color = "darkred"),
    plot.subtitle = element_text(size = 12, face = "italic"),
    axis.text = element_text(size = 10),
    legend.position = "none"
  ) +
  coord_sf(xlim = c(-74.3, -73.6), ylim = c(40.4, 41.0))

print(nyc_rat_map)

ggsave(filename = "output/A1(5).png", plot = nyc_rat_map, width = 10, height = 7, dpi = 300)
ggsave(filename = "output/A1(5).pdf", plot = nyc_rat_map, width = 10, height = 7)
