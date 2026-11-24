-- films.species must equal the inverse side species.films. Returns rows present on one side only.
with canonical as (

    select film_id, species_id from {{ ref('int_film_species') }}

),

inverse as (

    select
        {{ extract_id('u.film_url') }} as film_id,
        s.species_id
    from {{ ref('stg_species') }} as s
    cross join unnest(s.film_urls) as u(film_url)

)

select 'only in films.species' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in species.films' as side, * from (select * from inverse except select * from canonical)
