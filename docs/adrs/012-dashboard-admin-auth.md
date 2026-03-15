# ADR-012: Dashboard Uses Admin-Only Authentication

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner, Security Engineer, API Design Architect, UX/UI Designer

## Context

The system has two authentication strategies:

1. **Admin token** (`INBOXED_ADMIN_TOKEN` env var) — system-wide access for operators
2. **Project API keys** (bcrypt-hashed Bearer tokens) — project-scoped access for integrations

The dashboard needs to display data from all projects: list projects, browse inboxes, read emails, manage API keys. The question is which auth strategy the dashboard should use.

### Options Considered

**A: Admin token only**
- Dashboard authenticates with the admin token for all operations.
- Admin endpoints (`/admin/`) are extended with email/inbox reading capabilities.
- Pro: Single credential, simple flow, full system visibility.
- Con: Must add read endpoints to `/admin/` namespace. Admin token is a superuser — if compromised, full access.

**B: Admin token + per-project API keys**
- Dashboard authenticates with admin token for project management, then uses a project's API key for reading that project's emails via `/api/v1/`.
- Pro: Reuses existing `/api/v1/` endpoints. Principle of least privilege per project.
- Con: Complex auth flow. Dashboard must store multiple credentials. User must select/configure API keys per project. Terrible UX for a self-hosted tool where the operator already controls the server.

**C: Session-based auth (cookie)**
- Dashboard logs in once, gets a session cookie, backend manages session state.
- Pro: Standard web auth pattern.
- Con: Adds session management to an API-only Rails app. CSRF protection needed. Doesn't align with the existing token-based design. Adds complexity for a dev tool.

## Decision

**Admin token only (A).** The dashboard authenticates exclusively with `INBOXED_ADMIN_TOKEN` and uses extended `/admin/` endpoints for all operations including email reading.

### Rationale

1. **Single credential, zero friction.** The operator already knows the admin token (they set it in `.env`). No additional setup, no API key management just to view emails.

2. **The dashboard IS the admin interface.** It's not a multi-tenant app with user roles — it's a control panel for the operator of a self-hosted dev tool. The admin token is the right credential for this.

3. **Clean API separation.** `/admin/*` = dashboard (full system access), `/api/v1/*` = external integrations (project-scoped). Each namespace has one auth strategy, one audience, one mental model.

4. **Security is adequate.** The admin token is:
   - Set by the operator (not generated/stored in DB)
   - Transmitted via HTTPS in production
   - Compared with `secure_compare` (timing-safe)
   - Required on every request (stateless)
   - The dashboard is typically on a private network or behind VPN

### Admin Endpoints for Dashboard

The following read endpoints are added to `/admin/` (spec 004):

```
GET    /admin/projects/:id/inboxes                    → list inboxes
GET    /admin/projects/:id/inboxes/:id                → inbox detail
DELETE /admin/projects/:id/inboxes/:id                → delete inbox
GET    /admin/projects/:id/inboxes/:id/emails         → list emails (paginated)
DELETE /admin/projects/:id/inboxes/:id/emails         → purge inbox emails
GET    /admin/emails/:id                              → email detail
GET    /admin/emails/:id/raw                          → raw MIME source
DELETE /admin/emails/:id                              → delete email
GET    /admin/emails/:id/attachments                  → list attachments
GET    /admin/attachments/:id/download                → download attachment
GET    /admin/search                                  → full-text search (cross-project)
```

These mirror the `/api/v1/` endpoints but:
- Authenticated with admin token (not API key)
- Not project-scoped by default — can access any project's data
- Search is cross-project (useful for "find that email from yesterday")

## Consequences

### Easier

- **Dashboard auth is trivial** — one token, one `localStorage` key, one `apiClient()`
- **No API key management to view emails** — just log in and browse
- **Clear namespace separation** — admin = dashboard, api/v1 = integrations
- **No session state** — stateless token auth on every request

### Harder

- **Admin token is a single point of compromise** — if leaked, full access. Mitigated by: HTTPS, private network, operator-controlled env var, ability to rotate instantly.
- **More endpoints to maintain** — admin read endpoints partially duplicate `/api/v1/` logic. Mitigated by: shared read models, thin controllers, DRY serializers.
- **No granular admin permissions** — the admin token is all-or-nothing. Acceptable for a dev tool. If multi-user admin is ever needed (unlikely), add it then.

## Revisit When

- Multi-user admin access is needed → add user accounts with roles (unlikely for a self-hosted dev tool)
- Admin token rotation causes downtime → add token list or short-lived JWT exchange
