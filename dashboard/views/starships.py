import numpy as np
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from db import query, require_database

require_database()

st.title("Starship cost vs hyperdrive rating: what does speed cost?")

starships = query(
    """
    select
        name,
        craft_class,
        cost_credits,
        hyperdrive_rating,
        1.0 / hyperdrive_rating as hyperdrive_speed,
        mglt
    from marts.dim_crafts
    where craft_type = 'starship'
    """
)

st.markdown(
    "A **lower hyperdrive rating is faster** (class 0.5 covers distance twice as fast as class 1.0). "
    "To read the chart naturally, speed is `1 / hyperdrive_rating` where 1.0 is the standard class: "
    "further right is faster."
)

with st.sidebar:
    speed_measure = st.radio(
        "Speed measure",
        ["Hyperdrive speed (1 / rating)", "MGLT (sublight)"],
        help="MGLT is megalights per hour in realspace, known for fewer ships.",
    )
    log_cost = st.toggle("Logarithmic cost axis", value=True)
    exclude_extreme = st.toggle(
        "Exclude Death Star-scale cost", value=False, help="Cost above 10 billion credits."
    )

x_column = "hyperdrive_speed" if speed_measure.startswith("Hyperdrive") else "mglt"
x_label = "Hyperdrive speed (1 = class 1.0, higher is faster)" if x_column == "hyperdrive_speed" else "MGLT"

plotted = starships.dropna(subset=["cost_credits", x_column])
if exclude_extreme:
    plotted = plotted[plotted["cost_credits"] <= 10_000_000_000]

missing_cost = int(starships["cost_credits"].isna().sum())
missing_speed = int(starships[x_column].isna().sum())

if len(plotted) < 3:
    st.warning("Too few starships with both cost and speed for this selection.")
    st.stop()

figure = px.scatter(
    plotted,
    x=x_column,
    y="cost_credits",
    hover_name="name",
    hover_data={
        "craft_class": True,
        "hyperdrive_rating": True,
        "mglt": True,
        "cost_credits": ":,",
        x_column: ":.2f",
    },
    log_y=log_cost,
    labels={x_column: x_label, "cost_credits": "Cost (credits)", "craft_class": "Class"},
)
figure.update_traces(marker={"size": 11})

# Log-linear trend: what each step of speed does to cost.
slope, intercept = np.polyfit(plotted[x_column], np.log10(plotted["cost_credits"]), 1)
xs = np.linspace(plotted[x_column].min(), plotted[x_column].max(), 50)
figure.add_trace(
    go.Scatter(
        x=xs,
        y=10 ** (intercept + slope * xs),
        mode="lines",
        line={"dash": "dash", "color": "grey"},
        name="Trend (log-linear)",
        hoverinfo="skip",
    )
)
figure.update_layout(height=560, margin={"l": 0, "r": 0, "t": 10, "b": 0}, showlegend=False)
st.plotly_chart(figure, width="stretch")

rank_correlation = plotted[x_column].rank().corr(plotted["cost_credits"].rank())
columns = st.columns(2)
columns[0].metric("Starships plotted", f"{len(plotted)} of {len(starships)}")
columns[1].metric(
    "Rank correlation (speed vs cost)",
    f"{rank_correlation:+.2f}",
    help="Spearman: +1 means faster ships always cost more, 0 means no relationship.",
)

if abs(rank_correlation) < 0.3:
    verdict = "Speed explains little of the price."
elif rank_correlation > 0:
    verdict = "Faster ships tend to cost more."
else:
    verdict = (
        "Faster ships tend to be cheaper. Size is the likely confounder: capital ships and the Death Star are "
        "expensive and slow, small fighters are cheap and fast."
    )
st.success(f"{verdict} (n = {len(plotted)}, so treat this as indicative only.)")

st.subheader("Cost by hyperdrive class")
by_class = (
    starships.dropna(subset=["hyperdrive_rating"])
    .groupby("hyperdrive_rating")
    .agg(
        starships=("name", "count"),
        with_cost=("cost_credits", "count"),
        median_cost=("cost_credits", "median"),
        cheapest=("cost_credits", "min"),
        most_expensive=("cost_credits", "max"),
    )
    .reset_index()
    .sort_values("hyperdrive_rating")
)
st.dataframe(
    by_class,
    hide_index=True,
    width="stretch",
    column_config={
        "hyperdrive_rating": "Hyperdrive rating",
        "median_cost": st.column_config.NumberColumn("Median cost", format="%,.0f"),
        "cheapest": st.column_config.NumberColumn("Cheapest", format="%,.0f"),
        "most_expensive": st.column_config.NumberColumn("Most expensive", format="%,.0f"),
    },
)

st.caption(
    f"{missing_cost} of {len(starships)} starships have no cost and {missing_speed} no value for the chosen "
    "speed measure; they are left out, not set to zero. Cost is the SWAPI list price, "
    "and the Death Star's 1 trillion credits is a real value, so use the toggles in the sidebar."
)
