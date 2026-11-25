import duckdb
import pytest
import requests

from ingestion import swapi_ingest as si


class FakeResponse:
    def __init__(self, payload, status=200):
        self._payload, self.status_code = payload, status

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"{self.status_code}")

    def json(self):
        return self._payload


class FakeSession:
    def __init__(self, pages):
        self.pages, self.calls = pages, []

    def get(self, url, **_):
        self.calls.append(url)
        return FakeResponse(self.pages[url])


@pytest.fixture(autouse=True)
def no_retry_wait(monkeypatch):
    monkeypatch.setattr(si._get_json.retry, "wait", lambda *_: 0)


def test_fetch_follows_pagination():
    base = "https://x/api"
    session = FakeSession(
        {
            f"{base}/people/": {"results": [{"name": "a"}], "next": f"{base}/people/?page=2"},
            f"{base}/people/?page=2": {"results": [{"name": "b"}], "next": None},
        }
    )
    assert si.fetch_resource(base, "people", session) == [{"name": "a"}, {"name": "b"}]


def test_fetch_supports_bare_list():
    session = FakeSession({"https://x/api/people/": [{"name": "a"}]})
    assert si.fetch_resource("https://x/api", "people", session) == [{"name": "a"}]


def test_fetch_wraps_failures_after_retries():
    class Failing:
        calls = 0

        def get(self, *_, **__):
            Failing.calls += 1
            raise requests.ConnectionError("down")

    with pytest.raises(si.SwapiUnavailableError):
        si.fetch_resource("https://x/api", "people", Failing())
    assert Failing.calls == 4


def _fake_fetch(n=2):
    return lambda base, resource, *_, **__: [
        {"name": f"{resource}{i}", "url": f"u/{i}/", "films": [f"f/{i}/"]} for i in range(n)
    ]


def test_ingest_loads_from_api_and_is_idempotent(tmp_path, monkeypatch):
    monkeypatch.setattr(si, "fetch_resource", _fake_fetch())
    db = tmp_path / "t.duckdb"

    for _ in range(2):
        counts = si.ingest(base_url="https://x/api", db_path=db)
        assert counts == {r: 2 for r in si.RESOURCES}

    with duckdb.connect(str(db)) as con:
        assert con.execute("select count(*) from raw.people").fetchone() == (2,)
        assert con.execute("select distinct _source from raw.people").fetchall() == [("https://x/api",)]
        assert con.execute("select typeof(doc) from raw.people limit 1").fetchone() == ("JSON",)
        assert con.execute("select doc ->> 'name' from raw.people order by 1").fetchall() == [
            ("people0",),
            ("people1",),
        ]


def test_ingest_failure_keeps_previous_raw_tables(tmp_path, monkeypatch):
    db = tmp_path / "t.duckdb"
    monkeypatch.setattr(si, "fetch_resource", _fake_fetch())
    si.ingest(db_path=db)

    def fail_on_last(base, resource, *_, **__):
        if resource == si.RESOURCES[-1]:
            raise si.SwapiUnavailableError("down")
        return [{"name": "new"}]

    monkeypatch.setattr(si, "fetch_resource", fail_on_last)
    with pytest.raises(si.SwapiUnavailableError):
        si.ingest(db_path=db)

    with duckdb.connect(str(db)) as con:
        assert con.execute("select doc ->> 'name' from raw.people order by 1").fetchall() == [
            ("people0",),
            ("people1",),
        ]


def test_load_keeps_unexpected_fields_and_types(tmp_path):
    records = [{"name": "a", "height": 172, "new_field": {"x": 1}}, {"name": "b", "height": "unknown"}]
    with duckdb.connect(str(tmp_path / "t.duckdb")) as con:
        con.execute("create schema raw")
        assert si.load_raw_table(con, "people", records, "src") == 2
        assert con.execute("select doc ->> 'height' from raw.people order by doc ->> 'name'").fetchall() == [
            ("172",),
            ("unknown",),
        ]
        assert con.execute(
            "select doc -> 'new_field' ->> 'x' from raw.people where doc ->> 'name' = 'a'"
        ).fetchone() == ("1",)
