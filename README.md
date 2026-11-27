# SWAPI data platform

Ingests the Star Wars API (SWAPI) into DuckDB, models it with **dbt** into a star schema, orchestrates it with **Dagster**, and answers three questions in a **Streamlit** dashboard. Everything runs with one Docker command.

```
SWAPI ──► Python ingest ──► DuckDB raw ──► dbt (staging → marts) ──► Streamlit
              └──────────── orchestrated by Dagster, packaged in Docker ───────────┘
```

## Run it

### Docker (one command)

Needs Docker Desktop running.

```powershell
docker compose up                          # ingest + dbt build, then the dashboard
docker compose --profile orchestrator up   # same, plus the Dagster UI
docker compose down                        # stop; data is kept (add -v to wipe it)
```

| What | Where |
|---|---|
| Dashboard | http://localhost:8501 (starts only if the pipeline succeeded) |
| Dagster UI | http://localhost:3000 (needs `--profile orchestrator`) |

If `swapi.dev` is down or has certificate problems, use a mirror: `$env:SWAPI_BASE_URL = "https://swapi.info/api"; docker compose up`. `SWAPI_VERIFY_SSL=false` turns off certificate checking.

After changing dbt models or Python code, add `--build` (`docker compose up --build`); the dbt manifest is baked into the image.

### Inspect a run

- **Dagster UI:** *Runs* shows logs per run, *Assets* shows lineage and the status of every model, and each dbt test appears as an asset check. Use *Materialize all* to trigger a refresh.
- **Logs:** `docker compose logs pipeline` (available until `docker compose down`).
- **Run dbt by hand** in a one-off container on the same data:
  ```powershell
  docker compose run --rm --no-deps pipeline dbt test --project-dir dbt_project --profiles-dir dbt_project
  docker compose run --rm --no-deps pipeline dbt show --project-dir dbt_project --profiles-dir dbt_project --inline "select count(*) from marts.dim_films"
  ```

### Locally (Windows, PowerShell)

