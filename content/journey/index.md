---
title: "The Journey"
description: "How this platform evolved from constraint to solution"
---

## Overview

This wasn't a planned project with a budget and a team. It was a grassroots effort born from identifying gaps in existing tooling and a desire to do meaningful analytical work. Here's how it evolved.

---

## Era 1: The Analyst Phase

**January 2024 – June 2024**

Joined QVC UK as a Senior Commercial Analyst. Three months in, I was assigned the Customer Segmentation Dashboard — a standard dashboard build in theory, but this one would serve the entire UK market. A lot of eyes were on it, which raised the stakes.

### The Landscape

- **Data lived in**: Oracle, Hyperion, scattered Excel files
- **Hardware**: 16GB RAM laptop, often working from home over VPN
- **My goal**: Prove myself as an analyst, deliver the dashboard

### The Project: Customer Segmentation Dashboard

A top-down mandate: classify customers into 5 segments and make this data available to the whole UK business.

The awkward truth? 80% of customers fell into just 2 of the 5 segments. The segmentation itself wasn't particularly useful. But the project was necessary — it was my job to make it work.

### Key Decision: Skip Hyperion, Use Tableau

Hyperion was the "approved" tool for extracts. On paper, it made sense: a drag-and-drop interface for building queries, the ability to schedule extracts, and direct access to Oracle. In practice, it wasn't suited to my needs.

The problems with Hyperion were fundamental:

- **No incremental refreshes.** Every scheduled extract runs the full query from scratch. Need daily data? That's a full query hitting Oracle every single day, increasing load on an already slow system.
- **Locked to the data dump folder.** Hyperion can only save extracts to a specific network folder. I needed data in SharePoint so Tableau could access it. Hyperion couldn't do that.
- **No flexibility for joins.** I needed to enrich order data with customer segments, product attributes, and demographic information. Hyperion made this awkward at best, impossible at worst.
- **End of life.** Support ended years ago. The interface crashed regularly. Work got lost without warning. Investing time in mastering it felt like investing in legacy technology with limited future.

So I opted out. Instead, I went with Tableau — the business-approved BI tool. The standard approach was to connect Tableau directly to the Oracle Data Warehouse using Custom SQL. The query runs on Oracle, and the results feed into Tableau. This works, but it has limitations: making changes to field names or doing analytical cleaning in Tableau is awkward. As a bridge, you could load data into Python, do your transformations, and upload a CSV that Tableau embeds in the workbook.

### The Real Problem: Tableau Server Refresh

I needed one big table — two years of order-level data with customer segments attached. About 60 million rows. Not an insane amount, and the computations were simple: summing sales, distinct counts of customers.

The initial build worked fine. Oracle → Tableau Desktop on my laptop was fast enough. I could pull two years of data, publish to Tableau Server, and set up incremental refreshes.

The problem came with full refreshes.

The connection between Oracle and Tableau Server (based in the US) was capped at around 7 Mbps. The customer segmentation dashboard needed a full refresh every quarter due to how the segments were calculated. These refreshes would timeout. They'd fail. They'd break.

My workaround: rebuild the full dataset locally on my laptop every week or month, then publish. This took half a day to a full day. I used Dask to process the data out-of-memory because 16GB wasn't enough to hold it all in Pandas.

### The Gap

I knew the one-big-table approach could work. Tableau could handle 60 million rows for simple aggregations. But the infrastructure around it — the Oracle-to-Server connection speeds, the lack of an intermediate layer — didn't support this pattern.

This gap — between what was technically possible and what the existing infrastructure supported — became the motivation for the MDS.

### What I Learned

- The pattern worked: **extract → transform → serve**
- But it was manual, fragile, and took a full day to rebuild
- Hardware and network were real constraints, not excuses
- Seed planted: *"There has to be a better way"*

---

## Era 2: The Wilderness

**July 2024 – December 2024**

### The Problem

I wanted to be an impactful analyst. But getting the data I needed required significant manual effort each time. The tooling was the bottleneck, not my analysis skills.

By this point, I had a working solution for the Customer Segmentation Dashboard: Python scripts that pulled data from Oracle, performed the joins and transformations, and output CSVs to OneDrive for Tableau to consume. I even set up Prefect on a virtual machine to schedule these scripts automatically.

It worked. But it wasn't built for long-term maintainability.

Every time I needed a new dataset, I faced the same problem: where do I get the data, how do I transform it, and how do I schedule the refresh? There was no reusable infrastructure. Every project started from scratch. I was spending most of my time wrestling with data plumbing instead of doing actual analysis.

### The Organisational Context

The legacy stack worked. It had served the business for years, and people had built real expertise around it. But it wasn't designed for the kind of analysis I wanted to do — large datasets, frequent refreshes, version-controlled transformations.

A cloud migration was in progress, but these things take time. Azure existed somewhere in the organisation, but it wasn't yet accessible for ad-hoc analytics work. Oracle remained the source of truth, and the tooling around it was what we had to work with.

I raised the constraints with management. The response was reasonable: the cloud project was moving forward, and in the meantime we should work with what we had.

### The Search

So I started looking for alternatives. Tools I could run myself, without waiting for IT approval.

