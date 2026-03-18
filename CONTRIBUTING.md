# Contributing to Inboxed

First off — thanks for taking the time. Inboxed is a small project built to scratch a real developer itch, and contributions from people who've felt the same pain are genuinely welcome.

---

## Before You Start

**Check existing issues first.** Someone may already be working on what you have in mind. If you're planning something non-trivial, open an issue to discuss it before writing code — saves everyone time.

**This is a dev tool, not a production email server.** Keep that in mind when proposing features. Deliverability, bulk sending, unsubscribe management — those are out of scope. Testing, inspection, and automation are in scope.

---

## What We Welcome

- Bug fixes (always welcome, no discussion needed)
- MCP tool additions for new use cases
- Dashboard UX improvements
- Documentation fixes and examples
- Performance improvements to the SMTP receiver
- SDK/helper integrations — Playwright, RSpec, pytest, Cypress, k6, etc.

## What We're Cautious About

- Large architectural changes — discuss in an issue first
- Features that blur the line between testing tool and production email server
- Dependencies that add significant bundle weight
- Changes to the public API contract without a migration path

---

## Development Setup

### Option A: Dev Container (recommended)

The easiest way to get started. Works with VS Code or GitHub Codespaces.

```bash
git clone https://github.com/rodacato/inboxed
code inboxed/
# Then: Cmd+Shift+P → "Dev Containers: Reopen in Container"
```

The Dev Container installs Ruby 3.3, Node.js 22, PostgreSQL, and Redis automatically. All ports are forwarded.

### Option B: Manual Setup

#### Prerequisites
- Ruby 3.3+
- Node.js 22+
- Docker + Docker Compose (for PostgreSQL and Redis)
- PostgreSQL 16 (or use Docker)

#### Getting Started

```bash
git clone https://github.com/rodacato/inboxed
cd inboxed

# Start PostgreSQL and Redis
docker compose up db redis -d

# Install Ruby dependencies
cd apps/api && bundle install && cd ../..

# Install Node dependencies (dashboard + MCP)
cd apps/dashboard && npm install && cd ../..
cd apps/mcp && npm install && cd ../..

# Copy and configure environment
cp .env.example .env
# Edit .env with local settings

# Setup database
cd apps/api && bin/rails db:create db:migrate && cd ../..

# Start all services (API, SMTP, dashboard, MCP)
bin/dev
```

### Running Tests

```bash
# Ruby (API)
cd apps/api && bundle exec rspec

# MCP server
cd apps/mcp && npm test

# Dashboard
cd apps/dashboard && npm run check
```

---

## Code Style

**Ruby:** Standard Ruby style. Run `bundle exec standardrb` before committing. No cops are disabled without a comment explaining why.

**TypeScript (MCP + Dashboard):** ESLint + Prettier. `npm run lint` before committing.

**CSS:** Tailwind utility classes only. No custom CSS unless there's a compelling reason. Document it if you add it.

**Commits:** Conventional commits preferred but not enforced.
```
feat: add extract_link MCP tool
fix: prevent duplicate emails with same message-id
docs: add pytest integration example
chore: bump ruby to 3.3.4
```

---

## Pull Request Process

1. Fork → branch from `master` → PR back to `master`
2. Branch naming: `feat/mcp-extract-link`, `fix/duplicate-message-id`, `docs/pytest-example`
3. Include tests for new behavior. Bug fixes should include a regression test.
4. Update docs if you're changing behavior or adding features
5. Keep PRs focused — one thing per PR
6. The PR description should explain *why*, not just *what*

### PR Checklist

- [ ] Tests pass
- [ ] New behavior has tests
- [ ] Docs updated if needed
- [ ] No debug code / console.log left in
- [ ] `.env.example` updated if new env vars added
- [ ] `CHANGELOG.md` entry added for user-facing changes

---

## Reporting Bugs

Use GitHub Issues. Include:

- Inboxed version (or commit hash)
- How you're running it (Docker Compose / Dev Container / bare metal)
- What you expected vs what happened
- Minimal reproduction steps
- Relevant logs (redact any API keys or personal data)

---

## Security Issues

**Do not open a public issue for security vulnerabilities.** See [SECURITY.md](SECURITY.md) for the responsible disclosure process.

---

## Questions

Open a GitHub Discussion. Issues are for bugs and concrete feature requests — for general questions, discussions are the right place.
