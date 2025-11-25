---
title: "Case Studies"
description: "Real-world problems solved"
---

## Case Study 1: Multi-Market Daily Sales Pipeline

**Situation:**

QVC operates across 4 markets (UK, Germany, Italy, Japan), each with different source systems and data formats. The commercial team needed a unified daily sales report comparing actual sales against budget, broken down by market and product category.

Previously, this required an analyst to manually:
1. Extract data from each market's Oracle database
2. Combine in Excel with VLOOKUP gymnastics
3. Add budget data from SharePoint
4. Apply exchange rate conversions
5. Format and distribute by email

This took 4+ hours daily and was error-prone.

**Task:**

Build an automated end-to-end pipeline that:
- Ingests data from all 4 markets
- Joins with budget and exchange rate data
- Produces a unified executive daily sales view
- Publishes to Tableau Server by 7:30 AM

**Action:**

Designed a Dagster job that orchestrates the entire flow:

```python
daily_sales_flow_job = define_asset_job(
    name="daily_sales_flow",
    selection=AssetSelection.keys(
        # Orders from all 4 markets
        "uk_orders_azure", "it_orders_azure",
        "de_orders_azure", "jp_orders_azure",
        # Reference data
        "uk_new_names",
        # Budget and exchange rates from SharePoint
        "daily_sales_budget_exchange_ingest",
        # DBT model for unified view
        "build_daily_sales_models",
        # Tableau publish
        "tableau_executive_daily_sales"
    ),
    tags={"dbt_duckdb": "true"}
)
```

Each market's data flows through:
1. **Azure Blob ingestion** → Parquet files on network storage
2. **DBT staging** → Standardised column names across markets
3. **DBT intermediate** → Currency conversion, metric calculations
4. **DBT mart** → Executive daily sales view with YoY comparisons
5. **Tableau export** → Published to Tableau Server

**Impact:**

| Metric | Before | After |
|--------|--------|-------|
| Time to produce report | 4+ hours | 20 minutes (automated) |
| Data available | ~10 AM | 7:30 AM |
| Error rate | ~2 issues/week | ~1 issue/month |
| Analyst time freed | - | 20 hours/week |

---

## Case Study 2: Configuration-Driven Tableau Exports

**Situation:**

The team had 10+ Tableau exports, each defined as a separate Dagster asset with ~50 lines of nearly identical code. Adding a new export meant:
1. Copy an existing asset
2. Change 5-6 values (table name, project, etc.)
3. Update the job definitions
4. Test and deploy

This took 2-3 hours per export and the codebase was bloated with repetitive code.

**Task:**

Make adding new Tableau exports trivial—ideally a few lines of configuration.

**Action:**

Designed a factory pattern that generates Dagster assets from configuration:

```python
# Before: 50+ lines per export
@asset(deps=["run_int_orderline_attribute"])
def int_orderline_attribute_hyper(context):
    script_path = project_root / 'python' / 'duckdb_to_tableau_server.py'
    cmd = [sys.executable, str(script_path),
           '--tables', 'int_orderline_attribute',
           '--name', 'ORDERLINE_ATTRIBUTES',
           # ... 40 more lines of boilerplate
    ]
    result = subprocess.run(cmd, capture_output=True, check=True)
    # ... error handling, logging, etc.

# After: 5 lines of config
TableauExport(
    name="orderline_attributes",
    source_tables=["int_orderline_attribute"],
    tableau_site="UK",
    tableau_project="Merchandising",
    dbt_asset_deps=["run_int_orderline_attribute"]
)
```

The factory function handles all the boilerplate:

```python
def create_tableau_export_asset(export_config, servers):
    @asset(
        name=f"tableau_{export_config.name}",
        deps=export_config.dbt_asset_deps,
        group_name=export_config.group
    )
    def tableau_export(context):
        # Shared implementation for all exports
        ...
    return tableau_export

# Generate all assets dynamically
tableau_assets = [
    create_tableau_export_asset(config, SERVERS)
    for config in ALL_EXPORTS
]
```

**Impact:**

| Metric | Before | After |
|--------|--------|-------|
| Time to add new export | 2-3 hours | 5 minutes |
| Lines of code per export | ~50 | 5 |
| Risk of copy-paste errors | High | Zero |
| Total codebase reduction | - | ~400 lines removed |

