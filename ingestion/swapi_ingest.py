"""Ingest SWAPI resources into the DuckDB ``raw`` schema.

Raw JSON is loaded as-is (ELT): one table per resource with the whole record in a
JSON ``doc`` column, plus ``_loaded_at`` and ``_source`` metadata columns, so API
schema changes never break the load. Every run fully refreshes the raw tables, so it is
idempotent. If the API is unreachable, the committed snapshot in
``data/snapshot/`` is used instead.

Usage:
    python -m ingestion.swapi_ingest                    # API, snapshot fallback
    python -m ingestion.swapi_ingest --update-snapshot  # also rewrite the snapshot
"""

from __future__ import annotations

import argparse
import json
import logging
import os
from pathlib import Path

import duckdb
import requests
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger("swapi_ingest")

RESOURCES = ("people", "planets", "films", "species", "vehicles", "starships")

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASE_URL = "https://swapi.dev/api"
DEFAULT_DB_PATH = REPO_ROOT / "data" / "swapi.duckdb"
DEFAULT_SNAPSHOT_DIR = REPO_ROOT / "data" / "snapshot"
REQUEST_TIMEOUT_SECONDS = 30
MAX_PAGES = 100  # guard against a pagination loop


class SwapiUnavailableError(RuntimeError):
    """Raised when a resource cannot be fetched from the API."""


@retry(
    retry=retry_if_exception_type(requests.RequestException),
    stop=stop_after_attempt(4),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def _get_json(session: requests.Session, url: str, verify: bool) -> dict | list:
    response = session.get(url, timeout=REQUEST_TIMEOUT_SECONDS, verify=verify)
    response.raise_for_status()
    return response.json()


def fetch_resource(
    base_url: str, resource: str, session: requests.Session | None = None, verify: bool = True
) -> list[dict]:
    """Fetch all records of a resource.

    Supports the paginated ``{"results": [...], "next": url}`` shape (swapi.dev)
    and a bare JSON array (swapi.info).
    """
    session = session or requests.Session()
    url: str | None = f"{base_url.rstrip('/')}/{resource}/"
    records: list[dict] = []
    seen: set[str] = set()
    try:
        while url:
            if url in seen or len(seen) >= MAX_PAGES:
                raise SwapiUnavailableError(f"Pagination loop detected for {resource}")
            seen.add(url)
            payload = _get_json(session, url, verify)
            if isinstance(payload, list):
                records.extend(payload)
                url = None
            else:
                records.extend(payload["results"])
                url = payload.get("next")
    except (requests.RequestException, KeyError, ValueError) as exc:
        raise SwapiUnavailableError(f"Failed to fetch {resource} from {base_url}: {exc}") from exc
    if not records:
        raise SwapiUnavailableError(f"No records returned for {resource} from {base_url}")
    return records


def read_snapshot(snapshot_dir: Path, resource: str) -> list[dict]:
    path = snapshot_dir / f"{resource}.json"
    if not path.exists():
        raise FileNotFoundError(f"No snapshot for {resource} at {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def write_snapshot(snapshot_dir: Path, resource: str, records: list[dict]) -> None:
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    path = snapshot_dir / f"{resource}.json"
    path.write_text(json.dumps(records, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_raw_table(con: duckdb.DuckDBPyConnection, resource: str, records: list[dict], source: str) -> int:
    """Replace ``raw.<resource>`` with one row per record: the whole record as a JSON ``doc``."""
    con.execute("begin")
    try:
        con.execute(
            f"""
            create or replace table raw.{resource} (
                doc json,
                _loaded_at timestamptz,
                _source varchar
            )
            """
        )
        con.executemany(
            f"insert into raw.{resource} values (?, current_timestamp, ?)",
            [[json.dumps(record, ensure_ascii=False), source] for record in records],
        )
        con.execute("commit")
    except Exception:
        con.execute("rollback")
        raise
    return len(records)


def ingest(
    base_url: str = DEFAULT_BASE_URL,
    db_path: Path = DEFAULT_DB_PATH,
    snapshot_dir: Path = DEFAULT_SNAPSHOT_DIR,
    update_snapshot: bool = False,
    verify_ssl: bool = True,
) -> dict[str, int]:
    """Load every resource into DuckDB and return the row count per resource."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    counts: dict[str, int] = {}
    with requests.Session() as session, duckdb.connect(str(db_path)) as con:
        con.execute("create schema if not exists raw")
        api_available = True
        for resource in RESOURCES:
            records, source = [], "snapshot"
            if api_available:
                try:
                    records = fetch_resource(base_url, resource, session, verify_ssl)
                    source = base_url
                    if update_snapshot:
                        write_snapshot(snapshot_dir, resource, records)
                except SwapiUnavailableError as exc:
                    # Skip the API for the remaining resources instead of retrying each one.
                    api_available = False
                    logger.warning("%s; falling back to snapshot in %s", exc, snapshot_dir)
            if source == "snapshot":
                records = read_snapshot(snapshot_dir, resource)
            counts[resource] = load_raw_table(con, resource, records, source)
            logger.info("raw.%s: %d rows (source: %s)", resource, counts[resource], source)
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--update-snapshot", action="store_true", help="rewrite data/snapshot from the API")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    ingest(
        base_url=os.getenv("SWAPI_BASE_URL", DEFAULT_BASE_URL),
        db_path=Path(os.getenv("DUCKDB_PATH", DEFAULT_DB_PATH)),
        snapshot_dir=Path(os.getenv("SWAPI_SNAPSHOT_DIR", DEFAULT_SNAPSHOT_DIR)),
        update_snapshot=args.update_snapshot,
        verify_ssl=os.getenv("SWAPI_VERIFY_SSL", "true").lower() != "false",
    )


if __name__ == "__main__":
    main()
