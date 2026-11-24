select
    {{ extract_id("doc ->> 'url'") }} as film_id,
    doc ->> 'title' as title,
    cast(doc ->> 'episode_id' as integer) as episode_id,
    doc ->> 'opening_crawl' as opening_crawl,
    doc ->> 'director' as director,
    doc ->> 'producer' as producer,
    cast(doc ->> 'release_date' as date) as release_date,
    {{ json_array('characters') }} as character_urls,
    {{ json_array('planets') }} as planet_urls,
    {{ json_array('species') }} as species_urls,
    {{ json_array('starships') }} as starship_urls,
    {{ json_array('vehicles') }} as vehicle_urls,
    cast(doc ->> 'created' as timestamptz) as source_created_at,
    cast(doc ->> 'edited' as timestamptz) as source_edited_at,
    _loaded_at as loaded_at,
    _source as source_system
from {{ source('raw', 'films') }}
