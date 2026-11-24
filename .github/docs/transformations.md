# Transformations (dbt)

dbt project in [dbt_project/](../../dbt_project). Target design is in [data-model.md](data-model.md); this file records what is implemented and the gotchas.

## Status

| Layer | State |
|---|---|
| staging | Done: 6 models flatten `raw.<resource>.doc` and clean it per data-model §4 (missing markers to NULL, number and unit parsing, renames with units, category fixes, `species_id` and `homeworld_planet_id` extracted). The `*_urls` columns are kept for the bridges |
| intermediate | Done: 5 bridge views (§7), row counts match the design (162 / 33 / 73 / 104 / 43) |
| marts | Done: 5 dimensions and 2 facts as contract-enforced tables in schema `marts` (§6). Row counts: 162 appearances, 43 pilot rows, 60 planets (59 + unknown), 38 species (37 + unknown), 75 crafts |

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
- **URL columns:** raw URL fields are renamed `*_url` (single) and `*_urls` (arrays), e.g. `homeworld_url`, `film_urls`. Staging also extracts `homeworld_planet_id` and `species_id` from them; the arrays stay for the bridges.
- **Cleaning macros:** `clean_null` (trim, `unknown`/`n/a`/empty to NULL), `to_number` (comma removal, `try_cast`), `consumables_days`, `split_list`. `try_cast` can hide a value that fails to parse, so the generic test `no_silent_null` compares each cleaned number column with `raw` and fails if a real value became NULL.
- **Source quirk, diameter 0:** 6 planets have `diameter = 0` (Polis Massa, Cato Neimoidia, Stewjon, Trandosha, Socorro and the placeholder). Staging keeps the 0 and its `positive_value` test only warns (expected: 6 warnings). `dim_planets` turns 0 into NULL.
- **Marts:** tables with `contract: enforced`, so every column in `_marts.yml` needs a `data_type` that matches the SQL. Unknown members (`-1`) are added in `dim_planets` and `dim_species`. `dim_characters` maps a missing homeworld, the placeholder planet 28 and a missing species to `-1` by joining the dimensions, so a fact FK can never be NULL. `fct_film_appearances` copies those keys from `dim_characters` and reads the release date from `dim_films`, so it is built after both.
- **Mart tests:** keys, `relationships` from facts to dimensions, one unknown member per dimension, row counts against staging (`tests/marts_row_counts_match_source.sql`) and the copied keys (`tests/fct_film_appearances_copied_keys_match.sql`).
- **`craft_key`:** the `craft_key` macro (`md5(craft_type || '|' || id)`) is used in `stg_starships`, `stg_vehicles` and the two craft bridges, so the bridges can be tested against the staging models. The same macro will build `dim_crafts.craft_key`. Craft bridges also carry `craft_type` and `source_craft_id`.
- **Craft relationships tests:** a bridge row refers to either `stg_starships` or `stg_vehicles`, so there is one `relationships` test per target, each limited with `config: where: "craft_type = ..."`.
- **Bridges are not de-duplicated.** A duplicate in the source array should fail the `unique_combination_of_columns` test, not be hidden.
- **Two-way match tests** (`tests/int_*_two_way_match.sql`) compare each bridge with the inverse side (e.g. `films.characters` vs `people.films`) using `except` in both directions. Any row returned is a failure. They need the inverse `*_urls` arrays in staging.
- **Other two-way matches:** `tests/species_people_two_way_match.sql` (`people.species` vs `species.people`) and `tests/planet_residents_two_way_match.sql` (`people.homeworld` vs `planets.residents`). The dimension counts `member_count` and `resident_count` rely on the first side only.
- **Reconciliation and plausibility tests:** `tests/marts_counts_reconcile.sql` checks that dimension counts (`resident_count`, `member_count`, `pilot_count`, `film_count`, ...) add up to the facts and bridges. `tests/crafts_numbers_are_coherent.sql` checks `crew_min <= crew_max` and that consumables text with a number is not turned into NULL days. `tests/raw_sources_uniform.sql` fails if the raw tables do not share one `_source` (API and snapshot mixed). `value_between` (generic) bounds height, mass, BMI and surface water.
- **dbt unit tests** (`models/*/_unit_tests.yml`) run the cleaning and mart logic on hand-written rows with known SWAPI quirks (`47,060`, `30-165`, `1000km`, `ABY`, `indefinite`, `Galatic Basic`, the BMI guard, release order).
- **`unique_combination_of_columns`** is a small own generic test in `tests/generic/`, to avoid adding `dbt_utils` for one test.
- Generic test arguments are written under `arguments:` (the form dbt 1.10+ expects).

## Not yet done

- `sources.yml` freshness and the snapshot-fallback warning.
- sqlfluff config.
