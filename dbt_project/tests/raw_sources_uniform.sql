-- Ingestion loads all raw tables in one run from one base URL. This guards against raw tables that were
-- loaded from different sources (for example after a manual load or a changed SWAPI_BASE_URL), which the
-- marts would then join. Returns a row when the raw
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
