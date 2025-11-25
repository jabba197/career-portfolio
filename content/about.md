---
title: "About"
description: "About the author and this portfolio"
---

## About Me

I'm a data professional who bridges the gap between analysis and engineering. My background is in commercial analytics—understanding business questions and finding answers in data. But I've always been drawn to the infrastructure that makes analysis possible.

This project emerged from frustration. I joined QVC UK as a Senior Commercial Analyst and quickly discovered that the hardest part of analysis wasn't the analysis itself—it was getting the data into a usable state. So I built the tooling I needed.

What started as "making my job easier" evolved into a modern data stack serving multiple teams across 4 international markets.

## What I Bring

### The Analyst's Perspective

I've sat in the chair of the end user. I know what it's like to:
- Wait hours for a dataset to materialise
- Debug VLOOKUPs across 50-tab Excel workbooks
- Explain to stakeholders why the numbers changed overnight
- Rebuild the same analysis from scratch every quarter

This shapes how I build infrastructure—with empathy for the people who'll use it.

### The Engineer's Toolkit

Building this platform taught me:
- **Orchestration design** that handles real-world complexity
- **Transformation architecture** that scales with the business
- **Pipeline engineering** that's defensive and recoverable
- **Documentation** that keeps pace with code

### The Pragmatist's Approach

I work within constraints, not against them:
- Corporate network blocking packages? Build with native functions.
- No cloud budget? DuckDB runs anywhere.
- Single desktop for production? Design for resilience.
- AI assistants available? Use them systematically.

## Technologies

### Strong Proficiency

| Technology | What I've Built |
|------------|-----------------|
| **Dagster** | 50+ assets, custom translators, configuration-driven factories |
| **DBT Core** | 100+ models across medallion architecture, incremental strategies |
| **DuckDB** | Analytical queries, Parquet integration, native function implementations |
| **Python** | Data pipelines, Azure SDK integration, subprocess orchestration |

### Working Knowledge

- Tableau Server Client API
- Azure Blob Storage
- Oracle (as source)
- Git workflow and collaboration

### Familiar With

- Airflow (can articulate differences from Dagster)
- Snowflake/BigQuery (understand trade-offs vs DuckDB)
- dbt Cloud (vs dbt Core)

## STAR Stories

### Multi-Market Data Integration

**Situation:** QVC operates in 4 markets with different data sources and formats. No unified view existed.

**Task:** Create unified analytics across all markets with proper identity handling.

**Action:** Built DBT models that union market data with composite key patterns, automated daily refresh via Dagster.

**Result:** Single source of truth for cross-market reporting. Data available by 7:30 AM instead of mid-morning. ~4 hours/day of manual work eliminated.

---

### Reducing Manual Work

**Situation:** Analysts spent 4+ hours daily on manual data updates and report generation.

**Task:** Automate the entire data pipeline from source to dashboard.

**Action:** Built Dagster orchestration with scheduled jobs, dependency management, and failure notifications.

**Result:** Fully automated refresh. Analysts focus on analysis instead of data preparation.

---

### Scaling Tableau Exports

**Situation:** Each new Tableau export required 50+ lines of boilerplate code and hours of development time.

**Task:** Make adding exports trivial for the team.

**Action:** Built configuration-driven asset factory pattern in Dagster.

**Result:** New exports in 5 minutes instead of hours. ~400 lines of code removed from codebase.

## Questions I Can Discuss

**Data Quality:**
- DBT tests for uniqueness, not-null, accepted values
- Row count validation before overwriting files
- Backup/restore pattern for safe operations

**Failure Handling:**
- Dagster retry policies with exponential backoff
- State tracking for incremental processing
- Backup files restored on write failures

**Performance Optimisation:**
- Views for staging/intermediate, tables only for marts
- Incremental models for high-volume tables
- DuckDB columnar storage for analytical queries

**Maintainability:**
- Configuration-driven patterns where possible
- Clear folder structure following medallion architecture
- CLAUDE.md documentation that stays current with code

## This Portfolio

This documentation showcases a production system—not a tutorial project. The code referenced throughout is from a working platform that:

- Processes 10M+ rows daily across 4 markets
- Serves commercial and operational analytics teams
- Runs automated refreshes via Dagster scheduling
- Publishes to Tableau Server for business consumption

### Built With

- [Quarto](https://quarto.org/) - Documentation framework
- [Mermaid](https://mermaid.js.org/) - Diagrams
- Production code from the QVC MDS project

## Contact

Available to discuss technical implementation details, architecture decisions, and lessons learned from building this platform.
