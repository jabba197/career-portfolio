---
title: "Tableau - Business Delivery"
description: "Connecting the data platform to business users"
---

## Why This Matters

A data platform is only as valuable as its ability to deliver insights to decision-makers. This section covers how the MDS integrates with Tableau Server to serve commercial and operational teams.

## The Challenge

<!-- TODO: Describe the gap between data engineering and business consumption -->

Building transformation pipelines is one thing. Getting that data into the hands of analysts and business users in a reliable, automated way is another challenge entirely.

**Questions we had to answer:**

- How do we publish DuckDB tables to Tableau Server automatically?
- How do we manage dependencies between DBT models and Tableau extracts?
- How do we make adding new exports trivial instead of a development project?

## Architecture Decision: Configuration-Driven Exports

<!-- TODO: Explain the evolution from manual to config-driven -->

### The Before State

Each Tableau export was a separate Dagster asset with ~50 lines of boilerplate:

```python
@asset(deps=["run_int_orderline_attribute"])
def int_orderline_attribute_hyper(context):
    script_path = project_root / 'create_hyper_files' / 'duckdb_to_tableau_server.py'
    cmd = [sys.executable, str(script_path), '--tables', 'int_orderline_attribute', ...]
    # ... 40 more lines of error handling, logging, etc.
```

Adding 10 new exports meant writing 500 lines of nearly identical code.

### The After State

A declarative configuration:

```python
TableauExport(
    name="orderline_attributes",
    source_tables=["int_orderline_attribute"],
    tableau_site="UK",
    tableau_project="Merchandising",
    dbt_asset_deps=["run_int_orderline_attribute"]
)
```

An asset factory generates Dagster assets dynamically from config.

### Why This Design?

<!-- TODO: Explain the factory pattern rationale -->

| Consideration | Decision |
|---------------|----------|
| **Scalability** | Config-driven means O(1) effort per new export |
| **Consistency** | Single implementation, no copy-paste drift |
| **Discoverability** | All exports visible in one config file |
| **Flexibility** | Different projects, sites, schedules per export |

## Data Flow: DuckDB to Tableau

```{mermaid}
flowchart LR
    subgraph Dagster
        A[DBT Model Asset] --> B[Tableau Export Asset]
    end

    subgraph Local
        B --> C[Query DuckDB]
        C --> D[Write Parquet]
        D --> E[Convert to Hyper]
    end

    subgraph Tableau
        E --> F[Publish to Server]
        F --> G[Datasource Available]
    end
```

## Export Categories

<!-- TODO: Expand on each category -->

### Commercial Team Exports

| Export | Source | Purpose |
|--------|--------|---------|
| Orderline Attributes | `int_orderline_attribute` | Main commercial analysis dataset |
| Daily Reactivants | `mrt_daily_reactivants` | Customer reactivation tracking |
| Executive Daily Sales | `qi_executive_daily_sales` | C-level performance dashboard |

### Operational Team Exports

| Export | Source | Purpose |
|--------|--------|---------|
| Basket PnP | `mrt_basket_PnP_data` | Pick and pack operations |

### Multi-Market Exports

| Export | Source | Purpose |
|--------|--------|---------|
| Orders Summary Daily | `int_orders_summary_daily` | Cross-market daily aggregates |

## Scheduling Strategy

<!-- TODO: Explain the timing rationale -->

| Schedule | Time | Rationale |
|----------|------|-----------|
| Morning refresh | 7:15 AM | Data ready before business hours |
| Daily sales flow | 3:45 PM | After Azure data lands (~3:15 PM) |

## Lessons Learned

<!-- TODO: Add retrospective insights -->

### What Worked Well

### What We'd Do Differently

## Code References

- [`tableau_exports.py`](../../dagster_automation/dagster_automation/config/tableau_exports.py) - Export configuration
- [`asset_factory.py`](../../dagster_automation/dagster_automation/tableau/asset_factory.py) - Dynamic asset generation
- [`duckdb_to_tableau_server.py`](../../bat_file_data_refresh/python/create_hyper_files/duckdb_to_tableau_server.py) - Publishing script
