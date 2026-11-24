with source as (

    select
        {{ extract_id("doc ->> 'url'") }} as planet_id,
        doc ->> 'name' as name,
        doc ->> 'rotation_period' as rotation_period,
        doc ->> 'orbital_period' as orbital_period,
        doc ->> 'diameter' as diameter,
        doc ->> 'climate' as climate,
        doc ->> 'gravity' as gravity,
        doc ->> 'terrain' as terrain,
        doc ->> 'surface_water' as surface_water,
        doc ->> 'population' as population,
        {{ json_array('residents') }} as resident_urls,
        {{ json_array('films') }} as film_urls,
        cast(doc ->> 'created' as timestamptz) as source_created_at,
        cast(doc ->> 'edited' as timestamptz) as source_edited_at,
        _loaded_at as loaded_at,
        _source as source_system
    from {{ source('raw', 'planets') }}

)

select
    planet_id,
    trim(name) as name,
    lower(trim(name)) = 'unknown' as is_placeholder,
    {{ to_number('rotation_period', 'integer') }} as rotation_period_hours,
    {{ to_number('orbital_period', 'integer') }} as orbital_period_days,
    {{ to_number('diameter', 'integer') }} as diameter_km,
    {{ to_number('surface_water', 'double') }} as surface_water_pct,
    {{ to_number('population', 'bigint') }} as population,
    try_cast(regexp_extract({{ clean_null('gravity') }}, '^[0-9]+(\.[0-9]+)?', 0) as double) as gravity_g,
    {{ clean_null('gravity') }} as gravity_desc,
    {{ split_list(clean_null('climate'), lower=true) }} as climates,
    {{ split_list(clean_null('terrain'), lower=true) }} as terrains,
    resident_urls,
    film_urls,
    source_created_at,
    source_edited_at,
    loaded_at,
    source_system
from source
