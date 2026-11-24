-- Ingestion falls back to the snapshot per resource. If the API fails halfway, some raw tables come from
-- the API and others from the snapshot, and the marts would join the two. Returns a row when the raw
-- tables do not all share exactly one _source.
with sources as (

    select 'films' as resource, _source from {{ source('raw', 'films') }}
    union all
    select 'people', _source from {{ source('raw', 'people') }}
    union all
    select 'planets', _source from {{ source('raw', 'planets') }}
    union all
    select 'species', _source from {{ source('raw', 'species') }}
    union all
    select 'starships', _source from {{ source('raw', 'starships') }}
    union all
    select 'vehicles', _source from {{ source('raw', 'vehicles') }}

)

select
    count(distinct _source) as distinct_sources,
    count(*) filter (where _source is null) as null_sources,
    string_agg(distinct resource || '=' || coalesce(_source, 'NULL'), ', ') as resource_sources
from sources
having count(distinct _source) <> 1
    or count(*) filter (where _source is null) > 0
