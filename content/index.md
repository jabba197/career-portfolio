---
title: "QVC Modern Data Stack"
description: "How I built a modern analytics platform that cut pipeline runtime from a day to 20 minutes"
---

## Overview

I'm Vishal Kerai. I joined QVC in January 2024 as a Senior Commercial Analyst — but a natural affinity for solving problems with code led me down a different path. I became QVC International's first analytics engineer, designing and building a modern data stack from scratch. This portfolio documents what I built and the thinking behind it.

### The Environment I Inherited

QVC is a company rich in data but constrained by legacy infrastructure. When I arrived, the analytics platform had been built incrementally over years — before modern tooling was accessible to analysts.

My first project, a customer segmentation dashboard, exposed every weakness. Joining 60 million orderline rows with product and member data took over an hour in Oracle. Transfers were capped at 7 Mbps over VPN. CSV files were scattered across network drives with no unified source of truth. New business insights could take days or weeks to generate.

The broader stack looked like this:

- **Oracle** — the transactional source database, not designed for analytical workloads
- **Hyperion** — a deprecated OLAP layer scheduling extracts to network drives
- **Excel + Power Query** — the analytics platform. Analysts connected to Oracle via ODBC, transformed in Power Query, and built pivots. Business logic lived inside spreadsheets
- **16GB laptops** — where it all ran, often from home over 7 Mbps VPN connections

It worked. People delivered insights, built dashboards, ran the business. But no one was bridging the gap between analyst work and modern engineering practices — multiple analysts were creating different versions of similar reports, nothing was version-controlled, and there was no path to scale.

### Why I Built Something Different

When I hit the limitations — Excel row limits, day-long rebuilds, queries that crashed my laptop — I reached for what I knew: Python and SQL. Six months of exploration led me to dbt, DuckDB, and a local-first approach that worked within existing infrastructure rather than waiting for cloud approvals.

The full story is in [[journey/index|The Journey]].

### What I Built

A modern analytics platform that consolidates data from Oracle, Azure Blob Storage, and SharePoint into a unified, version-controlled data warehouse powered by DuckDB and dbt.

> [!success] Impact
> **Pipeline runtime: 1 day → 20 minutes.** What used to crash my laptop now runs reliably every morning. 100+ dbt models serve 4 international markets (UK, DE, IT, JP), with ~50 stakeholders consuming Tableau reports built on this foundation.

## Architecture at a Glance

```mermaid
flowchart LR
    subgraph Sources
        Azure[Azure Blob]
        Oracle[(Oracle)]
        SharePoint[SharePoint]
    end

    subgraph Ingestion
        Python[Python Pipelines]
    end

    subgraph Storage
        Parquet[Parquet Lake]
        DuckDB[(DuckDB)]
    end

    subgraph Transform
        DBT[dbt Models]
    end

    subgraph Serve
        Tableau[Tableau Server]
    end

    subgraph Orchestrate
        Dagster{Dagster}
    end

    Azure --> Python
    Oracle --> Python
    SharePoint --> Python
    Python --> Parquet
    Parquet --> DuckDB
    DuckDB --> DBT
    DBT --> Tableau
    Dagster -.-> Python
    Dagster -.-> DBT
    Dagster -.-> Tableau
```

**Sources:**
- **Oracle** — Legacy transactional database. Sales, inventory, customer data. Slow to query directly for large datasets.
- **Azure Blob** — Files dumped by data engineering. CSVs, Excel exports, and the [[parquet-lake|Parquet Lake]].
- **SharePoint** — Business-managed spreadsheets. Pricing, promotions, manual overrides.

---

## 📚 The Stack

Technologies powering the platform. [[stack/index|Browse all →]]

| Technology | Purpose |
|------------|---------|
| [[sources\|Sources]] | Where the data comes from (Oracle, Azure, SharePoint) |
| [[parquet-lake\|Parquet Lake]] | Extending the existing data lake for analyst access |
| [[duckdb\|DuckDB]] | The database that made it all possible |
| [[dbt\|dbt]] | Transformation layer (medallion architecture) |
| [[dbt-duckdb\|dbt-duckdb]] | Technical patterns and SQL reference |
| [[dagster\|Dagster]] | Orchestration and scheduling |
| [[python-pipelines\|Python Pipelines]] | Ingestion from Azure, Oracle, SharePoint |
| [[tableau\|Tableau]] | Serving data to the business |

---

## 🛤️ The Journey

How this platform evolved and what I learned. [[journey/index|Browse all →]]

| Topic | Description |
|-------|-------------|
| [[case-studies\|Case Studies]] | Real problems solved (STAR format) |
| [[challenges\|Challenges]] | Technical obstacles overcome |
| [[ai-accelerated-development\|AI-Accelerated Dev]] | How I used Claude Code |

---

## 🔧 How-To Guides

Practical patterns for common data problems. [[how-to/index|Browse all →]]

| Guide | Problem It Solves |
|-------|-------------------|
| [[hyper-api\|Automating Tableau Extracts]] | Publish data to Tableau Server without opening Desktop |
| [[transformation-layer\|Building a Transformation Layer]] | Structure transformations so you're not starting from scratch |
| [[local-large-data\|Working with Large Data Locally]] | Handle datasets that push against your laptop's RAM limits |

*These guides share what I've learned. They're based on Python/dbt, but the concepts often transfer to other tools.*

