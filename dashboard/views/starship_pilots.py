import plotly.express as px
import streamlit as st
from db import query, require_database

require_database()

st.title("Which starships have pilots, and who flies the most?")
st.markdown(
    "SWAPI records **pilots**, not captains or owners. A link does not say when or how often "
    "someone flew a ship, or whether listed pilots flew together."
)

ships = query(
    """
    select craft_key, name, craft_class, cost_credits, length_m, crew_max, pilot_count, pilot_names
    from reporting.rpt_starship_pilots
    """
)
pilots = query(
    """
    select character_id, name, craft_class, all_classes, starship_count, starship_names
    from reporting.rpt_starship_pilot_counts
    """
)

with st.sidebar:
    ship_class = st.selectbox(
        "Starship class",
        [None, *sorted(ships["craft_class"].unique())],
        format_func=lambda value: "All classes" if value is None else value,
    )

if ship_class is None:
    selected_ships = ships.copy()
    selected_pilots = pilots[pilots["all_classes"]].copy()
else:
    selected_ships = ships[ships["craft_class"] == ship_class].copy()
    selected_pilots = pilots[(~pilots["all_classes"]) & (pilots["craft_class"] == ship_class)].copy()

recorded = selected_ships[selected_ships["pilot_count"] > 0].copy()
unrecorded = selected_ships[selected_ships["pilot_count"] == 0]
columns = st.columns(3)
columns[0].metric("Starships", len(selected_ships))
columns[1].metric("With recorded pilots", len(recorded))
columns[2].metric("Distinct recorded pilots", len(selected_pilots))

st.subheader("Which starships have the most recorded pilots?")
if recorded.empty:
    st.info("No recorded pilots for the selected starships.")
else:
    recorded["label"] = recorded["name"]
    duplicate_names = recorded["name"].duplicated(keep=False)
    recorded.loc[duplicate_names, "label"] += " (" + recorded.loc[duplicate_names, "craft_key"] + ")"
    recorded = recorded.sort_values(["pilot_count", "label"])
    ship_chart = px.bar(
        recorded,
        x="pilot_count",
        y="label",
        orientation="h",
        hover_data={"label": False, "name": True, "craft_class": True, "pilot_names": True},
        labels={"pilot_count": "Recorded pilots", "label": "", "craft_class": "Class", "pilot_names": "Pilots"},
    )
    ship_chart.update_layout(height=max(350, 28 * len(recorded) + 120), margin={"l": 0, "r": 0, "t": 10, "b": 0})
    st.plotly_chart(ship_chart, width="stretch")

st.subheader("Which pilots fly the most starships?")
if selected_pilots.empty:
    st.info("No pilots are recorded for this class.")
else:
    selected_pilots["label"] = selected_pilots["name"]
    duplicate_names = selected_pilots["name"].duplicated(keep=False)
    selected_pilots.loc[duplicate_names, "label"] += (
        " (#" + selected_pilots.loc[duplicate_names, "character_id"].astype(str) + ")"
    )
    selected_pilots = selected_pilots.sort_values(["starship_count", "label"])
    pilot_classes = pilots[~pilots["all_classes"]].copy()
    if ship_class is not None:
        pilot_classes = pilot_classes[pilot_classes["craft_class"] == ship_class].copy()
    labels = selected_pilots.set_index("character_id")["label"]
    pilot_classes["label"] = pilot_classes["character_id"].map(labels)
    pilot_chart = px.bar(
        pilot_classes,
        x="starship_count",
        y="label",
        color="craft_class",
        orientation="h",
        hover_data={"label": False, "name": True, "starship_names": True},
        category_orders={"label": selected_pilots["label"].tolist()},
        labels={"starship_count": "Starships", "label": "", "starship_names": "Starships", "craft_class": "Class"},
    )
    pilot_chart.update_layout(
        height=max(350, 28 * len(selected_pilots) + 120), margin={"l": 0, "r": 0, "t": 10, "b": 0}
    )
    st.plotly_chart(pilot_chart, width="stretch")

st.subheader("Starships without recorded pilots")
st.caption(
    f"{len(unrecorded)} of {len(selected_ships)} starships in the selection have no recorded pilot. "
    "This means the source lists none, not that these ships have never had pilots."
)
if unrecorded.empty:
    st.info("All starships in this selection have recorded pilots.")
else:
    st.dataframe(
        unrecorded[["name", "craft_class", "cost_credits", "length_m", "crew_max"]].sort_values("name"),
        hide_index=True,
        width="stretch",
        column_config={
            "name": "Starship",
            "craft_class": "Class",
            "cost_credits": st.column_config.NumberColumn("Cost (credits)", format="%,.0f"),
            "length_m": "Length (m)",
            "crew_max": "Maximum crew",
        },
    )
