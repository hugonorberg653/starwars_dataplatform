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
