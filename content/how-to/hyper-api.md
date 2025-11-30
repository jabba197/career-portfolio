---
title: "Automating Tableau Extracts with the Hyper API"
description: "How to publish data to Tableau Server without opening Tableau Desktop"
---

## The Problem

You've got data on your machine — a CSV, a Parquet file, a database table. You need it in Tableau Server so analysts can build reports.

The traditional workflow:

1. Open Tableau Desktop
2. Connect to your data source
3. Wait while Tableau parses the file (can take 30+ minutes for large CSVs)
4. Create an extract
5. Publish to Tableau Server
6. Wait again while it uploads
7. Close Tableau Desktop

This works, but:
- **You can't automate it** — someone has to sit there and click
- **It ties up your machine** — Tableau Desktop uses significant resources
- **It's slow** — CSV parsing is expensive; every refresh repeats this
- **It's error-prone** — manual steps mean manual mistakes

## Why It Matters

If you're refreshing data daily, weekly, or even monthly, the manual approach adds up. Every refresh means:
- Someone's time (yours)
- Tableau Desktop hogging resources on your machine
- The risk of forgetting, or using the wrong file, or publishing to the wrong project

The Hyper API lets you:
- **Automate the entire workflow** — no manual steps, no forgetting
- **Skip Tableau Desktop entirely** — your machine stays free
- **Schedule refreshes** — data is ready when people need it
- **Do the heavy lifting locally** — convert to Hyper on your machine, upload the finished file

## Alternative: Tableau Server Network Drive

There's another approach worth knowing about: Tableau Server can connect to a shared network drive. You drop CSVs into a designated folder, and scheduled refreshes will pick them up automatically.

This works if:
- You don't want to write code
- You're comfortable with CSV format
- You have access to the network drive location
- You're okay waiting for the next scheduled refresh (or triggering one manually in the web UI)

**Why I prefer the Hyper API:**

1. **Full control over timing** — Data is live the moment I push. No waiting for scheduled refreshes.

2. **No conversion step** — When you upload a CSV to the network drive, Tableau Server still has to convert it to an extract (its internal `.hyper` format). With the Hyper API, you're creating the `.hyper` file directly — Tableau Server can use it immediately without processing.

The network drive method is a valid option if scripting isn't feasible. But if you can write Python, the Hyper API gives you more control and skips the server-side conversion overhead.

## The Solution: Hyper API + Tableau Server Client

Tableau provides two Python libraries that give you full control:

