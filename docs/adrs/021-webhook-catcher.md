# ADR-021: HTTP Catcher — Webhooks, Forms, and Heartbeats

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner
**Panel consulted:** Product Manager, API Design Architect, Developer Advocate, MCP Engineer, Security Engineer

## Context

Inboxed catches SMTP emails and makes them inspectable via API, dashboard, and MCP. The same "catch, store, inspect" pattern applies to HTTP webhook requests — a developer testing Stripe webhooks, GitHub events, or any third-party callback faces the same problem: "Did the request arrive? What was in it?"

Today, developers use separate tools for each: Mailpit/Mailtrap for emails, webhook.site/RequestBin for HTTP requests. This fragments the debugging experience.

### The Pattern

| | Emails (existing) | Webhooks (proposed) |
|---|---|---|
| **Receives** | SMTP connections | HTTP requests (any method) |
| **Stores** | MIME, headers, body, attachments | Method, URL, headers, query params, body |
| **Inspects via** | Dashboard, REST API, MCP | Dashboard, REST API, MCP |
| **Unique endpoint** | `user@mail.inboxed.dev` | `https://inboxed.dev/hook/:token` |
| **Belongs to** | Project → Inbox | Project → WebhookEndpoint |

### Options Considered

**A: Don't build it — stay email-only**
- Pro: Focused product, no scope creep
- Con: Misses a natural extension of the core concept
- Con: Users need a second tool for webhook inspection

**B: Build as separate product**
- Pro: Clean separation of concerns
- Con: Duplicates infrastructure (auth, projects, API, dashboard, MCP)
- Con: Developer needs two tools, two setups, two dashboards

**C: Build as a module within Inboxed (Phase 8)**
- Pro: Reuses existing infrastructure (Projects, API keys, TTL, cleanup, dashboard, MCP)
- Pro: Unified experience — emails and webhooks in one place
- Pro: Natural extension of "catch & inspect" brand identity
- Con: Broadens scope — requires discipline to not delay core email features

## Decision

**Option C** — build webhook catching as a module within Inboxed, scheduled as Phase 8 (after core email features are complete and stable).

### Data Model

New entities, separate from email entities but sharing the same `Project` parent:

- **`WebhookEndpoint`** (analogous to `Inbox`)
  - `id`, `project_id`, `token` (unique, cryptographically secure), `label`, `created_at`
  - Optional: `allowed_ips` (IP allowlist), `expected_content_type`

- **`WebhookRequest`** (analogous to `Email`)
  - `id`, `webhook_endpoint_id`, `method`, `url`, `path`, `query_string`, `headers` (jsonb), `body` (text), `content_type`, `ip_address`, `size_bytes`, `created_at`

### API Design

```
# Public endpoint — receives webhooks (no auth required, token is the auth)
POST/GET/PUT/PATCH/DELETE /hook/:token
POST/GET/PUT/PATCH/DELETE /hook/:token/*path

# Management API (requires API key)
GET    /api/v1/endpoints                     # list endpoints
POST   /api/v1/endpoints                     # create endpoint
GET    /api/v1/endpoints/:token              # show endpoint
DELETE /api/v1/endpoints/:token              # delete endpoint
GET    /api/v1/endpoints/:token/requests     # list captured requests
GET    /api/v1/endpoints/:token/requests/:id # show request detail
DELETE /api/v1/endpoints/:token/requests/:id # delete request
```

### MCP Tools

```
create_webhook_endpoint(project, label?)
wait_for_request(endpoint_token, method?, path_pattern?, timeout)
get_latest_request(endpoint_token)
extract_json_field(endpoint_token, json_path)
list_requests(endpoint_token, limit)
delete_endpoint(endpoint_token)
```

### Security Considerations

- Tokens: minimum 32 bytes, cryptographically random (SecureRandom.urlsafe_base64(32))
- Rate limiting per endpoint (prevent abuse as free storage)
- Max body size: 256KB per request (configurable)
- TTL/cleanup: same lifecycle as emails — project TTL applies
- Optional IP allowlist per endpoint
- Response to captured requests: always `200 OK` with `{"ok": true}` (configurable per endpoint)

### Dashboard Integration

- New tab in project view: "Webhooks" alongside "Inboxes"
- Endpoint list view with token, label, request count
- Request detail view: method badge, headers, body (with JSON pretty-print), query params, IP, timestamp
- Real-time updates via existing ActionCable infrastructure

### Branding Alignment

The tagline evolves naturally:

- Current: *"Your emails go nowhere. You see everything."*
- Extended: *"Your emails go nowhere. Your webhooks go nowhere. You see everything."*

The core promise — "catch, inspect, assert" — applies identically to both.

## Consequences

### Easier

- **Unified tool** — one setup for emails AND webhooks
- **Infra reuse** — Projects, API keys, TTL, dashboard, MCP, ActionCable all shared
- **Stronger value prop** — "Mailpit + webhook.site + MCP" in one self-hosted tool
- **Same mental model** — developers already understand "unique address → inspect what arrives"

### Harder

- **Broader scope** — more surface area to maintain and test
- **Dashboard complexity** — two types of "incoming data" in the UI
- **Public endpoint security** — `/hook/:token` is unauthenticated by design, needs hardening

### Mitigations

- Phase 8 timing ensures core email features are rock solid first
- Separate database tables — webhook bugs can't corrupt email data
- Rate limiting + body size cap prevent abuse
- Feature flag to disable webhook module entirely for users who don't need it
