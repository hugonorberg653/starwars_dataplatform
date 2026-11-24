-- people.species must equal the inverse side species.people. dim_species.member_count is built from
-- people.species only, so a disagreement means the counts are wrong. Returns rows present on one side only.
with canonical as (

    select character_id, species_id from {{ ref('stg_people') }} where species_id is not null

),

inverse as (

    select
        {{ extract_id('u.person_url') }} as character_id,
        s.species_id
    from {{ ref('stg_species') }} as s
    cross join unnest(s.people_urls) as u(person_url)

)

select 'only in people.species' as side, * from (select * from canonical except select * from inverse)
union all
select 'only in species.people' as side, * from (select * from inverse except select * from canonical)
