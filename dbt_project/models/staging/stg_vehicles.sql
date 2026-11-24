with source as (

    select
        {{ extract_id("doc ->> 'url'") }} as vehicle_id,
        doc ->> 'name' as name,
        doc ->> 'model' as model,
        doc ->> 'manufacturer' as manufacturer,
        doc ->> 'cost_in_credits' as cost_in_credits,
        doc ->> 'length' as length,
        doc ->> 'max_atmosphering_speed' as max_atmosphering_speed,
        doc ->> 'crew' as crew,
        doc ->> 'passengers' as passengers,
        doc ->> 'cargo_capacity' as cargo_capacity,
        doc ->> 'consumables' as consumables,
        doc ->> 'vehicle_class' as vehicle_class,
        {{ json_array('pilots') }} as pilot_urls,
        {{ json_array('films') }} as film_urls,
        cast(doc ->> 'created' as timestamptz) as source_created_at,
        cast(doc ->> 'edited' as timestamptz) as source_edited_at,
        _loaded_at as loaded_at,
        _source as source_system
    from {{ source('raw', 'vehicles') }}

)

select
    {{ craft_key("'vehicle'", 'vehicle_id') }} as craft_key,
    *
from source
