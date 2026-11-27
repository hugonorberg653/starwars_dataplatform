-- films.planets must equal the inverse side planets.films. Returns rows present on one side only.
with canonical as (

    select film_id, planet_id from {{ ref('fct_film_planets') }}

),

inverse as (

    select
        {{ extract_id('u.film_url') }} as film_id,
        p.planet_id
    from {{ ref('stg_planets') }} as p
    cross join unnest(p.film_urls) as u(film_url)

)

select 'only in films.planets' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in planets.films' as side, * from (select * from inverse except select * from canonical)
