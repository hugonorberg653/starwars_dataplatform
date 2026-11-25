"""Read-only access to the marts for the dashboard pages."""

import os
from pathlib import Path

import duckdb
import pandas as pd
import streamlit as st

DEFAULT_DB_PATH = Path(__file__).resolve().parents[1] / "data" / "swapi.duckdb"


def db_path() -> Path:
    return Path(os.environ.get("DUCKDB_PATH", DEFAULT_DB_PATH))


@st.cache_data(ttl=300, show_spinner=False)
def query(sql: str) -> pd.DataFrame:
    # Open and close per query so the file is not left locked for `dbt build`.
    with duckdb.connect(str(db_path()), read_only=True) as con:
        return con.sql(sql).df()


def require_database() -> None:
    if not db_path().exists():
        st.error(f"DuckDB file not found at `{db_path()}`. Run the ingestion and `dbt build` first.")
        st.stop()
