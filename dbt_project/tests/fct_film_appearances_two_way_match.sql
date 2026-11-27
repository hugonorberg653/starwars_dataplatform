-- films.characters must equal the inverse side people.films. Returns rows present on one side only.
with canonical as (

    select film_id, character_id from {{ ref('fct_film_appearances') }}

),

inverse as (

    select
        {{ extract_id('u.film_url') }} as film_id,
        p.character_id
    from {{ ref('stg_people') }} as p
    cross join unnest(p.film_urls) as u(film_url)

)

select 'only in films.characters' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in people.films' as side, * from (select * from inverse except select * from canonical)
