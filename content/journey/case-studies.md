---
title: "Case Studies"
description: "Real-world problems solved"
created: 2025-11-30
modified: 2026-10-30
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

Designed a Dagster job (2025) that orchestrates the entire flow:

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

**2026 update:** when I retired Dagster in May 2026, this flow became a plain Python job with the same steps as numbered phases. Each phase retries, and a failed run resumes from the phase that broke. The steps did not change, which is the point: the business logic lived in dbt and the scripts, not in the orchestrator.

---

## Case Study 2: Flag-Based Tableau Exports

**Situation:**

The team had 10+ [[tableau|Tableau]] exports, each defined as a separate [[dagster|Dagster]] asset with ~50 lines of nearly identical code. Each asset handled:
- DuckDB connection and query
- Parquet export
- Hyper file conversion
- Tableau Server authentication
- Publishing and error handling

Adding a new export meant copying an existing asset, changing a few values, and hoping you didn't introduce bugs. The codebase was bloated with repetitive logic.

**Task:**

Make adding new Tableau exports trivial—ideally just specifying the table name and extract name.

**Action:**

Built a single script that handles the entire workflow, controlled by command-line flags:

```bash
python duckdb_to_tableau_server.py --tables table1 table2 --name extract_name
```

The script (`duckdb_to_tableau_server.py`) handles all complexity:
1. Connects to [[duckdb|DuckDB]] and queries specified tables
2. Exports to Parquet format
3. Converts to Tableau Hyper format
4. Publishes to Tableau Server
5. Creates local backup copies

Dagster assets became simple wrappers (2025):

```python
@asset(
    deps=["build_daily_sales_models"],
    description="Export daily sales to Tableau Server",
    group_name="export"
)
def daily_sales_tableau_export(context):
    cmd = [
        sys.executable, str(script_path),
        '--tables', 'int_orders_summary_daily',
        '--name', 'daily_sales_summary'
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    context.log.info(f"Published: {result.stdout}")
    return {"status": "success"}
```

The script is also testable from the command line—no Dagster required for debugging.

**Impact:**

| Metric | Before | After |
|--------|--------|-------|
| Time to add new export | 2-3 hours | 10 minutes |
| Lines of code per export | ~50 | ~15 |
| Debugging complexity | High (Dagster context required) | Low (CLI testable) |
| Total codebase reduction | - | ~400 lines removed |

**The real payoff came later.** When Dagster was retired in May 2026, the export script moved into the new scheduled jobs unchanged. Because all the publishing logic lived in one command-line script, not in the orchestrator, there was nothing to rewrite.

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

**2026 update:** the model is still the core UK dataset. It is rebuilt every morning in the first dbt step and fully rebuilt once a week, and it is now the default starting point for ad-hoc UK questions about sales, products and customers.

---

## Case Study 5: Catching Reports That Did Not Land

**Situation:**

By 2026 the platform fed weekly and monthly scorecards as well as daily datasets. Two failures kept slipping through. A weekly job could die before its export step, and nobody noticed until someone asked for the file. And a fixed table could be rebuilt correctly while the published dashboard still showed the old snapshot, because rebuilding a table does not refresh a dashboard.

Every job had logs and alerts. The gap was that nothing checked the *outputs*.

**Task:**

Detect a missing or stale deliverable on the same day, without adding a server or a framework.

**Action:**

- **A register of deliverables.** One YAML file lists every scheduled output: what it is, how often it is due, which job and phase produce it, and a grace window.
- **A ledger.** The phase that produces an output records it in the run-history database when it lands. Adding a new deliverable is one register entry plus one line in the phase.
- **A daily gate.** A small job compares the register with the ledger every afternoon. Anything missing past its grace window, or landed but empty, raises an alert to phone and Teams. A missed week keeps alerting until it is fixed.
- **A stale-datasource check.** The same gate compares each published datasource's last publish with its table's last successful build. If the table is newer, the dashboard is showing old numbers.

The gate reads only the small run-history database, never the main DuckDB file, so it runs in seconds and can never block a build.

**Impact:**

- A job that fails silently is now caught the same day or the next, not when a stakeholder asks.
- "Did the report go out?" is a query, not a question for me.
- The design is the asset idea from Dagster - think in outputs, not jobs - without the server.

---

## Themes Across Case Studies

1. **Automation compounds** - Manual processes that seem small add up to hours per week
2. **Configuration > code** - The less code per use case, the fewer bugs and easier maintenance
3. **Resilience matters** - Real-world data is messy; build for the messiness
4. **Show value early** - The customer segmentation rebuild proved the concept before scaling
5. **Check outputs, not jobs** - A job that ran is not the same as a report that landed
