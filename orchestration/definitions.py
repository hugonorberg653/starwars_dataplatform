"""Dagster entry point.

Run the whole pipeline once:   dagster job execute -m orchestration.definitions -j swapi_full_refresh
Open the UI with the daemon:   dagster dev -m orchestration.definitions
"""

import shutil
import sys
from pathlib import Path

from dagster import (
    AssetSelection,
    DefaultScheduleStatus,
    Definitions,
    ScheduleDefinition,
    define_asset_job,
    in_process_executor,
)
from dagster_dbt import DbtCliResource

from orchestration.assets import dbt_project, raw_swapi, swapi_dbt_assets

# DuckDB allows one writer, so steps run one at a time in the launching process.
swapi_full_refresh = define_asset_job(
    "swapi_full_refresh",
    selection=AssetSelection.all(),
    executor_def=in_process_executor,
    description="Ingest SWAPI into DuckDB, then `dbt build` every model and test.",
)

daily_refresh = ScheduleDefinition(
    job=swapi_full_refresh,
    cron_schedule="0 6 * * *",
    default_status=DefaultScheduleStatus.RUNNING,
)

# Use the dbt installed next to this interpreter, never whichever `dbt` is first on PATH:
# a global install bundles a different DuckDB and cannot read the file the venv wrote.
DBT_EXECUTABLE = shutil.which("dbt", path=str(Path(sys.executable).parent)) or "dbt"

defs = Definitions(
    assets=[raw_swapi, swapi_dbt_assets],
    jobs=[swapi_full_refresh],
    schedules=[daily_refresh],
    resources={"dbt": DbtCliResource(project_dir=dbt_project, dbt_executable=DBT_EXECUTABLE)},
)
