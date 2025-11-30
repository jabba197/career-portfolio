---
title: "dbt-duckdb"
description: "Technical reference for running dbt with DuckDB"
---

## Overview

This is the technical reference for how [[dbt]] and [[duckdb|DuckDB]] work together in the MDS — patterns, gotchas, and DuckDB-native SQL that replaces common dbt packages.

For the story of why we chose DuckDB, see [[duckdb]]. For dbt architecture and model organisation, see [[dbt]].

## Why No External Packages

Corporate network restrictions block `pip install` for external packages. SSL certificate errors and proxy settings add complexity to package management. Working within these constraints, we adopted a "no external packages" policy.

This means no `dbt-utils`, no `dbt-expectations`, no community packages.

**The upside**: DuckDB's native SQL is powerful enough that we don't miss them. The resulting code is simpler and has zero external dependencies.

## DuckDB Alternatives to dbt_utils

### Date Spines

```sql
-- Instead of dbt_utils.date_spine
SELECT unnest(generate_series(
    DATE '2020-01-01',
    current_date,
    INTERVAL '1 day'
)) AS calendar_date
```

No need to maintain a separate calendar table. Generate it on the fly.

### Pivot Tables

```sql
-- Instead of dbt_utils.pivot
PIVOT sales_data ON market USING SUM(revenue)
```

DuckDB has native `PIVOT` syntax - cleaner than the macro approach.

### Safe Divide

```sql
-- Instead of dbt_utils.safe_divide
CASE WHEN denominator = 0 THEN NULL ELSE numerator / denominator END
```

Or use DuckDB's `try_divide()` function.

## Schema Strategy

Two schemas separate raw data from transformations:

```
main_qi_data_lake/     # Source data (Parquet files read as tables)
├── uk_ingest_orders
├── de_ingest_orders
├── it_ingest_orders
└── jp_ingest_orders

main/                  # All dbt transformations
├── stg_*              # Staging views
├── int_*              # Intermediate views
└── mrt_*              # Mart tables
```

**Why this separation:**
- Clear boundary between "raw" and "transformed"
- dbt sources point to `main_qi_data_lake`
- dbt models materialise in `main`
- Easy lineage tracing

## Parquet Source Definitions

dbt sources can read Parquet files directly using DuckDB's `read_parquet()`:

```yaml
# schema.yml
sources:
  - name: qi_data_lake
    schema: main_qi_data_lake
    tables:
      - name: uk_ingest_orders
        identifier: "read_parquet('{{ env_var('DBT_SOURCE_PATH') }}/qi_data_lake/UK/ingest_orders/*/*/*.parquet')"
```

**Key options:**
- `hive_partitioning=true` - read year/month folders as columns
- `union_by_name=true` - handle schema evolution across files

```sql
-- In a staging model
SELECT * FROM read_parquet(
    '{{ env_var("DBT_SOURCE_PATH") }}/qi_data_lake/UK/orders/*/*/*.parquet',
    hive_partitioning=true,
    union_by_name=true
)
```

## Materialisation Strategy

| Layer | Materialisation | Why |
|-------|-----------------|-----|
| Staging | View | No storage cost, always fresh |
| Intermediate | View | Recomputes from source each time |
| Marts | Table | Persisted for fast dashboard queries |

Views mean staging and intermediate layers don't consume disk space. Only the final marts are stored.

```sql
-- Staging model
{{ config(materialized='view') }}

SELECT
    market,
    order_no,
    CAST(order_date AS DATE) AS order_date
FROM {{ source('qi_data_lake', 'uk_ingest_orders') }}
```

```sql
-- Mart model
{{ config(materialized='table') }}

SELECT * FROM {{ ref('int_orders_enriched') }}
```

## Incremental Models

For high-volume tables, use incremental materialisation with merge strategy:

```sql
{{
  config(
    materialized='incremental',
    unique_key='order_key',
    incremental_strategy='merge'
  )
}}

SELECT
    md5(concat_ws(chr(0), market, order_no, line_no)) AS order_key,
    *
FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
WHERE order_date > (SELECT MAX(order_date) - INTERVAL '3 days' FROM {{ this }})
{% endif %}
```

**The 3-day lookback**: Orders can be updated retroactively (returns, adjustments). Looking back 3 days catches most updates while keeping the incremental window small.

## Multi-Market Identity

Customer IDs (`member_no`) overlap between markets. A UK customer 12345 is a different person from a German customer 12345.

**Rule**: Always use composite keys `(market, member_no)`:

```sql
-- Correct: composite key
SELECT
    market,
    member_no,
    COUNT(*) AS order_count
FROM orders
GROUP BY market, member_no

-- Wrong: will mix customers across markets
SELECT
    member_no,
    COUNT(*) AS order_count
FROM orders
GROUP BY member_no
```

**Enforce with tests:**

```yaml
# schema.yml
models:
  - name: fct_orders
    tests:
      - unique:
          column_name: "market || '_' || member_no || '_' || order_no"
```

## Concurrency with Dagster

DuckDB is single-process - only one connection can write at a time. When Dagster runs multiple dbt jobs concurrently, they compete for locks.

**Solution**: Tag-based concurrency limits:

```yaml
# dagster.yaml
run_coordinator:
  config:
    tag_concurrency_limits:
      - key: "dbt_duckdb"
        limit: 1
```

Every dbt-related asset gets tagged:

```python
@asset(
    name="build_daily_sales_models",
    op_tags={"dbt_duckdb": "true"}
)
def build_daily_sales_models(context):
    # dbt operations here
```

Dagster ensures only one DuckDB write operation runs at a time.

## DuckDB-Specific SQL Patterns

### Direct Parquet Reads

Query Parquet files without loading:

```sql
SELECT * FROM read_parquet(
    '/path/to/qi_data_lake/UK/orders/*/*/*.parquet',
    hive_partitioning=true,
    union_by_name=true
)
```

### Window Functions

DuckDB handles these efficiently:

```sql
SELECT
    member_no,
    order_date,
    SUM(revenue) OVER (
        PARTITION BY member_no
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM orders
```

### List Aggregation

```sql
SELECT
    member_no,
    LIST(DISTINCT category) AS categories_purchased
FROM orders
GROUP BY member_no
```

### Struct Types

```sql
SELECT
    member_no,
    {'first': first_order_date, 'last': last_order_date} AS order_range
FROM customer_summary
```

## Related

- [[duckdb]] - Why DuckDB was the right choice (the story)
- [[dbt]] - Transformation architecture and model organisation
- [[challenges#Challenge 1 DuckDB Concurrency in Orchestration|Concurrency challenge]] - More on the single-process limitation
- [[challenges#Challenge 3 Corporate Network Restrictions|Network restrictions]] - Why we can't use external packages
