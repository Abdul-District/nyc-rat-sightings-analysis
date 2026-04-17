"""
NYC Rat Sightings REST API
Powers Power BI dashboards via JSON endpoints.

Usage:
  python api.py

Place your 'A1_sightings.csv' in the same directory.
If the CSV is missing, synthetic sample data is loaded for testing.
"""

import os
import random
from datetime import datetime, timedelta

import pandas as pd
import uvicorn
from contextlib import asynccontextmanager

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

CSV_PATH = os.path.join(os.path.dirname(__file__), "A1_sightings.csv")


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_data()
    yield


app = FastAPI(
    title="NYC Rat Sightings API",
    description="REST API for NYC rat sightings data — connect to Power BI via Web connector.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def _generate_sample_data(n: int = 5000) -> pd.DataFrame:
    """Generate synthetic rat sightings for testing when CSV is absent."""
    random.seed(42)
    boroughs = ["Manhattan", "Brooklyn", "Bronx", "Queens", "Staten Island"]
    location_types = [
        "Residential Building/House",
        "3+ Family Apt. Building",
        "Commercial Building",
        "Street/Sidewalk",
        "1-2 Family Dwelling",
        "Other",
        "Park/Playground",
    ]
    borough_coords = {
        "Manhattan":     (40.7831, -73.9712),
        "Brooklyn":      (40.6782, -73.9442),
        "Bronx":         (40.8448, -73.8648),
        "Queens":        (40.7282, -73.7949),
        "Staten Island": (40.5795, -74.1502),
    }

    start = datetime(2014, 1, 1)
    end = datetime(2017, 12, 31)
    span = (end - start).days

    rows = []
    for _ in range(n):
        borough = random.choice(boroughs)
        base_lat, base_lon = borough_coords[borough]
        dt = start + timedelta(days=random.randint(0, span), hours=random.randint(0, 23))
        rows.append({
            "created_date":  dt,
            "year":          dt.year,
            "month":         dt.month,
            "day":           dt.day,
            "weekday":       dt.strftime("%A"),
            "borough":       borough,
            "location_type": random.choice(location_types),
            "latitude":      round(base_lat + random.uniform(-0.05, 0.05), 6),
            "longitude":     round(base_lon + random.uniform(-0.05, 0.05), 6),
        })
    return pd.DataFrame(rows)


def _load_csv() -> pd.DataFrame:
    df = pd.read_csv(CSV_PATH, na_values=["", "NA", "N/A"])
    df["created_date"] = pd.to_datetime(df["Created Date"], format="mixed", dayfirst=False, errors="coerce")
    df = df.dropna(subset=["created_date"])
    df["year"]     = df["created_date"].dt.year
    df["month"]    = df["created_date"].dt.month
    df["day"]      = df["created_date"].dt.day
    df["weekday"]  = df["created_date"].dt.strftime("%A")
    df["borough"]  = df["Borough"].str.title()
    df["location_type"] = df["Location Type"].str.title().fillna("Unknown")
    df["latitude"]  = pd.to_numeric(df["Latitude"],  errors="coerce")
    df["longitude"] = pd.to_numeric(df["Longitude"], errors="coerce")
    df = df.dropna(subset=["borough", "latitude", "longitude"]).drop_duplicates()
    return df[[
        "created_date", "year", "month", "day", "weekday",
        "borough", "location_type", "latitude", "longitude",
    ]]


def load_data():
    global _df, _using_sample
    if os.path.exists(CSV_PATH):
        _df = _load_csv()
        _using_sample = False
        print(f"Loaded {len(_df):,} records from {CSV_PATH}")
    else:
        _df = _generate_sample_data()
        _using_sample = True
        print("CSV not found — using synthetic sample data (5,000 rows).")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _df_filtered(borough: str | None, year: int | None, month: int | None) -> pd.DataFrame:
    df = _df
    if borough:
        df = df[df["borough"].str.lower() == borough.lower()]
    if year:
        df = df[df["year"] == year]
    if month:
        df = df[df["month"] == month]
    return df


def _to_records(df: pd.DataFrame) -> list:
    return df.where(df.notna(), None).to_dict(orient="records")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "ok",
        "total_records": len(_df),
        "using_sample_data": _using_sample,
        "years_available": sorted(_df["year"].dropna().unique().astype(int).tolist()),
    }