| Library | What It Does |
|---------|--------------|
| **tableauhyperapi** | Creates `.hyper` files (Tableau's extract format) directly from data |
| **tableauserverclient** | Publishes files to Tableau Server via the REST API |

Together, they let you:
1. Read data from any source (CSV, Parquet, database)
2. Convert it to Hyper format
3. Publish directly to Tableau Server

No Tableau Desktop required.

## The Workflow

```
Your Data (CSV/Parquet/DB)
        ↓
   [Python Script]
        ↓
   .hyper file (local)
        ↓
   [Tableau Server Client]
        ↓
   Published Datasource
```

## Installation

```bash
pip install tableauhyperapi tableauserverclient
```

## Example 1: CSV to Tableau Server

Here's a minimal example that takes a CSV and publishes it to Tableau Server:

```python
import pandas as pd
from tableauhyperapi import (
    HyperProcess, Connection, TableDefinition,
    SqlType, Telemetry, CreateMode, Inserter
)
import tableauserverclient as TSC

# --- Step 1: Read your data ---
df = pd.read_csv('your_data.csv')

# --- Step 2: Create the Hyper file ---
hyper_path = 'output.hyper'

with HyperProcess(telemetry=Telemetry.SEND_USAGE_DATA_TO_TABLEAU) as hyper:
    with Connection(
        endpoint=hyper.endpoint,
        database=hyper_path,
        create_mode=CreateMode.CREATE_AND_REPLACE
    ) as connection:

        # Define table structure (simplified - adjust types as needed)
        table_def = TableDefinition(
            table_name="Extract",
            columns=[
                TableDefinition.Column(col, SqlType.text())
                for col in df.columns
            ]
        )

        connection.catalog.create_table(table_def)

        # Insert data
        with Inserter(connection, table_def) as inserter:
            for row in df.itertuples(index=False):
                inserter.add_row(list(row))
            inserter.execute()

print(f"Hyper file created: {hyper_path}")

# --- Step 3: Publish to Tableau Server ---
server_url = 'https://your-tableau-server.com'
username = 'your_username'
password = 'your_password'
site_name = 'YourSite'  # Empty string for default site
project_name = 'YourProject'

tableau_auth = TSC.TableauAuth(username, password, site_name)
server = TSC.Server(server_url, use_server_version=True)

with server.auth.sign_in(tableau_auth):
    # Find the project
    all_projects, _ = server.projects.get()
    project = next(p for p in all_projects if p.name == project_name)

    # Publish
    datasource = TSC.DatasourceItem(project.id, name='MyExtract')
    server.datasources.publish(
        datasource,
        hyper_path,
        mode=TSC.Server.PublishMode.Overwrite
    )

print("Published to Tableau Server!")
```

## Example 2: Making It Scriptable

The real power comes from making the script accept parameters, so you can reuse it for any data:

```python
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True, help='Path to CSV file')
parser.add_argument('--name', required=True, help='Name of the Tableau datasource')
parser.add_argument('--project', default='Default', help='Tableau project name')
args = parser.parse_args()

# Now you can call:
# python publish_to_tableau.py --input sales.csv --name SalesData --project Analytics
```

This means you can:
- Schedule the script with Windows Task Scheduler, cron, or an orchestrator
- Publish different datasets with the same script
- Integrate into larger data pipelines

## Example 3: Parquet (More Efficient)

If you're working with large datasets, Parquet is more efficient than CSV. The Hyper API can load Parquet directly:

```python
# Instead of inserting row-by-row, copy from Parquet
connection.execute_command(f"""
    COPY "Extract"."YourTable"
    FROM '{parquet_path}'
    (FORMAT PARQUET)
""")
```

This is significantly faster for large files because:
- No row-by-row insertion
- Parquet is already columnar (like Hyper)
- Type information is preserved

## Type Mapping

One gotcha: you need to map your data types to Hyper types. Here's a basic mapping:

| Your Data Type | Hyper Type |
|----------------|------------|
| Integer | `SqlType.int()` or `SqlType.big_int()` |
| Float/Decimal | `SqlType.double()` |
| String/Text | `SqlType.text()` |
| Boolean | `SqlType.bool()` |
| Date | `SqlType.date()` |
| Datetime | `SqlType.timestamp()` |

For more complex mappings (especially decimals with precision), see the full implementation in the MDS codebase.

## Scheduling

Once you have a working script, you can automate it:

| Method | Best For |
|--------|----------|
| **Windows Task Scheduler** | Simple daily/weekly runs |
| **Python scheduler (schedule, APScheduler)** | More control, still simple |
| **Dagster/Prefect/Airflow** | Complex pipelines with dependencies |

In the MDS, we use [[dagster|Dagster]] to orchestrate Tableau exports as part of a larger pipeline — the dbt models run first, then the exports trigger automatically.

## Results

After implementing this approach:

| Metric | Before | After |
|--------|--------|-------|
| Manual steps | 7 (open Desktop, connect, wait, extract, publish, wait, close) | 0 (runs automatically) |
| Time per refresh | 30-60 min (sitting there) | 5-10 min (unattended) |
| Errors | Common (forgot to refresh, wrong file) | Rare (automated, logged) |

## When Not to Use This

This approach assumes:
- You have Python available
- You can install packages (or have them pre-installed)
- You have Tableau Server credentials with publish permissions

If you're in an environment where you can't run Python scripts, this won't work. But if you can, it's a significant improvement over the manual workflow.

## Related

- [[tableau|Tableau in the MDS]] — How this fits into the broader architecture
- [[dagster|Dagster]] — How we orchestrate these exports
- [[challenges|Challenges]] — Problems we solved along the way

## Further Reading

- [Tableau Hyper API Documentation](https://tableau.github.io/hyper-db/)
- [Tableau Server Client (Python) Documentation](https://tableau.github.io/server-client-python/)
- MDS Codebase: `bat_file_data_refresh/python/create_hyper_files/duckdb_to_tableau_server.py`
