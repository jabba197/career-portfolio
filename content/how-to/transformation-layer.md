---
title: "Building a Transformation Layer"
description: "How to structure your data transformations so you're not starting from scratch every time"
---

## The Problem

Every analyst has been here: you need a dataset, so you write a script. It pulls from the source, does some joins, filters out the bad rows, calculates a few fields, and outputs a CSV or a table. It works.

Then you need a similar dataset for a different report. So you copy the script, tweak it, and run it again.

Six months later, you have:
- 15 scripts that all pull from the same source
- Slightly different versions of the same logic
- No idea which script is the "right" one
- A bug fix that needs to be applied to all 15 scripts (but you'll miss a few)

This is the absence of a transformation layer.

## What Is a Transformation Layer?

A transformation layer is the structured code that sits between your raw data and your final outputs.

```
Raw Data (Oracle, CSVs, APIs)
        ↓
   [Transformation Layer]
        ↓
Final Outputs (Tableau, Reports, Analysis)
```

Instead of each output having its own bespoke script pulling directly from source, you build reusable intermediate datasets that multiple outputs can share.

```
Raw Data
    ↓
[Staging: Clean, standardise]
    ↓
[Intermediate: Join, enrich, business logic]
    ↓
[Marts: Final shapes for specific use cases]
    ↓
Multiple Outputs (all using the same trusted data)
```

## Why It Matters

### Without a Transformation Layer

- **Repeated work** — Every new report starts from scratch
- **Inconsistent logic** — "How did we calculate revenue again?" varies by script
- **Fragile changes** — Fix a bug in one place, forget to fix it in 10 others
- **No testing** — You only find out data is wrong when someone complains
- **Tribal knowledge** — Only you know how your scripts work

### With a Transformation Layer

- **Build once, reuse many times** — The orders table exists once, used everywhere
- **Single source of truth** — Revenue is calculated one way, in one place
- **Change once, fix everywhere** — Update the logic in one model, all downstream outputs get the fix
- **Built-in testing** — Null checks, row counts, value ranges run automatically
- **Self-documenting** — The structure itself explains the data flow

## Key Principles

### 1. Don't Repeat Yourself (DRY)

If you're writing the same join or the same filter in multiple places, that logic should live in one place.

**Before (repeated logic):**
```
Script A: SELECT * FROM orders WHERE status != 'cancelled' AND date > '2024-01-01'
Script B: SELECT * FROM orders WHERE status != 'cancelled' AND date > '2024-01-01'
Script C: SELECT * FROM orders WHERE status <> 'cancelled' AND date > '2024-01-01'  -- subtle difference!
```

**After (single source):**
```
Intermediate model: int_orders_valid
  → Filters out cancelled, applies date logic, standardises fields

Script A, B, C: SELECT * FROM int_orders_valid
```

### 2. Layer Your Transformations

Don't try to do everything in one massive query. Break it into stages:

| Layer | Purpose | Example |
|-------|---------|---------|
| **Staging** | Clean and standardise raw data | Rename columns, cast types, handle nulls |
| **Intermediate** | Join sources, apply business logic | Combine orders with products and customers |
| **Marts** | Shape for specific use cases | Aggregated for finance, detailed for ops |

Each layer builds on the previous one. If the source data changes, you fix it in staging — everything downstream benefits.

### 3. Make It Testable

A transformation layer lets you add checks:
- **Not null** — Critical fields should never be empty
- **Unique** — Primary keys shouldn't have duplicates
- **Accepted values** — Status should only be 'active', 'cancelled', 'pending'
- **Row counts** — Did we lose data somewhere?
- **Referential integrity** — Every order should have a valid customer

Without a transformation layer, these checks happen in your head (or not at all).

### 4. Version Control Everything

Your transformation logic is code. It should be:
- In Git (or similar)
- Reviewed before changes go live
- Rollback-able if something breaks

This is hard to do with scattered Excel files or ad-hoc Python scripts.

### 5. Separate Logic from Execution

The *what* (business logic) should be separate from the *how* (orchestration, scheduling).

This means you can:
- Run transformations manually while developing
- Schedule them automatically in production
- Test changes without affecting live data

## What This Looks Like in Practice

### If You're Using SQL/dbt

dbt is one popular tool for this. Each transformation is a SQL file that references other models:

```sql
-- int_orders_with_products.sql
SELECT
    o.order_id,
    o.order_date,
    o.customer_id,
    p.product_name,
    p.category,
    o.quantity * p.price AS line_total
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_products') }} p ON o.product_id = p.product_id
```

The `{{ ref() }}` function creates dependencies — dbt knows to run `stg_orders` and `stg_products` before this model.

### If You're Using Python/Pandas

The same principles apply. Instead of one giant script:

```python
# staging/stg_orders.py
def get_stg_orders():
    df = pd.read_parquet('raw_orders.parquet')
    df = df.rename(columns={'ord_id': 'order_id', 'ord_dt': 'order_date'})
    df = df[df['status'] != 'cancelled']
    return df

# intermediate/int_orders_with_products.py
def get_int_orders_with_products():
    orders = get_stg_orders()
    products = get_stg_products()
    return orders.merge(products, on='product_id')

# marts/mrt_daily_sales.py
def get_mrt_daily_sales():
    df = get_int_orders_with_products()
    return df.groupby('order_date').agg({'line_total': 'sum'})
```

The structure is the same — layered, reusable, testable.

### If You're Using R

Same pattern:

```r
# staging/stg_orders.R
get_stg_orders <- function() {
  df <- read_parquet("raw_orders.parquet")
  df <- df %>%
    rename(order_id = ord_id, order_date = ord_dt) %>%
    filter(status != "cancelled")
  return(df)
}

# Use it downstream
orders <- get_stg_orders()
```

### If You're Using Excel/Power Query

The concept still applies, though the tooling is different:
- Use named tables and queries
- Build queries that reference other queries (Power Query lets you do this)
- Keep a "staging" workbook that cleans raw data
- Reference the clean data from analysis workbooks

Excel has limits for large datasets, but the principle of layered, reusable transformations still helps.

## The Payoff

Once you have a transformation layer:

| Task | Without | With |
|------|---------|------|
| New report using existing data | Write new script from scratch | Query from existing mart |
| Fix a calculation bug | Find and update every script | Fix once, rebuild downstream |
| Add a new data source | Integrate into every script | Add to staging, join in intermediate |
| Someone else needs your data | Explain your script, hope they understand | Point them to the model |

## Honest Limitations

Building a transformation layer takes time upfront. If you're doing a one-off analysis that will never be repeated, it might not be worth it.

But if you're:
- Building reports that refresh regularly
- Sharing data with colleagues
- Working with datasets you'll query again
- Tired of "which version is correct?"

...then the investment pays off quickly.

## What I Use

I use [[dbt|dbt]] with [[duckdb|DuckDB]] for my transformation layer. dbt handles the structure (staging → intermediate → marts), the dependencies, and the testing. DuckDB handles the actual query execution.

This isn't the only option. The concepts here apply regardless of tool:
- **dbt + any database** — The standard for modern analytics engineering
- **SQLMesh** — A dbt alternative with some different trade-offs
- **Python + functions** — Build your own structure
- **R + targets** — The R ecosystem has workflow tools too

The tool matters less than the principle: **structure your transformations so you're not starting from scratch every time**.

## Related

- [[dbt|dbt in the MDS]] — How I implemented this with dbt
- [[duckdb|DuckDB]] — The database powering the transformations
- [[stack/index|The Stack]] — How the transformation layer fits into the broader architecture
