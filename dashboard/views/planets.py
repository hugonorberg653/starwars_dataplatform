import plotly.express as px
import streamlit as st
from db import query, require_database

require_database()

st.title("Which home planets produce the most characters relative to population?")

planets = query(
    """
    select
        name,
        population,
        resident_count,
        resident_count * 1e6 / population as characters_per_million
    from marts.dim_planets
    where not is_unknown_member
      and population > 0
    """
)
excluded = query(
    """
    select
        count(*) filter (where population is null) as unknown_population,
        count(*) filter (where population = 0) as zero_population,
        sum(resident_count) filter (where is_unknown_member) as unknown_homeworld
    from marts.dim_planets
    """
).iloc[0]

with st.sidebar:
    min_residents = st.slider("Minimum characters per planet", 1, int(planets["resident_count"].max()), 1)
    top_n = st.slider("Planets shown", 5, 30, 15)

shown = planets[planets["resident_count"] >= min_residents]
ranked = shown.sort_values("characters_per_million", ascending=False).head(top_n)

st.markdown(
    "Density = characters whose homeworld is the planet, per **million inhabitants**. "
    "The scale is logarithmic because populations span nine orders of magnitude."
)

if ranked.empty:
    st.warning("No planets match the filters.")
    st.stop()

top = ranked.iloc[0]
most_characters = shown.sort_values("resident_count", ascending=False).iloc[0]
columns = st.columns(2)
columns[0].metric(
    "Highest density",
    top["name"],
    f"{top['characters_per_million']:,.1f} per million",
    delta_color="off",
)
columns[1].metric(
    "Most characters in total",
    most_characters["name"],
    f"{int(most_characters['resident_count'])} characters, {most_characters['characters_per_million']:.4f} per million",
    delta_color="off",
)

bar = px.bar(
    ranked.sort_values("characters_per_million"),
    x="characters_per_million",
    y="name",
    orientation="h",
    log_x=True,
    hover_data={"population": ":,", "resident_count": True, "characters_per_million": ":.4f"},
    labels={"characters_per_million": "Characters per million inhabitants (log)", "name": ""},
)
bar.update_layout(height=max(350, 28 * len(ranked) + 120), margin={"l": 0, "r": 0, "t": 10, "b": 0})
st.plotly_chart(bar, width="stretch")

st.subheader("Population vs characters")
scatter = px.scatter(
    shown,
    x="population",
    y="resident_count",
    text="name",
    log_x=True,
    hover_data={"characters_per_million": ":.4f"},
    labels={"population": "Population (log)", "resident_count": "Characters"},
)
scatter.update_traces(textposition="top center", marker={"size": 9})
scatter.update_layout(height=450, margin={"l": 0, "r": 0, "t": 10, "b": 0})
st.plotly_chart(scatter, width="stretch")

st.info(
    "**Read with care.** With one character the ratio is just `1 / population`, so tiny populations "
    "(Dathomir, Haruun Kal) top the ranking. Raise the minimum slider to see planets that produced several "
    "characters. Absolute counts tell a different story, see the second chart."
)
st.caption(
    f"Not shown: {int(excluded['unknown_population'])} planets with unknown population, "
    f"{int(excluded['zero_population'])} with population 0 (a division by zero), and "
    f"{int(excluded['unknown_homeworld'])} characters with no usable homeworld."
)
with st.expander("Data"):
    st.dataframe(
        shown.sort_values("characters_per_million", ascending=False),
        hide_index=True,
        width="stretch",
    )
