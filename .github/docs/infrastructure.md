# Infrastructure (Docker)

Files: [Dockerfile](../../Dockerfile), [docker-compose.yml](../../docker-compose.yml), [.dockerignore](../../.dockerignore).

## Commands

```powershell
docker compose up                            # ingest + dbt build, then dashboard on http://localhost:8501
docker compose --profile orchestrator up     # same, plus Dagster UI and schedule on http://localhost:3000
docker compose down                          # keeps the data; add -v to wipe volumes and start from scratch
```

Docker Desktop must be running first.

## Design

- **One image, three services.** `pipeline`, `dashboard` and `dagster` all use the same image and differ only in command. One dependency set, one build, no version drift between services.
- **`pipeline` is a one-shot `dagster job execute`** rather than calling ingest and dbt directly, so every container run is recorded in the Dagster instance (visible in the UI) and uses the same code path as the schedule.
- **`dashboard` waits for `pipeline` to finish successfully** (`service_completed_successfully`). If ingestion or a dbt test fails the dashboard never starts, instead of serving stale or half-built data. Healthcheck: `/_stcore/health`.
- **`dagster` is behind the `orchestrator` profile** so the default command stays small. It is `dagster dev` (webserver + daemon in one process), which is enough for a demo; see production notes in [orchestration.md](orchestration.md).
- **State lives in two named volumes**: `warehouse` (`/data`, the DuckDB file, mounted read-only into the dashboard) and `dagster_home` (run history, shared by `pipeline` and `dagster`). Both mount points exist in the image owned by the non-root `app` user (uid 1000), which is what makes the named volumes writable.
- **The dbt manifest is built into the image** (`dbt parse` with a scratch `DUCKDB_PATH`) because [assets.py](../../orchestration/assets.py) reads it at import time. Models therefore need an image rebuild (`docker compose up --build`) to take effect.
- **Dev tooling is excluded.** The image installs only [requirements.txt](../../requirements.txt); sqlfluff, ruff and pytest are in [requirements-dev.txt](../../requirements-dev.txt). `tests/` is not copied either.
- **uv** installs the pinned requirements; its version is pinned in the `COPY --from` line.

## Configuration

`SWAPI_BASE_URL` and `SWAPI_VERIFY_SSL` are passed through from the host shell or a `.env` file next to the compose file (defaults match local runs). Example for a mirror: `$env:SWAPI_BASE_URL = "https://swapi.info/api"; docker compose up`. `DUCKDB_PATH=/data/swapi.duckdb` and `DAGSTER_HOME=/dagster_home` are set in the image.

## Gotchas

- **Starting `dagster` re-runs `pipeline`.** Compose starts a `service_completed_successfully` dependency again if it has exited, so a second `docker compose up` produces a second (idempotent) refresh. Harmless, but it shows as an extra run in Dagster.
- **A scheduled run can block the dashboard.** DuckDB allows one writer across containers sharing the volume; while the 06:00 refresh holds the write lock, dashboard queries fail until it finishes.
- **The container database is separate from `data/swapi.duckdb` on the host.** `.dockerignore` keeps the local file out of the image, and the volume starts empty.

## Verified

Built and run on Docker Desktop (Windows): `pipeline` exits 0 with `PASS=203 WARN=1 ERROR=0`, the dashboard is healthy and reads the marts over the read-only mount, and the Dagster UI shows the `swapi_full_refresh` job, the schedule and the run.

## Not done

- No CI workflow yet (planned: `dbt build` + sqlfluff + pytest on push).
- No image scanning, no multi-stage build (the image is not size-optimised).
- No separate webserver/daemon, no Postgres for Dagster storage.
