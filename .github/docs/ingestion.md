# Ingestion

Loads SWAPI data into DuckDB as raw tables. Business logic does not live here; all cleaning and modelling happens in dbt (see [data_engineer_test_plan.md](../data_engineer_test_plan.md)).

```
SWAPI ──► ingestion/swapi_ingest.py ──► data/swapi.duckdb (schema raw) ──► dbt
```

## Files

| Path | Purpose |
|---|---|
| `ingestion/swapi_ingest.py` | Fetch from the API and load into DuckDB |
| `data/swapi.duckdb` | Output database (git-ignored) |
| `tests/test_swapi_ingest.py` | Unit tests (no network) |
| `pyproject.toml` | pytest and ruff settings |

## Usage

Run from the repo root with the venv (Python 3.11):

```powershell
.\.venv\Scripts\python.exe -m ingestion.swapi_ingest
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\ruff.exe check .
```

### Configuration (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `SWAPI_BASE_URL` | `https://swapi.dev/api` | API base URL. `https://swapi.info/api` works as a mirror |
| `DUCKDB_PATH` | `data/swapi.duckdb` | Output database file |
| `SWAPI_VERIFY_SSL` | `true` | Set to `false` if `swapi.dev` has certificate problems |

## Behaviour

- **Resources:** `people`, `planets`, `films`, `species`, `vehicles`, `starships` (one table each, `raw.<resource>`).
- **Pagination:** follows `next` URLs for the paginated `{"results": [...], "next": ...}` shape (`swapi.dev`). A bare JSON array (`swapi.info`) is read in one request. A page cap and a seen-URL check stop pagination loops.
- **Retries:** `tenacity`, 4 attempts, exponential backoff (1–10 s) on any `requests` exception. A 30 s timeout applies per request.
- **Raw load:** each record is stored as delivered in a single JSON column, `raw.<resource>(doc JSON, _loaded_at, _source)`, one row per record (ELT, like a Snowflake `VARIANT`). Ingestion knows no column names or types, so API changes cannot break the load. Flattening and typing are done in dbt staging.
- **Metadata columns:** `_loaded_at` (timestamp of the load) and `_source` (the base URL).
- **Idempotency and atomicity:** every resource is fetched first; only if all succeed are the raw tables replaced (`create or replace table`), all in one transaction. Re-runs give the same result, and a failed fetch or load keeps the previous tables, so raw never mixes old and new data.
- **No fallback:** data always comes from the API. If a resource cannot be fetched after retries, `SwapiUnavailableError` is raised and the run fails (non-zero exit). The trade-off is that the pipeline needs a reachable API (or a mirror via `SWAPI_BASE_URL`); a failed run is loud instead of silently loading stale data.

## Verified

- Live load from `swapi.dev`: people 82, planets 60, films 6, species 37, vehicles 39, starships 36.
- Same counts from the `swapi.info` mirror.
- 6 unit tests pass (pagination, bare list, retry exhaustion, API load with idempotent re-run, failed fetch keeping previous tables, JSON raw load keeping unexpected fields and types); `ruff check` is clean.

## Design decisions (interview talking points)

- **Hand-written ingestion over `dlt`:** shows pagination, retry and load handling directly; the volume (about 260 rows) does not need a framework. `dlt` would be the choice for many sources or incremental state.
- **Full refresh, not incremental:** SWAPI is tiny and static, and has no reliable change marker. At scale: incremental loads keyed on `edited`, or append-only raw tables with `_loaded_at` and dedupe in staging.
- **API failure handling:** retries with backoff, then fail the run. There is no fallback data, so a run never loads stale data; raw tables keep their previous content until a complete fetch succeeds.
- **Schema drift:** the whole record goes into `doc`, so new, renamed, removed or retyped fields never fail the load. They surface in dbt: a removed field becomes NULL, and a changed type fails the staging `cast` or a test. The earlier design used `read_json` with inferred columns, which could silently change raw column types; it was replaced for that reason.
- **Raw as a JSON document:** values stay exactly as delivered (`"1,000"`, `"unknown"`, URL arrays). Casting and cleaning (`unknown`/`n/a` to NULL, comma removal, ID extraction from URLs) belong in dbt staging. The cost is more verbose staging SQL (`doc ->> 'name'`) and no columnar typing in raw, which does not matter at this volume.
- **Mirror differences:** `swapi.tech` is not supported; it nests records under `properties` and would need its own parser.

## Production notes

- Load into a real warehouse (Snowflake or BigQuery) with a different dbt profile.
- Incremental loads, source freshness checks (`_loaded_at`) and alerting on failed runs.
- Orchestrate with Dagster (or the Makefile fallback) and run `pytest` and `ruff` in CI.
