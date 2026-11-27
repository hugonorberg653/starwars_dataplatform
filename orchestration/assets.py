"""Dagster assets: raw SWAPI ingestion plus every dbt model, test and source."""

from collections.abc import Mapping
from pathlib import Path
from typing import Any

from dagster import AssetExecutionContext, AssetKey, AssetSpec, MaterializeResult, multi_asset
from dagster_dbt import DagsterDbtTranslator, DbtCliResource, DbtProject, dbt_assets

from ingestion.swapi_ingest import RESOURCES, ingest_from_env

DBT_PROJECT_DIR = Path(__file__).resolve().parent.parent / "dbt_project"

dbt_project = DbtProject(project_dir=DBT_PROJECT_DIR, profiles_dir=DBT_PROJECT_DIR)
# Writes target/manifest.json when running under `dagster dev`; elsewhere it must already exist.
dbt_project.prepare_if_dev()

# Keys match the default dagster-dbt key for dbt source `raw.<resource>`, which links ingestion to dbt.
RAW_KEYS = {resource: AssetKey(["raw", resource]) for resource in RESOURCES}


@multi_asset(
    specs=[
        AssetSpec(key, group_name="raw", description=f"SWAPI `{resource}` loaded as-is into raw.{resource}.")
        for resource, key in RAW_KEYS.items()
    ],
    # All resources are fetched and loaded in one transaction, so they cannot be materialized separately.
    can_subset=False,
)
def raw_swapi(context: AssetExecutionContext):
    counts = ingest_from_env()
    for resource, key in RAW_KEYS.items():
        context.log.info("raw.%s: %d rows", resource, counts[resource])
        yield MaterializeResult(asset_key=key, metadata={"row_count": counts[resource]})


class SwapiDbtTranslator(DagsterDbtTranslator):
    def get_group_name(self, dbt_resource_props: Mapping[str, Any]) -> str | None:
        # fqn is [project, layer, ..., model]; group by layer (staging, marts).
        fqn = dbt_resource_props.get("fqn", [])
        return fqn[1] if len(fqn) > 2 else super().get_group_name(dbt_resource_props)


@dbt_assets(manifest=dbt_project.manifest_path, dagster_dbt_translator=SwapiDbtTranslator())
def swapi_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    # `build` runs models and tests; dbt tests are reported as Dagster asset checks.
    yield from dbt.cli(["build"], context=context).stream()
