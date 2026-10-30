---
title: "Parquet Lake"
description: "A local data layer extending the existing data lake"
date: 2025-11-28
draft: false
created: 2025-11-30
modified: 2026-10-30
---

## Overview

The Parquet Lake is a local data store that serves two purposes: a mirror of the QI Data Lake (converted from CSV to Parquet) and a staging area for Oracle extracts. It started on the network drive; since July 2026 it lives on the machine's local disk, and the network drive holds a mirror copy (see [[#Local-First Storage (2026)]]).

> [!success] Impact
> Queries that timed out against Azure now complete in seconds. Files are 5-10x smaller than the original CSVs, making single-machine analytics viable.

---

## The QI Data Lake

The QI Data Lake is a lift-and-shift of QVC data from legacy systems (Oracle, SAS, SAP) into Azure Blob Storage. That's the scope — raw data moved to the cloud.

The team chose CSV as the storage format, which works fine in principle. The challenge came when I tried to query it directly with DuckDB.

### Why It Didn't Work for My Use Case

**Network latency**: Querying CSVs over the network to Azure was too slow. The transfer speeds weren't viable for interactive analysis. If the files had been Parquet (smaller, columnar), I might have avoided building a local mirror entirely. But with CSVs, the only practical option was to pull the data locally.

**Inconsistent schemas**: The migration was a straight lift-and-shift without transformation. This means:

- No type enforcement — everything comes through as strings
- **Inconsistent ingestion across years** — for example, UK orders from 2022 were ingested differently to 2023/2024
- To do a simple `SELECT *` across years, you first have to clean and align the schemas

The data isn't analyst-ready. It's a faithful copy of what was in the source systems, but the work to make it queryable still needs to happen somewhere.

### The Trade-off

I understand the rationale: deliver quickly, get something shipped. That's a valid approach, especially under time pressure. The consequence is that the transformation and cleaning work shifts downstream — in this case, to me.

---

## My Solution

I built a Parquet Lake on the local network drive. The approach:

1. Pull CSVs from Azure Blob (the QI Data Lake)
2. Convert to Parquet with proper types
3. Store on the network drive

**Why local?** Network drives are on the local network — much faster than going over the internet to Azure. Queries that timed out against Azure complete in seconds locally.

The Azure pulls now sign in with the user's own corporate identity instead of a shared access token, so there is no long-lived secret to rotate or leak.

**Why Parquet?**

| Aspect | CSV | Parquet |
|--------|-----|---------|
| File size | 100% | 10-20% (5-10x smaller) |
| Query speed | Full scan required | Columnar, predicate pushdown |
| Type safety | None | Enforced schema |
| Compression | None | Built-in |

The size difference matters. You don't need a Spark cluster to query Parquet files — DuckDB handles them on a single machine. Parquet is an industry-standard format; every modern tool reads it.

---

## Local-First Storage (2026)

In July 2026 the network share started failing in an odd way. Bulk reads and writes still worked, but file operations such as rename, delete and directory listing failed at random. The pipeline wrote files to a temporary name and then renamed them, so the morning job kept failing on the rename.

I changed the rule: **write locally, mirror to the share afterwards, and never let the share block a job.**

- Local disk is the source of truth for the Parquet files, the DuckDB database and the Tableau extracts.
- A small mirror helper copies each finished file to the share. It copies data only, writes straight to the final name (no rename), has a timeout, and never raises an error.
- Phases whose only job is the network copy are optional: a failure is a warning, not a failed run.
- One switch pauses mirroring altogether without stopping the extracts.

**The lesson that bit hardest:** for three days the extracts wrote to one location and dbt read from another. Every build passed, every test passed, every report published, all on data frozen at the day of the split. No error anywhere. The write path and the read path are now documented as one rule: if you move one, move the other.

---

## Oracle Mirror

The Parquet Lake wasn't just for the QI Data Lake mirror. Originally, it was also a staging area for Oracle extracts.

### The Pattern

For tables like `order_line`, we'd do a rolling extract:

- **90-day lookback** — captures all recent changes
- **Daily refresh** — the last 90 days are re-extracted each run
- **Why 90 days?** — QVC has a 60-day money-back guarantee, so order data can change for weeks after the initial transaction

This ensured reporting was always up-to-date and reflective of the latest state, without requiring a full table extract every time.

---

## Lessons Learned

With more time and resources, the architecture could be improved:

### What I'd Consider

**Apache Iceberg** or **Delta Lake** instead of raw Parquet:

- Metadata catalog — know what tables exist without asking
- Time travel and versioning
- ACID transactions
- Works with DuckDB, Databricks, Spark, etc.

These are becoming industry standards for lakehouse architectures. The tooling exists; it's a matter of implementation scope.

### The Takeaway

A data lake is only as useful as its access layer. Raw files in cloud storage are a starting point, not an end state. The transformation, typing, and documentation work has to happen somewhere — either upstream (by the team building the lake) or downstream (by the analysts consuming it).

In this case, it happened downstream. The MDS and Parquet Lake are the access layer that makes the raw data usable.

---

## Related

- [[sources|Sources]] — Where the raw data comes from
- [[stack/index|The Stack]] — How the Parquet Lake fits into the stack
- [[duckdb|DuckDB]] — How I query Parquet files directly
- [[python-pipelines|Python Pipelines]] — The ingestion scripts that populate the lake
