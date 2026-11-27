with species as (

    select * from {{ ref('stg_species') }}

),

known as (

    select
        species_id,
        name,
        classification,
        designation,
        average_height_cm,
        skin_colors,
        hair_colors,
        eye_colors,
        average_lifespan_years,
        is_lifespan_indefinite,
        language,
        -- A species without a homeworld stays NULL. The placeholder planet becomes the unknown member.
        case
            when homeworld_planet_id is null then null
            else {{ resolve_planet_id('homeworld_planet_id') }}
        end as homeworld_planet_id,
        false as is_unknown_member,
        loaded_at,
        source_system
    from species

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
        cast(null as boolean) as is_lifespan_indefinite,
        cast(null as varchar) as language,
        cast(null as integer) as homeworld_planet_id,
        true as is_unknown_member,
        cast(null as timestamptz) as loaded_at,
        cast(null as varchar) as source_system

)

select * from known
union all
select * from unknown_member
