# Transformations (dbt)

dbt project in [dbt_project/](../../dbt_project). Target design is in [data-model.md](data-model.md); this file records what is implemented and the gotchas.

## Status

| Layer | State |
|---|---|
| staging | **Partly done**: 6 models flatten `raw.<resource>.doc` into all source fields, typed where the source declares a type (ids, `episode_id`, `release_date`, `created`/`edited`, URL arrays). Value cleaning (data-model §4: `unknown`/`n/a` to NULL, number and unit parsing, renames with units) is not implemented, so those columns are still text with source names |
| intermediate | Done: 5 bridge views (§7), row counts match the design (162 / 33 / 73 / 104 / 43) |
| marts | Not started |

## Running

Run from `dbt_project/`; `profiles.yml` lives there and the default DB path `../data/swapi.duckdb` is relative to the working directory.

```powershell
cd dbt_project
..\.venv\Scripts\dbt.exe build --profiles-dir .
```

`DUCKDB_PATH` overrides the database file. DuckDB allows one writer, so close the DuckDB UI (`launch_duckdb_ui.bat`) before `dbt build`.

## Decisions and gotchas

- **Schema names:** the `generate_schema_name` macro uses the custom schema as is (`staging`, `intermediate`), not `main_staging`.
- **JSON raw:** staging reads `doc` with `->>` and the `json_array` macro. All six raw tables share one set of source column tests, written once with a YAML anchor in `sources.yml` (dbt does not allow `columns` on the source level).
- **URL columns:** raw URL fields are renamed `*_url` (single) and `*_urls` (arrays), e.g. `homeworld_url`, `film_urls`. Marts will turn them into IDs.
- **`craft_key`:** the `craft_key` macro (`md5(craft_type || '|' || id)`) is used in `stg_starships`, `stg_vehicles` and the two craft bridges, so the bridges can be tested against the staging models. The same macro will build `dim_crafts.craft_key`. Craft bridges also carry `craft_type` and `source_craft_id`.
- **Craft relationships tests:** a bridge row refers to either `stg_starships` or `stg_vehicles`, so there is one `relationships` test per target, each limited with `config: where: "craft_type = ..."`.
- **Bridges are not de-duplicated.** A duplicate in the source array should fail the `unique_combination_of_columns` test, not be hidden.
- **Two-way match tests** (`tests/int_*_two_way_match.sql`) compare each bridge with the inverse side (e.g. `films.characters` vs `people.films`) using `except` in both directions. Any row returned is a failure. They need the inverse `*_urls` arrays in staging.
- **`unique_combination_of_columns`** is a small own generic test in `tests/generic/`, to avoid adding `dbt_utils` for one test.
- Generic test arguments are written under `arguments:` (the form dbt 1.10+ expects).

## Not yet done

- Staging cleaning rules and tests (data-model §4, §8), `sources.yml` freshness and the snapshot-fallback warning.
- Marts, contracts, sqlfluff config.
