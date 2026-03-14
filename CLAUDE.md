# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quartz v4 is a static site generator for publishing digital gardens and personal notes as websites. It transforms Markdown content into a fully-featured website with search, graph visualization, and backlinks.

## Requirements

- Node.js 22+ (see `.node-version`)
- npm 10.9.2+

## Common Commands

```bash
# Install dependencies
npm install

# Type check and format check
npm run check

# Format code
npm run format

# Run tests
npm test

# Build and serve locally (development)
npx quartz build --serve

# Alternative dev server with auto-restart
./serve.sh

# Build documentation
npm run docs

# Build with bundle analysis
npx quartz build --bundleInfo
```

## Architecture

### Plugin-Based Content Pipeline

Content flows through three plugin types in `quartz/plugins/`:

1. **Transformers** (`transformers/`): Process content (parse frontmatter, syntax highlighting, link resolution)
2. **Filters** (`filters/`): Include/exclude content (draft removal, explicit publish)
3. **Emitters** (`emitters/`): Generate output (HTML pages, RSS feeds, sitemap, search index)

### Key Directories

- `quartz/build.ts` - Main build orchestrator
- `quartz/cfg.ts` - Configuration type definitions
- `quartz/components/` - Preact UI components with associated styles and client scripts
- `quartz/processors/` - Content processing stages (parse → filter → emit)
- `quartz/util/path.ts` - Path manipulation and slug generation (critical for routing)

### User Configuration

- `quartz.config.ts` - Site configuration (title, plugins, theme)
- `quartz.layout.ts` - Page layout component arrangement

### Component Structure

Components in `quartz/components/` follow this pattern:
- Main `.tsx` file exports a Preact component
- Optional `scripts/*.inline.ts` for client-side JavaScript
- Optional `styles/*.scss` for component styling
- Components receive `QuartzComponentProps` with build context

## Code Style

- TypeScript with strict mode (no unused variables/parameters)
- Prettier formatting: 100 char width, no semicolons, trailing commas
- ES Modules throughout (`"type": "module"`)
- Preact for UI (JSX with `react-jsx` pragma)

## Content Voice & Vocabulary

This portfolio is public-facing, targeting analytics engineering roles at UK fintechs. Use language that mirrors how modern data teams talk about their work.

**Prefer → Avoid:**
- "data products" → "reports" or "dashboards"
- "enabling self-serve analytics" → "building dashboards for people"
- "enabling teams" → "doing analysis for teams"
- "software engineering best practices applied to data" → "modern tools"
- "version-controlled, tested, documented" → "clean" or "professional"
- "founding analytics engineer" or "first mover" → "solo builder" or "lone wolf"

**Framing principles:**
- Lead with what stakeholders can do now, not what you built
- Describe decisions and trade-offs, not just outcomes
- DuckDB was constraint-driven (no cloud budget, no server access), not ideological — make this clear where relevant
- No internal names. Use roles ("a peer analyst", "UK market leadership", "the BI team")
- No internal politics or frustrations. Honest but professional
- Blog tone, not business document

## PR Guidelines

Follow Conventional Commits: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`
