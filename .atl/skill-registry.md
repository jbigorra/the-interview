# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

See `_shared/skill-resolver.md` for the full resolution protocol.

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| Go tests, Bubbletea TUI testing, teatest | go-testing | ~/.config/opencode/skills/go-testing/SKILL.md |
| GitHub issue, bug report, feature request | issue-creation | ~/.config/opencode/skills/issue-creation/SKILL.md |
| Pull request, PR, branch for review | branch-pr | ~/.config/opencode/skills/branch-pr/SKILL.md |
| Create new AI skill, agent instructions | skill-creator | ~/.config/opencode/skills/skill-creator/SKILL.md |
| "judgment day", adversarial review, dual review | judgment-day | ~/.config/opencode/skills/judgment-day/SKILL.md |
| Ruby/Rails code, service objects, .call pattern | ruby-service-objects | ~/.config/opencode/skills/ruby-service-objects/SKILL.md |
| RSpec tests, TDD, first failing spec | rails-tdd-slices | ~/.config/opencode/skills/rails-tdd-slices/SKILL.md |
| Write test, RSpec, test-driven, spec type | rspec-best-practices | ~/.config/opencode/skills/rspec-best-practices/SKILL.md |
| Rails code review, PR review, Rails Way | rails-code-review | ~/.config/opencode/skills/rails-code-review/SKILL.md |
| Rails conventions, clean code, DRY/YAGNI | rails-code-conventions | ~/.config/opencode/skills/rails-code-conventions/SKILL.md |
| Rails migrations, zero-downtime, add column | rails-migration-safety | ~/.config/opencode/skills/rails-migration-safety/SKILL.md |
| Rails background jobs, Active Job, Sidekiq | rails-background-jobs | ~/.config/opencode/skills/rails-background-jobs/SKILL.md |
| Rails authorization, Pundit, CanCanCan, roles | rails-authorization-policies | ~/.config/opencode/skills/rails-authorization-policies/SKILL.md |
| Rails Hotwire, Turbo, Stimulus, frames | rails-frontend-hotwire | ~/.config/opencode/skills/rails-frontend-hotwire/SKILL.md |
| Rails responding to review feedback | rails-review-response | ~/.config/opencode/skills/rails-review-response/SKILL.md |
| YARD, inline docs, method documentation | yard-documentation | ~/.config/opencode/skills/yard-documentation/SKILL.md |
| DDD, shared vocabulary, define terms, bounded context | ddd-ubiquitous-language | ~/.config/opencode/skills/ddd-ubiquitous-language/SKILL.md |
| Context boundaries, language leakage, ownership | ddd-boundaries-review | ~/.config/opencode/skills/ddd-boundaries-review/SKILL.md |
| Aggregate, value object, domain event, DDD | ddd-rails-modeling | ~/.config/opencode/skills/ddd-rails-modeling/SKILL.md |

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### go-testing
- Use table-driven tests for pure functions and multi-case scenarios
- Test Bubbletea TUI: `Model.Update()` directly for state, `teatest.NewTestModel()` for flows
- Golden file testing for visual output — compare against saved `.golden` files
- Mock `os/exec` via interface + mock; use `t.TempDir()` for file operations
- Commands: `go test ./...`, `go test -v`, `go test -cover`, `go test -short`

### issue-creation
- Blank issues disabled — MUST use template (Bug Report or Feature Request)
- Every issue gets `status:needs-review` automatically on creation
- Maintainer MUST add `status:approved` before any PR can be opened
- Questions go to Discussions, not issues
- Search for duplicates before creating; use `gh issue create --template`

### branch-pr
- Every PR MUST link an approved issue with `status:approved` label
- Every PR MUST have exactly one `type:*` label
- Branch names: `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)\/[a-z0-9._-]+$`
- Conventional commits required: `type(scope): description`
- Run shellcheck on modified scripts before pushing

### skill-creator
- Create skill when pattern repeats, conventions differ, or workflow is complex
- Don't create for trivial, one-off, or already-documented patterns
- Structure: `skills/{name}/SKILL.md` + `assets/` (templates) + `references/` (local docs)
- Frontmatter required: name, description (with Trigger), license, metadata.author, metadata.version
- `references/` points to LOCAL files, not web URLs

### judgment-day
- Launch TWO blind judge sub-agents in parallel via `delegate` (async) — NEVER sequential
- Neither judge knows about the other; identical criteria, independent findings
- Synthesize: Confirmed (both), Suspect (one), Contradiction (disagree)
- WARNING classification: "Can normal user trigger?" YES→real, NO→theoretical (report as INFO)
- After 2 fix iterations, ASK user before continuing; never escalate automatically
- Orchestrator NEVER reviews code itself — only coordinates judges and synthesizes

