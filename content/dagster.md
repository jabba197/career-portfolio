---
title: "Dagster Orchestration"
description: "Asset-based data pipelines and scheduling"
---

## Overview

Dagster serves as the orchestration backbone, managing 50+ assets across ingestion, transformation, and serving layers.

## Key Implementations

### Asset-Based Architecture

<!-- TODO: Explain software-defined assets -->
<!-- Reference: dagster_automation/dagster_automation/assets.py -->

```python
# Example: Azure ingestion asset
@asset(
    description="Sync UK orders from Azure to Parquet",
    group_name="azure_ingestion"
)
def uk_orders_azure(context: AssetExecutionContext):
    result = run_azure_sync("UK", "ingest_orders", force=True)
    context.log.info(f"Synced {result['rows_loaded']:,} rows")
    return result
```

### Custom DBT Translator

<!-- TODO: Document the QVCDbtTranslator -->
<!-- Reference: dagster_automation/dagster_automation/dbt_translator.py -->

Organizes 100+ DBT models into logical groups:
- `dbt_staging_{market}_{source}`
- `dbt_transformations_{market}_{domain}`
- `dbt_marts_{market}_{team}`

### Concurrency Control

<!-- TODO: Explain DuckDB single-process challenge -->

```yaml
# dagster.yaml
run_coordinator:
  config:
    tag_concurrency_limits:
      - key: "dbt_duckdb"
        limit: 1
```

### Configuration-Driven Tableau Exports

<!-- TODO: Detail the factory pattern -->
<!-- Reference: dagster_automation/dagster_automation/tableau/asset_factory.py -->

## Jobs & Schedules

| Job | Schedule | Purpose |
|-----|----------|---------|
| `ingest_azure_qi_job` | 3:15 PM daily | Multi-market orders + reference data |
| `daily_sales_flow_job` | 3:45 PM daily | End-to-end sales pipeline |
| `uk_morning_refresh_with_backup` | 7:15 AM daily | Orderline + brand tool + backup |
| `ingest_scv_job` | 4:00 PM (1st-3rd monthly) | Single Customer View data |

## Code References

- [`definitions.py`](../../dagster_automation/dagster_automation/definitions.py) - Asset registration
- [`assets.py`](../../dagster_automation/dagster_automation/assets.py) - Asset definitions
- [`jobs.py`](../../dagster_automation/dagster_automation/jobs.py) - Job definitions
- [`schedules.py`](../../dagster_automation/dagster_automation/schedules.py) - Schedule definitions
