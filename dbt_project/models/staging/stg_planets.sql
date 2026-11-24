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
