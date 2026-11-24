with species as (

    select * from {{ ref('stg_species') }}

),

planets as (

    select planet_id from {{ ref('dim_planets') }}

),

members as (

    select
        species_id,
        count(*) as member_count
    from {{ ref('stg_people') }}
    group by 1

),

known as (

    select
        s.species_id,
        s.name,
        s.classification,
        s.designation,
        s.average_height_cm,
        s.skin_colors,
        s.hair_colors,
        s.eye_colors,
        s.average_lifespan_years,
        s.is_lifespan_indefinite,
        s.language,
        -- A species without a homeworld stays NULL. The placeholder planet becomes the unknown member.
        case
            when s.homeworld_planet_id is null then null
            else coalesce(p.planet_id, -1)
        end as homeworld_planet_id,
        coalesce(m.member_count, 0) as member_count,
        false as is_unknown_member,
        s.loaded_at,
        s.source_system
    from species as s
    left join planets as p on s.homeworld_planet_id = p.planet_id
    left join members as m on s.species_id = m.species_id

),

-- Characters with no species point here. They are not assumed to be Human.
unknown_member as (

    select
        -1 as species_id,
        'Unknown' as name,
        cast(null as varchar) as classification,
        cast(null as varchar) as designation,
        cast(null as integer) as average_height_cm,
        cast(null as varchar) as skin_colors,
        cast(null as varchar) as hair_colors,
        cast(null as varchar) as eye_colors,
        cast(null as integer) as average_lifespan_years,
        false as is_lifespan_indefinite,
        cast(null as varchar) as language,
        cast(null as integer) as homeworld_planet_id,
        (select count(*) from {{ ref('stg_people') }} where species_id is null) as member_count,
        true as is_unknown_member,
        cast(null as timestamptz) as loaded_at,
        cast(null as varchar) as source_system

)

select * from known
union all
select * from unknown_member
