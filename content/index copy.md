---
title: "QVC Modern Data Stack"
subtitle: "A portfolio showcasing modern data engineering at scale"
---

## Overview

Built and maintain a modern analytics platform for QVC UK/CA, consolidating data from Oracle, Azure, and business sources across **4 international markets** into a unified DuckDB-based data warehouse.

::: {.callout-note}
## Quick Stats
| Metric | Value |
|--------|-------|
| Markets | UK, Germany, Italy, Japan |
| DBT Models | 100+ |
| Dagster Assets | 50+ |
| Daily Data Volume | 10M+ rows |
:::

## What This Portfolio Demonstrates

- **Orchestration Design** - Asset-based pipelines with Dagster
- **Transformation Architecture** - DBT medallion pattern at scale
- **Database Optimization** - DuckDB for analytical workloads
- **Pipeline Engineering** - Python ingestion from diverse sources
- **AI-Assisted Development** - Leveraging Claude Code for productivity

## Architecture at a Glance

```{mermaid}
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
        DBT[DBT Models]
    end

    subgraph Serve
        Tableau[Tableau Server]
        CSV[CSV Extracts]
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
    DBT --> CSV
    Dagster -.-> Python
    Dagster -.-> DBT
    Dagster -.-> Tableau
```

## Navigate This Portfolio

:::: {.columns}

::: {.column width="50%"}
**By Technology**

- [Dagster Orchestration](dagster.qmd)
- [DBT Transformations](dbt.qmd)
- [DuckDB Analytics](duckdb.qmd)
- [Python Pipelines](python-pipelines.qmd)
- [AI-Assisted Development](agentic-ai.qmd)
:::

::: {.column width="50%"}
**By Topic**

- [Architecture Deep Dive](architecture.qmd)
- [Case Studies](case-studies.qmd)
- [Challenges Solved](challenges.qmd)
- [About Me](about.qmd)
:::

::::
