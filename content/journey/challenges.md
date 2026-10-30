---
title: "Challenges"
description: "Problems solved and lessons learned"
created: 2025-11-30
modified: 2026-10-30
---

Technical obstacles encountered while building the MDS, and how I solved them. For business impact metrics, see [[case-studies|Case Studies]].

---

## Challenge 1: DuckDB Concurrency in Orchestration

**Problem:**

DuckDB is a single-process database. When Dagster tried to run multiple DBT jobs concurrently, they competed for locks on the same DuckDB file, causing failures and data corruption risks.

**Solution (2025):**

Implemented tag-based concurrency limits in Dagster's configuration:

```yaml
# dagster.yaml
run_coordinator:
  tag_concurrency_limits:
    - key: "dbt_duckdb"
      limit: 1
```

Every DBT-related asset gets tagged with `dbt_duckdb`, ensuring only one DuckDB operation runs at a time while allowing other non-DuckDB tasks to continue in parallel.

```python
@asset(
    name="build_daily_sales_models",
    op_tags={"dbt_duckdb": "true"}
)
def build_daily_sales_models(context):
    # DBT operations here
```

**Lesson Learned:**

Understanding your database's concurrency model is crucial when designing orchestration. DuckDB's single-writer limitation isn't a bug—it's a design choice for simplicity. The solution is to embrace it at the orchestration layer, not fight it.

