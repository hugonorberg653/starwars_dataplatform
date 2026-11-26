# One image for every service (pipeline, dashboard, Dagster UI); the command differs per service.
FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:0.11.6 /uv /usr/local/bin/uv

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    DUCKDB_PATH=/data/swapi.duckdb \
    DAGSTER_HOME=/dagster_home

WORKDIR /app

# Dependencies first so this layer is cached until requirements.txt changes.
COPY requirements.txt .
RUN uv pip install --system --no-cache -r requirements.txt

RUN useradd --create-home --uid 1000 app \
    && mkdir /data /dagster_home \
    && chown app:app /data /dagster_home /app
USER app

COPY --chown=app:app ingestion ingestion
COPY --chown=app:app dbt_project dbt_project
COPY --chown=app:app orchestration orchestration
COPY --chown=app:app dashboard dashboard

# Dagster reads the dbt manifest at import time, so build it into the image.
# Parsing does not need data; the scratch path keeps a stray DuckDB file out of /data.
RUN DUCKDB_PATH=/tmp/parse.duckdb dbt parse --project-dir dbt_project --profiles-dir dbt_project \
    && rm -f /tmp/parse.duckdb

# /data and /dagster_home are mounted as named volumes (see docker-compose.yml).
VOLUME ["/data", "/dagster_home"]
EXPOSE 8501 3000

# Default: run the pipeline once. Compose overrides this for the dashboard and the Dagster UI.
CMD ["dagster", "job", "execute", "-m", "orchestration.definitions", "-j", "swapi_full_refresh"]
