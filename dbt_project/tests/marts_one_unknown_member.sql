-- Each dimension with an unknown member has exactly one. Returns a row when the count is not 1.
select 'dim_planets' as model, count(*) as unknown_members
from {{ ref('dim_planets') }}
where is_unknown_member
having count(*) <> 1

union all

select 'dim_species' as model, count(*) as unknown_members
from {{ ref('dim_species') }}
where is_unknown_member
having count(*) <> 1
