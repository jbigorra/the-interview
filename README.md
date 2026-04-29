# the-interview

Job search automation tool. Discovers jobs via Google (ATS portals), matches them using a hybrid keyword/LLM engine, manages the pipeline in a Kanban board, and assists with applications.

## Stack

| Component | Technology |
|-----------|------------|
| **Language** | Ruby 3.4.2 |
| **Framework** | Rails 8.1.3 |
| **Database** | PostgreSQL 17 |
| **Frontend** | Hotwire/Turbo + Stimulus + Tailwind CSS + SortableJS |
| **Background Jobs** | Solid Queue (database-backed, no Redis) |
| **LLM** | ruby_llm (Claude Haiku 4.5 via Anthropic) |
| **Job Discovery** | SerpApi (Google search) |
| **Testing** | RSpec + FactoryBot + VCR + WebMock |
| **Static Analysis** | Brakeman, bundler-audit, RuboCop, Sorbet (WIP) |

## Quick Start

```bash
# Install dependencies
make setup

# Run the full stack (web + workers)
make dev

# Run in a specific environment
make dev ENV=production

# Run only the web server
make server

# Run only background workers
make jobs
```

## Prerequisites

- **Ruby** 3.4+ (managed by mise)
- **PostgreSQL** 17 (`brew install postgresql@17 && brew services start postgresql@17`)
- **Node.js** (for Tailwind compilation)

## Configuration

### Environment Variables

Create a `.env` file (or export in your shell):

| Variable | Required | Description |
|----------|----------|-------------|
| `SERPAPI_API_KEY` | Yes | SerpApi key for Google search integration |
| `ANTHROPIC_API_KEY` | Yes (for LLM matching) | Anthropic API key for Claude Haiku |
| `OPENAI_API_KEY` | No | Optional, for OpenAI models |
| `RAILS_ENV` | No | Environment (default: `development`) |

### Setup

```bash
make setup
```

This will:
1. Install gem dependencies
2. Create the database
3. Run migrations
4. Seed initial data

## Development

### Running the Application

```bash
make dev          # Web server + Solid Queue workers (concurrent)
make server       # Web server only
make jobs         # Solid Queue workers only
```

### Database

```bash
make migrate          # Run pending migrations
make migrate:status   # Show migration status
make rollback         # Rollback last migration
make db:reset         # Drop, create, and migrate
make db:seed          # Run seed data
```

### Testing

```bash
make test             # Run full test suite
make test:fast        # Run tests without coverage
make test:coverage    # Run tests with SimpleCov report
make test:failed      # Rerun failed tests
```

Coverage reports are written to `coverage/index.html`.

### Code Quality

```bash
make lint             # Run RuboCop (auto-correct)
make lint:check       # Run RuboCop (check only, no changes)
make lint:fix         # Run RuboCop with auto-correct
make security         # Run Brakeman + bundler-audit + importmap audit
make format           # Run RuboCop auto-correct (alias for lint:fix)
make quality          # Run lint + security checks
```

### Type Checking

```bash
make typecheck        # Run Sorbet type check
make typecheck:autocorrect  # Run Sorbet with autocorrect
```

> **Note**: Sorbet is in gradual adoption mode. Some errors are expected until Tapioca RBI files are fully configured.

### Background Jobs

```bash
make jobs             # Start Solid Queue workers
make jobs:clear       # Clear all queues
make jobs:stats       # Show queue statistics
```

### Console

```bash
make console          # Rails console
make console:prod     # Production console
```

## Architecture

### Job Discovery Pipeline

```
Google Queries → SerpApi → ATS URLs → AtsDetector → Lead Creation
                                                    ↓
                                        Stage1MatchingJob (keyword filter)
                                                    ↓
                                        ATS Enrichment (full descriptions)
                                                    ↓
                                        Stage2MatchingJob (Claude Haiku LLM)
                                                    ↓
                                        Kanban Board (drag-and-drop)
                                                    ↓
                                        Apply Review → Submit
```

### Supported ATS Platforms

| Platform | Discovery | Apply Adapter |
|----------|-----------|---------------|
| Greenhouse | ✅ Public API | ✅ Standard fields |
| Lever | ✅ Public API | ✅ Standard fields |
| Ashby | ✅ Public API | ✅ Standard fields |
| Jobvite | ⚠️ URL detection only | ❌ Not yet |
| Workday | ⚠️ URL detection only | ❌ Not yet |
| LinkedIn | ❌ Deferred | ❌ Deferred |

### Matching Engine

Two-stage hybrid pipeline:

1. **Stage 1** — Keyword filter (free, ~0ms). Checks required/excluded keywords against lead title + description. Eliminates 60-80% of leads.
2. **Stage 2** — LLM evaluation (~$0.002/eval via Claude Haiku). Scores 0-100 with reasoning, strengths, and concerns.

### Kanban Board Stages

| Stage | Description |
|-------|-------------|
| `fresh` | New lead, pending evaluation |
| `reviewed` | Passed matching, ready for review |
| `applied` | Application submitted |
| `interviewing` | Interview process started |
| `offered` | Offer received |
| `rejected` | Rejected by employer |
| `skipped` | Skipped by matching engine |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and PR:

| Job | Tool | Purpose |
|-----|------|---------|
| `scan_ruby` | Brakeman + bundler-audit | Ruby security scan |
| `scan_js` | importmap audit | JS dependency security |
| `lint` | RuboCop | Code style consistency |
| `test` | RSpec + PostgreSQL | Test suite |
| `typecheck` | Sorbet | Static type checking |

## Project Structure

```
app/
├── controllers/          # Rails controllers
├── jobs/                 # Solid Queue background jobs
├── models/               # ActiveRecord models
├── services/             # Service objects
│   ├── discovery/        # Job discovery (SerpApi, ATS fetchers)
│   ├── matching/         # Matching engine (keywords, LLM)
│   └── apply/            # Apply adapters (Greenhouse, Lever, Ashby)
├── views/                # ERB templates
│   ├── dashboard/        # Dashboard with stats and queries
│   ├── leads/            # Kanban board, lead detail, apply review
│   ├── notes/            # Notes partials and forms
│   ├── profiles/         # Profile and criteria settings
│   └── search_queries/   # Query CRUD forms
└── javascript/
    └── controllers/      # Stimulus controllers (Kanban, auto-dismiss)

spec/
├── factories/            # FactoryBot definitions
├── jobs/                 # Job specs
├── models/               # Model specs
├── requests/             # Request specs (controller integration)
├── services/             # Service specs
└── support/              # VCR, FactoryBot, time helpers
```

## License

Private. All rights reserved.
