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
| **Webhook notifications** | High | HTTP POST on email received, with retry logic (see [ADR-020](adrs/020-webhook-delivery-strategy.md)) |
| **Routing rules** | Medium | Forward, drop, auto-reply based on from/to/subject patterns |
| **SMTP relay mode** | Medium | Capture + optional release to real SMTP (level 3 — see below) |
| **CLI** | Medium | `inboxed list`, `inboxed wait`, `inboxed clear` |
| **Email HTML preview** | Low | Multi-client rendering simulation |
| **Load testing mode** | Low | Accept high volume, verify delivery stats |
| **Prometheus metrics** | Low | `/metrics` endpoint for observability |
| **Additional SDKs** | Low | Python (pytest), Cypress, k6 helpers |

---

## Phase 8 — HTTP Catcher (Webhooks, Forms, Heartbeats)

Extend the "catch & inspect" model to HTTP requests. The HTTP catcher is the second primitive — everything beyond email is built on it. See [ADR-021](adrs/021-webhook-catcher.md) for design rationale and [VISION.md](VISION.md) for how modules map to primitives.

### Core: HTTP Catcher

- [ ] **Data models:** `HttpEndpoint`, `HttpRequest` — separate tables, same `Project` parent
- [ ] **Endpoint types:** `webhook`, `form`, `heartbeat` — same table, different behavior/UI per type
- [ ] **Public catch endpoint:** `POST/GET/PUT/PATCH/DELETE /hook/:token` — receives and stores any HTTP request
- [ ] **REST API:** CRUD for endpoints and captured requests under `/api/v1/endpoints/`
- [ ] **Dashboard:** "HTTP" tab in project view — endpoint list, request detail with method badge, headers, body (JSON pretty-print), query params, IP
- [ ] **Real-time:** Incoming requests appear live via existing ActionCable infrastructure
- [ ] **MCP tools:** `create_endpoint`, `wait_for_request`, `get_latest_request`, `extract_json_field`, `list_requests`
- [ ] **Security:** Cryptographic tokens (32+ bytes), rate limiting per endpoint, max body size (256KB), TTL cleanup
- [ ] **Feature flag:** HTTP catcher module can be disabled entirely for email-only deployments

### Form Submissions

Zero new backend — forms are HTTP POSTs to the same catcher. The additions are UI and DX:

- [ ] **Endpoint type `form`:** when creating an endpoint, choose "Form" to get form-optimized UI
- [ ] **Dashboard:** form view parses `application/x-www-form-urlencoded` and `multipart/form-data` into a readable field table (key → value), shows uploaded files
- [ ] **HTML snippet generator:** dashboard provides a copy-pasteable `<form action="https://inboxed.dev/hook/:token" method="POST">` snippet
- [ ] **Response config:** form endpoints return a configurable redirect URL or a simple "Thank you" HTML page (for prototyping without a backend)

### Heartbeat Monitor

Webhook catcher + expected interval. Alert when a ping is missed:

- [ ] **Endpoint type `heartbeat`:** has an `expected_interval` (e.g. "5m", "1h", "24h")
- [ ] **Status tracking:** `healthy` (last ping within interval), `late` (1x interval missed), `down` (2x+ intervals missed)
- [ ] **Dashboard:** heartbeat endpoints show status badge, last ping time, and timeline of pings
- [ ] **Alerts:** when status transitions to `down`, fire a webhook notification (reuses Phase 7 webhook delivery infra)
- [ ] **MCP tools:** `check_heartbeat(endpoint)` returns status, last ping, next expected

**Exit criteria:** (1) Create a webhook endpoint, send an HTTP request via `curl`, see it in the dashboard and retrieve via API/MCP. (2) Create a form endpoint, submit an HTML form to it, see parsed fields in dashboard. (3) Create a heartbeat endpoint with 1-minute interval, send pings, stop pinging, see status transition to `down`.

---

## Phase 9 — Inboxed Cloud (Free Tier)

Hosted version as a try-before-you-self-host funnel. Not a SaaS — no paid plans, no Stripe. Cloud exists to reduce the barrier to adoption. See [ADR-022](adrs/022-cloud-free-tier.md) and [VISION.md](VISION.md) for full strategy.

- [ ] **User model:** `User` (email, password_digest, verified_at) + `users_projects` join table
- [ ] **Registration flow:** email + password or GitHub OAuth, email verification required
- [ ] **Cloud mode flag:** `INBOXED_MODE=cloud` — conditional behavior for auth, limits, features
- [ ] **Multi-tenant scoping:** Every query scoped by `project_id`. Test suite verifies tenant isolation
- [ ] **Free tier limits:** 1 project, 5 inboxes, 50 emails, 2 webhook endpoints, 20 requests, 1h TTL, 60 req/min API
- [ ] **Feature gates:** MCP disabled, HTML email preview disabled (text + headers only)
- [ ] **SMTP multi-tenant:** Wildcard subdomain routing — `*@{slug}.inboxed.dev` via single MX record
- [ ] **Limit banners:** Dashboard shows usage ("4/5 inboxes") with CTA to self-hosting docs
- [ ] **Abuse prevention:** SMTP rate limit (10/hour per account), body size caps, fail2ban, aggressive cleanup cron
- [ ] **Deploy:** Single Hetzner VPS (CAX21), same docker-compose with cloud config overlay

**Exit criteria:** A developer registers, sends a test email to their `@{slug}.inboxed.dev` inbox, inspects it in the dashboard, hits a limit, and follows the self-hosting CTA to `docker compose up` on their own machine.

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
| **Full Dev Inbox** | + 8 | Webhook catcher — emails + HTTP requests in one tool |
| **Try Before You Host** | + 9 | Inboxed Cloud — free hosted tier as adoption funnel |

---

## SMTP Evolution Path

Inboxed's SMTP capabilities evolve in three levels. Levels 1-2 are the MVP. Level 3 is post-MVP.

| Level | Name | How it works | When |
|-------|------|-------------|------|
| **1. Direct reception** | App sends to `user@mail.inboxed.dev` | Inboxed receives and stores. Standard MX-based inbound. | Phase 1 (MVP) |
| **2. Transparent relay** | App configures Inboxed as its SMTP server | App thinks it's "sending" email. Inboxed captures everything that passes through — another form of reception. Transparent to the app. | Phase 1 (MVP) |
| **3. Outbound relay** | Capture + optional release to real recipient | Inboxed captures the email AND can forward it to the actual destination. Useful in staging when you need to inspect but also deliver. Requires DKIM signing, bounce handling, deliverability management. | Post-MVP |

> **Design note:** The data model should include a `direction` or `source_type` field on emails from day one, so level 3 doesn't require a migration that changes the core schema. Plan for it in the data models spec.