---

## Case Study 3: European CSV Dialect Handling

**Situation:**

Azure Blob Storage receives daily data exports from SAP systems across markets. German and Italian exports use semicolons as delimiters (European standard), while UK uses commas. The ingestion pipeline kept failing randomly on EU files.

Error message: `could not automatically detect CSV parsing dialect`

The failures were inconsistent—same file structure would work one day and fail the next, depending on the data content.

**Task:**

Build robust CSV parsing that handles regional format differences without manual intervention.

**Action:**

Implemented a fallback parsing strategy:

```python
class AzureToParquetPipeline:
    def try_parse_csv(self, azure_path, output_path):
        """Try multiple CSV dialects until one works."""

        fallback_configs = [
            # EU format (German/Italian)
            {'delim': ';', 'quote': '"', 'escape': '"'},
            {'delim': ';', 'strict_mode': False},
            # UK/US format
            {'delim': ',', 'quote': '"', 'escape': '"'},
            # Last resort
            {'delim': ',', 'strict_mode': False},
        ]

        for config in fallback_configs:
            try:
                query = f"""
                    COPY (
                        SELECT *, '{self.market}' AS _market
                        FROM read_csv(
                            '{azure_path}',
                            header=true,
                            delim='{config['delim']}',
                            quote='{config['quote']}',
                            # ... other params
                        )
                    ) TO '{output_path}' (FORMAT PARQUET)
                """
                self.conn.execute(query)
                return True  # Success

            except Exception as e:
                self.log.debug(f"Config {config} failed: {e}")
                continue

        raise ValueError(f"All CSV parsing attempts failed for {azure_path}")
```

Also added encoding detection for Windows-generated files (CP1252 vs UTF-8).

**Impact:**

| Metric | Before | After |
|--------|--------|-------|
| CSV parsing failures | 3-5/week | 0/month |
| Manual intervention needed | Every failure | None |
| Markets supported seamlessly | UK only | All 4 |

---

## Case Study 4: Customer Segmentation Rebuild

**Situation:**

This is where it all started. The Customer Segmentation Dashboard was my first major project at QVC. The original approach:

```
Oracle → SQL Extract → CSV → Python (Pandas/Dask) → CSV → Tableau
```

This took a **full day** to rebuild. My laptop (16GB RAM) crashed regularly when processing 2 years of order data with customer attributes joined.

**Task:**

Rebuild the same analysis using modern tooling, making it reproducible and fast.

**Action:**

The new approach using the MDS:

```
Oracle → Parquet → DBT (int_orderline_attribute) → DuckDB → Tableau
```

The `int_orderline_attribute` model does what my Python script did, but:
- Runs in ~20 minutes instead of a day
- Is version controlled and documented
- Can be run by anyone, not just me
- Automatically refreshes daily

```sql
-- int_orderline_attribute.sql
{{ config(
    materialized='incremental',
    unique_key='order_key',
    incremental_strategy='merge'
) }}

SELECT
    md5(concat_ws(chr(0), market, order_no, line_no)) AS order_key,
    o.market,
    o.order_date,
    o.member_no,
    c.customer_segment,
    p.brand,
    p.category,
    o.quantity,
    o.revenue_gbp
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_customers') }} c
    ON o.market = c.market AND o.member_no = c.member_no
LEFT JOIN {{ ref('stg_products') }} p
    ON o.sku = p.sku
{% if is_incremental() %}
WHERE o.order_date > (SELECT MAX(order_date) - INTERVAL '3 days' FROM {{ this }})
{% endif %}
```

**Impact:**

| Metric | Era 1 (2024) | Era 3 (2025) |
|--------|--------------|--------------|
| Time to rebuild | ~8 hours | ~20 minutes |
| Reproducible | Barely | Always |
| Who can run it | Just me | Anyone on team |
| Documentation | None | Full DBT docs |
| Version controlled | No | Yes |

This single model becoming fast and reliable proved the value of the entire MDS approach.

---

## Themes Across Case Studies

1. **Automation compounds** - Manual processes that seem small add up to hours per week
2. **Configuration > code** - The less code per use case, the fewer bugs and easier maintenance
3. **Resilience matters** - Real-world data is messy; build for the messiness
4. **Show value early** - The customer segmentation rebuild proved the concept before scaling
