# Inboxed — Architecture Decision Records

> Lightweight records of significant architectural decisions. Each ADR captures the context, decision, and consequences so future contributors (human and AI) understand *why* things are the way they are.

---

## Format

Each ADR follows [Michael Nygard's template](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):

```
# ADR-NNN: Title

**Status:** proposed | accepted | deprecated | superseded by ADR-NNN
**Date:** YYYY-MM-DD
**Deciders:** who was involved

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or harder as a result of this decision?
```

## Naming Convention

```
NNN-short-slug.md
```

- `NNN` — sequential number, zero-padded to 3 digits
- `short-slug` — lowercase, hyphen-separated

---

## Index

| # | ADR | Status | Date | Summary |
|---|-----|--------|------|---------|
| 001 | [Rich DDD over Anemic Models](001-rich-ddd.md) | accepted | 2026-03-15 | Domain logic lives in rich entities and aggregates, not service objects |
| 002 | [Custom Event Store](002-custom-event-store.md) | accepted | 2026-03-15 | Build a custom event store instead of using Rails Event Store |
| 003 | [dry-types + dry-struct for Domain Layer](003-dry-types-domain.md) | accepted | 2026-03-15 | Use dry-rb ecosystem for immutable, type-safe domain objects |
| 004 | [Feature-based Svelte Architecture](004-svelte-features.md) | accepted | 2026-03-15 | Organize dashboard by features with separated services/stores/types |
| 005 | [Hexagonal Light for MCP Server](005-mcp-hexagonal.md) | accepted | 2026-03-15 | Tools + Ports pattern for the MCP server |
| 006 | [Store Attachments in PostgreSQL](006-attachment-storage.md) | accepted | 2026-03-15 | Store attachment binary in PostgreSQL bytea column for simplicity |
| 007 | [SMTP Server Design](007-smtp-server-design.md) | accepted | 2026-03-15 | Separate process + async processing + midi-smtp-server |
| 008 | [API Response Format & Error Handling](008-api-response-format.md) | accepted | 2026-03-15 | JSON resource envelope for success, RFC 7807 Problem Details for errors |
| 009 | [Cursor-based Pagination](009-cursor-pagination.md) | accepted | 2026-03-15 | Cursor pagination with Base64-encoded sort keys for all collections |
| 010 | [Rate Limiting with Rack::Attack](010-rate-limiting.md) | accepted | 2026-03-15 | Per-API-key and per-IP throttling with transparent headers |
| 011 | [Real-time via ActionCable + Solid Cable](011-realtime-actioncable.md) | accepted | 2026-03-15 | ActionCable with solid_cable DB backend for real-time dashboard updates |
| 012 | [Dashboard Admin-Only Auth](012-dashboard-admin-auth.md) | accepted | 2026-03-15 | Dashboard uses only admin token; extended /admin/ endpoints for email reading |
| 013 | [MCP Tool Design & Extraction Strategy](013-mcp-tool-design.md) | accepted | 2026-03-15 | Extraction logic (OTP, links) lives in MCP server, not Rails API; inbox addressed by email address |
| 014 | [MCP Error Handling & Timeout Strategy](014-mcp-error-handling.md) | accepted | 2026-03-15 | Structured isError responses, no internal retries, timeouts are not errors |
| 015 | [Lightweight Clients over Framework SDKs](015-testing-helper-architecture.md) | accepted | 2026-03-15 | Framework-agnostic API clients in TS/Ruby instead of Playwright fixtures or RSpec matchers |
| 016 | [Client Library Distribution](016-package-distribution.md) | accepted | 2026-03-15 | Monorepo packages/, install from source/git, publish to registries when demand warrants |
| 017 | [Setup Script with Secure Defaults](017-setup-script-secure-defaults.md) | accepted | 2026-03-15 | Interactive bin/setup generates secrets and .env, secure by default, no "changeme" |
| 018 | [Static Landing Page](018-static-landing-page.md) | accepted | 2026-03-15 | Single HTML + Tailwind page in site/, GitHub Pages, no JavaScript, dark terminal aesthetic |
| 019 | [Docker Compose as Primary Deploy](019-docker-compose-primary-deploy.md) | accepted | 2026-03-15 | Docker Compose is the recommended path, Kamal optional for advanced users |
| 020 | [Webhook Delivery & Retry Strategy](020-webhook-delivery-strategy.md) | accepted | 2026-03-15 | Exponential backoff via Solid Queue, HMAC-SHA256 signing, at-least-once delivery, auto-disable failing endpoints |
| 021 | [Webhook Catcher — HTTP Request Inspection](021-webhook-catcher.md) | accepted | 2026-03-15 | Catch and inspect incoming HTTP requests (like webhook.site), reusing Projects/API/Dashboard/MCP infrastructure |
| 022 | [Inboxed Cloud — Free Tier as Funnel](022-cloud-free-tier.md) | accepted | 2026-03-15 | Hosted free tier to drive self-hosted adoption. Same codebase, mode flag, ~€7-10/mo single VPS |
