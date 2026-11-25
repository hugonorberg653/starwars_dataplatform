import streamlit as st
from db import db_path, query, require_database

require_database()

st.title("Star Wars data platform: findings")
st.markdown(
    "Three questions answered from the dbt marts (`dim_planets`, `dim_characters`, `dim_species`, "
    "`dim_crafts`). Cleaning happens in dbt; the pages only select, filter and plot."
)

counts = query(
    """
    select
        (select count(*) from marts.dim_characters) as characters,
        (select count(*) from marts.dim_planets where not is_unknown_member) as planets,
        (select count(*) from marts.dim_species where not is_unknown_member) as species,
        (select count(*) from marts.dim_crafts where craft_type = 'starship') as starships,
        (select max(loaded_at) from marts.dim_characters) as loaded_at
    """
).iloc[0]

columns = st.columns(4)
columns[0].metric("Characters", int(counts["characters"]))
columns[1].metric("Planets", int(counts["planets"]))
columns[2].metric("Species", int(counts["species"]))
columns[3].metric("Starships", int(counts["starships"]))
st.caption(f"Raw data loaded at {counts['loaded_at']:%Y-%m-%d %H:%M} UTC from `{db_path().name}`.")

st.subheader("Questions")
st.markdown(
    """
1. **Homeworld density**: which home planets produce the most characters relative to their population?
2. **BMI by species**: how does BMI differ by species, and what had to be cleaned to compute it?
3. **Starship cost vs speed**: does a faster hyperdrive cost more?

Each page lists its caveats next to the chart. The common one is that SWAPI is small and incomplete,
so many groups hold one or two rows. Treat the charts as descriptive, not statistical.
"""
)
