import plotly.express as px
import streamlit as st
from db import query, require_database

require_database()

st.title("Character BMI by species")

characters = query(
    """
    select
        c.name,
        case when c.species_id = -1 then 'Unknown (no species in source)' else c.species_name end as species,
        c.is_droid,
        c.height_cm,
        c.mass_kg,
        c.bmi
    from marts.dim_characters as c
    """
)
total = len(characters)
with_bmi = characters[characters["bmi"].notna()]

with st.sidebar:
    include_droids = st.toggle("Include droids", value=True)
    include_unknown = st.toggle("Include unknown species", value=True)
    cap_axis = st.toggle(
        "Cap axis at BMI 100",
        value=True,
        help="Jabba (BMI 443) is a real value. Capping only zooms the chart, the data is untouched.",
    )

data = with_bmi
if not include_droids:
    data = data[~data["is_droid"]]
if not include_unknown:
    data = data[data["species"] != "Unknown (no species in source)"]

st.markdown(
    "BMI = `mass_kg / (height_cm / 100)^2`, computed in dbt only when both values are known. "
    "It is a fun metric here, not a health one: it was designed for humans."
)

if data.empty:
    st.warning("No characters match the filters.")
    st.stop()

summary = (
    data.groupby("species")["bmi"]
    .agg(characters="count", median="median", mean="mean", min="min", max="max")
    .sort_values("median", ascending=False)
    .reset_index()
)

order = summary["species"].tolist()[::-1]
strip = px.strip(
    data,
    x="bmi",
    y="species",
    hover_name="name",
    hover_data={"height_cm": True, "mass_kg": ":.0f", "bmi": ":.1f", "species": False},
    category_orders={"species": order},
    labels={"bmi": "BMI", "species": ""},
)
strip.update_traces(marker={"size": 11, "opacity": 0.85})
repeated = summary[summary["characters"] >= 2]
strip.add_scatter(
    x=repeated["median"],
    y=repeated["species"],
    mode="markers",
    marker={"symbol": "diamond", "size": 12, "color": "white", "line": {"width": 1.5, "color": "black"}},
    name="Median (2+ characters)",
    hoverinfo="skip",
)
if cap_axis:
    strip.update_xaxes(range=[0, 100])
strip.update_layout(
    height=max(450, 24 * len(summary) + 120),
    margin={"l": 0, "r": 0, "t": 10, "b": 0},
    legend={"orientation": "h", "y": 1.05},
)
st.plotly_chart(strip, width="stretch")
if cap_axis and (data["bmi"] > 100).any():
    off_scale = ", ".join(f"{r['name']} ({r['bmi']:.0f})" for _, r in data[data["bmi"] > 100].iterrows())
    st.caption(f"Off the chart: {off_scale}.")

highest = data.loc[data["bmi"].idxmax()]
lowest = data.loc[data["bmi"].idxmin()]
columns = st.columns(3)
columns[0].metric("Characters with a BMI", len(data))
columns[1].metric("Highest", highest["name"], f"{highest['bmi']:.1f}", delta_color="off")
columns[2].metric("Lowest", lowest["name"], f"{lowest['bmi']:.1f}", delta_color="off")

st.subheader("Summary by species")
st.dataframe(
    summary.round(1),
    hide_index=True,
    width="stretch",
    column_config={"characters": st.column_config.NumberColumn("Characters with BMI")},
)

st.subheader("What the cleaning had to handle")
missing_height = int(characters["height_cm"].isna().sum())
missing_mass = int(characters["mass_kg"].isna().sum())
st.markdown(
    f"""
- **{len(with_bmi)} of {total} characters** have a BMI. {missing_height} have no height and {missing_mass} no mass
  (`unknown` in SWAPI), so they are NULL, not zero.
- **Numbers are text with commas** in the source (Jabba's mass is `1,358`). dbt strips the comma before
  casting; a test fails if a real value silently turns into NULL.
- **Jabba the Hutt is a real value**, not an error (BMI ≈ 443). It is kept and flagged, hence the axis cap.
- **Species is empty for many characters**, including most humans. It is shown as *Unknown* and not guessed as
  Human.
- Groups are tiny (often one character), so differences between species are anecdotes.
"""
)
