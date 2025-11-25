---
title: "Architecture Overview"
description: "End-to-end data platform design"
---

## High-Level Architecture

<!-- TODO: Add detailed architecture diagram -->
<!-- TODO: Explain design decisions -->

## Data Flow

```{mermaid}
flowchart TD
    subgraph "Data Sources"
        A1[Azure Blob Storage]
        A2[Oracle Database]
        A3[SharePoint Files]
    end

    subgraph "Ingestion Layer"
        B1[azure_to_parquet.py]
        B2[Legacy SQL Scripts]
        B3[Budget Ingest]
    end

    subgraph "Storage Layer"
        C1[Parquet Files<br/>Network Drive]
        C2[DuckDB<br/>Analytical DB]
    end

    subgraph "Transformation Layer"
        D1[Staging Views]
        D2[Intermediate Views]
        D3[Mart Tables]
    end

    subgraph "Serving Layer"
        E1[Tableau Server]
        E2[CSV Extracts]
        E3[Direct Queries]
    end

    A1 --> B1
    A2 --> B2
    A3 --> B3
    B1 --> C1
    B2 --> C1
    B3 --> C1
    C1 --> C2
    C2 --> D1
    D1 --> D2
    D2 --> D3
    D3 --> E1
    D3 --> E2
    D3 --> E3
```

## Design Principles

<!-- TODO: Document key design decisions -->

### 1. Configuration Over Code

### 2. Explicit Dependencies

### 3. Fail-Safe Operations

### 4. Multi-Market Support

## Schema Strategy

<!-- TODO: Explain the two-schema approach -->

- `main_qi_data_lake` - Source data only
- `main` - All DBT models

## Key Technical Decisions

<!-- TODO: Document trade-offs -->

| Decision | Why | Trade-off |
|----------|-----|-----------|
| DuckDB over Postgres | Analytical workload, no server needed | Single-process limitation |
| Views for staging | Reduce storage, always fresh | Query-time compute |
| Tables for marts | Performance for dashboards | Storage cost |
