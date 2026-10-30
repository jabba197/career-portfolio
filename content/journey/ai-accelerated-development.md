---
title: "AI-Accelerated Development"
description: "How I used Claude Code to build faster and learn deeper"
created: 2025-11-30
modified: 2026-10-30
---

## The Honest Truth

I built this platform with significant help from AI assistants - primarily Claude Code. Rather than hide this, I think it's worth discussing openly because:

1. **AI-assisted development is the future** - Engineers who leverage AI effectively will outpace those who don't
2. **It's a skill in itself** - Getting useful output from AI requires clear communication and good prompts
3. **The learning was real** - AI accelerated my understanding, it didn't replace it

## How I Used AI in This Project

### 1. Rapid Prototyping

When exploring a new approach, I could iterate through ideas in minutes instead of hours.

**Example:** Designing the [[tableau|Tableau]] export factory pattern

> "I have 10 Tableau exports that all follow the same pattern. Each is a separate [[dagster|Dagster]] asset with ~50 lines of code. I want to make this configuration-driven. Show me a factory pattern approach."

AI generated an initial design. I refined it, asked follow-up questions about edge cases, and arrived at a working solution in an afternoon instead of days. See [[case-studies#Case Study 2 Flag-Based Tableau Exports|the case study]] for the full story.

### 2. Learning New Technologies

I hadn't used [[dagster|Dagster]] before this project (I later retired it, in May 2026). AI served as an always-available tutor.

**Example:** Understanding Dagster's asset dependencies

> "In Dagster, what's the difference between using `deps` parameter vs `AssetIn`? When should I use each?"

Instead of reading through documentation for an hour, I got a targeted explanation and could ask follow-up questions.

### 3. Debugging Unfamiliar Errors

[[duckdb|DuckDB]], [[dagster|Dagster]], and [[dbt|dbt]] each have their quirks. AI helped me understand errors faster.

**Example:** DuckDB CSV parsing failures

> "I'm getting 'could not automatically detect CSV parsing dialect' for German market files. The files use semicolons as delimiters. How do I handle this in [[duckdb|DuckDB]]?"

See [[challenges#Challenge 4 European CSV Dialect Handling|the challenges page]] for how this was solved.

### 4. Writing Documentation as I Code

The `CLAUDE.md` file in this repo serves two purposes:
- Gives AI context about the project
- Documents the project for human readers

This means documentation stays current because it's actively used, not an afterthought.

## The CLAUDE.md Approach

I maintain a comprehensive `CLAUDE.md` file at the project root. Key sections:

| Section | Purpose |
|---------|---------|
| Project Overview | High-level context for AI and humans |
| Key Commands | How to run things (AI can execute, humans can copy) |
| Querying DuckDB | Syntax gotchas that trip up AI (and humans) |
| Architecture Overview | Where things live, how they connect |
| Development Guidelines | Coding standards, patterns to follow |
| Data Quality Rules | Business logic that must be applied |

### Why This Works

When I start a coding session, the AI already knows:
- This is a Windows environment
- [[duckdb|DuckDB]] queries need specific syntax (see [[dbt-duckdb|dbt on DuckDB]])
- Customer IDs overlap between markets (see [[challenges#Challenge 2 Cross-Market Customer Identity|identity challenges]])
- Model SQL uses DuckDB's native functions; [[dbt|dbt]] packages are for tests only

I don't have to explain context repeatedly. I can just say "add a new dbt staging model for the UK events table" and get something useful.

## AI-Friendly Coding Patterns

I've developed habits that make AI assistance more effective:

### Explicit Over Implicit

```python
# AI understands this immediately
def sync_azure_to_parquet(
    market: str,
    folder_name: str,
    days_back: int = 30
) -> dict:
    """
    Sync data from Azure Blob Storage to local Parquet files.

    Args:
        market: Market code (UK, DE, IT, JP)
        folder_name: Azure folder to sync
        days_back: How many days of data to fetch

    Returns:
        Dictionary with sync statistics
    """
```

### Configuration Over Code

When logic is in config files, AI can modify behavior without touching Python:

```python
# tableau_exports.py - AI can add exports here easily
COMMERCIAL_EXPORTS = [
    TableauExport(name="orderline_attributes", ...),
    TableauExport(name="daily_reactivants", ...),
    # AI: "Add a new export for vendor_performance"
]
```

### Clear Error Messages

```python
if not source_path.exists():
    raise FileNotFoundError(
        f"Source data not found at {source_path}. "
        f"Run 'python scripts/sync_azure.py --market UK' first."
    )
```

AI can read these and suggest fixes. Vague errors waste everyone's time.

## 2026: AI Agents Working in the Repo

The way I use AI changed in 2026. It is no longer only a tutor and a pair programmer. AI agents now do real work inside the repo: they write and change models, run checks, investigate failures and draft commentary. A peer analyst produces reports end to end with an agent working in the same codebase.

That only works because agents follow the same rules and tests as a person.

### Rules Written Down

- **`CLAUDE.md` is a short contract**, not a manual. It holds the operating rules every session needs: how to run dbt, how to size a query for this machine, the data rules that must never be broken.
- **Deep knowledge lives in a knowledge bundle**: over 100 pages of design notes, methods and past incidents, linked from the contract. When a rule and a deep page disagree, the rule wins and the page gets fixed.
- **Procedures live in skills**: packaged instructions for one kind of task, such as managing the schedule, sending notifications or working in Synapse. Each topic has one home, so knowledge is not copied into several places to drift.

### Guardrails Learned the Hard Way

- **Agents do not commit or push unless the brief names the exact files.** This rule came after an agent swept unreviewed work in progress onto the shared main branch. Commits now stage explicit paths only.
- **On a database lock, wait; never kill.** A "stuck" process may be a two-hour build. Agents read through the read-only query broker, which waits through locks and says who holds them.
- **Size every query for the machine.** The rules on memory-heavy queries apply to agents too, and heavy analysis runs as a small number of narrow, read-only background agents.
- **Keep tool output small.** One oversized result once broke a whole session, so outputs are capped and large results go to files.

### Tests as the Safety Net

- **Data tests** guard grain, ranges, freshness and currency conversion, so a wrong number fails a test before it reaches a report, whoever wrote the model.
- **A rule check** fails when a model re-types a business rule by hand instead of using its one shared definition. A rule that had been copied into about fifteen places had drifted between the copies.
- **The run-history database records who ran each build**, a person or an agent, so I can see what agents built and how long it took.

### AI in Operations

When a scheduled phase fails, an AI step reads its log, writes a post-mortem and files a triage note. It sorts the failure into one of three kinds: something it can fix, something that needs a deeper read-only investigation, or something only a human can resolve (credentials, infrastructure, upstream data). A fix is limited to the files named in the diagnosis and is never committed: it can't run dbt, touch secrets or delete files. I review every change.

### What I Learned

- **An agent is only as safe as the rules around it.** The value came from writing the rules down and backing them with tests, not from the model.
- **Every incident becomes a rule.** Most of the guardrails above exist because something went wrong once.

## What AI Can't Do (Yet)

### Business Context

AI doesn't know that:
- German markets use semicolons in CSVs (cultural convention)
- Customer IDs overlap between markets (business decision from years ago)
- The commercial team needs its core data before the working day starts (an SLA)

I had to provide this context explicitly.

### Architecture Intuition

AI can implement patterns, but choosing the right pattern requires understanding:
- Team capabilities
- Infrastructure constraints
- Business priorities
- Technical debt tolerance

These decisions remained mine.

### Production Operations

AI helped write the code. But:
- Monitoring for failures
- Investigating data quality issues
- Coordinating with stakeholders

Still require human judgment and relationships.

## My Advice for AI-Assisted Development

### 1. Invest in Context Files

A good `CLAUDE.md` or `AGENTS.md` pays dividends across every session.

### 2. Be Specific About Constraints

Don't say "write a data pipeline." Say "write a [[python-pipelines|Python pipeline]] that reads from Azure Blob, handles semicolon-delimited CSVs, and outputs to Parquet on a Windows network drive."

### 3. Iterate in Conversation

First output is rarely final. Ask follow-up questions:
- "What if the file is empty?"
- "How would this handle 10 million rows?"
- "Can you add logging?"

### 4. Verify Understanding, Not Just Code

When AI explains something, restate it in your own words. If you can't, you haven't learned it - you've just copied it.

### 5. Use AI to Learn, Not Just Produce

The goal isn't to produce code faster. It's to become a better engineer faster.

## Productivity Impact

| Task Type | Without AI | With AI | Notes |
|-----------|------------|---------|-------|
| New [[dbt|dbt]] model | 30-60 min | 5-15 min | Still need to understand the data |
| Debug unfamiliar error | Variable | Usually < 10 min | AI as tutor |
| Write tests | 15-30 min | 5 min | Boilerplate heavy |
| Documentation | Often skipped | Generated with code | Stays current |
| Learn new tool | Days | Hours | Targeted Q&A |

## Related

- [[journey/index|The Journey]] — The full story from frustrated analyst to platform builder
- [[dagster|Dagster]] — The orchestration layer AI helped me learn, and why I retired it
- [[dbt|dbt]] — Transformation architecture developed iteratively with AI
- [[challenges|Challenges]] — Technical problems where AI accelerated debugging
- [[case-studies|Case Studies]] — Real outcomes from AI-assisted development
