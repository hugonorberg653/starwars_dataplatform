# Dashboard

Streamlit app in [dashboard/](../../dashboard). It reads the marts only (`rpt_planet_residents`, `dim_characters`, `dim_crafts`) through a read-only DuckDB connection, and answers the three findings questions from the plan. Cleaning stays in dbt; the pages select, filter and plot, plus small display statistics (a ratio, a median, a rank correlation).

## Running

```powershell
.\.venv\Scripts\streamlit.exe run dashboard\app.py
```

- Double-click [launch_dashboard.bat](../../launch_dashboard.bat) to do the same; close its window to stop the app.
- `DUCKDB_PATH` overrides the database file (default `data/swapi.duckdb`). A relative value resolves against the working directory.
- DuckDB allows one writer. [dashboard/db.py](../../dashboard/db.py) opens a read-only connection per query and closes it, so the app does not block `dbt build`, but a running `dbt build` blocks the app's queries. Results are cached for 5 minutes.
- Smoke test: `pytest tests/test_dashboard.py` renders each page with Streamlit's `AppTest`. It is skipped when `data/swapi.duckdb` does not exist.

## Layout

`app.py` is only the `st.navigation` entry point. Pages live in `dashboard/views/` (not `pages/`, which would add a second automatic navigation).

| Page | Reads | Decisions |
|---|---|---|
| Homeworld density | `rpt_planet_residents` | Density = `resident_count * 1e6 / population` (characters per million inhabitants). Unknown member, NULL population and population 0 are excluded. A minimum-characters slider is needed because one character on a tiny planet (Dathomir) otherwise tops the ranking |
| BMI by species | `dim_characters` (`species_name` is denormalised there) | The unknown species is kept and labelled instead of dropped, because it holds most characters (including Luke and Leia; SWAPI lists no species for them and the model does not guess Human). Axis capped at BMI 100 by default: Jabba (≈ 443) stays in the data and metrics and is named under the chart. Medians only for species with 2+ characters |
| Starship cost vs speed | `dim_crafts where craft_type = 'starship'` | Hyperdrive rating is inverted (`1 / rating`) so that faster is to the right. Alternative speed measure: MGLT, known for fewer ships. Ships with no cost or no speed are left out, not set to 0. Correlation is Pearson on ranks (Spearman) to avoid a scipy dependency |

## Findings and caveats

- Starships: the rank correlation between speed and cost is negative (about -0.4 for hyperdrive, stronger for MGLT). Size is the likely confounder: capital ships and the Death Star are expensive and slow. 26 of 36 starships have both cost and hyperdrive rating, so this is indicative only.
- Species groups are mostly 1 character; per-species BMI comparisons are anecdotes.
- Density is dominated by small-population planets; absolute counts (Naboo, Tatooine) rank differently. Both views are on the page.

## Not done

- Other plan questions (film with most characters, characters in all films) have no page.
- Docker: the `dashboard` service runs this app; see [infrastructure.md](infrastructure.md).
