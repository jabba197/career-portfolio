---
title: "Working with Large Data on Local Hardware"
description: "How to handle datasets that push against your laptop's RAM limits without cloud infrastructure"
---

## The Problem

You've got a dataset that's larger than your laptop can comfortably handle. Maybe it's 5GB, maybe it's 15GB — not "big data" by industry standards, but big enough that your 16GB machine starts struggling.

The obvious approaches don't work:

- **Excel** — Opens slowly, crashes on large files, struggles past a million rows
- **Pandas** — Loads everything into memory; a 10GB CSV needs 10GB+ of RAM just to open
- **Power Query** — Streams data, but sorts and aggregations still need the full dataset in memory
- **"Just use the cloud"** — Not always an option, and overkill for medium-sized data anyway

This guide is for analysts who need to work with medium-to-large datasets on constrained hardware — the laptop you've been issued.

## Why It Matters

At QVC, most tables aren't massive. The full historical orders table is perhaps 10-15GB as Parquet files. That's not an insurmountable volume.

But the moment you want to:
- Join orders with product information
- Add customer attributes
- Filter to a specific brand and aggregate by week
- Build a dataset for long-term analysis

...your 16GB laptop becomes a constraint. You're not doing "big data" work — you're just trying to do normal analyst work on data that's slightly larger than your tools expect.

I've been through the progression: Pandas (memory errors), Dask (technically works but fragile), and eventually DuckDB (reliable, fast, just works). This guide captures what I've learned.

## The Fundamentals

Before choosing a tool, understand what actually affects performance:

### 1. File Format

The format you store data in matters more than you might think.

| Format | Compression | Column Access | Type Info | Best For |
|--------|-------------|---------------|-----------|----------|
| **CSV** | None | Must read all | None | Small files, interchange |
| **Excel** | Some | Must read all | Limited | Sharing with non-technical users |
| **Parquet** | High | Read only needed columns | Full | Anything large |

**Parquet wins** for any serious data work:
- **Compressed**: 10GB of CSV might become 2GB of Parquet
- **Columnar**: Query only `order_date` and `revenue`? Only those columns are read from disk
- **Metadata**: The file header knows min/max values per column, enabling fast filtering
- **Typed**: No guessing whether "1234" is a number or text

> [!tip] Converting to Parquet
> Most tools can write Parquet directly. In DuckDB:
> ```sql
> COPY (SELECT * FROM 'data.csv') TO 'data.parquet' (FORMAT PARQUET);
> ```

> [!warning] Excel Can't Read Parquet
> Excel has no native Parquet support. If your final output needs to go to Excel, you'll need to export back to CSV or use a tool like DuckDB to query the Parquet and write to CSV/Excel format. Parquet is for working with data efficiently — not for sharing with Excel users.

### 2. Storage Location

Where your data lives affects how fast you can read it:

| Location | Speed | Notes |
|----------|-------|-------|
| **Local SSD** | Fast | Best option for working data |
| **Local HDD** | Moderate | Still fine for most work |
| **Network drive** | Slower | Acceptable; latency adds up on large scans |
| **SharePoint/OneDrive** | Variable | Fine for final outputs; slow for iterative work |

If you're doing repeated queries on the same data, copy it locally first. The initial copy takes time; every subsequent query is faster.

### 3. In-Memory vs Out-of-Core

This is the key distinction:

**In-memory tools** (Pandas, Excel) load all data into RAM before doing anything. If your data is 12GB and you have 16GB RAM, you'll likely crash because the OS and other applications need memory too.

**Out-of-core tools** (DuckDB, Polars with streaming) process data in chunks, spilling to disk when needed. They can handle datasets larger than your available RAM.

| Tool | In-Memory or Out-of-Core | Notes |
|------|--------------------------|-------|
| Excel | In-memory | Hard limit around 1M rows anyway |
| Pandas | In-memory | Will crash on large data |
| Power Query | Streaming (partial) | Filters stream; sorts/aggregations need full data |
| Dask | Out-of-core | Works but can be fragile |
| DuckDB | Out-of-core | Reliable, fast, my recommendation |
| Polars | Out-of-core (streaming mode) | Good alternative to DuckDB |

