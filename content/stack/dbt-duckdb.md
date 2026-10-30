---
title: "dbt-duckdb"
description: "Technical reference for running dbt with DuckDB"
created: 2025-11-30
modified: 2026-10-30
---

## Overview

This is the technical reference for how [[dbt]] and [[duckdb|DuckDB]] work together in the MDS — patterns, gotchas, and DuckDB-native SQL that replaces common dbt packages.

For the story of why we chose DuckDB, see [[duckdb]]. For dbt architecture and model organisation, see [[dbt]].

## Why No External Packages (until August 2026)

Corporate network restrictions block `pip install` for external packages. SSL certificate errors and proxy settings add complexity to package management. Working within these constraints, we adopted a "no external packages" policy.

This meant no `dbt-utils`, no `dbt-expectations`, no community packages.

**The upside**: DuckDB's native SQL is powerful enough that we don't miss them for SQL generation. The resulting code is simpler and has fewer external dependencies.

### What Changed in 2026

Plain `dbt deps` still cannot reach the package hub from this machine: the proxy re-signs TLS traffic, and newer Python versions apply stricter certificate checks. In August 2026 I wrote a small installer that handles both without turning certificate verification off, and installed `dbt_expectations` and `dbt_utils`. Exact versions are pinned in a committed lock file, and everyday `dbt run` and `dbt test` need no network.

The split is deliberate: **packages for tests, DuckDB for SQL.** The native alternatives below are still the house style for model code.

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
        identifier: "read_parquet('{{ env_var('DBT_SOURCE_PATH') }}/qi_data_lake/UK/ingest_orders/*/*/*.parquet', hive_partitioning=true)"
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
| Refined staging (`stg_ref_*`) | Table | Curated columns, cheap to query |
| Intermediate | View (default) | Recomputes from source each time; heavy models are set to table |
| Marts | Table | Persisted for fast dashboard queries |

Views mean most staging and intermediate models don't consume disk space. The catch: a view over Parquet re-reads every file on each query. As the platform grew, I added persisted refined tables for the busiest sources, and analysis queries go there instead of to the views.

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
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [market, member_no, order_no]
```

(Before the test packages arrived, I used `unique` on a concatenated string, `market || '_' || member_no || '_' || order_no`. The combination test is clearer and cannot be fooled by a separator inside a value.)

## Concurrency (One Writer at a Time)

DuckDB is single-process - only one connection can write at a time. When several jobs build dbt models at once, they compete for the lock.

**2025: tag-based limits in Dagster.**

```yaml
# dagster.yaml
run_coordinator:
  config:
    tag_concurrency_limits:
      - key: "dbt_duckdb"
        limit: 1
```

Every dbt-related asset was tagged:

```python
@asset(
    name="build_daily_sales_models",
    op_tags={"dbt_duckdb": "true"}
)
def build_daily_sales_models(context):
    # dbt operations here
```

Dagster ensured only one DuckDB write operation ran at a time.

**Since May 2026: plain jobs that wait.** With Dagster retired, the scheduled jobs are spaced through the day, a task cannot start a second copy of itself, and a job that finds the database locked polls until it is free instead of failing. Reads use a separate read-only query broker that queues behind a write lock and reports who holds it.

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
- [[challenges#Challenge 3 Corporate Network Restrictions|Network restrictions]] - Why packages were off-limits until 2026
