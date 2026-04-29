# the-interview — Makefile
#
# Usage: make <target> [ENV=production]
#
# Environment:
#   ENV        Rails environment (default: development)

ENV ?= development
export RAILS_ENV := $(ENV)

# ============================================================================
# Setup & Installation
# ============================================================================

.PHONY: setup install
setup install: ## Install dependencies, create database, run migrations
	@echo "==> Installing gem dependencies..."
	bundle install
	@echo "==> Creating database..."
	bin/rails db:create
	@echo "==> Running migrations..."
	bin/rails db:migrate
	@echo "==> Seeding database..."
	bin/rails db:seed || true
	@echo "==> Setup complete."

.PHONY: deps
deps: ## Install gem dependencies only
	bundle install

# ============================================================================
# Development Server
# ============================================================================

.PHONY: dev server
dev: ## Run web server + Solid Queue workers (concurrent)
	bin/dev

server: ## Run web server only (Puma)
	bin/rails server

# ============================================================================
# Background Jobs
# ============================================================================

.PHONY: jobs jobs-clear jobs-stats
jobs: ## Run Solid Queue workers
	bin/jobs

jobs-clear: ## Clear all job queues
	bin/rails db:queue:reset

jobs-stats: ## Show queue statistics
	bin/rails solid_queue:stats

# ============================================================================
# Database
# ============================================================================

.PHONY: migrate migrate-status rollback
migrate: ## Run pending database migrations
	bin/rails db:migrate

migrate-status: ## Show migration status
	bin/rails db:migrate:status

rollback: ## Rollback last migration
	bin/rails db:rollback

.PHONY: db-reset db-seed db-drop
db-reset: ## Drop, create, and migrate database
	bin/rails db:drop db:create db:migrate

db-seed: ## Run seed data
	bin/rails db:seed

db-drop: ## Drop the database
	bin/rails db:drop

# ============================================================================
# Console
# ============================================================================

.PHONY: console console-prod
console: ## Open Rails console
	bin/rails console

console-prod: ## Open production Rails console
	RAILS_ENV=production bin/rails console

# ============================================================================
# Testing
# ============================================================================

.PHONY: test test-fast test-coverage test-failed
test: ## Run full test suite with coverage
	bin/rails db:test:prepare
	bin/rspec --format progress

test-fast: ## Run tests without coverage overhead
	bin/rails db:test:prepare
	SIMPLECOV=off bin/rspec --format progress

test-coverage: ## Run tests and open coverage report
	bin/rails db:test:prepare
	bin/rspec --format progress
	@echo "==> Coverage report: coverage/index.html"
	open coverage/index.html 2>/dev/null || true

test-failed: ## Rerun previously failed tests
	bin/rspec --only-failures --format progress

# ============================================================================
# Code Quality — Linting & Formatting
# ============================================================================

.PHONY: lint lint-check lint-fix format
lint: ## Run RuboCop with auto-correct
	bin/rubocop -a

lint-check: ## Run RuboCop (check only, no changes)
	bin/rubocop

lint-fix: ## Run RuboCop with auto-correct (alias for lint)
	bin/rubocop -a

format: ## Format code (alias for lint)
	bin/rubocop -a

# ============================================================================
# Code Quality — Security
# ============================================================================

.PHONY: security
security: ## Run all security scanners
	@echo "==> Running Brakeman..."
	bin/brakeman --no-pager
	@echo "==> Running bundler-audit..."
	bin/bundler-audit
	@echo "==> Running importmap audit..."
	bin/importmap audit
	@echo "==> All security checks passed."

# ============================================================================
# Code Quality — Combined
# ============================================================================

.PHONY: quality check
quality check: ## Run lint + security + tests
	@echo "==> Running lint check..."
	bin/rubocop
	@echo "==> Running security scans..."
	bin/brakeman --no-pager --exit-on-warn
	bin/bundler-audit --update
	bin/importmap audit
	@echo "==> Running tests..."
	bin/rspec --format progress
	@echo "==> All checks passed."

# ============================================================================
# Type Checking
# ============================================================================

.PHONY: typecheck typecheck-autocorrect
typecheck: ## Run Sorbet type check
	bundle exec srb tc

typecheck-autocorrect: ## Run Sorbet with autocorrect
	bundle exec srb tc --autocorrect

# ============================================================================
# Sorbet / Tapioca
# ============================================================================

.PHONY: tapioca-gem tapioca-dsl tapioca-init
tapioca-gem: ## Regenerate gem RBI files
	bundle exec tapioca gem

tapioca-dsl: ## Regenerate DSL RBI files
	bundle exec tapioca dsl

tapioca-init: ## Run full Tapioca initialization
	bundle exec tapioca init

# ============================================================================
# CI
# ============================================================================

.PHONY: ci
ci: ## Run full CI pipeline locally
	@echo "==> Lint check..."
	bin/rubocop
	@echo "==> Security scans..."
	bin/brakeman --no-pager --exit-on-warn
	bin/bundler-audit --update
	bin/importmap audit
	@echo "==> Tests..."
	bin/rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml
	@echo "==> Type check..."
	bundle exec srb tc || echo "⚠️  Sorbet has errors (expected during gradual adoption)"
	@echo "==> CI complete."

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: ## Remove temporary files
	rm -rf tmp/cache/*
	rm -rf log/*.log
	rm -rf coverage/
	rm -rf storage/

# ============================================================================
# Help
# ============================================================================

.PHONY: help
help: ## Show this help
	@echo "the-interview — Makefile targets"
	@echo ""
	@grep -E '^[a-zA-Z].*:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' | \
		sort

.DEFAULT_GOAL := help
