import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "dashboard"
DATABASE = ROOT / "data" / "swapi.duckdb"

pytest.importorskip("streamlit")
from streamlit.testing.v1 import AppTest

pytestmark = pytest.mark.skipif(not DATABASE.exists(), reason="needs a built data/swapi.duckdb")


@pytest.fixture(autouse=True)
def dashboard_on_path(monkeypatch):
    monkeypatch.syspath_prepend(str(DASHBOARD))
    yield
    sys.modules.pop("db", None)


@pytest.mark.parametrize("page", ["overview", "planets", "bmi", "starships"])
def test_page_renders_without_error(page):
    app = AppTest.from_file(str(DASHBOARD / "views" / f"{page}.py"), default_timeout=60).run()
    assert not app.exception
    assert not app.error


def test_starships_metrics_for_both_speed_measures():
    app = AppTest.from_file(str(DASHBOARD / "views" / "starships.py"), default_timeout=60).run()
    plotted = {m.label: m.value for m in app.metric}["Starships plotted"]
    assert plotted.endswith("of 36")

    app.radio[0].set_value("MGLT (sublight)").run()
    assert not app.exception
    assert int(app.metric[0].value.split()[0]) > 0
