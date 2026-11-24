-- people.starships/vehicles must equal the inverse sides starships.pilots/vehicles.pilots.
-- Returns rows present on one side only.
with canonical as (

    select character_id, craft_key from {{ ref('int_character_crafts') }}

),

inverse as (

    select
        {{ extract_id('u.pilot_url') }} as character_id,
        s.craft_key
    from {{ ref('stg_starships') }} as s
    cross join unnest(s.pilot_urls) as u(pilot_url)

    union all

    select
        {{ extract_id('u.pilot_url') }} as character_id,
        v.craft_key
    from {{ ref('stg_vehicles') }} as v
    cross join unnest(v.pilot_urls) as u(pilot_url)

)

select 'only in people.starships/vehicles' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in starships/vehicles.pilots' as side, * from (select * from inverse except select * from canonical)
