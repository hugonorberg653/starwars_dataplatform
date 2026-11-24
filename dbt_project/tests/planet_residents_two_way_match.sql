-- people.homeworld must equal the inverse side planets.residents. dim_planets.resident_count is built from
-- people.homeworld only, so a disagreement means the counts are wrong. Returns rows present on one side only.
with canonical as (

    select character_id, homeworld_planet_id as planet_id
    from {{ ref('stg_people') }}
    where homeworld_planet_id is not null

),

inverse as (

    select
        {{ extract_id('u.resident_url') }} as character_id,
        p.planet_id
    from {{ ref('stg_planets') }} as p
    cross join unnest(p.resident_urls) as u(resident_url)

)

select 'only in people.homeworld' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in planets.residents' as side, * from (select * from inverse except select * from canonical)
