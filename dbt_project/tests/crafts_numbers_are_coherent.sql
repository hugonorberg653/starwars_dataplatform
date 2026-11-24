-- Cross-column checks on dim_crafts that single-column tests cannot see: a crew range must not be reversed, and
-- consumables text that contains a number must not end up as NULL days (a duration format the macro missed).
-- Only free text such as 'Live food tanks' may have no days.
select craft_key, name, 'crew_min > crew_max' as problem, cast(crew_min as varchar) || ' > ' || cast(crew_max as varchar) as detail
from {{ ref('dim_crafts') }}
where crew_min > crew_max

union all

select craft_key, name, 'consumables lost', consumables_desc
from {{ ref('dim_crafts') }}
where consumables_days is null
    and regexp_matches(consumables_desc, '[0-9]')
