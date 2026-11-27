-- Grain: one row per character. Films are counted from the appearances fact.
with appearances as (

    select character_id, count(*) as film_count
    from {{ ref('fct_film_appearances') }}
    group by 1

),

total_films as (

    select count(*) as film_total from {{ ref('dim_films') }}

)

select
    c.character_id,
    c.name,
    coalesce(a.film_count, 0) as film_count,
    coalesce(a.film_count, 0) = t.film_total as is_in_all_films
from {{ ref('dim_characters') }} as c
left join appearances as a on c.character_id = a.character_id
cross join total_films as t
