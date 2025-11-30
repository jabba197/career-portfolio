---
title: "Python Pipelines"
description: "Ingestion from Azure, Oracle, and business sources"
---

## Overview

Custom Python pipelines handle data ingestion from diverse sources—Azure Blob Storage, Oracle databases, SharePoint—converting everything to Parquet for [[dbt]] transformation.

> [!success] Impact
> Automated ingestion across 4 markets. State tracking means only new files are processed. Safe file operations ensure no data loss on failure.

These pipelines were built with significant AI assistance. Claude helped design patterns, debug edge cases, and iterate quickly on solutions. See [[ai-accelerated-development|AI-Accelerated Development]] for more on this approach.

## Key Pipelines

### Azure to Parquet

**Location:** `dlt/pipelines/azure_to_network/azure_to_parquet.py`

The workhorse pipeline. Syncs CSV files from Azure Blob Storage to local Parquet files.

```bash
# Called via Dagster asset
run_azure_sync(market="UK", folder_name="ingest_orders", days_back=30)
```

**What it does:**
- Auto-detects folder structure (single file vs year-partitioned)
- Handles European CSV dialects (semicolon delimiters for DE/IT)
- Tracks state to avoid reprocessing unchanged files
- Converts to Parquet using [[duckdb|DuckDB]]

**Handles two patterns:**
```
# Single file
UK/raw_data/DWH/Oracle/ingest_products_sku/ingest_products_sku.csv

# Year-partitioned (daily files)
UK/raw_data/DWH/Oracle/ingest_orders/2024/ingest_orders_20240115.csv
UK/raw_data/DWH/Oracle/ingest_orders/2024/ingest_orders_20240116.csv
```

### SCV Azure Sync

**Location:** `dlt/pipelines/scv_azure_to_network_drive.py`

Specialised sync for Single Customer View data—orders and members across all markets.

```bash
run_scv_sync(market="UK", entity="orders", months_back=3)
```

**What it does:**
- Downloads multiple daily Parquet files per month
- Merges into single monthly Parquet using DuckDB
- Supports UK, DE, IT, JP markets
- Tracks detailed metadata (row counts, file counts)

### DuckDB to Tableau Server

**Location:** `bat_file_data_refresh/python/create_hyper_files/duckdb_to_tableau_server.py`

Exports DuckDB tables to Tableau Hyper format and publishes to Tableau Server. See [[tableau|Tableau]] for how this fits into the export flow.

```bash
python duckdb_to_tableau_server.py --tables int_orders_summary_daily --name daily_sales
```

**What it does:**
1. Queries specified tables from DuckDB
2. Exports to Parquet (intermediate format)
3. Converts to Tableau Hyper using the Hyper API
4. Publishes to Tableau Server
5. Creates local backup copy

**Key patterns:**
- Multi-table support (combine tables into one extract)
- Column name standardisation (uppercase for Tableau)
- Type mapping (DuckDB types → Hyper types)
- Ntfy notifications on completion

### Budget & Exchange Rate Ingest

**Location:** `dlt/pipelines/daily_sales_budget_ingest.py`

Ingests daily sales budget data from a SharePoint Excel file.

```bash
run_daily_sales_ingest()
```

**What it does:**
- Reads 4 market tabs from Excel (UK, DE, IT, JP)
- Transforms wide format (day columns) to long format (rows)
- Outputs to DuckDB for joining with actuals

### Oracle Extraction (Legacy)

**Location:** `bat_file_data_refresh/python/create_parquets/`

Direct Oracle extraction for data not yet available via Azure. Being phased out as more data moves to Azure exports.

**Scripts:**
- `refresh_orderline.py` — Large orderline extract (3 months, partitioned)
- `refresh_misc_data.py` — Multiple small tables in parallel with incremental support

**Key patterns:**
- Credential testing before extraction (prevents account lockout)
- Batched fetching (100k rows at a time)
- Parallel processing with ThreadPoolExecutor

### Network Backup

**Location:** `dlt/copy_duckdb_to_network.py`

Simple but critical: copies the DuckDB database file to a network drive for backup.

```bash
copy_duckdb_to_network()
```

Runs after morning refresh to ensure a recovery point exists.

## Common Patterns

### European CSV Handling

German and Italian markets use semicolons as delimiters. Pipelines try multiple configurations:

```python
fallback_configs = [
    {'delim': ';', 'quote': '"'},   # European standard
    {'delim': ';', 'strict_mode': False},
    {'delim': ',', 'quote': '"'},   # UK/US standard
]

for config in fallback_configs:
    try:
        return process_with_config(config)
    except Exception:
        continue
```

See [[challenges#Challenge 4 European CSV Dialect Handling|CSV Dialect Challenge]] for the full story.

### State Tracking

Pipelines track what's been processed to enable incremental syncs:

```python
# State file: .state/UK_ingest_orders_state.json
{
    "market": "UK",
    "folder_name": "ingest_orders",
    "processed_files": ["ingest_orders_20240115.csv", "ingest_orders_20240116.csv"],
    "last_sync": "2024-01-16T10:30:00",
    "total_rows_loaded": 15000000
}
```

### Safe File Operations

Backup before overwriting, restore on failure:

```python
if output_path.exists():
    backup_path = output_path.with_suffix('.parquet.backup')
    shutil.copy2(output_path, backup_path)

try:
    write_parquet(output_path)
    backup_path.unlink()  # Success - remove backup
except Exception:
    shutil.move(backup_path, output_path)  # Restore
    raise
```

See [[challenges#Challenge 5 Safe File Operations|Safe File Operations Challenge]] for why this matters.

## Orchestration

All pipelines are wrapped as [[dagster|Dagster]] assets. Dagster handles:
- Scheduling (when to run)
- Dependencies (what must complete first)
- Retries (exponential backoff on failure)
- Logging (every run recorded)

Example asset wrapping a pipeline:

```python
@asset(group_name="azure_ingestion_orders")
def uk_orders_azure(context: AssetExecutionContext):
    result = run_azure_sync(market="UK", folder_name="ingest_orders", days_back=30)
    context.log.info(f"Synced {result['rows_loaded']:,} rows")
    return result
```

## Related

- [[dagster#Ingestion Assets|Dagster Ingestion Assets]] — How pipelines are orchestrated
- [[duckdb|DuckDB]] — Used for CSV→Parquet conversion and data merging
- [[tableau|Tableau]] — Destination for `duckdb_to_tableau_server.py`
- [[challenges|Challenges]] — Problems solved in these pipelines
- [[ai-accelerated-development|AI-Accelerated Development]] — How these were built