- **dbt** — "Wait, you can version control SQL? And it generates documentation automatically?"
- **DuckDB** — "A database that just... runs? No server? No installation? Just a file?"
- **BigQuery** — "This would be perfect... but IT approval would take months."
- **Prefect** — Already using it for scheduling, but it felt like overkill for what should be simple.

I explored what was available. Azure Synapse existed but wasn't accessible for my use case. Snowflake and BigQuery would have required approval processes I couldn't shortcut. I read about data mesh, medallion architecture, modern analytics engineering.

Mostly, I read. And learned. And waited for something to click.

### The Turning Point

At some point, I stopped waiting for the infrastructure to arrive and started asking: what can I build with what I have?

The constraints were real — limited RAM, no cloud access, legacy tooling. But constraints can be clarifying. If I couldn't get approval for BigQuery, maybe I didn't need BigQuery. If I couldn't run a server, maybe I didn't need a server.

### What I Learned

- **Enterprise IT moves at its own pace** — Approval chains exist for good reasons (security, compliance, support). But they also mean you can't always wait for the ideal solution.
- **Cloud access is an organisational problem, not a technical one** — Getting BigQuery or Snowflake wasn't about capability. It was about navigating procurement, security reviews, and budget approval. That takes time and seniority I didn't have.
- **Local-first tools offer autonomy** — If it runs on my laptop, I can start building today. This realisation would prove crucial.
- **This era felt slow, but I was building knowledge** — I didn't ship much. But I learned what modern data infrastructure looked like, even if I couldn't build it yet.

---

## Era 3: The Acceleration

**January 2025 – Present**

Everything clicked. dbt + DuckDB inspired me to actually build something.

### The Moment It Clicked

I'd been reading about dbt and DuckDB for months. But in January 2025, I stopped reading and started building.

The first real model I built? **`int_orderline_attribute`**.

This was the dbt model that replaced my painful Era 1 pipeline. Same purpose — order-level data with product attributes for the Customer Segmentation Dashboard. But instead of a day of Python crashes, it ran in minutes. And it was version-controlled. And documented. And testable.

```
Era 1: Oracle → CSV → Python (crashes) → CSV → Tableau
       Time: 1 day. Reproducible: barely.

Era 3: Oracle → Parquet → dbt model → DuckDB → Tableau
       Time: ~20 minutes. Reproducible: always.
```

### AI-Accelerated Development

This is also when I discovered [[ai-accelerated-development|Claude Code]]. The combination of AI assistance and modern tooling meant I could build faster than I ever had before. Not by cutting corners, but by removing friction.

### The Stack Crystallised

- **dbt** for transformations and lineage
- **DuckDB** for fast analytical queries (no server needed)
- **Python** for ingestion pipelines
- **Git** for version control
- **Dagster** for orchestration

See [[case-studies]] for real examples of problems solved with this stack.

### Progress

- Built 100+ dbt models across 4 markets (UK, DE, IT, JP)
- Created 50+ Dagster assets for orchestration
- Automated daily refresh replacing manual runs
- Integrated with Tableau Server for business delivery

### What Changed

The difference wasn't just tools — it was **having a system**.

Before: Scattered SQL files, undocumented Python scripts, tribal knowledge. 
After: One repo, version controlled, self-documenting, onboardable.

Along the way, I solved a number of [[challenges|technical challenges]] — DuckDB concurrency, European CSV dialects, safe file operations.

---

## Era 4: The Realisation

**Present**

Every good project needs an exit strategy. But sometimes the exit isn't a handover — it's an honest assessment of your own position.

### The Honest Truth

I built a modern data stack. It works. It's faster, cleaner, more maintainable than what existed before.

But driving platform-level change requires more than a working solution. It requires sustained advocacy, the right timing, and enough political capital to shepherd something through an organisation. As an individual contributor, I only have so much influence — and there are competing priorities, other ways of working, and market pressures that reasonably take precedence.

### What I've Learned About Change

Technical solutions don't adopt themselves. Organisational change requires:

- The right timing and business context
- Someone with the positional authority to champion it
- Bandwidth from teams who would need to adopt new workflows
- Alignment with broader strategic priorities

None of this is a criticism — it's just reality. People have different learning preferences, different comfort levels with new tooling, and different views on what "good enough" looks like. That's normal. My job was to build something that worked; whether it gets adopted is a separate question that depends on factors beyond my control.

### What This Project Becomes

This portfolio. Proof that I can:

- Identify infrastructure problems
- Research and evaluate solutions
- Build a working system from scratch
- Document it for others to understand

Regardless of where the MDS lands organisationally, it demonstrates a transferable capability set. The learning compounds regardless of adoption.

---

## The Lesson

The best infrastructure often comes from practitioners who felt a problem acutely and built a solution.

But building something isn't the same as getting it adopted. Influence and timing matter as much as technical quality — and those aren't always within your control.

If you're in Era 2 right now — exploring options, trying things that don't work — keep going. The learning compounds, even if adoption doesn't follow immediately.

And if you build something great that doesn't get picked up? That's not failure. That's proof of capability — and it travels with you.

---