## The Tools

### DuckDB — The Standard Recommendation

DuckDB is an in-process analytical database. In practical terms: it lets you query files with SQL, handles larger-than-memory data gracefully, and runs entirely on your machine.

**Why it wins:**
- **SQL interface** — If you know SQL, you know DuckDB
- **Reads Parquet/CSV directly** — No loading step; query files in place
- **Out-of-core execution** — Spills to disk automatically when memory is tight
- **Fast** — Optimised for analytical queries; often 10-100x faster than Pandas

**Getting started (Python):**
```python
import duckdb

# Query a Parquet file directly
result = duckdb.sql("""
    SELECT order_date, SUM(revenue) as total_revenue
    FROM 'orders.parquet'
    WHERE brand = 'ELEMIS'
    GROUP BY order_date
""").df()
```

**Getting started (SQL only):**
```bash
# Install DuckDB CLI
# Then just run queries
duckdb -c "SELECT COUNT(*) FROM 'orders.parquet'"
```

**Performance comparison** (from my notes):

| Query | Oracle (production DB) | DuckDB (local Parquet) |
|-------|------------------------|------------------------|
| Daily revenue, all orders | 5 minutes | 3 seconds |
| Daily revenue, filtered to brand | 30+ minutes | 3 seconds |

The Oracle queries were hitting a production transactional database over the network. DuckDB was reading local Parquet files. Not an apples-to-apples comparison, but representative of what you'll actually experience.

> [!info] R Users
> DuckDB has excellent R support. Install the `duckdb` package and use `dbConnect(duckdb::duckdb())` to get a connection.

### Polars — The DataFrame Alternative

If you prefer DataFrame syntax over SQL, Polars is a strong alternative. Think of it as Pandas, but faster and with out-of-core support. It's a Rust-based DataFrame library with Python bindings, designed from the ground up for performance.

**Key features:**
- **Lazy execution** — Instead of executing each operation immediately (like Pandas), Polars builds up a query plan and optimises it before running. This means it can skip unnecessary work, reorder operations, and push filters down to the data source.
- **Streaming mode** — Process larger-than-memory data in chunks
- **Fast** — Often 10-50x faster than Pandas, even on data that fits in memory

**Basic usage:**
```python
import polars as pl

# Lazy query on Parquet
result = (
    pl.scan_parquet("orders.parquet")  # Lazy - doesn't load yet
    .filter(pl.col("brand") == "ELEMIS")
    .group_by("order_date")
    .agg(pl.col("revenue").sum())
    .collect()  # Execute the query
)
```

**Streaming for larger-than-memory:**
```python
# For data that won't fit in RAM
result = (
    pl.scan_parquet("huge_file.parquet")
    .filter(pl.col("year") >= 2020)
    .group_by("category")
    .agg(pl.col("sales").sum())
    .collect(streaming=True)  # Process in batches
)
```

> [!warning] Streaming Limitations
> Not all operations support streaming. Sorts and some aggregations may still require fitting intermediate results in memory. Polars will fall back to non-streaming mode when needed.

**When to choose Polars over DuckDB:**
- You prefer method chaining to SQL
- You're building data pipelines where intermediate DataFrames are useful
- You need tight integration with the Python ecosystem

**When to choose DuckDB:**
- You already know SQL
- You want to query files without writing Python
- You're integrating with dbt or other SQL-based tools

Both are excellent. I default to DuckDB because SQL is universal and it integrates well with dbt, but Polars is a perfectly valid choice.

### What About Dask?

Dask extends Pandas to work on larger-than-memory data using parallel and out-of-core computation.

In my experience: it works, but it's fragile. Operations that should be simple sometimes fail with cryptic errors. The debugging experience is poor compared to DuckDB or Polars.

If Dask is already working for you, keep using it. But if you're starting fresh, I'd recommend DuckDB or Polars instead.

