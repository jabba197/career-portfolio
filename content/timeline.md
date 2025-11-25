---
title: "The Journey"
description: "How this platform evolved from frustration to solution"
---

## Overview

This wasn't a planned project with a budget and a team. It was a grassroots effort born from frustration with legacy tools and a desire to do meaningful analytical work. Here's how it evolved.

---

## Era 1: The Analyst Phase

**January 2024 - June 2024**

Joined QVC UK as a Senior Commercial Analyst. Three months in, thrown into the deep end with the Customer Segmentation Dashboard project.

### The Landscape

- **Data lived in**: Oracle, Hyperion, scattered Excel files
- **Hardware**: 16GB RAM laptop, painful network speeds from home
- **My goal**: Prove myself as an analyst, deliver the dashboard

### The Project: Customer Segmentation Dashboard

A top-down mandate: classify customers into 5 segments and make this data available to the whole UK business.

**The awkward truth?** 80% of customers fell into just 2 of the 5 segments. The segmentation itself wasn't particularly useful. But the project was necessary - it was my job to make it work.

The dashboard showed:
- Sales by customer segment
- Customer counts by segment
- Product category breakdowns by segment

Nothing groundbreaking, but it needed to exist.

### Key Decision: Skip Hyperion

Hyperion was the "approved" tool for this kind of work. I opted out. It felt outdated, and I didn't want to invest time mastering a platform with no future. In hindsight, this was the right call.

### The Pain of Building the Dataset

I needed one big table: 2 years of order-level data with customer segments attached. The only way I knew how:

```
Oracle → SQL Extract → CSV → Python (Pandas/Dask) → Master Dataset → Tableau
```

**How long did this take?** A full day. Sometimes longer.

- Frequent crashes (16GB RAM + large datasets = bad time)
- Lots of waiting
- Dask helped, but only so much
- Every time I needed to rebuild, I lost a day

But it worked. The data got into Tableau, and building dashboards from a single denormalized table was actually pleasant.

### Pestering IT

I knew compute was the bottleneck. I wrote a formal business case to senior management:

> *"While a cloud-based infrastructure would be ideal, this is not feasible in the near term... The compute aspect remains an issue. Taking the Customer Segmentation dataset as an example, it currently takes two hours to generate the necessary dataset before any analysis can be undertaken."*

I asked for high-spec machines. I got a 7-year-old 32GB desktop. It was actually faster than my laptop. I took the win.

**Key insight from this era**: Network speed mattered. In the office: 4 seconds to access data. From home: 10+ minutes. Physical location was a performance variable.

### What I Learned

- The pattern worked: **extract → transform → serve**
- But it was manual, fragile, and took a full day to rebuild
- Hardware and network were real constraints, not excuses
- Seed planted: *"There has to be a better way"*

---

## Era 2: The Wilderness

**July 2024 - December 2024**

Returned from Malaysia. Lost the vision. Found frustration.

### The Problem

I wanted to be an impactful analyst. But I couldn't get the data I needed without heroic effort every time. The tooling was the bottleneck, not my analysis skills.

### The Response

What I called an "ego death" - a recalibration. Stopped trying to force the old tools to work. Started exploring what else was out there.

### The Search

- [ ] Discovered DBT - "wait, you can version control SQL?"
- [ ] Found DuckDB - "a database that just... runs? No server?"
- [ ] Explored BigQuery - "this would be perfect but... IT approval"
- [ ] Pestered IT for access to various tools
- [ ] Trial and error. Mostly error.

### What I Learned

- Corporate IT moves slowly (or not at all)
- Cloud solutions require approval chains I couldn't navigate
- Local-first tools (DuckDB) bypass a lot of bureaucracy
- This era felt unproductive, but I was building knowledge

---

## Era 3: The Acceleration

**January 2025 - Present (March 2025)**

Everything clicked. DBT + DuckDB inspired me to actually build something.

### The Moment It Clicked

I'd been reading about DBT and DuckDB for months. But in January 2025, I stopped reading and started building.

The first real model I built? **`int_orderline_attribute`**.

This was the DBT model that replaced my painful Era 1 pipeline. Same purpose - order-level data with product attributes for the Customer Segmentation Dashboard. But instead of a day of Python crashes, it ran in minutes. And it was version-controlled. And documented. And testable.

```
Era 1: Oracle → CSV → Python (crashes) → CSV → Tableau
       Time: 1 day. Reproducible: barely.

Era 3: Oracle → Parquet → DBT model → DuckDB → Tableau
       Time: ~20 minutes. Reproducible: always.
```

Seeing that transformation work - fast, clean, automated - was the proof I needed that this approach was worth investing in.

### The Solution Crystallized

**The Stack:**
- **DBT** for transformations and lineage
- **DuckDB** for fast analytical queries (no server needed)
- **Python** for ingestion pipelines
- **Git** for version control and collaboration
- **Dagster** for orchestration

**The Outcome:**
- Single codebase replacing scattered Excel/VBA/SQL files
- Data lineage you can actually trace
- Data dictionary that stays current (DBT docs)
- Governance built into the workflow, not bolted on

### Progress

- [ ] Built 100+ DBT models across 4 markets (UK, DE, IT, JP)
- [ ] Created 50+ Dagster assets for orchestration
- [ ] Automated daily refresh replacing manual runs
- [ ] Integrated with Tableau Server for business delivery
- [ ] Started training team members on the new approach
- [ ] Exploring MotherDuck for potential cloud hosting

### What Changed

The difference wasn't just tools - it was **having a system**.

Before: Scattered SQL files, undocumented Python scripts, tribal knowledge.
After: One repo, version controlled, self-documenting, onboardable.

---

## Era 4: The Realization

**Present**

Every good project needs an exit strategy. But sometimes the exit isn't a handover - it's an honest assessment.

### The Hard Truth

I built a modern data stack. It works. It's faster, cleaner, more maintainable than what existed before.

But QVC isn't in a position to adopt this kind of change. Not because the technology is wrong, but because organizational change requires the right leadership to champion it. And that person isn't me - I'm a senior analyst, not a data platform owner with executive backing.

### What I've Learned About Organizational Fit

A technical solution is necessary but not sufficient. You also need:

- [ ] Leadership buy-in at the right level
- [ ] Budget for ongoing maintenance
- [ ] Cultural readiness to change workflows
- [ ] Someone accountable for the platform long-term

QVC has none of these in place for a modern data stack. The legacy tools work "well enough" for most people. The pain I felt wasn't universal.

### The Ally: Kenan Salkic

Kenan was my counterpart on the UK team. We both joined recently. We both felt the pain of not having a proper data platform like BigQuery.

Every technical gain I discovered, he was on board to follow. Because the alternative for him was the same as for me: legacy tooling that felt ancient.

Having one person who understood the vision made a difference. But two analysts can't drive platform adoption.

### What This Project Becomes

This portfolio. Proof that I can:

- [ ] Identify infrastructure problems
- [ ] Research and evaluate solutions
- [ ] Build a working system from scratch
- [ ] Document it for others to understand

The MDS may not transform QVC. But it demonstrates capability I can take elsewhere - somewhere positioned to actually adopt modern tooling.

---

## The Lesson

The best infrastructure often comes from practitioners who got frustrated enough to build something better.

But building something isn't the same as getting it adopted. Organizational change is a different skillset - one that requires positional power, not just technical skill.

If you're in Era 2 right now - stuck, frustrated, trying things that don't work - keep going. The learning compounds, even if the organization doesn't change.

And if you build something great that your organization can't adopt? That's not failure. That's a portfolio piece and a signal that you've outgrown the environment.
