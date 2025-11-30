---
title: "Sources"
description: "Where QVC's data comes from"
date: 2025-11-28
draft: false
---

## Overview

The MDS pulls data from four source systems. Consolidating them into a single queryable database means analysts no longer need to context-switch between tools, wait for slow Oracle queries, or manually reconcile data across markets.

---

## Oracle

The legacy transactional database. Sales, inventory, customers, airtime — the core business data lives here.

**What we extract:**
- `orderline` — order transactions
- `member_analysis` — customer segmentation
- `airtime` — TV broadcast data
- `item_hist` — product history
- `reviews` — customer reviews
- Plus reference tables (products, brands, categories)

**Connection:** `oracledb` Python driver with parallel extraction. SQL files define each extract, streamed to Parquet in chunks to avoid memory issues.

**The problem:** Slow. Queries that take seconds in DuckDB take minutes in Oracle. That's why we extract to local Parquet files rather than querying live.

---

## Azure Blob (QI Data Lake)

CSVs lifted from legacy systems (Oracle, SAS, SAP) and dumped into Azure Blob Storage. This is the "official" data lake.

**Markets:** UK, Germany, Italy, Japan

**What's there:** Orders, customers, products — similar data to Oracle, but for all markets.

**The problem:** Network latency + CSV format made it unusable for interactive analysis. See [[parquet-lake|Parquet Lake]] for how I worked around this.

---

## Azure Synapse

Operational data from QVC's global data warehouse. Separate from the QI Data Lake.

**What we extract:**
- `orders` — cross-market order data
- `ship` — shipping/fulfilment
- `qi_merch` — merchandising dimension table

**Connection:** ODBC with Windows SSO (ActiveDirectoryIntegrated). Partitioned by year/month for large tables.

---

## Network Drives

Business-managed files. Excel spreadsheets and CSVs maintained by commercial teams.

**Examples:**
- **TSV Plans** — Today's Special Value schedules. TSV drives 40-60% of daily sales, so this data is critical.
- **Budgets** — Market-level sales targets
- **Exchange rates** — Currency conversion factors

**The challenge:** Schema changes without warning. Column names shift, formats vary. Staging models include defensive cleaning.

---

## Related

- [[stack/index|The Stack]] — How these sources fit into the full stack
- [[python-pipelines|Python Pipelines]] — How data is ingested from each source
- [[parquet-lake|Parquet Lake]] — The local mirror that makes Azure data usable
