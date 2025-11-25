---
title: "DBT Transformations"
description: "SQL transformations with medallion architecture"
---
## Overview

100+ DBT models organized in a medallion architecture (staging → intermediate → marts) supporting 4 international markets.

## Model Organization

```
dbt/models/
├── a_staging/           # Raw data views
│   ├── azure/           # Azure Blob sources
│   ├── oracle/          # Oracle database
│   └── business_created/# Manual reference data
│
├── b_intermediate/      # Business logic
│   ├── products/        # Cross-market products
│   ├── customers/       # Segmentation, churn
│   └── legacy/          # Market-specific
│       ├── uk/
│       ├── de/
│       ├── it/
│       └── jp/
│
└── c_marts/             # Final datasets
    ├── commercial/      # Sales, brand analysis
    ├── operational/     # Warehouse metrics
    └── shared/          # Cross-team reports
```

## Key Patterns

### No External Packages

<!-- TODO: Explain corporate network constraints -->
<!-- TODO: Document DuckDB-native alternatives -->

```sql
-- Instead of dbt_utils.surrogate_key
md5(concat_ws(chr(0), market, member_no, order_date)) AS unique_key

-- Instead of dbt_utils.date_spine
SELECT unnest(generate_series(
    DATE '2020-01-01', current_date, INTERVAL '1 day'
)) AS date
```

### Multi-Market Customer Identity

<!-- TODO: Explain overlapping member_no problem -->

```sql
-- Always use composite key
SELECT
  market,
  member_no,
  COUNT(DISTINCT (market, member_no)) AS unique_customers
FROM orders
GROUP BY market, member_no
```

### Incremental Models

<!-- TODO: Document incremental strategy -->

```sql
{{
  config(
    materialized='incremental',
    unique_key='order_key',
    incremental_strategy='merge'
  )
}}

SELECT * FROM {{ ref('stg_orders') }}
{% if is_incremental() %}
WHERE order_date > (SELECT MAX(order_date) - INTERVAL '3 days' FROM {{ this }})
{% endif %}
```

### Source Definitions

<!-- TODO: Explain parquet source pattern -->

```yaml
sources:
  - name: qi_data_lake
    schema: main
    tables:
      - name: uk_ingest_orders
        identifier: "read_parquet('{{ env_var('DBT_SOURCE_PATH') }}/qi_data_lake/UK/ingest_orders/*/*/*.parquet')"
```

## Code References

- [`dbt/models/`](../../dbt/models/) - All model SQL
- [`dbt/macros/`](../../dbt/macros/) - Reusable macros
- [`dbt_project.yml`](../../dbt/dbt_project.yml) - Project configuration