@app.get("/sightings")
def get_sightings(
    borough: str | None = Query(None, description="Filter by borough name"),
    year: int | None = Query(None, description="Filter by year"),
    month: int | None = Query(None, description="Filter by month number (1–12)"),
    limit: int = Query(1000, ge=1, le=10000, description="Max rows to return"),
    offset: int = Query(0, ge=0, description="Row offset for pagination"),
):
    """
    Raw sightings records — use in Power BI as the base table.
    Connect via: Home → Get Data → Web → paste API URL.
    """
    df = _df_filtered(borough, year, month)
    total = len(df)
    page = df.iloc[offset: offset + limit].copy()
    page["created_date"] = page["created_date"].dt.strftime("%Y-%m-%dT%H:%M:%S")
    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "data": _to_records(page),
    }


@app.get("/summary/by-borough")
def summary_by_borough(
    year: int | None = Query(None),
    month: int | None = Query(None),
):
    """Total sightings per borough — use for bar / donut chart."""
    df = _df_filtered(None, year, month)
    result = (
        df.groupby("borough", as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
        .sort_values("total_sightings", ascending=False)
    )
    return _to_records(result)


@app.get("/summary/by-year")
def summary_by_year(
    borough: str | None = Query(None),
    month: int | None = Query(None),
):
    """Total sightings per year — use for line / column chart."""
    df = _df_filtered(borough, None, month)
    result = (
        df.groupby("year", as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
        .sort_values("year")
    )
    result["year"] = result["year"].astype(int)
    return _to_records(result)


@app.get("/summary/by-borough-year")
def summary_by_borough_year(
    month: int | None = Query(None),
):
    """Sightings broken down by borough × year — use for grouped/stacked bar."""
    df = _df_filtered(None, None, month)
    result = (
        df.groupby(["year", "borough"], as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
        .sort_values(["year", "total_sightings"], ascending=[True, False])
    )
    result["year"] = result["year"].astype(int)
    return _to_records(result)


@app.get("/summary/by-month")
def summary_by_month(
    borough: str | None = Query(None),
    year: int | None = Query(None),
):
    """Total sightings per month — use for seasonality / heatmap visual."""
    month_names = {
        1: "Jan", 2: "Feb", 3: "Mar", 4: "Apr", 5: "May", 6: "Jun",
        7: "Jul", 8: "Aug", 9: "Sep", 10: "Oct", 11: "Nov", 12: "Dec",
    }
    df = _df_filtered(borough, year, None)
    result = (
        df.groupby("month", as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
        .sort_values("month")
    )
    result["month_name"] = result["month"].map(month_names)
    return _to_records(result)


@app.get("/summary/by-location-type")
def summary_by_location_type(
    borough: str | None = Query(None),
    year: int | None = Query(None),
    top_n: int = Query(10, ge=1, le=50, description="Return only top N location types"),
):
    """Top location types by sighting count — use for horizontal bar chart."""
    df = _df_filtered(borough, year, None)
    result = (
        df.groupby("location_type", as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
        .sort_values("total_sightings", ascending=False)
        .head(top_n)
    )
    return _to_records(result)


@app.get("/summary/by-weekday")
def summary_by_weekday(
    borough: str | None = Query(None),
    year: int | None = Query(None),
):
    """Sightings by day of week — use for bar chart or heatmap."""
    order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    df = _df_filtered(borough, year, None)
    result = (
        df.groupby("weekday", as_index=False)
        .size()
        .rename(columns={"size": "total_sightings"})
    )
    result["weekday"] = pd.Categorical(result["weekday"], categories=order, ordered=True)
    result = result.sort_values("weekday")
    return _to_records(result)


@app.get("/geo")
def get_geo_points(
    borough: str | None = Query(None),
    year: int | None = Query(None),
    limit: int = Query(5000, ge=1, le=50000, description="Max map points to return"),
):
    """
    Lat/lon points for map visual in Power BI.
    Use with the 'Map' or 'Azure Maps' visual — latitude/longitude fields.
    """
    df = _df_filtered(borough, year, None).dropna(subset=["latitude", "longitude"])
    df = df[
        (df["latitude"].between(40.4, 41.0)) &
        (df["longitude"].between(-74.3, -73.6))
    ].head(limit)
    cols = ["latitude", "longitude", "borough", "location_type", "year", "month"]
    return _to_records(df[cols])


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=False)
