with source as (

    select
        {{ extract_id("doc ->> 'url'") }} as starship_id,
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
        doc ->> 'hyperdrive_rating' as hyperdrive_rating,
        doc ->> 'MGLT' as mglt,
        doc ->> 'starship_class' as starship_class,
        {{ json_array('pilots') }} as pilot_urls,
        {{ json_array('films') }} as film_urls,
        cast(doc ->> 'created' as timestamptz) as source_created_at,
        cast(doc ->> 'edited' as timestamptz) as source_edited_at,
        _loaded_at as loaded_at,
        _source as source_system
    from {{ source('raw', 'starships') }}

)

select
    {{ craft_key("'starship'", 'starship_id') }} as craft_key,
    starship_id,
    trim(name) as name,
    {{ clean_null('model') }} as model,
    {{ clean_null('manufacturer') }} as manufacturer,
    {{ to_number('cost_in_credits', 'bigint') }} as cost_credits,
    {{ to_number('length', 'double') }} as length_m,
    {{ to_number("regexp_replace(max_atmosphering_speed, '(?i)km$', '')", 'integer') }} as max_atmosphering_speed_kmh,
    {{ to_number("split_part(crew, '-', 1)", 'integer') }} as crew_min,
    coalesce(
        {{ to_number("split_part(crew, '-', 2)", 'integer') }},
        {{ to_number("split_part(crew, '-', 1)", 'integer') }}
    ) as crew_max,
    {{ to_number('passengers', 'integer') }} as passengers,
    case
        when lower(trim(cargo_capacity)) = 'none' then 0
        else {{ to_number('cargo_capacity', 'bigint') }}
    end as cargo_capacity_kg,
    {{ consumables_days('consumables') }} as consumables_days,
    {{ clean_null('consumables') }} as consumables_desc,
    {{ to_number('hyperdrive_rating', 'double') }} as hyperdrive_rating,
    {{ to_number('mglt', 'integer') }} as mglt,
    case
        when lower(trim(starship_class)) = 'air speeder' then 'airspeeder'
        else lower({{ clean_null('starship_class') }})
    end as craft_class,
    pilot_urls,
    film_urls,
    source_created_at,
    source_edited_at,
    loaded_at,
    source_system
from source
