# Data quality tests

A test fails if it finds a row that breaks the rule.

## Rules for single values

- A value that must be positive (for example a planet's diameter) cannot be zero or negative. Unknown (empty) is allowed.
- A value must fall within a sensible range. This catches unit or parsing mistakes that still look positive, such as a height of 18,000 cm.
- A character has at most one species.
- A value that exists in the raw data cannot turn into empty during cleaning, unless we chose that on purpose (for example "indefinite").
- A combination of columns, such as film and character, cannot appear twice.

## Rules for crafts

- The minimum crew cannot be larger than the maximum crew.
- If the consumables text contains a number, the number of days must be filled in.

## Rules that both sides of a relationship must agree on

SWAPI states each relationship twice, once on each side. Both sides must match:

- Films and their characters
- Films and their planets
- Films and their species
- Films and their starships and vehicles
- Characters and their starships and vehicles (pilots)
- Planets and their residents (a character's homeworld)
- Species and their members

## Rules for the final tables

- The number of rows must match the source, so no rows are lost or duplicated by joins.
- Totals in the reporting models must add up. For example, the residents of all planets must equal the number of characters, and the film counts must equal the arrays on the films.
- Planets and species each have exactly one "unknown" row.
- Facts hold keys only, so there is no copy of a dimension attribute to keep in sync.

## Rules for the load

- All raw tables must come from the same source (one base URL), not a mix.
