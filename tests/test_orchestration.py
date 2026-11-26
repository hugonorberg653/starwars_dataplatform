import pytest
from dagster import AssetKey

from ingestion.swapi_ingest import RESOURCES
from orchestration.definitions import defs


@pytest.fixture(scope="module")
def graph():
    return defs.resolve_asset_graph()


def test_every_raw_resource_feeds_a_staging_model(graph):
    # Lineage only connects if the raw asset keys equal the dbt source keys.
    upstream_of_staging = {
        key
        for staging_key in graph.get_all_asset_keys()
        if graph.get(staging_key).group_name == "staging"
        for key in graph.get(staging_key).parent_keys
    }
    assert {AssetKey(["raw", resource]) for resource in RESOURCES} <= upstream_of_staging


def test_dbt_tests_are_asset_checks(graph):
    assert len(list(graph.asset_check_keys)) > 0


def test_models_are_grouped_by_layer(graph):
    groups = {graph.get(key).group_name for key in graph.get_all_asset_keys()}
    assert {"raw", "staging", "intermediate", "marts"} <= groups