### ruby-service-objects
- Entry point: `def self.call(...) → new(...).call` — ≤20 lines in `call`
- Response contract: `{ success: true/false, response: { ... } }` — NO booleans, raw models
- Error handling: `rescue` → log + error hash; never re-raise to caller
- YARD on `self.call` AND every public method: `@param`, `@return [Hash]`, `@raise` per exception
- Module README required at `app/services/<module>/README.md` even for single-service modules
- Error messages as UPPER_SNAKE_CASE constants, never inline in rescue
- Patterns: `.call→new.call` (orchestration), Batch (per-item rescue), Class-only (static), Orchestrator (≤20 lines)
- TESTS GATE: spec written and failing BEFORE implementation

### rails-tdd-slices
- Start at highest-value boundary that proves behavior with least setup
- API contract → request spec; Domain rule → model spec; Orchestration → service spec; Async → job spec; Browser flow → system spec
- HARD-GATE: run spec, verify failure is because behavior missing (not setup error)
- Excessive factory setup = wrong boundary; simplify or move slice
- Never default to request specs for everything or model specs for controller behavior
- After failing spec: present for test design review before implementation
- Hand off: `rspec-best-practices` for TDD loop, `rspec-service-testing` for service specs

### rspec-best-practices
- Spec types: Model (domain), Request (HTTP, prefer over controller), Job (background), System (E2E only, slow)
- TDD: write failing spec → run → confirm failure → minimum code → refactor → verify full suite
- Factories: minimal, use `build`/`build_stubbed` over `create`, traits for optional states
- NO "and" in example descriptions — split into separate examples (most-missed rule)
- `let` default, `let!` ONLY when object must exist before action; no `let_it_be` without test-prof
- External boundaries mocked at class-method level; ActiveRecord finders NEVER mocked
- Service specs: `describe '.call'` + `subject(:result)` required
- Time-dependent: `freeze_time`/`travel_to`; async: `queue_adapter = :test` + `have_enqueued_job`
- One behavior per example; `change.from().to()` over final state assertions

### rails-code-review
- Review order: Config → Routing → Controllers → Views → Models → Associations → Queries → Migrations → Validations → Security → Caching → Jobs → Tests
- ALWAYS Critical (block merge): `permit!`, `html_safe`/`raw` on user content, missing auth check, business logic in controller, unparameterized SQL, destructive migration on large tables
- Severity labels ONLY: `Critical` | `Suggestion` | `Nice to have` — no High/Low, P0-P2
- Output: group by severity, `[file:line] (Area)` + risk + `Mitigation:` required, cover ≥4 areas
- Re-review mandatory after any Critical fix; recommended after 3+ Suggestion fixes
- Anti-patterns: thin controller→fat model (extract to services), N+1 hidden by small seeds, callbacks vs jobs

### rails-code-conventions
- Principles: DRY, YAGNI, PORO where helpful, CoC, KISS
- Logging MANDATORY shape: `Rails.logger.level(static_string, { event: "dot.namespaced", ... })` — no interpolation in 1st arg
- Error rescue: log `e.message` AND `e.backtrace.first(5).join("\n")` — backtrace non-optional
- Comments: explain WHY not WHAT; tagged notes (TODO/FIXME/HACK/NOTE/OPTIMIZE) require actionable context (owner, ticket, deadline)
- RSpec: `let` > `let!`; request over controller specs; FactoryBot; no `let_it_be` without test-prof
- Detect linter first (rubocop/standard/eslint); defer style to project config
- Tests gate: no implementation before failing test

### rails-migration-safety
- NEVER combine schema change + data backfill in one migration
- Add nullable column first → backfill later → enforce NOT NULL last
- Add indexes concurrently on large tables: `algorithm: :concurrent` (PG) / `:inplace` (MySQL)
- Rename column: add new → copy data → migrate callers → drop old
- Remove column: remove code references FIRST, then drop column
- Deploy code that tolerates both old and new schemas during transitions
- If project uses `strong_migrations`, follow it; otherwise apply same rules manually
- Output: list risks first with failure mode, safer rollout, rollback strategy

### rails-background-jobs
- Pass IDs not objects — load fresh in `perform`
- EVERY job needs idempotency check before side effect ("already done?" guard)
- `perform` does 3 things only: load record → guard for idempotency → delegate to service
- `retry_on` for transient errors (with `attempts:` limit); `discard_on` for permanent errors
- Rails 8: Solid Queue (database-backed, `config/recurring.yml`); Rails 7: Sidekiq + Redis
- Recurring jobs: `config/recurring.yml` (Solid Queue) or sidekiq-cron
- TESTS GATE: job spec written and failing before implementation
- Verify: enqueue twice → second run is no-op; confirm retry/discard config