Needs Python 3.11 and [uv](https://docs.astral.sh/uv/). Python 3.14 is too new for dbt and Dagster.

```powershell
uv venv --python 3.11 .venv
uv pip install --python .venv\Scripts\python.exe -r requirements-dev.txt

# Whole pipeline (ingest + dbt build) through Dagster
.\.venv\Scripts\dagster.exe job execute -m orchestration.definitions -j swapi_full_refresh

# Or step by step
.\.venv\Scripts\python.exe -m ingestion.swapi_ingest
cd dbt_project; ..\.venv\Scripts\dbt.exe build --profiles-dir .; cd ..

# Dashboard, and the Dagster UI with schedules
.\.venv\Scripts\streamlit.exe run dashboard\app.py
$env:DAGSTER_HOME = "$PWD\dagster_home"; .\.venv\Scripts\dagster.exe dev -m orchestration.definitions

# Checks
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\ruff.exe check .
```

Run dbt from the venv (`.venv\Scripts\dbt.exe`), not from a global install: a global dbt bundles a different DuckDB and cannot read the database file. DuckDB allows one writer, so close the DuckDB UI before `dbt build`.

### Configuration

| Variable | Default | Purpose |
|---|---|---|
| `SWAPI_BASE_URL` | `https://swapi.dev/api` | API base URL (`https://swapi.info/api` works as a mirror) |
| `SWAPI_VERIFY_SSL` | `true` | `false` skips certificate checks |
| `DUCKDB_PATH` | `data/swapi.duckdb` locally, `/data/swapi.duckdb` in Docker | Database file used by ingestion, dbt and the dashboard |

## How it works

1. **Ingestion** ([ingestion/](ingestion)) fetches six resources (people, planets, films, species, vehicles, starships) with pagination, retries and backoff. Each record is stored as delivered in one JSON column of `raw.<resource>`, plus `_loaded_at` and `_source`. Every resource is fetched before anything is written, and the load is one transaction. A failed fetch fails the run and leaves the previous raw tables untouched; there is no fallback data.
2. **dbt** ([dbt_project/](dbt_project)) holds all business logic:
   - `staging`: flattens the JSON, casts types and turns `unknown`/`n/a` into NULL. It also strips commas from numbers, parses units and ranges, fixes known typos and extracts IDs from URLs.
   - `marts`: five dimensions and five keys-only facts (one per many-to-many relationship, unnested straight from staging), contract-enforced tables with an unknown member (`-1`) so fact keys are never NULL. Dimensions hold attributes only. A separate `reporting` layer (`models/reporting`, `rpt_*`, schema `reporting`) holds the counts and flags that aggregate the facts.
   - 19 models in total. There is no intermediate layer: the unnest models were identical to the facts, so they were merged into them.
3. **Dagster** ([orchestration/](orchestration)) models ingestion as one multi-asset (`raw/*`) and every dbt model as an asset, so lineage runs from raw to marts. dbt tests become asset checks. The job `swapi_full_refresh` runs one step at a time, and a daily schedule runs it at 06:00.
4. **Dashboard** ([dashboard/](dashboard)) reads the marts only, through a read-only DuckDB connection.
5. **Docker** uses one image for three services: `pipeline` (one-shot Dagster run), `dashboard` (waits for `pipeline` to succeed) and `dagster` (UI, optional). Data lives in named volumes.

### Testing

- **dbt:** keys (`unique`, `not_null`), `relationships` from facts to dimensions, `accepted_values`, and custom generic tests (`positive_value`, `value_between`, `no_silent_null`, `unique_combination_of_columns`).
  - Singular tests include two-way match tests (each fact against the inverse side of the API data), count reconciliation, and a check that raw tables share one source.
  - dbt unit tests run the cleaning logic on hand-written rows with known SWAPI quirks.
  - A full `dbt build` ends with `PASS=203 WARN=1 ERROR=0` (models and tests together; the warning is expected, see Data quirks).
- **Python:** `pytest` covers ingestion (no network), the dashboard pages (skipped without a database) and the Dagster asset graph.

## Findings

Details and caveats are in [dashboard.md](.github/docs/dashboard.md).

- **Homeworld density** (characters per million inhabitants): dominated by small planets such as Dathomir, so the page has a minimum-characters filter. Absolute counts (Naboo, Tatooine) rank differently, and both views are shown.
- **BMI by species:** the *unknown* species holds most characters (including Luke and Leia, whom SWAPI lists without a species; the model does not guess Human). Jabba's BMI (about 443) is real data, so the chart caps the axis and names him instead of dropping him. Most species have one character, so comparisons are anecdotes.
- **Starship cost vs speed:** the rank correlation between speed and cost is negative (about -0.4 for hyperdrive, stronger for MGLT). Size is the likely confounder, since capital ships and the Death Star are expensive and slow. Only 26 of 36 starships have both values, so this is indicative only.

## Design decisions

| Decision | Why | Alternative |
|---|---|---|
| dbt Core + DuckDB | Anyone can run it with one command, with no accounts or credentials. | dbt Cloud with a cloud warehouse; the same project would work with a different profile. |
| Hand-written ingestion | Shows pagination, retry and load handling directly, and the volume (about 260 rows) doesn't need a framework. | `dlt`, for many sources or incremental state. |
| Raw as a JSON document | New, renamed or retyped API fields cannot break the load. Drift shows up in dbt as NULLs or failed casts and tests. | Inferred columns, which can silently change raw types. |
| Full refresh | SWAPI is tiny and static, with no reliable change marker, and full refresh is idempotent. | Incremental loads keyed on `edited`. |
| No fallback data | A failed run is loud instead of silently serving stale data. | A committed snapshot. |
| Starships + vehicles in one `dim_crafts` | They share most attributes and play the same role. The key includes `craft_type` so it doesn't rely on the IDs staying disjoint. | Two dimensions and two craft facts. |
| Business logic in dbt only | The dashboard selects, filters and plots. | Calculations in Streamlit. |
| One image for all services | One dependency set and no version drift. | Separate images per service. |
| Dashboard doesn't start if the pipeline fails | It never shows half-built data. | Start anyway with the previous data. |

More detail per area is in [.github/docs/](.github/docs): [ingestion](.github/docs/ingestion.md), [data model](.github/docs/data-model.md), [transformations](.github/docs/transformations.md), [orchestration](.github/docs/orchestration.md), [dashboard](.github/docs/dashboard.md) and [infrastructure](.github/docs/infrastructure.md).

## Data quirks handled

- Missing values come in three kinds: `unknown` and `n/a` become NULL, while `none` is a real value (0 for numbers).
- Numbers arrive as strings with commas (`1,358`), units (`1000km`) or ranges (`30-165`).
- 6 planets have `diameter = 0`, which is SWAPI's stand-in for unknown. Staging keeps it and warns (the 1 expected dbt warning); `dim_planets` turns it into NULL.
- Planet 28 is a placeholder named `unknown`; it maps to the unknown member.
- Typos such as `Galatic Basic`, `mammals`/`mammal` and `blonde`/`blond` are normalised.
- `try_cast` could hide a value that fails to parse, so the `no_silent_null` test fails if a real raw value becomes NULL.

## Known limitations

- **One writer:** DuckDB allows one writer at a time. While a refresh runs (including the 06:00 schedule), dashboard queries fail until it finishes. A real warehouse removes this.
- **Extra refresh:** starting the `dagster` service makes Compose re-run `pipeline`, which shows as an extra (idempotent) run.
- **Not served:** `dbt docs` is not served, so lineage is only in the Dagster UI.
- **Questions not answered:** two plan questions (film with the most characters, characters in all films) have no dashboard page. The marts support them.
- **Missing pieces:** no CI workflow, no source freshness checks, no sqlfluff config yet.
- **API availability:** `swapi.dev` is sometimes down, and the pipeline fails rather than falling back. `swapi.tech` is not supported because its response shape differs.

## In production

- A real warehouse (Snowflake or BigQuery) through a different dbt profile, which also removes the single-writer limit.
- Incremental loads: append-only raw tables with `_loaded_at`, dedupe in staging, and incremental marts.
- Type 2 history with `dbt snapshot` and surrogate keys.
- Source freshness checks, and alerting on failed runs and asset checks.
- Dagster with separate webserver and daemon, Postgres storage and a code-location image. Partitions once the data grows.
- CI on every push: `dbt build`, sqlfluff, ruff and pytest, plus image scanning.

## Repo layout

```
ingestion/        API client and raw load
dbt_project/      models (staging, marts), macros, tests, profiles.yml
orchestration/    Dagster assets, job and schedule
dashboard/        Streamlit app (pages in views/)
tests/            pytest: ingestion, dashboard, orchestration
Dockerfile, docker-compose.yml, .dockerignore
requirements.txt (runtime, used by the image), requirements-dev.txt (adds sqlfluff, ruff, pytest)
.github/docs/     detailed working documentation
```
