# Ingestion

Loads SWAPI data into DuckDB as raw tables. Business logic does not live here; all cleaning and modelling happens in dbt (see [data_engineer_test_plan.md](../data_engineer_test_plan.md)).

```
SWAPI ──► ingestion/swapi_ingest.py ──► data/swapi.duckdb (schema raw) ──► dbt
              └── fallback: data/snapshot/*.json
```

## Files

| Path | Purpose |
|---|---|
| `ingestion/swapi_ingest.py` | Fetch, snapshot fallback and load into DuckDB |
| `data/snapshot/*.json` | Committed raw JSON per resource, used when the API is unreachable |
| `data/swapi.duckdb` | Output database (git-ignored) |
| `tests/test_swapi_ingest.py` | Unit tests (no network) |
| `pyproject.toml` | pytest and ruff settings |

## Usage

Run from the repo root with the venv (Python 3.11):

```powershell
.\.venv\Scripts\python.exe -m ingestion.swapi_ingest                    # API, snapshot fallback
.\.venv\Scripts\python.exe -m ingestion.swapi_ingest --update-snapshot  # also rewrite data/snapshot
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\ruff.exe check .
```

### Configuration (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `SWAPI_BASE_URL` | `https://swapi.dev/api` | API base URL. `https://swapi.info/api` works as a mirror |
| `DUCKDB_PATH` | `data/swapi.duckdb` | Output database file |
| `SWAPI_SNAPSHOT_DIR` | `data/snapshot` | Fallback and snapshot directory |
| `SWAPI_VERIFY_SSL` | `true` | Set to `false` if `swapi.dev` has certificate problems |

## Behaviour

- **Resources:** `people`, `planets`, `films`, `species`, `vehicles`, `starships` (one table each, `raw.<resource>`).
- **Pagination:** follows `next` URLs for the paginated `{"results": [...], "next": ...}` shape (`swapi.dev`). A bare JSON array (`swapi.info`) is read in one request. A page cap and a seen-URL check stop pagination loops.
- **Retries:** `tenacity`, 4 attempts, exponential backoff (1–10 s) on any `requests` exception. A 30 s timeout applies per request.
- **Raw load:** the JSON is loaded as delivered (ELT). Column types come from DuckDB `read_json` over the full file (`sample_size = -1`); numbers stay strings (e.g. `"1,000"`, `"unknown"`) and URL arrays become `VARCHAR[]`.
- **Metadata columns:** `_loaded_at` (timestamp of the load) and `_source` (base URL, or `snapshot`).
- **Idempotency:** each run does `create or replace table` per resource inside a transaction, so re-runs give the same result and a failed load keeps the previous table.
- **Fallback:** if a resource cannot be fetched after retries, the snapshot is used. After the first failure the API is skipped for the remaining resources, so a fully down API costs one round of retries, not six. A missing snapshot file raises an error.
- **Snapshot:** `--update-snapshot` rewrites `data/snapshot/<resource>.json` from the API response. Commit it so the pipeline runs when the API is down during review.

## Verified

- Live load from `swapi.dev`: people 82, planets 60, films 6, species 37, vehicles 39, starships 36.
- Same counts from the `swapi.info` mirror.
- Fallback with an unreachable base URL loads all six resources from the snapshot (about 24 s, mostly the first resource's retries).
- 5 unit tests pass (pagination, bare list, retry exhaustion, snapshot fallback with idempotent re-run, snapshot writing); `ruff check` is clean.

## Design decisions (interview talking points)

- **Hand-written ingestion over `dlt`:** shows pagination, retry and load handling directly; the volume (about 260 rows) does not need a framework. `dlt` would be the choice for many sources or incremental state.
- **Full refresh, not incremental:** SWAPI is tiny and static, and has no reliable change marker. At scale: incremental loads keyed on `edited`, or append-only raw tables with `_loaded_at` and dedupe in staging.
- **API failure handling:** retries with backoff, then a committed snapshot. `_source` makes it visible which data a run used, so a snapshot load is not mistaken for fresh data.
- **Schema drift:** raw tables take the columns the API returns. New fields appear automatically; renamed or removed fields surface as dbt source or staging test failures instead of being hidden in Python.
- **Everything as strings in raw:** casting and cleaning (`unknown`/`n/a` to NULL, comma removal, ID extraction from URLs) belongs in dbt staging.
- **Mirror differences:** `swapi.tech` is not supported; it nests records under `properties` and would need its own parser.

## Production notes

- Load into a real warehouse (Snowflake or BigQuery) with a different dbt profile.
- Incremental loads, source freshness checks (`_loaded_at`) and alerting on snapshot fallback.
- Orchestrate with Dagster (or the Makefile fallback) and run `pytest` and `ruff` in CI.
