# Hooks Revamp Plan

## Context

The current hooks feature splits webhooks, forms, and heartbeats into three separate tabs (Hooks In, Forms, Heartbeats), each with its own page and endpoint list. This creates unnecessary friction for a development tool — developers want to see **what arrived**, not manage resource categories.

The Mail section already solves this well: inboxes in the sidebar act as filters over a unified email stream. We apply the same pattern to hooks.

---

## Changes

### 1. Flat sidebar + in-page filtering

The sidebar stays simple — just top-level navigation, no nested sub-items:

```
PROYECTO
  Mail              (15)
  Hooks             (12)
  Settings
```

No inboxes under Mail, no endpoints under Hooks. The list of inboxes/endpoints can grow fast and would clutter the sidebar.

Filtering by inbox or endpoint happens **inside the page** via a dropdown or filter bar:

```
Hooks                    [All endpoints ▾]  [+ Create]
┌─────────────────────┬────────────────────────────────┐
│ POST • events • 2s  │  Request Detail                │
│ POST • stripe • 5m  │  ...                           │
│ POST • contact • 1h │                                │
└─────────────────────┴────────────────────────────────┘
```

The same pattern applies to Mail — the inbox filter would be a dropdown inside the mail page, not sidebar sub-items. This is a separate change but keeps the UI consistent.

**Files affected:**
- `apps/dashboard/src/lib/config/modules.ts` — collapse 3 modules (Hooks In, Forms, Heartbeats) into 1 "Hooks" module
- `apps/dashboard/src/lib/components/Sidebar.svelte` — remove inbox/endpoint sub-items, keep flat module links only
- Remove: `apps/dashboard/src/routes/projects/[projectId]/forms/`
- Remove: `apps/dashboard/src/routes/projects/[projectId]/heartbeats/`
- `apps/dashboard/src/routes/projects/[projectId]/hooks/+page.svelte` — becomes the unified view with endpoint filter dropdown

### 2. Request-centric view (not endpoint-centric)

The main content area shows **captured requests**, not endpoint configuration:

```
┌──────────────────────────┬──────────────────────────────────────┐
│ Recent Requests          │  Request Detail                      │
│                          │                                      │
│ POST /hook/wh_k7Flo9xQ3m │  POST /hook/wh_k7Flo9xQ3m           │
│ ⌁ events • 2s ago        │  Content-Type: application/json      │
│                          │  X-Stripe-Signature: t=12345...      │
│ POST /hook/wh_k7Flo9xQ3m │                                      │
│ ⌁ events • 5m ago        │  ─── Body ─────────────────────────  │
│                          │  { "event": "test" }                 │
│ POST /hook/fm_8bR2nYpL   │                                      │
│ 📋 contact form • 1h ago │                                      │
└──────────────────────────┴──────────────────────────────────────┘
```

Each request item shows: HTTP method, endpoint label, type icon, and time ago. Selecting a request shows headers, body, query string, and response info.

**New backend endpoint needed:**
- `GET /admin/projects/:project_id/requests` — returns all requests across all endpoints for the project, with endpoint info (label, type, token) embedded. Supports optional `?endpoint_token=` filter and pagination.

**Files affected:**
- `apps/api/config/routes.rb` — add project-level requests route
- `apps/api/app/controllers/admin/requests_controller.rb` — new controller
- `apps/api/app/read_models/` — new read model for project-level request list
- `apps/dashboard/src/features/hooks/hooks.service.ts` — add `fetchProjectRequests()`
- `apps/dashboard/src/features/hooks/hooks.types.ts` — update types to include endpoint info on requests

### 3. Short tokens with semantic prefix

Replace `SecureRandom.urlsafe_base64(32)` (43 chars) with prefix + nanoid(16):

| Type | Prefix | Example |
|------|--------|---------|
| Webhook | `wh_` | `wh_k7Flo9xQ3mAbRt2n` |
| Form | `fm_` | `fm_8bR2nYpLqX5vKwMs` |
| Heartbeat | `hb_` | `hb_mX5vKqRtZj9wLn4p` |

16-char nanoid with URL-safe alphabet = ~96 bits of entropy. More than sufficient for a self-hosted system with rate limiting.

**Files affected:**
- `apps/api/app/models/http_endpoint_record.rb` — update `generate_token` to use prefix + nanoid
- `apps/api/Gemfile` — add `nanoid` gem (or use `SecureRandom` with custom alphabet)
- Existing tokens remain valid (backward compatible, no migration needed)

### 4. Create Endpoint dialog (with type selector)

Since there's now a single entry point for creating endpoints (instead of one per tab), the dialog **must include the type selector** so the user can choose webhook, form, or heartbeat.

```
┌─────────────────────────────────────┐
│ Create Endpoint                     │
│                                     │
│ TYPE                                │
│ [⌁ Webhook] [📋 Form] [♡ Heartbeat] │
│                                     │
│ LABEL                               │
│ [e.g. Stripe webhooks            ]  │
│                                     │
│ (type-specific fields shown below)  │
│                                     │
│              [Cancel]  [Create]     │
└─────────────────────────────────────┘
```

