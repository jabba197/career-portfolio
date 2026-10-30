---
title: "dbt"
description: "SQL transformations with medallion architecture"
created: 2025-11-30
modified: 2026-10-30
---

## What dbt Brings

dbt (data build tool) is the transformation layer of the MDS. It turns raw data into analytics-ready datasets through version-controlled SQL.

> [!success] Impact
> About 500 models across 4 markets (October 2026), all version-controlled and tested. In 2025 it was 100+. What was once scattered SQL files and tribal knowledge is now a documented, maintainable codebase that any analyst can contribute to.

**Why dbt matters:**
- **Version control** - Every transformation is tracked in Git
- **Modularity** - Models build on each other with explicit dependencies
- **Testing** - Data quality checks run automatically
- **Documentation** - Schema and descriptions live with the code
- **Collaboration** - Software engineering best practices (branching, PRs, code review) applied to data

Before dbt, transformations lived in scattered SQL files, undocumented Python scripts, and tribal knowledge. Now they're in one place, testable, and self-documenting.

## The Medallion Architecture

Models are organised in layers, each with a clear purpose:

```
dbt/models/
├── a_staging/           # Bronze: Raw → Standardised (~160 models)
│   ├── oracle_uk/       # One folder per source system, source first
│   │   └── refined/     # Curated, typed tables (see below)
│   ├── oracle_de/
│   ├── data_lake_qi/    # The Azure data lake
│   ├── synapse/
│   ├── sap_jp/
│   ├── sas_it/
│   └── business_created/# Manual reference data
│
├── b_intermediate/      # Silver: Standardised → Business Logic (~210 models)
│   ├── orders/
│   ├── products/        # Cross-market product data
│   ├── customers/       # Segmentation, cohorts
│   └── legacy/          # Market-specific transforms
│
└── c_marts/             # Gold: Business Logic → Final Datasets (125 models)
    ├── commercial/      # Sales, brand analysis
    ├── customers/
    ├── operations/
    ├── scorecards/      # Weekly and monthly scorecards
    └── tableau_reporting/
```

In 2025 the staging folders were grouped by how data arrived (`azure/`, `oracle/`). I renamed them after the system the data comes from, because a pipeline or a person is not a source.

### Staging (a_staging)

**Purpose**: Standardise raw data into a consistent format.

- Rename columns to snake_case
- Cast data types explicitly
- Add market identifier
- No business logic - just cleaning

**Refined staging (`stg_ref_*`)** came later. A staging view is cheap to build but re-reads every Parquet file each time it is queried. For the busiest sources I added a second layer: a persisted table with a curated column subset, usually floored to a start date. It is slower to build and fast to query. The two layers are a deliberate contract, and analysis queries go to the refined tables, not the views.

```sql
-- stg_uk_orders.sql
SELECT
    'UK' AS market,
    CAST(order_no AS VARCHAR) AS order_no,
    CAST(order_date AS DATE) AS order_date,
    CAST(member_no AS VARCHAR) AS member_no,
    CAST(revenue AS DECIMAL(10,2)) AS revenue
FROM {{ source('qi_data_lake', 'uk_ingest_orders') }}
```

### Intermediate (b_intermediate)

**Purpose**: Apply business logic and combine data.

- Joins across sources
- Calculations and derivations
- Business rules applied
- Still relatively granular

```sql
-- int_orders_enriched.sql
SELECT
    o.*,
    p.brand,
    p.category,
    c.customer_segment,
    o.revenue * fx.rate AS revenue_gbp
FROM {{ ref('stg_uk_orders') }} o
LEFT JOIN {{ ref('stg_products') }} p ON o.sku = p.sku
LEFT JOIN {{ ref('stg_customers') }} c ON o.member_no = c.member_no
LEFT JOIN {{ ref('stg_exchange_rates') }} fx ON o.order_date = fx.date
```

### Marts (c_marts)

**Purpose**: Final datasets optimised for consumption.

- Aggregated to the grain needed
- Pre-calculated metrics
- Ready for dashboards and reports
- Persisted as tables for performance

```sql
-- mrt_daily_sales.sql
SELECT
    order_date,
    market,
    brand,
    SUM(revenue_gbp) AS total_revenue,
    COUNT(DISTINCT member_no) AS unique_customers,
    COUNT(*) AS order_count
FROM {{ ref('int_orders_enriched') }}
GROUP BY order_date, market, brand
```

## How Models Connect

dbt builds a dependency graph using `ref()`:

```sql
-- This model depends on stg_orders
SELECT * FROM {{ ref('stg_orders') }}
```

When you run a model, dbt automatically runs its dependencies first. The graph looks like:

