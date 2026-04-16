# NYC Rat Sightings — Data Analysis Portfolio
**Abdul Gadiru Sannoh · Data Analyst · Business Analytics Graduate**

---

## Project Overview

This project performs a full end-to-end analysis of New York City's 311 rat sighting complaint data — from raw ingestion and cleaning through statistical modeling, temporal analysis, and geospatial visualization. The goal is to surface actionable patterns that can guide public health resource allocation and sanitation policy.

**Dataset:** NYC Open Data — 311 Service Requests (`Rat_Sightings.csv`)  
**Language / Stack:** R · tidyverse · ggplot2 · sf · patchwork · ggridges · viridis

---

## Technical Skills Demonstrated

| Skill | Detail |
|---|---|
| **Data Wrangling** | Multi-step pipeline with `dplyr` — renaming, type coercion, feature engineering, deduplication |
| **Date/Time Analysis** | `lubridate` parsing; extraction of year, month, quarter, day-of-week, hour |
| **Feature Engineering** | Derived `resolution_days` (closed − created), seasonal quarters, temporal segments |
| **Statistical Analysis** | YoY growth rates, median resolution times, density distributions, borough-level aggregations |
| **Data Visualization** | 8 publication-quality plots with a consistent custom theme (`theme_rat`) |
| **Geospatial Analysis** | `sf` for CRS projection; `stat_density_2d_filled` for kernel density contours over NYC |
| **Code Architecture** | Reusable helper functions (`theme_rat`, `save_plot`), named colour palettes, modular sections |

---

## Analyses & Visualizations

### 1. Borough-Level Sightings
Bar chart ranking all five boroughs by total sighting count with percentage labels.  
**Finding:** Brooklyn and Manhattan together account for the majority of all complaints.

![Borough Sightings](plots/01_borough_sightings.png)

---

### 2. Annual Trends by Borough
Multi-line time series (2010–present) with peak-year annotations per borough.  
**Finding:** Sightings rose sharply city-wide post-2014, with Brooklyn maintaining the highest volume.

![Yearly Trends](plots/02_yearly_trends.png)

---

### 3. Seasonal Heatmap — Month × Borough
Tile heatmap showing monthly sighting volume per borough with viridis colour scaling.  
**Finding:** Summer months (June–September) consistently drive peak activity across all boroughs.

![Seasonal Heatmap](plots/03_seasonal_heatmap.png)

---

### 4. Temporal Patterns — Day of Week & Hour of Day
Side-by-side bar and area charts revealing when complaints are filed.  
**Finding:** Reports peak Tuesday–Thursday and during daytime hours (9 am–5 pm), reflecting when residents are most active.

![Temporal Patterns](plots/04_temporal_patterns.png)

---

### 5. Top 12 Location Types
Horizontal bar chart with viridis gradient fill and count labels.  
**Finding:** Residential buildings and 3+ unit dwellings are the dominant infestation sites, underscoring the need for building-focused inspection programs.

![Top Locations](plots/05_top_locations.png)

---

### 6. Case Resolution Time — Ridge Plot
Kernel density ridgeline plot (0–90 days) with median markers per borough.  
**Finding:** Resolution time varies significantly by borough, pointing to unequal service responsiveness across the city.

![Resolution Time](plots/06_resolution_time.png)

---

### 7. Year-over-Year Growth Rate
Diverging bar chart showing % change in sightings vs. the prior year.  
**Finding:** Several years show double-digit growth, with isolated drops potentially tied to reporting behaviour or sanitation initiatives.

![YoY Growth](plots/07_yoy_growth.png)

---

### 8. Geospatial Density Map
Kernel density contour map overlaid on borough-coloured individual sighting points.  
**Finding:** High-density infestation corridors concentrate in central Brooklyn, lower Manhattan, and the South Bronx — areas with dense residential stock and older infrastructure.

![Geospatial Density](plots/08_geospatial_density.png)

---

## Methodology

```
Raw CSV → Column standardisation → Type coercion (dates, strings)
       → Feature engineering (temporal, resolution_days)
       → Coordinate validation & deduplication
       → Borough / location-type aggregations
       → 8 ggplot2 visualizations (consistent theme + palette)
       → Summary statistics table
```

**Data quality steps:**
- Parsed `created_date` and `closed_date` with `lubridate::mdy_hms()`
- Filtered bounding box `lat ∈ [40.4, 41.0]`, `lon ∈ [−74.3, −73.7]` to remove erroneous coordinates
- Removed `"Unspecified"` borough entries and duplicate rows
- Clipped `resolution_days` to `[0, 90]` days for distribution plots

---

## How to Run

```r
# Install dependencies (first time only)
install.packages(c("tidyverse", "lubridate", "ggplot2", "sf",
                   "scales", "patchwork", "ggridges", "viridis", "ggrepel"))

# Place Rat_Sightings.csv in the project root, then:
Rscript rat_sightings_analysis.R
# → 8 PNG plots saved to ./plots/
```

---

## Key Insights

1. **Brooklyn is the epicentre** — highest sighting volume every year since 2010.
2. **Residential buildings drive infestations** — targeted inspection programs would have the highest ROI.
3. **Summer seasonality is consistent** — pest control resource deployment should ramp up April–September.
4. **Resolution time inequality** — some boroughs close cases significantly faster, suggesting systemic service gaps.
5. **YoY acceleration** — the long-run upward trend signals that current interventions are not keeping pace with the problem.

---

## Real-World Impact

This analysis provides a data-driven foundation for:
- **Public health officials** to prioritise high-density infestation zones
- **City planners** to schedule seasonal sanitation surges
- **Policy makers** to address resolution-time inequities across boroughs
- **Building inspectors** to focus on high-risk residential location types

---

*Abdul Gadiru Sannoh · Data Analyst | Business Analytics Graduate*
