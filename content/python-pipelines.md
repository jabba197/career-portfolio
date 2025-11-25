---
title: "Python Data Pipelines"
description: "Ingestion from Azure, Oracle, and business sources"
---

## Overview

Custom Python pipelines handle data ingestion from diverse sources, converting to Parquet for downstream processing.

## Key Pipelines

### Azure to Parquet Pipeline

<!-- TODO: Detail the unified pipeline -->
<!-- Reference: dlt/pipelines/azure_to_network/azure_to_parquet.py -->

Handles both simple and year-partitioned datasets with auto-detection:

```python
class AzureToParquetPipeline:
    """
    Auto-detects folder structure:
    - Single CSV: {folder}/{folder}.csv
    - Year-partitioned: {folder}/YYYY/{folder}_YYYYMMDD.csv
    """
```

**Features:**
- Stateful processing (tracks processed files)
- Auto CSV dialect detection (comma vs semicolon)
- Backup/restore on failure
- DuckDB-based conversion

### SCV Data Sync

<!-- TODO: Document Single Customer View pipeline -->
<!-- Reference: dlt/pipelines/scv_azure_to_network_drive.py -->

### Budget & Exchange Rate Ingest

<!-- TODO: Document SharePoint ingestion -->
<!-- Reference: dlt/pipelines/daily_sales_budget_ingest.py -->

## Technical Highlights

### European CSV Handling

```python
# German/Italian markets use semicolons
fallback_configs = [
    {'delim': ';', 'quote': '"', 'escape': '"'},
    {'delim': ';', 'strict_mode': False},
    {'delim': ',', 'quote': '"', 'escape': '"'},
]

for config in fallback_configs:
    try:
        result = process_with_config(config)
        break
    except Exception:
        continue
```

### Safe File Operations

```python
# Backup before overwriting
if output_path.exists():
    backup_path = output_path.with_suffix('.parquet.backup')
    shutil.copy2(output_path, backup_path)

try:
    # Process and write
    write_parquet(output_path)
    # Success - remove backup
    backup_path.unlink()
except Exception:
    # Restore from backup
    shutil.move(backup_path, output_path)
    raise
```

### State Management

```python
state = {
    'market': 'UK',
    'folder_name': 'ingest_orders',
    'processed_files': ['file1.csv', 'file2.csv'],
    'last_sync': '2024-01-15T10:30:00',
    'total_rows_loaded': 15_000_000
}
```

## Code References

- [`azure_to_parquet.py`](../../dlt/pipelines/azure_to_network/azure_to_parquet.py) - Main ingestion pipeline
- [`scv_azure_to_network_drive.py`](../../dlt/pipelines/scv_azure_to_network_drive.py) - SCV sync
- [`daily_sales_budget_ingest.py`](../../dlt/pipelines/daily_sales_budget_ingest.py) - Budget data
