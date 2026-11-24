with source as (

    select
        {{ extract_id("doc ->> 'url'") }} as character_id,
        doc ->> 'name' as name,
        doc ->> 'height' as height,
        doc ->> 'mass' as mass,
        doc ->> 'hair_color' as hair_color,
        doc ->> 'skin_color' as skin_color,
        doc ->> 'eye_color' as eye_color,
        doc ->> 'birth_year' as birth_year,
        doc ->> 'gender' as gender,
        doc ->> 'homeworld' as homeworld_url,
        {{ json_array('films') }} as film_urls,
        {{ json_array('species') }} as species_urls,
        {{ json_array('vehicles') }} as vehicle_urls,
        {{ json_array('starships') }} as starship_urls,
        cast(doc ->> 'created' as timestamptz) as source_created_at,
        cast(doc ->> 'edited' as timestamptz) as source_edited_at,
        _loaded_at as loaded_at,
        _source as source_system
    from {{ source('raw', 'people') }}

)

select
    character_id,
    trim(name) as name,
    {{ to_number('height', 'integer') }} as height_cm,
    {{ to_number('mass', 'double') }} as mass_kg,
    case
        when upper({{ clean_null('birth_year') }}) like '%BBY'
            then {{ to_number("regexp_replace(upper(birth_year), 'BBY$', '')", 'double') }}
        when upper({{ clean_null('birth_year') }}) like '%ABY'
            then -{{ to_number("regexp_replace(upper(birth_year), 'ABY$', '')", 'double') }}
    end as birth_year_bby,
    case when lower(trim(gender)) in ('n/a', 'none', 'unknown', '') then null else lower(trim(gender)) end as gender,
    case
        when lower(trim(hair_color)) = 'blonde' then 'blond'
        else lower({{ clean_null('hair_color') }})
    end as hair_color,
    lower({{ clean_null('skin_color') }}) as skin_color,
    lower({{ clean_null('eye_color') }}) as eye_color,
    homeworld_url,
    {{ extract_id('homeworld_url') }} as homeworld_planet_id,
    {{ extract_id('species_urls[1]') }} as species_id,
    film_urls,
    species_urls,
    vehicle_urls,
    starship_urls,
    source_created_at,
    source_edited_at,
    loaded_at,
    source_system
from source