### rails-authorization-policies
- ALWAYS test with multiple roles (admin, user, guest)
- NEVER inline authorization logic in controllers — use policy objects
- Pundit: explicit policy classes per resource; `authorize @record` + `policy_scope(Model)`
- CanCanCan: centralized Ability class; `authorize! :action, @record` + `accessible_by(current_ability)`
- Verify: attempt unauthorized action → confirm `Pundit::NotAuthorizedError` or `CanCan::AccessDenied`
- Cover every role in both policy specs and request specs

### rails-frontend-hotwire
- HARD-GATE: start with HTML-only, enhance progressively; test without JavaScript first
- NEVER use Turbo Frames for full page navigation
- Workflow: plain HTML → identify update regions (`turbo_frame_tag`) → add Frames/Streams → layer Stimulus → verify degraded mode
- Turbo Streams: `turbo_stream.append/replace/update` for server-side changes via ActionCable
- Stimulus: attach controllers only where JS needed beyond Turbo; register in `app/javascript/controllers/index.js`
- Validate: DevTools Network tab confirms `text/vnd.turbo-stream.html` responses

### rails-review-response
- HARD-GATE: READ all feedback → UNDERSTAND → VERIFY against codebase → EVALUATE → RESPOND → IMPLEMENT one at a time → RE-REVIEW
- FORBIDDEN: "You're absolutely right!", "Great point!", "I'll fix all" — performative, skips verification
- Classify feedback: Correct+Critical (fix immediately), Correct+Suggestion (fix or ticket), Incorrect (push back with evidence), Ambiguous (clarify first)
- Push back structure: acknowledge concern → explain codebase constraint → propose alternative
- Re-review mandatory after Critical fixes or 3+ Suggestion logic changes; skip for cosmetic only
- Implementation order: clarify ambiguous → Critical → simple fixes → complex changes → test each → full suite

### yard-documentation
- Every public class and method MUST have YARD: `@param`, `@return`, `@raise`
- `self.call` return tag MUST specify `{ success: Boolean, response: Hash }` structure
- One `@raise` per exception class — even if rescued internally
- Use `@option` for every valid key in hash params
- Include at least one `@example` on `.call` or main entry point
- All YARD text in English unless user explicitly requests otherwise
- Verify: `yard stats --list-undoc` → `yard doc` → confirm no undocumented surfaces changed

### ddd-ubiquitous-language
- Pick ONE business term for ONE concept; capture synonyms, choose preferred term
- Flag overloaded words early; split meanings explicitly
- Output: glossary with canonical term, aliases, definition, invariant, context, open questions
- Scan Rails class/module names across layers to collect terms
- DO NOT introduce DDD terminology without grounding in real domain language
- Chain to `ddd-boundaries-review` when glossary reveals multiple contexts

### ddd-boundaries-review
- Fix context leakage before adding more patterns
- Map entry points (controllers, jobs, services, APIs) → name contexts by business capability → find leakage
- Use ripgrep to find cross-context references before manual reading
- DO NOT recommend splitting unless business boundary is explicit enough to name
- Output per finding: severity, contexts involved, leaked term, why risky, smallest credible improvement
- DO NOT treat every large module as a bounded context automatically

### ddd-rails-modeling
- Model real domain pressure, not textbook DDD vocabulary
- Entity → ActiveRecord model; Value object → PORO (immutable, equality by value); Aggregate root → model guarding invariants
- Domain service → PORO for behavior spanning multiple entities; Application service → orchestrator in `app/services/`
- Repository → ONLY when real persistence boundary beyond ActiveRecord (rare)
- Domain event → explicit object when multiple downstream consumers justify it
- DO NOT introduce repositories/aggregates/events just to sound "DDD"
- DO NOT fight Rails defaults when normal model/service expresses domain clearly

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| AGENTS.md | ~/.config/opencode/AGENTS.md | Index — persona, skills auto-load table, engram protocol |

Read the convention files listed above for project-specific patterns and rules.

## SDD Context

- **Project**: the-interview
- **Mode**: engram
- **Strict TDD**: enabled (pending Rails setup)
- **Init observation ID**: 28 (topic_key: `sdd-init/the-interview`)
- **Testing capabilities ID**: 29 (topic_key: `sdd/the-interview/testing-capabilities`)
- **Stack**: Ruby on Rails (new project — not yet initialized)
- **Intent**: Job posting search + kanban board for lead management
