with films as (

    select * from {{ ref('stg_films') }}

)

select
    f.film_id,
    f.title,
    f.episode_id,
    f.release_date,
    cast(row_number() over (order by f.release_date, f.episode_id) as integer) as release_order,
    case
        when f.episode_id between 1 and 3 then 'prequel'
        when f.episode_id between 4 and 6 then 'original'
    end as trilogy,
    f.director,
    f.producers,
    f.loaded_at,
    f.source_system
from films as f
