with source as (

    select
        {{ extract_id("doc ->> 'url'") }} as species_id,
        doc ->> 'name' as name,
        doc ->> 'classification' as classification,
        doc ->> 'designation' as designation,
        doc ->> 'average_height' as average_height,
        doc ->> 'skin_colors' as skin_colors,
        doc ->> 'hair_colors' as hair_colors,
        doc ->> 'eye_colors' as eye_colors,
        doc ->> 'average_lifespan' as average_lifespan,
        doc ->> 'homeworld' as homeworld_url,
        doc ->> 'language' as language,
        {{ json_array('people') }} as people_urls,
        {{ json_array('films') }} as film_urls,
        cast(doc ->> 'created' as timestamptz) as source_created_at,
        cast(doc ->> 'edited' as timestamptz) as source_edited_at,
        _loaded_at as loaded_at,
        _source as source_system
    from {{ source('raw', 'species') }}

)

select
    species_id,
    trim(name) as name,
    case lower({{ clean_null('classification') }})
        when 'mammals' then 'mammal'
        when 'reptilian' then 'reptile'
        else lower({{ clean_null('classification') }})
    end as classification,
    lower({{ clean_null('designation') }}) as designation,
    {{ to_number('average_height', 'integer') }} as average_height_cm,
    lower({{ clean_null('skin_colors') }}) as skin_colors,
    lower({{ clean_null('hair_colors') }}) as hair_colors,
    lower({{ clean_null('eye_colors') }}) as eye_colors,
    case
        when lower(trim(average_lifespan)) = 'indefinite' then null
        else {{ to_number('average_lifespan', 'integer') }}
    end as average_lifespan_years,
    coalesce(lower(trim(average_lifespan)) = 'indefinite', false) as is_lifespan_indefinite,
    case
        when lower(trim(language)) in ('galatic basic', 'galactic basic') then 'Galactic Basic'
        else {{ clean_null('language') }}
    end as language,
    homeworld_url,
    {{ extract_id('homeworld_url') }} as homeworld_planet_id,
    people_urls,
    film_urls,
    source_created_at,
    source_edited_at,
    loaded_at,
    source_system
from source
