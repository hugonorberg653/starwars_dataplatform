"""Entry point: streamlit run dashboard/app.py"""

import streamlit as st

st.set_page_config(page_title="SWAPI findings", page_icon=":material/rocket_launch:", layout="wide")

navigation = st.navigation(
    [
        st.Page("views/overview.py", title="Overview", icon=":material/home:", default=True),
        st.Page("views/planets.py", title="Homeworld density", icon=":material/public:"),
        st.Page("views/bmi.py", title="BMI by species", icon=":material/monitor_weight:"),
        st.Page("views/starships.py", title="Starship cost vs speed", icon=":material/speed:"),
        st.Page("views/starship_pilots.py", title="Starship pilots", icon=":material/flight:"),
    ]
)
navigation.run()
