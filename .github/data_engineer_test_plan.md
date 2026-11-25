# Plan for the SWAPI/PokeAPI Data Engineer Test

## Assignment summary

- **Time:** 4–8 hours
- **Tasks:** Ingest data from SWAPI or PokeAPI, transform it with dbt, and present the findings.
- **Bonus:** Single command (2–3 at most), containerization, orchestration.
- **Hard requirement:** dbt. Everything else is up to me.

---

## First decision: dbt Core + DuckDB instead of dbt Cloud

I have dbt Cloud, but I'll build this with **dbt Core and DuckDB**:

- **The bonus points need it.** dbt Cloud can't run inside the container, and it can't be started with one command on the reviewer's laptop.
- **The reviewer can run it.** With dbt Cloud they'd need access to my account and warehouse credentials. With DuckDB, anyone who clones the repo can run `docker compose up` and it works.
- **It's a choice I can defend.** DuckDB is a single file and needs no infrastructure. The README will say something like: *"In production I'd point the same project at Snowflake or BigQuery via a different profile, and run it on dbt Cloud or an orchestrator."*

dbt Cloud stays a talking point, but the solution doesn't depend on it.

---

## Data source: SWAPI

- **Small:** about 6 resources and a few hundred rows. Time goes into modelling instead of waiting on API calls.
- **Relational:** people, films, planets, species, starships and vehicles link to each other through URL arrays. This shows dimensional modelling and many-to-many bridge tables well.
- **Messy in ways worth discussing:** `"unknown"`, `"n/a"`, numbers with commas like `"1,000"`, and heights and costs stored as strings.
- **Risk:** `swapi.dev` is sometimes down or has certificate problems.
  - Make the base URL configurable (`swapi.info` and `swapi.tech` are mirrors).
  - The pipeline always ingests from the API (no snapshot fallback); a failed fetch fails the run and keeps the previous raw tables.

PokeAPI is richer for analysis but more nested and heavier to ingest. Within 4–8 hours, SWAPI gives a cleaner finished result.

---

## Architecture

```
SWAPI ──► Python ingest ──► DuckDB (raw) ──► dbt (staging → intermediate → marts) ──► Dashboard
                └─────────── orchestrated by Dagster (or a Makefile) ───────────┘
                                 all inside Docker
```

### 1. Ingestion (Python, about 80 lines)

- Use `requests` with pagination and retries/backoff.
- Load the raw JSON as-is (the ELT approach) into `raw.<resource>`, with a `_loaded_at` column.
- Make it idempotent: each run does a full refresh of the raw tables. That's fine at this size; be ready to explain when to switch to incremental loading.
- `dlt` is an alternative that handles pagination and schemas. Hand-written code shows more of my own understanding. Either is fine; be ready to explain the choice.

### 2. dbt layers (keep it to about 12–15 models)

| Layer | Purpose | Examples |
|---|---|---|
| `staging` | One model per source: rename columns, cast types, turn `unknown`/`n/a` into NULL, extract IDs from URLs | `stg_people`, `stg_films`, `stg_planets`… |
| `intermediate` | Unnest the URL arrays into bridge tables | `int_film_characters`, `int_film_planets`, `int_people_starships` |
| `marts` | Tables the analysis uses | `dim_characters`, `dim_planets`, `dim_films`, `fct_film_appearances` |

On top of that:

- **Tests:** `unique` and `not_null` on keys, `relationships` between facts and dimensions, `accepted_values`, and one or two custom tests (for example, height must be positive).
- **Documentation:** `sources.yml` and model descriptions, plus `dbt docs generate` to show lineage in the follow-up.
- Use `dbt build` instead of separate run and test steps.

### 3. Findings: pick 3–5 questions

Answer a few specific questions rather than making a generic dashboard. For example:

- Which film has the most characters, and how diverse are its species?
- Which home planets produce the most characters relative to population?
- Character BMI by species (a good showcase for cleaning the data)
- Starship cost vs. hyperdrive rating: what does speed cost?
- Which characters appear in all films?

**How to present them:** Streamlit or Evidence.dev, both of which read DuckDB directly. Evidence is just markdown plus SQL and looks polished with little effort; Streamlit is more familiar. Also summarize the main findings in the README so the reviewer sees them without running anything.

### 4. Bonus items

- **Single command:** `docker compose up` (or `make run`) ingests, builds with dbt and starts the dashboard.
- **Container:** one Dockerfile, with dependencies installed via `uv` or pip and pinned versions.
- **Orchestration:** Dagster with `dagster-dbt` shows every dbt model as an asset with lineage in the UI, which looks impressive for little effort. Airflow is too heavy for this. If time runs short, a Makefile that runs the steps in sequence is acceptable; say so in the README.

---

## Repo layout

```
├── ingestion/          # swapi_ingest.py
├── dbt_project/        # models/{staging,intermediate,marts}, tests, profiles.yml
├── orchestration/      # dagster definitions
├── dashboard/          # streamlit app or evidence project
├── docker-compose.yml, Dockerfile, Makefile
├── .github/workflows/ci.yml   # optional: dbt build + sqlfluff on push
└── README.md           # how to run, assumptions, design decisions, findings, next steps
```

---

## Time budget (about 6 hours)

| Task | Time |
|---|---|
| Ingestion + DuckDB | 1h |
| dbt models + tests + docs | 2–2.5h |
| Dashboard/findings | 1h |
| Docker + single command | 0.5–1h |
| Orchestration | 0.5–1h |
| README | 0.5h |

---

## What makes it clean

- **The README matters as much as the code.** Include assumptions, why each tool was chosen, what was deliberately left out, and what I'd do in production: incremental loads, a real warehouse, alerting, CI/CD, and source freshness checks.
- **Keep the scope tight.** Fifteen well-tested models beat forty half-done ones.
- **Prepare for the follow-up.** Expect questions on idempotency, handling API failures, schema drift, how to scale it, and where business logic should live.

---

## Next steps

- [ ] Set up the repo structure
- [ ] Write the ingestion script
- [ ] Build the dbt staging, intermediate and marts models with tests and docs
- [ ] Build the dashboard and write up the findings
- [ ] Add Docker and the single-command run
- [ ] Add orchestration (Dagster, or a Makefile as fallback)
- [ ] Write the README
