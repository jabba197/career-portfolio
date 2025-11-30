---
title: "Challenges"
description: "Problems solved and lessons learned"
---

Technical obstacles encountered while building the MDS, and how I solved them. For business impact metrics, see [[case-studies|Case Studies]].

---

## Challenge 1: DuckDB Concurrency in Orchestration

**Problem:**

DuckDB is a single-process database. When Dagster tried to run multiple DBT jobs concurrently, they competed for locks on the same DuckDB file, causing failures and data corruption risks.

**Solution:**

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

Added DBT tests to catch violations:

```yaml
# schema.yml
models:
  - name: fct_orders
    tests:
      - unique:
          column_name: "market || '_' || member_no || '_' || order_no"
```

Documented the pattern prominently in CLAUDE.md so AI assistants and new developers don't make the same mistake.

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

---

## Themes Across Challenges

Looking back, these challenges share common patterns:

1. **Constraints are features** - Corporate restrictions forced simpler, more maintainable solutions
2. **Defensive coding matters** - Production systems fail; the question is whether they recover gracefully
3. **Documentation is code** - CLAUDE.md and inline comments prevented recurring mistakes
4. **Test your assumptions** - Customer IDs, CSV formats, concurrency—all seemed obvious until they weren't
