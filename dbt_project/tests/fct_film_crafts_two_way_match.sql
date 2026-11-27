-- films.starships/vehicles must equal the inverse sides starships.films/vehicles.films.
-- Returns rows present on one side only.
with canonical as (

    select film_id, craft_key from {{ ref('fct_film_crafts') }}

),

inverse as (

    select
        {{ extract_id('u.film_url') }} as film_id,
        s.craft_key
    from {{ ref('stg_starships') }} as s
    cross join unnest(s.film_urls) as u(film_url)

    union all

    select
        {{ extract_id('u.film_url') }} as film_id,
        v.craft_key
    from {{ ref('stg_vehicles') }} as v
    cross join unnest(v.film_urls) as u(film_url)

)

select 'only in films.starships/vehicles' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in starships/vehicles.films' as side, * from (select * from inverse except select * from canonical)
