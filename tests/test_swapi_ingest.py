import json

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


def _snapshot(tmp_path, n=2):
    snap = tmp_path / "snap"
    snap.mkdir()
    for resource in si.RESOURCES:
        records = [{"name": f"{resource}{i}", "url": f"u/{i}/", "films": [f"f/{i}/"]} for i in range(n)]
        (snap / f"{resource}.json").write_text(json.dumps(records))
    return snap


def test_ingest_falls_back_to_snapshot_and_is_idempotent(tmp_path, monkeypatch):
    def unavailable(*_, **__):
        raise si.SwapiUnavailableError("down")

    monkeypatch.setattr(si, "fetch_resource", unavailable)
    db, snap = tmp_path / "t.duckdb", _snapshot(tmp_path)

    for _ in range(2):
        counts = si.ingest(db_path=db, snapshot_dir=snap)
        assert counts == {r: 2 for r in si.RESOURCES}

    with duckdb.connect(str(db)) as con:
        assert con.execute("select count(*) from raw.people").fetchone() == (2,)
        assert con.execute("select distinct _source from raw.people").fetchall() == [("snapshot",)]
        assert con.execute("select typeof(doc) from raw.people limit 1").fetchone() == ("JSON",)
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
        assert con.execute("select doc -> 'new_field' ->> 'x' from raw.people where doc ->> 'name' = 'a'").fetchone() == ("1",)


def test_ingest_writes_snapshot_when_requested(tmp_path, monkeypatch):
    monkeypatch.setattr(si, "fetch_resource", lambda *_, **__: [{"name": "a", "films": []}])
    snap = tmp_path / "snap"
    si.ingest(db_path=tmp_path / "t.duckdb", snapshot_dir=snap, update_snapshot=True)
    assert json.loads((snap / "films.json").read_text()) == [{"name": "a", "films": []}]