The dialog is triggered from:
- `+ New Endpoint` in the sidebar (under the endpoints list)
- `+ Create` button in the hooks page header

**File:** `apps/dashboard/src/features/hooks/components/CreateEndpointDialog.svelte`
- Restore the type selector (was recently removed — needs to come back since there's one dialog for all types now)
- Keep type-specific fields (form response mode, heartbeat interval)

### 5. Endpoint management in Project Settings

Endpoint configuration (rename, allowed methods, max body size, IP whitelist, response mode, delete) moves to the **Project Settings** page. This is setup-once configuration, not something you look at while debugging requests.

Add an **Endpoints** section to the existing settings page (alongside API Keys and Inboxes):

```
┌─────────────────────────────────────────────────────────────┐
│ Endpoints                                        [+ Create] │
│                                                             │
│ Label         Type       Token              Actions         │
│ events        ⌁ webhook  wh_k7Flo9xQ3m      ✏️  🗑          │
│ stripe        ⌁ webhook  wh_9pLmNr4bXs      ✏️  🗑          │
│ contact       📋 form    fm_8bR2nYpLqX       ✏️  🗑          │
│ db-backup     ♡ heartbeat hb_mX5vKqRtZj      ✏️  🗑          │
└─────────────────────────────────────────────────────────────┘
```

Actions per endpoint:
- **Edit (✏️)** — opens modal to rename label, change allowed methods, max body size, IP whitelist, response mode (form), expected interval (heartbeat)
- **Delete (🗑)** — confirm dialog, deletes endpoint and all its captured requests

This replaces the current detail panel that shows endpoint config when you select an endpoint in the hooks list.

**Files affected:**
- `apps/dashboard/src/routes/projects/[projectId]/settings/+page.svelte` — add Endpoints section (same pattern as API Keys and Inboxes sections)
- `apps/dashboard/src/features/hooks/components/EditEndpointDialog.svelte` — new dialog for editing endpoint config

### 6. Getting Started snippets move to each resource's config

Instead of a monolithic Quick Start section in Settings with tabs for every resource type, each snippet lives **in context** — right where you configure that resource.

**Current state:** Settings page has a Quick Start with tabs: SMTP | Test Email | Webhook | Form | Heartbeat — all in one place.

**New state:**
- **SMTP / Test Email snippets** stay in project Settings (they're project-level config)
- **Webhook/Form/Heartbeat snippets** move to the Edit Endpoint dialog or the endpoint detail in Settings

When you create or edit an endpoint, the dialog/detail shows the relevant snippet:
- Webhook → curl example with the endpoint's actual token
- Form → HTML form snippet with the endpoint's actual action URL
- Heartbeat → crontab example with the endpoint's actual URL

This way the snippet always has the **real token** pre-filled, never a placeholder. The developer creates an endpoint, immediately sees how to use it.

**Files affected:**
- `apps/dashboard/src/routes/projects/[projectId]/settings/+page.svelte` — remove webhook/form/heartbeat tabs from Quick Start, keep only SMTP and Test Email
- `apps/dashboard/src/features/hooks/components/EditEndpointDialog.svelte` — include usage snippet for the endpoint's type

---

## What does NOT change

- **Backend API routes for endpoints** (`/admin/projects/:id/endpoints/...`) — unchanged
- **MCP server tools** — all tools use `endpoint_token` as parameter, the token format change (shorter + prefix) is transparent. MCP tools continue to work as-is.
- **HooksController** (`/hook/:token`) — the catch endpoint is unchanged, it just receives shorter tokens
- **API v1 endpoints** — unchanged
- **Mail section** — unchanged

---

## Open questions

1. **Heartbeat status visibility**: With a flat sidebar, heartbeat status (healthy/late/down) can't show as a dot next to the endpoint name. Options: (a) a small "Monitors" summary inside the Hooks page above the request stream, (b) status badges on heartbeat requests in the list, (c) defer — keep it simple for now.

2. **Mail inbox filter**: Should Mail also move to in-page dropdown filtering (removing inbox sub-items from sidebar) for consistency? This would be a separate task but keeps the sidebar uniformly flat. Recommendation: yes, same pattern.

3. **Top nav tabs**: With Forms and Heartbeats removed as separate tabs, the top nav becomes: Mail | Hooks | Settings. Is that enough, or should we remove the top nav entirely and rely only on the sidebar?

---

## Implementation order

1. **Tokens** — change token generation to prefix + nanoid (backend only, non-breaking)
2. **Project-level requests endpoint** — new API endpoint `GET /projects/:id/requests`
3. **Endpoints section in Settings** — add CRUD table for endpoints in project settings + edit dialog with usage snippets
4. **Create dialog** — restore type selector since it's now a single entry point
5. **Unified Hooks page** — replace 3 pages with 1 request-centric view
6. **Sidebar refactor** — collapse 3 modules into 1 "Hooks", remove sub-items (flat sidebar)
7. **Settings Quick Start cleanup** — remove webhook/form/heartbeat tabs, keep only SMTP/Test Email
8. **Clean up** — remove old Forms/Heartbeats pages, update module config