```mermaid
flowchart LR
    subgraph Staging
        stg_orders[stg_orders]
        stg_products[stg_products]
        stg_customers[stg_customers]
    end

    subgraph Intermediate
        int_enriched[int_orders_enriched]
    end

    subgraph Marts
        mrt_sales[mrt_daily_sales]
    end

    stg_orders --> int_enriched
    stg_products --> int_enriched
    stg_customers --> int_enriched
    int_enriched --> mrt_sales
```

## Testing

dbt tests validate data quality:

```yaml
# schema.yml
models:
  - name: stg_uk_orders
    columns:
      - name: order_no
        tests:
          - not_null
          - unique
      - name: order_date
        tests:
          - not_null
      - name: revenue
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 100000
```

Tests run after models build. Failures alert us to data quality issues before they reach downstream data products.

**Common test patterns:**
- `unique` - No duplicate keys
- `not_null` - Required fields are populated
- `accepted_values` - Enums match expected values
- `relationships` - Foreign keys exist in parent table

### Test packages (2026)

For a long time the project used no dbt packages, because the corporate proxy blocked the package hub. In August 2026 I wrote a small installer that works with the proxy's certificates without turning verification off, and added `dbt_expectations` and `dbt_utils` for their tests. I still use DuckDB's own SQL for anything that generates SQL.

- **Generic tests first.** A generic test sits in the YAML next to the column it guards, so it cannot drift away from it. Composite grains use `dbt_utils.unique_combination_of_columns`; ranges, freshness, volume floors and gap checks use `dbt_expectations`.
- **Singular tests for business logic only.** About 50 bespoke tests check things a generic test cannot, such as currency conversion being neutral in year-on-year comparisons.
- **Severity has a meaning.** `error` means the data is wrong; `warn` means it is late or unusual. Thresholds are tuned against history so that none fire on good data, because noisy tests get ignored.

## Documentation

Every model and column can be documented inline:

```yaml
# schema.yml
models:
  - name: mrt_daily_sales
    description: "Daily sales aggregated by market and brand. Refreshed daily at 7:30 AM."
    columns:
      - name: total_revenue
        description: "Sum of revenue in GBP, converted at daily exchange rate"
      - name: unique_customers
        description: "Count of distinct member_no values"
```

Generate documentation site:
```bash
dbt docs generate
dbt docs serve
```

This creates a browsable site with lineage graphs, column descriptions, and test results.

**Documentation is part of the build.** A model change is not finished until its description, grain and grain test are updated in the same commit. Published marts also carry a header that says where they publish. Shared columns, such as market and customer number, use one docs block instead of a description retyped in every model.

## Multi-Market Support

The MDS serves 4 markets: UK, Germany, Italy, Japan. Models handle this through:

**1. Market-specific staging models:**
```
stg_uk_orders.sql
stg_de_orders.sql
stg_it_orders.sql
stg_jp_orders.sql
```

**2. Union models for cross-market analysis:**
```sql
-- stg_all_orders.sql
SELECT * FROM {{ ref('stg_uk_orders') }}
UNION ALL
SELECT * FROM {{ ref('stg_de_orders') }}
UNION ALL
SELECT * FROM {{ ref('stg_it_orders') }}
UNION ALL
SELECT * FROM {{ ref('stg_jp_orders') }}
```

**3. Market column in every model:**
```sql
SELECT
    'UK' AS market,
    order_no,
    ...
```

See [[dbt-duckdb#Multi-Market Identity]] for the critical rule about composite keys.

## Running dbt

```bash
# Run all models
dbt run

# Run specific model and its dependencies
dbt run --select +mrt_daily_sales

# Run model and everything downstream
dbt run --select stg_orders+

# Run tests
dbt test

# Generate docs
dbt docs generate && dbt docs serve
```

In the MDS, every build goes through a small wrapper script rather than bare `dbt`. The wrapper records each run to a local run-history database: who ran it, the selection, per-model timing and status. That makes "which model got slow?" a query. Scheduled builds are started by the daily Python jobs (by [[dagster|Dagster]] until May 2026).

Before a build that touches more than a few models, I check whether upstream tables were already refreshed today and build only what changed. A careless `+model` selector rebuilds every expensive upstream table too, and on one desktop that competes with everything else.

## Related

- [[dbt-duckdb]] — Technical reference for dbt on DuckDB
- [[duckdb]] — Why DuckDB is the foundation
- [[dagster]] — How dbt runs were orchestrated until May 2026, and what replaced it
- [[stack/index|The Stack]] — Where dbt fits in the overall system
- [[case-studies#Case Study 4 Customer Segmentation Rebuild|Customer Segmentation rebuild]] — dbt replacing manual Python
