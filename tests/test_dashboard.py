import json
import sys
from pathlib import Path

import duckdb
import pytest

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "dashboard"
DATABASE = ROOT / "data" / "swapi.duckdb"

pytest.importorskip("streamlit")
from streamlit.testing.v1 import AppTest

needs_database = pytest.mark.skipif(not DATABASE.exists(), reason="needs a built data/swapi.duckdb")


@pytest.fixture(autouse=True)
def dashboard_on_path(monkeypatch):
    monkeypatch.syspath_prepend(str(DASHBOARD))
    yield
    sys.modules.pop("db", None)


@needs_database
@pytest.mark.parametrize("page", ["overview", "planets", "bmi", "starships", "starship_pilots"])
def test_page_renders_without_error(page):
    app = AppTest.from_file(str(DASHBOARD / "views" / f"{page}.py"), default_timeout=60).run()
    assert not app.exception
    assert not app.error


@needs_database
def test_starships_metrics_for_both_speed_measures():
    app = AppTest.from_file(str(DASHBOARD / "views" / "starships.py"), default_timeout=60).run()
    plotted = {m.label: m.value for m in app.metric}["Starships plotted"]
    assert plotted.endswith("of 36")

    app.radio[0].set_value("MGLT (sublight)").run()
    assert not app.exception
    assert int(app.metric[0].value.split()[0]) > 0


def test_starship_pilot_view_filters_rankings_and_unrecorded_ships(tmp_path, monkeypatch):
    database = tmp_path / "pilots.duckdb"
    with duckdb.connect(str(database)) as con:
        con.execute("create schema reporting")
        con.execute(
            """
            create table reporting.rpt_starship_pilots (
                craft_key varchar, name varchar, craft_class varchar, cost_credits bigint,
                length_m double, crew_max integer, pilot_count bigint, pilot_names varchar
            )
            """
        )
        con.execute(
            """
            insert into reporting.rpt_starship_pilots values
                ('s1', 'Alpha', 'fighter', 100, 10, 1, 2, 'Ada, Bob'),
                ('s2', 'Ghost', 'fighter', null, null, null, 0, null),
                ('s3', 'Sailor', 'yacht', 200, 20, 2, 1, 'Ada'),
                ('s4', 'Capital', 'capital ship', null, 200, 100, 0, null)
            """
        )
        con.execute(
            """
            create table reporting.rpt_starship_pilot_counts (
                character_id integer, name varchar, craft_class varchar, all_classes boolean,
                starship_count bigint, starship_names varchar
            )
            """
        )
        con.execute(
            """
            insert into reporting.rpt_starship_pilot_counts values
                (1, 'Ada', null, true, 2, 'Alpha, Sailor'),
                (1, 'Ada', 'fighter', false, 1, 'Alpha'),
                (1, 'Ada', 'yacht', false, 1, 'Sailor'),
                (2, 'Bob', null, true, 1, 'Alpha'),
                (2, 'Bob', 'fighter', false, 1, 'Alpha')
            """
        )
    monkeypatch.setenv("DUCKDB_PATH", str(database))
    from db import query

    query.clear()
    app = AppTest.from_file(str(DASHBOARD / "views" / "starship_pilots.py"), default_timeout=60).run()
    assert not app.exception
    assert [metric.value for metric in app.metric] == ["4", "2", "2"]
    pilot_chart = json.loads(app.get("plotly_chart")[1].proto.spec)
    pilot_classes = {trace["name"]: trace["customdata"] for trace in pilot_chart["data"]}
    assert ["Ada", "Alpha"] in pilot_classes["fighter"]
    assert ["Ada", "Sailor"] in pilot_classes["yacht"]

    app.selectbox[0].set_value("fighter").run()
    assert not app.exception
    assert [metric.value for metric in app.metric] == ["2", "1", "2"]
    assert app.dataframe[0].value["name"].tolist() == ["Ghost"]
    pilot_chart = json.loads(app.get("plotly_chart")[1].proto.spec)
    assert [trace["name"] for trace in pilot_chart["data"]] == ["fighter"]
    assert ["Ada", "Alpha"] in pilot_chart["data"][0]["customdata"]

    app.selectbox[0].set_value("capital ship").run()
    assert not app.exception
    assert [metric.value for metric in app.metric] == ["1", "0", "0"]
    assert len(app.get("plotly_chart")) == 0
    assert app.dataframe[0].value["name"].tolist() == ["Capital"]
    query.clear()