### Excel-Only Users

If Python or R aren't options for you, the path forward is harder but not impossible:

1. **Power Query** — Built into Excel, can handle larger datasets than raw Excel. Filter early, avoid sorting until the end, and don't pull more columns than you need.

2. **DuckDB Excel add-ins** — These exist but aren't widely used in corporate environments yet. Worth exploring if you can install add-ins.

3. **Ask someone with Python/DuckDB to prepare the data** — Have them filter and aggregate down to a size Excel can handle, then work from there.

## Best Practices

### 1. Only Load What You Need

Every column you don't need is wasted memory and I/O. Every row you don't need is wasted compute.

```sql
-- Bad: loads everything
SELECT * FROM 'orders.parquet'

-- Good: loads only what's needed
SELECT order_date, revenue
FROM 'orders.parquet'
WHERE order_date >= '2024-01-01'
```

With Parquet, this isn't just good practice — it's how the format is designed. DuckDB will only read the columns you ask for.

### 2. Filter Early

Push filters as close to the data source as possible:

```sql
-- Bad: loads all data, then filters
SELECT order_date, SUM(revenue)
FROM (
    SELECT * FROM 'orders.parquet'
)
WHERE brand = 'ELEMIS'
GROUP BY order_date

-- Good: filter at the source (DuckDB optimises this anyway, but be explicit)
SELECT order_date, SUM(revenue)
FROM 'orders.parquet'
WHERE brand = 'ELEMIS'
GROUP BY order_date
```

### 3. Don't Over-Pre-Compute

A trap I fell into: thinking "I have this powerful engine, so I should pre-compute everything — last year metrics, rolling averages, year-over-year comparisons."

The result? Larger datasets, longer build times, and marginal benefit.

**Tableau and Excel are good at simple aggregations.** If your visualisation tool can do the calculation efficiently, let it. Pre-compute only when:
- The calculation is expensive (complex window functions)
- The raw data is too large for the viz tool to handle
- Multiple reports need the same calculated field

Building `revenue_ly`, `revenue_last_4_weeks`, `revenue_ytd` for every row often just inflates your output and slows down your pipeline — and the end tool would have calculated it anyway.

### 4. Stage Your Data

For complex analysis, build intermediate datasets:

```
Raw Parquet (10GB)
      ↓ Filter to last 3 years
Filtered Parquet (4GB)
      ↓ Add product attributes
Enriched Parquet (5GB)
      ↓ Aggregate to weekly
Weekly Summary (100MB)
      ↓ Export to Tableau
```

Each stage is a checkpoint. If something goes wrong at the aggregation step, you don't re-run the extraction. See [[transformation-layer|Building a Transformation Layer]] for how to structure this.

## Quick Reference

| Situation | Recommendation |
|-----------|----------------|
| Large CSV, need to query it | Convert to Parquet, use DuckDB |
| Python user, prefer DataFrames | Use Polars with lazy evaluation |
| SQL user, need out-of-core | Use DuckDB |
| R user, large data | Use DuckDB with R bindings |
| Excel-only, large data | Use Power Query; filter aggressively |
| Data doesn't fit in RAM | DuckDB or Polars streaming mode |
| Need to share results | Export final output to Parquet or CSV |

## Related

- [[duckdb|DuckDB]] — Detailed documentation on DuckDB in our stack
- [[parquet-lake|The Parquet Data Lake]] — How we store data for efficient access
- [[transformation-layer|Building a Transformation Layer]] — Structuring your data transformations
- [[challenges|Challenges]] — Other problems solved along the way

## Further Reading

- [DuckDB Documentation](https://duckdb.org/docs/)
- [Polars User Guide](https://pola.rs/)
- [Streaming in Polars](https://www.rhosignal.com/posts/streaming-in-polars/) — Deep dive on Polars streaming mode
- [Handling Larger-than-Memory Datasets with Polars](https://python-bloggers.com/2025/06/handling-larger-than-memory-datasets-with-polars-lazyframe/)
