# Inboxed — Roadmap

> Development phases from zero to open-source release and beyond.

---

## Current State

- Monorepo structure created (`apps/web/`, `apps/mcp/`)
- Devcontainer configured (Ruby 3.3, Node 22, PostgreSQL 16, Redis 7)
- Project documentation and branding defined
- No application code yet

---

## Phase 0 — Foundation (Current)

Bootstrap the Rails app and core infrastructure inside the devcontainer.

- [ ] Generate Rails 8 app in `apps/web/`
- [ ] Configure `database.yml` for devcontainer PostgreSQL
- [ ] Run `db:create db:migrate`
- [ ] Add core gems: `midi-smtp-server`, `mail`, `solid_queue`, `bcrypt`, `rack-cors`
- [ ] Set up Procfile for dev (web + SMTP processes)
- [ ] Create production Dockerfile at `apps/web/Dockerfile`
- [ ] Initialize Node.js MCP project in `apps/mcp/`
- [ ] Configure `tsconfig.json` and build scripts for MCP

---

## Phase 1 — SMTP + Persistence

The core engine: receive emails and store them.

- [ ] **Data models:** `Project`, `Inbox`, `Email`, `Attachment`, `ApiKey`
- [ ] Add indexes: inbox address, email `created_at`, full-text search on subject/body
- [ ] **SMTP server** (`app/services/smtp_server.rb`) using `midi-smtp-server`
- [ ] MIME parsing: HTML, plain text, attachments, inline images
- [ ] TLS support: STARTTLS on 587, implicit TLS on 465
- [ ] SMTP AUTH: validate project API key on connection
- [ ] Reject mail for unregistered domains (no open relay)
- [ ] **Background jobs:** configure Solid Queue
- [ ] `EmailCleanupJob` — delete expired emails based on project TTL

**Exit criteria:** Send an email via `swaks` to the SMTP server, verify it's persisted in PostgreSQL.

---

## Phase 2 — REST API

Programmatic access to everything.

- [ ] `Api::V1::InboxesController` — index, show, destroy
- [ ] `Api::V1::EmailsController` — show, body, destroy
- [ ] `Api::V1::SearchController` — full-text search across inboxes
- [ ] `Api::V1::WaitController` — long-poll for incoming email (up to 30s)
- [ ] API key authentication via `Authorization: Bearer <key>` header
- [ ] Rate limiting (Rack::Attack or similar)
- [ ] Consistent error responses with useful messages
- [ ] API versioning strategy (v1 namespace)

**Exit criteria:** Full CRUD on emails via `curl`, including `wait` endpoint that blocks until a new email arrives.

---

## Phase 3 — Dashboard

Visual interface for inspecting emails.

- [ ] Set up Hotwire (Turbo + Stimulus) in the Rails app
- [ ] Inbox list view — grouped by email address
- [ ] Email detail view — metadata, HTML preview (sandboxed iframe), raw MIME source
- [ ] Full-text search UI
- [ ] Real-time updates via Turbo Streams + ActionCable
- [ ] Admin authentication with `INBOXED_ADMIN_TOKEN`
- [ ] Project management UI (create/edit projects, configure TTL)
- [ ] API key management UI (generate, revoke, label keys)
- [ ] Apply branding: dark terminal theme per `BRANDING.md`

**Exit criteria:** Open dashboard, see emails arrive in real-time, preview HTML, copy OTP from UI.

---

## Phase 4 — MCP Server

The key differentiator — AI agents can read emails without leaving their context.

- [ ] Initialize MCP server with `@modelcontextprotocol/sdk`
- [ ] Implement core tools:
  - `get_latest_email(inbox, subject_pattern?)`
  - `wait_for_email(inbox, subject_pattern, timeout_seconds)`
  - `extract_otp(inbox, pattern?)`
  - `extract_link(inbox, link_pattern?)`
  - `list_emails(inbox, limit)`
  - `delete_inbox(inbox)`
  - `search_emails(query)`
- [ ] Connect to Inboxed REST API as backend
- [ ] Create `apps/mcp/Dockerfile`
- [ ] Test with Claude Code and verify tool invocation works end-to-end

**Exit criteria:** Claude Code can `extract_otp` from an email sent 10 seconds ago, without the user leaving the conversation.

---

## Phase 5 — Testing Helpers

SDK integrations for popular test frameworks.

- [ ] **Playwright helper** (`@inboxed/playwright`):
  - `waitForEmail(inbox, options)`
  - `extractOtp(inbox)`
  - `extractLink(inbox, pattern)`
- [ ] **RSpec helper** (`inboxed-rspec` gem):
  - `Inboxed.wait_for_email(address, subject:)`
  - `Inboxed.extract_otp(address)`
  - Custom matchers: `expect(inbox).to have_email(subject: /verify/)`
- [ ] Integration test: send email via SMTP, fetch via API, verify in Playwright helper
- [ ] Publish npm package and Ruby gem (or document installation from source)

**Exit criteria:** A Playwright test signs up, extracts OTP via helper, and completes verification — fully deterministic, no sleeps.

---

## Phase 6 — Deploy & Self-Hosting

Make it runnable by anyone with a VPS.

- [ ] Production `docker-compose.yml` with all services
- [ ] DNS setup documentation (A, MX, SPF records)
- [ ] Kamal deploy configuration (`config/deploy.yml`)
- [ ] Health check endpoint (`/health`)
- [ ] Structured JSON logging (stdout)
- [ ] `.env.example` with all configuration options documented
- [ ] CI/CD with GitHub Actions (test + build + push Docker images)
- [ ] Multi-arch Docker builds (amd64 + arm64)

**Exit criteria:** A new user can go from `git clone` to receiving test emails in under 10 minutes.

---

## Phase 7 — Post-MVP Features

Backlog prioritized by user feedback after initial release.

| Feature | Priority | Description |
|---------|----------|-------------|
| **Webhooks** | High | HTTP POST on email received, with retry logic |
| **Routing rules** | Medium | Forward, drop, auto-reply based on from/to/subject patterns |
| **SMTP relay mode** | Medium | Capture + optional release to real SMTP |
| **CLI** | Medium | `inboxed list`, `inboxed wait`, `inboxed clear` |
| **Email HTML preview** | Low | Multi-client rendering simulation |
| **Load testing mode** | Low | Accept high volume, verify delivery stats |
| **Prometheus metrics** | Low | `/metrics` endpoint for observability |
| **Additional SDKs** | Low | Python (pytest), Cypress, k6 helpers |

---

## Milestones Summary

| Milestone | Phases | What it unlocks |
|-----------|--------|----------------|
| **Internal Alpha** | 0 + 1 + 2 | SMTP + API working, can be used from `curl` and test scripts |
| **Dogfood Ready** | + 3 | Dashboard for manual inspection, usable day-to-day |
| **Differentiator** | + 4 | MCP server live — no competitor has this |
| **Developer Ready** | + 5 | Test framework helpers, ready for other developers to adopt |
| **Public Launch** | + 6 | Self-hostable, documented, CI/CD, Docker images published |
| **Community Driven** | + 7 | Features driven by real user feedback |
