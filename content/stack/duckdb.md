---
title: "DuckDB"
description: "Why a local-first database was the only option that worked"
created: 2025-11-30
modified: 2026-10-30
---

## The Constraint That Shaped Everything

At QVC, we had one fundamental constraint that shaped every technical decision:

**Oracle was read-only. We couldn't create tables anywhere.**

No staging tables in Oracle. No cloud data warehouse. Cloud platforms like BigQuery and Snowflake weren't yet available in the environment, and the approval process for new tooling required time.

This meant:
- Every transformation had to happen client-side
- Tableau had to calculate queries when creating extracts
- Data transferred over the wire at **7 Mbps** (yes, megabits)
- Large queries frequently timed out

The standard analyst workflow had friction: run a query in Oracle, wait, hope it doesn't timeout, download a CSV, open in Excel or Tableau, wait again.

## The Pain Before DuckDB

### The 60 Million Row Problem

My first project was the Customer Segmentation Dashboard. Conceptually simple: join orderline data with product hierarchy and member information.

The reality:
- **60 million rows** of orderline data
- Oracle join query: **1 hour** (when it didn't timeout)
- Oracle maintenance window: midnight to 7am (connections closed)
- Network transfer: **7 Mbps cap**

### The Local Compute Attempts

I tried processing locally. The options:

| Tool | Result |
|------|--------|
| **Pandas** | Out of memory on 16GB laptop |
| **Dask** | Worked... sometimes. Fragile. Same query would fail the next day with no clear error. |
| **Excel** | Row limit exceeded |

I was spending more time fighting tooling than doing analysis.

### The Tableau Bottleneck

Even when I got data extracted, Tableau was another wall:

1. Output a CSV from Python
2. Drag into Tableau Desktop
3. Wait **1+ hours** for Tableau to parse the text and create an extract

We tried OneDrive + Tableau's SharePoint connector. Uploads took hours. Tableau still had to parse the CSV. No improvement.

## The DuckDB Revelation

**October 2024**: I discovered DuckDB.

The same query that took **1 hour in Oracle** ran in **10-16 minutes** in DuckDB.

A colleague and I were genuinely shocked. We'd barely optimised anything. It was just... faster. 6x faster.

### Why DuckDB Worked Where Others Didn't

| Constraint | Why DuckDB Fit |
|------------|----------------|
| No cloud approval | Runs locally, no server needed |
| No budget | Free, open source |
| Limited RAM laptops | Columnar storage, out-of-core processing |
| Read-only Oracle | Reads Parquet/CSV directly, creates local tables |
| 7 Mbps network | Process locally after one-time data transfer |

DuckDB wasn't the "best" database in some abstract sense. It was the **only database that worked within our constraints**. Given cloud access, I'd evaluate BigQuery or Snowflake — but DuckDB proved that right-sized tooling can outperform enterprise solutions for the right workload.

### The Technical Magic

DuckDB's architecture is built for exactly this use case:

**Columnar Storage**
- Only reads columns you need
- Compression reduces I/O
- Vectorised execution for analytical queries

**Out-of-Core Processing**
- Doesn't need all data in memory
- Spills to disk intelligently
- 16GB laptop could handle 60M+ rows

**Zero Infrastructure**
- No server to provision
- No ports to open
- No IT tickets to file
- Just `pip install duckdb` and go

**Parquet Native**
- Direct reads from Parquet files
- No ETL step to load data
- Schema on read

```python
# This just works
import duckdb
con = duckdb.connect('analytics.db')
result = con.execute("""
    SELECT * FROM read_parquet('orders/*.parquet')
    WHERE order_date >= '2024-01-01'
""").fetchdf()
```

## The Compound Effect

DuckDB alone was 6x faster. But it enabled other improvements that compounded:

### Stage 1: Fast Local Queries
- Oracle query: 60 min → DuckDB query: 10 min

### Stage 2: dbt on DuckDB
- Version-controlled transformations
- Modular, testable SQL
- Analysts could collaborate on a shared codebase instead of duplicating work

### Stage 3: Hyper API Integration
- We discovered we could create Tableau extracts programmatically
- Bypassed the CSV parsing bottleneck entirely

### Stage 4: Automated Pipelines
- Dagster orchestrating everything (2025; replaced by plain Python jobs on the Windows scheduler in May 2026)
- End-to-end refresh: **4+ hours → 30 minutes**

None of this would have been possible without DuckDB as the foundation.

## What DuckDB Enabled

The MDS wouldn't exist without DuckDB. It was the foundation that made everything else possible:

| Capability | Before DuckDB | After DuckDB |
|------------|---------------|--------------|
| Query speed | 60 min | 10 min |
| End-to-end refresh | 4+ hours | 30 min |
| Local development | Crashes, fragile | Fast, reliable |
| Collaboration | Impossible | dbt + Git |
| Automation | Manual | Scheduled pipelines (Dagster in 2025, plain Python jobs since May 2026) |

## DuckDB in 2026

Two years on, DuckDB is still the foundation. What changed is the scale and the discipline around it.

### Bigger Machine, Same Failure Mode

The platform started on a 16 GB laptop, moved to a 32 GB desktop, and now runs on a 64 GB desktop (Intel Core Ultra 5, 14 cores). More memory did not remove the risk. A greedy query plan can still use up the RAM and take the whole machine down: in mid-2026 the host shut down unexpectedly five times, with no crash dump, which points to resource exhaustion rather than a driver fault.

So I wrote rules for how queries are sized on this box:

- **Leave headroom.** dbt runs with a 45 GB memory limit. DuckDB's limit only covers its own buffer manager, so the process uses more than that; the rest keeps Windows alive.
- **Do not set the limit low either.** Too low a limit forces heavy disk spill and runs that never finish.
- **Aggregate in stages.** No `COUNT(DISTINCT)` or `median()` in a GROUP BY over 100M+ rows. A distinct aggregate keeps a hash set per group. I aggregate line to order to customer with plain sums, so a count of the previous stage is the distinct count.
- **Query tables, not views.** A staging view re-reads every Parquet file on each query. Analysis goes to the persisted refined tables.
- **Check free memory first** before a large scan or build, and run one heavy job at a time.

### A Read-Only Query Broker

DuckDB allows one writer, and a scheduled build can hold the lock for an hour. An ad-hoc query that hits that lock used to hang or fail. I built a small command-line broker for reads. It queues, polls through write locks and names the process holding the lock, times out and cancels cleanly, and logs every query with its memory use. Writes stay with dbt. Both people and AI agents use it, which matters: an agent that kills a "stuck" process can destroy a two-hour build.

### Upgrading to DuckDB 2.0

On 23 October 2026 I moved the engine from 1.5 to 2.0. The upgrade changed no model SQL. The database file stays on the older storage format, so an older engine can still open it, and a cutover script both installs and rolls back. The real work was TLS: 2.0 does not verify server certificates by default, and the corporate proxy re-signs traffic. I turned verification on and gave DuckDB a certificate bundle that includes the proxy's root, rather than leaving it off.

## The Lesson

Sometimes constraints are gifts.

If we'd had BigQuery access, I probably would have used it. It would have been "good enough." I wouldn't have discovered DuckDB, wouldn't have learned dbt, wouldn't have built this system.

The constraint - no cloud, no budget, read-only Oracle - forced me to find a local-first solution. That solution turned out to be **better** for our use case than a cloud warehouse would have been.

Modern tooling doesn't require modern infrastructure budgets. Sometimes it just requires stubbornness and a willingness to try something different.

## Related

- [[dbt-duckdb]] — Technical reference for dbt on DuckDB
- [[dbt]] — Transformation architecture and medallion pattern
- [[stack/index|The Stack]] — How DuckDB fits in the overall system
- [[journey/index|The Journey]] — The full story of building the MDS
- [[challenges]] — Technical problems solved along the way
