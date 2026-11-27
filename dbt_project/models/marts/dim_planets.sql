with planets as (

    select * from {{ ref('stg_planets') }}
    where not is_placeholder

),

known as (

    select
        planet_id,
        name,
        rotation_period_hours,
        orbital_period_days,
        -- The source uses 0 for an unknown diameter (6 planets), which is not a real size.
        nullif(diameter_km, 0) as diameter_km,
        gravity_g,
        gravity_desc,
        surface_water_pct,
        population,
        climates,
        terrains,
        false as is_unknown_member,
        loaded_at,
        source_system
    from planets

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
        true as is_unknown_member,
        cast(null as timestamptz) as loaded_at,
        cast(null as varchar) as source_system

)

select * from known
union all
select * from unknown_member
