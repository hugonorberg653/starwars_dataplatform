# Orchestration (Dagster)

Code: [orchestration/](../../orchestration). One code location, `orchestration.definitions`.

## What is modelled

- `raw_swapi` is **one multi-asset** (`raw/people`, `raw/films`, …). Ingestion fetches every resource and loads them in a single transaction, so the assets cannot be materialized separately (`can_subset=False`).
- `swapi_dbt_assets` is every dbt model, loaded from `dbt_project/target/manifest.json`. It runs `dbt build`, so dbt tests appear as Dagster asset checks.
- Lineage raw → staging needs no hand-written dependencies: the raw asset keys (`["raw", <resource>]`) equal the default dagster-dbt key of the dbt source `raw.<resource>`. [tests/test_orchestration.py](../../tests/test_orchestration.py) guards this.
- Asset groups: `raw`, then the dbt layer (`staging`, `intermediate`, `marts`), set in `SwapiDbtTranslator`.
- Job `swapi_full_refresh` materializes everything. Schedule `daily_refresh` runs it at 06:00, on by default.
- The dashboard is deliberately not an asset: it only reads the marts.

## Commands

```powershell
# Run the pipeline once (ingest + dbt build)
.\.venv\Scripts\dagster.exe job execute -m orchestration.definitions -j swapi_full_refresh

# UI + daemon (schedules only fire while this is running)
$env:DAGSTER_HOME = "$PWD\dagster_home"
.\.venv\Scripts\dagster.exe dev -m orchestration.definitions
```

`dagster_home/` is git-ignored. Without `DAGSTER_HOME`, `job execute` uses a throwaway instance and the run is not visible in the UI.

## Gotchas

- **dbt must come from the same environment as Python.** `DbtCliResource` defaults to the first `dbt` on PATH. A global install bundles a different DuckDB and fails with `Trying to read a database file with version number 999`. `DBT_EXECUTABLE` in [definitions.py](../../orchestration/definitions.py) pins the executable next to `sys.executable`.
- **The manifest must exist.** `prepare_if_dev()` regenerates it only under `dagster dev`. For `job execute`, run `dbt parse` after changing models; the Docker build does this. The `dagster dev` path still calls `dbt` from PATH for that parse (in the image that is the one `dbt`, so it is fine).
- **One DuckDB writer.** The job uses `in_process_executor`, so ingest and `dbt build` never overlap. The dashboard's read-only connection can fail while a run holds the write lock.

## Production

Separate webserver and daemon processes, Postgres run storage, a code-location image, freshness checks on `raw` and alerting on failed checks, partitions or incremental loads once data grows.
