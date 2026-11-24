with planets as (

    select * from {{ ref('stg_planets') }}
    where not is_placeholder

),

residents as (

    select
        homeworld_planet_id as planet_id,
        count(*) as resident_count
    from {{ ref('stg_people') }}
    group by 1

),

films as (

    select
        planet_id,
        count(*) as film_count
    from {{ ref('int_film_planets') }}
    group by 1

),

known as (

    select
        p.planet_id,
        p.name,
        p.rotation_period_hours,
        p.orbital_period_days,
        -- The source uses 0 for an unknown diameter (6 planets), which is not a real size.
        nullif(p.diameter_km, 0) as diameter_km,
        p.gravity_g,
        p.gravity_desc,
        p.surface_water_pct,
        p.population,
        p.climates,
        p.terrains,
        coalesce(r.resident_count, 0) as resident_count,
        coalesce(f.film_count, 0) as film_count,
        false as is_unknown_member,
        p.loaded_at,
        p.source_system
    from planets as p
    left join residents as r on p.planet_id = r.planet_id
    left join films as f on p.planet_id = f.planet_id

),

-- Characters with no homeworld, or with the placeholder planet, point here.
unknown_member as (

    select
        -1 as planet_id,
        'Unknown' as name,
        cast(null as integer) as rotation_period_hours,
        cast(null as integer) as orbital_period_days,
        cast(null as integer) as diameter_km,
        cast(null as double) as gravity_g,
        cast(null as varchar) as gravity_desc,
        cast(null as double) as surface_water_pct,
        cast(null as bigint) as population,
        cast(null as varchar[]) as climates,
        cast(null as varchar[]) as terrains,
        (
            select count(*)
            from {{ ref('stg_people') }} as p
            left join planets as pl on p.homeworld_planet_id = pl.planet_id
            where pl.planet_id is null
        ) as resident_count,
        0 as film_count,
        true as is_unknown_member,
        cast(null as timestamptz) as loaded_at,
        cast(null as varchar) as source_system

)

select * from known
union all
select * from unknown_member