**2026 update:** I retired Dagster in May 2026 (see [[dagster#Why I Retired It|why]]), and the single-writer rule moved into the jobs themselves. Jobs are spaced through the day, a task cannot start a second copy of itself, and a job that finds the database locked waits for it to free up. Reads were the remaining problem: an ad-hoc query that hit a write lock would hang. I built a small read-only query broker that queues, waits through locks, names the process holding the lock and times out cleanly. The rule for people and AI agents alike: on a lock, wait; never kill the holder, because it may be a two-hour build.

---

## Challenge 2: Cross-Market Customer Identity

**Problem:**

Customer IDs (`member_no`) overlap between markets. A UK customer with ID 12345 is a completely different person from a German customer with ID 12345. Early models that forgot this created nonsensical cross-market joins.

**Solution:**

Enforced a composite key pattern `(market, member_no)` across all models:

```sql
-- Every customer query must use both keys
SELECT
    market,
    member_no,
    COUNT(DISTINCT (market, member_no)) AS unique_customers
FROM orders
GROUP BY market, member_no
```

Added DBT tests to catch violations (2025 version; see below for today's):

```yaml
# schema.yml
models:
  - name: fct_orders
    tests:
      - unique:
          column_name: "market || '_' || member_no || '_' || order_no"
```

Documented the pattern prominently in CLAUDE.md so AI assistants and new developers don't make the same mistake.

Once test packages were available (2026), the concatenated-string test became `dbt_utils.unique_combination_of_columns` on `[market, member_no, order_no]`, which states the grain directly and cannot be fooled by a separator inside a value.

**Lesson Learned:**

Data modelling assumptions from source systems don't always translate to analytical contexts. When consolidating multiple systems, identity resolution must be explicit and tested—never assumed.

---

## Challenge 3: Corporate Network Restrictions

**Problem:**

Corporate firewalls and proxy settings blocked `pip install` for external packages. Couldn't install dbt-utils, dbt-expectations, or any community packages. SSL certificate errors added complexity to package management.

**Solution:**

Adopted a "no external packages" policy and implemented all transformations using DuckDB's native functions:

```sql
-- Instead of dbt_utils.surrogate_key
md5(concat_ws(chr(0), market, member_no, order_date)) AS unique_key

-- Instead of dbt_utils.date_spine
SELECT unnest(generate_series(
    DATE '2020-01-01', current_date, INTERVAL '1 day'
)) AS date

-- Instead of dbt_utils.pivot
PIVOT sales_data ON market USING SUM(revenue)
```

Created internal documentation mapping common dbt_utils functions to DuckDB equivalents.

**Lesson Learned:**

Constraints breed creativity. By not having access to packages, I learned DuckDB's native capabilities deeply. The resulting code is actually simpler and has no external dependencies to manage.

**2026 update:** I eventually found the root cause. The proxy re-signs TLS traffic, and newer Python versions apply stricter certificate checks, so two problems were stacked on top of each other. A small installer now handles both without switching certificate verification off, and the project uses `dbt_expectations` and `dbt_utils` for tests. Model SQL still uses DuckDB's native functions. The same certificate work was needed again when DuckDB 2.0 arrived in October 2026.

---

## Challenge 4: European CSV Dialect Handling

**Problem:**

German and Italian market data exports use semicolons as delimiters (EU convention), while UK uses commas. DuckDB's auto-detection sometimes failed, especially with edge cases like quoted fields containing the delimiter.

**Solution:**

Built a fallback parsing system that tries multiple dialect configurations:

```python
fallback_configs = [
    {'delim': ';', 'quote': '"', 'escape': '"'},   # EU standard
    {'delim': ';', 'strict_mode': False},           # EU lenient
    {'delim': ',', 'quote': '"', 'escape': '"'},   # UK/US standard
]

for config in fallback_configs:
    try:
        conn.execute(build_query(config))
        break  # Success, stop trying
    except Exception:
        continue  # Try next config
```

Added market-specific encoding handling (CP1252 for Windows-generated EU files).

**Lesson Learned:**

"Works on my machine" failures often come from regional data format differences. Build defensive parsing that handles the messiness of real-world data, not just clean test data.

---

## Challenge 5: Safe File Operations

**Problem:**

The pipeline overwrites Parquet files daily. If a write fails mid-operation, you're left with a corrupted file and no way to recover. Happened twice in production before we caught it.

**Solution:**

Implemented backup-before-write pattern:

```python
def process_blob(self, output_path):
    backup_path = None

    try:
        # Create backup before overwriting
        if output_path.exists():
            backup_path = output_path.with_suffix('.parquet.backup')
            shutil.copy2(output_path, backup_path)

        # Write new file
        conn.execute(f"COPY (...) TO '{output_path}'")

        # Verify output
        rows = conn.execute(f"SELECT COUNT(*) FROM '{output_path}'").fetchone()[0]
        if rows == 0:
            raise ValueError("Output has 0 rows")

        # Success - remove backup
        if backup_path and backup_path.exists():
            backup_path.unlink()

    except Exception:
        # Restore from backup on failure
        if backup_path and backup_path.exists():
            shutil.move(backup_path, output_path)
        raise
```

**Lesson Learned:**

Production data pipelines need the same defensive coding as any critical system. Always have a rollback path. Verify outputs before declaring success.

---

## Challenge 6: Single Point of Failure

**Problem:**

The entire data platform ran on one desktop machine. If that machine went offline, all data refreshes stopped. No redundancy, no monitoring, no alerts.

**Solution:**

Multi-pronged approach:

1. **State tracking**: Pipeline state stored in JSON files that can be picked up by any machine
2. **Stateless design**: Each pipeline run checks what's missing and processes only that
3. **Backup/restore procedures**: Documented recovery process tested monthly
4. **Monitoring**: Push notifications via ntfy on failures

```python
# State persisted to file, not memory
state = {
    'market': 'UK',
    'processed_files': ['file1.csv', 'file2.csv'],
    'last_sync': '2024-01-15T10:30:00',
    'total_rows_loaded': 15_000_000
}
```

**Lesson Learned:**

Grassroots projects can't wait for enterprise infrastructure. Build resilience into the design from day one, even with limited resources. Document everything so anyone can take over.

**2026 update:** it is still one desktop, now a 64 GB machine, but far less of a black box:

- **A run-history database** records every dbt build, with per-model timing, so "slow" and "stuck" can be told apart against a 30-day baseline.
- **A freshness gate** flags stale source feeds, and **a deliverables gate** flags any scheduled output that did not land.
- **Alerts go to phone and Teams**, and an AI step writes a post-mortem and a triage note for each failed phase. It can propose a fix, but never commits it; I review it.
- **The schedule lives in one manifest file**, so standing it up on a replacement machine is one command.
- **The database is backed up** to the network share after the morning run.
- **The knowledge is written down**: over 100 pages of design notes, rules and decisions live in the repo, so the system does not depend on what is in my head.

---

## Challenge 7: Network vs Local Build Strategy

**Problem:**

DuckDB is designed as a local-first database — ideally, the database file and source data live on the same machine. But our source Parquet files lived on network drives. This created a choice: build the database on the network (so others could access it), or build locally (for speed).

Initially, I tried building directly on the network drive. Multiple analysts wanted access to the same DuckDB file, and network storage seemed like the obvious solution. It wasn't.

**What I Tried:**

1. **Build on network** — Slow. DuckDB explicitly recommends against this due to the heavy I/O. Builds that should take minutes took much longer.

2. **Mirror network to local, then build** — Fastest option. Sync all Parquet files to local SSD, build the database there. But maintaining that mirror added operational overhead that wasn't worth it.

3. **Reference network, build locally** (final solution) — Source files stay on the network, but the DuckDB database file lives on the local SSD. This dramatically improved build times.

**The Materialisation Trick:**

The key insight was reducing repeated network reads. For large tables like orders (millions of rows), I materialise them once into DuckDB as staging tables:

```sql
-- stg_orders is materialised as a table, not a view
-- This pulls from network ONCE, then lives in DuckDB
{{ config(materialized='table') }}

SELECT * FROM read_parquet('//network/path/orders/*.parquet')
```

Subsequent intermediate and mart models reference `stg_orders` — which now lives locally in DuckDB — rather than pulling from network every time. It's a one-time transfer cost amortised across all downstream models.

**The Numbers:**

- Network speed: ~500 Mbps
- Local SSD: ~2000 Mbps (4x faster)
- But with staging tables materialised locally, the difference rarely mattered — most queries hit the local DuckDB, not the network

**Lesson Learned:**

DuckDB's local-first design isn't a limitation to work around — it's a feature to embrace. Rather than fighting the architecture (building on network), work with it: keep the database local, materialise large source tables once, and let DuckDB do what it's good at.

**2026 update:** option 2 came back. In July 2026 the network share began failing on file operations such as rename and delete, while bulk copies still worked, and the morning job kept failing on it. The source Parquet files moved to local disk, and the share became a best-effort mirror that can never fail a job. The materialisation trick also grew into a proper layer: persisted "refined" staging tables for the busiest sources, which analysis queries use instead of the views. See [[parquet-lake#Local-First Storage (2026)|Local-First Storage]].

---

## Challenge 8: Keeping One Machine Alive

**Problem:**

In mid-2026 the host shut down unexpectedly five times in under a month, with no crash dump. That pattern points to memory exhaustion, not a driver fault. A greedy query plan could use up the RAM and take the operating system with it, along with any build that was running.

**Solution:**

- **Headroom, not a tight cap.** dbt runs with a memory limit of 45 GB on the 64 GB box. DuckDB's limit only governs its buffer manager, so the process overshoots it; the remaining headroom keeps Windows alive. A very low limit is just as bad, because it forces heavy disk spill.
- **Size every query for the box.** No distinct counts or medians in a GROUP BY over 100M+ rows; aggregate in stages instead. Never join two very large tables twice in one query.
- **Query tables, not views.** Views over Parquet re-read every file each time.
- **Check free memory first,** and run one heavy job at a time.

**Lesson Learned:**

A bigger machine moves the limit; it does not remove it. On a single desktop, query design is capacity planning. See [[duckdb#DuckDB in 2026|DuckDB in 2026]].

---

## Themes Across Challenges

Looking back, these challenges share common patterns:

1. **Constraints are features** - Corporate restrictions forced simpler, more maintainable solutions
2. **Defensive coding matters** - Production systems fail; the question is whether they recover gracefully
3. **Documentation is code** - CLAUDE.md and inline comments prevented recurring mistakes
4. **Test your assumptions** - Customer IDs, CSV formats, concurrency—all seemed obvious until they weren't
5. **Silent failures are the dangerous ones** - Stale data that passes every test does more harm than a loud crash
