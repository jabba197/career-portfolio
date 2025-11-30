---
title: "How-To Guides"
description: "Practical patterns and solutions for common data problems"
---

## What This Is

These are lessons I've learned solving real problems at QVC. They're written from my experience — mostly Python, dbt, and DuckDB — but the underlying principles often transfer to other tools.

If you use R, Excel, or something else entirely, the concepts might still help even if the code doesn't.

## The Guides

| Guide | Problem It Solves |
|-------|-------------------|
| [[hyper-api\|Automating Tableau Extracts]] | How to publish data to Tableau Server without opening Tableau Desktop |
| [[transformation-layer\|Building a Transformation Layer]] | How to structure transformations so you're not starting from scratch every time |
| [[local-large-data\|Working with Large Data Locally]] | How to handle datasets that push against your laptop's RAM limits |

*More guides coming as I document what I've learned.*

---

## How These Are Structured

Each guide follows a simple format:

1. **The Problem** — What you're trying to solve
2. **Why It Matters** — Why the obvious approach doesn't work
3. **The Solution** — What I did
4. **The Code** — Examples you can adapt
5. **Related** — Links to deeper context in the [[stack/index|Stack]] or [[journey/index|Journey]]

---

## A Note on Tool Choices

I use Python, dbt, and DuckDB because they solved my specific constraints (no cloud access, 16GB laptop, read-only Oracle). Your constraints might be different.

Where possible, I'll note alternatives:
- If you're using **R**, DuckDB has an R package
- If you're using **Excel/Power Query**, some patterns translate
- If you have **cloud access**, you probably have better options than I did

The goal is to share what worked, not to prescribe what you should use.
