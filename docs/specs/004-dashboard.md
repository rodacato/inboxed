# Spec 004 — Dashboard

**Phase:** 3 — Dashboard
**Status:** implemented
**Created:** 2026-03-15
**ADRs:** [004](../adrs/004-feature-based-svelte.md), [008](../adrs/008-api-response-format.md), [009](../adrs/009-cursor-pagination.md), [011](../adrs/011-realtime-actioncable.md), [012](../adrs/012-dashboard-admin-auth.md)
**Depends on:** [002 — SMTP + Persistence](002-smtp-persistence.md), [003 — REST API](003-rest-api.md)

---

## 1. Objective

Build the visual dashboard for Inboxed — a SvelteKit SPA that lets operators browse projects, inspect inboxes, read emails (HTML + text + raw), search across all data, manage API keys, and see emails arrive in real-time via ActionCable WebSocket.

The dashboard is the **admin interface**. It authenticates exclusively with `INBOXED_ADMIN_TOKEN` and uses the `/admin/` API namespace (ADR-012). No project API keys are needed to view emails.

---

## 2. Current State

From spec 002 + 003 implementation:

### Backend (Rails API)

- **Admin endpoints exist:** `GET/POST/PATCH/DELETE /admin/projects`, `GET/POST/PATCH/DELETE /admin/projects/:id/api_keys`, `GET /admin/status`
- **API v1 endpoints exist:** inboxes, emails, attachments, search, wait — all project-scoped via API key
- **Missing:** Admin endpoints for reading inboxes/emails/attachments (currently only available via `/api/v1/` with API key)
- **ActionCable configured:** `solid_cable` in Gemfile, `cable.yml` set up, but no channels implemented
- **Shared infrastructure:** read models (`InboxList`, `EmailList`, `EmailDetail`, `EmailSearch`), serializers (`EmailListSerializer`, `EmailDetailSerializer`), `Paginatable` + `ErrorRenderable` concerns

### Dashboard (SvelteKit)

- **SvelteKit** with `adapter-static`, Tailwind CSS 4, TypeScript
- **Auth flow works:** login form → validates against `/admin/status` → stores token in localStorage
- **Feature-based architecture:** `features/auth/`, `features/messages/`, `features/system/`
- **API client exists:** `src/lib/api-client.ts` with auth headers, 401 redirect
- **UI is mock:** `MessageList` and `MessagePreview` use hardcoded data. `Sidebar` has hardcoded counts
- **No routing:** single page at `/`, no project/inbox/email navigation
- **Theme toggle works:** light/dark mode with localStorage persistence

---

## 3. What This Spec Delivers

### 3.1 New Admin Endpoints (Rails)

Extend `/admin/` with read endpoints so the dashboard can access all data with the admin token. These mirror `/api/v1/` but are cross-project and admin-authenticated.

#### 3.1.1 Inbox Endpoints

```
GET    /admin/projects/:project_id/inboxes
       → List inboxes for a project
       → Params: limit (default 20, max 100), after (cursor)
       → Response: { data: Inbox[], meta: { has_more, next_cursor, total_count } }

GET    /admin/projects/:project_id/inboxes/:id
       → Inbox detail with email count
       → Response: { data: Inbox }

DELETE /admin/projects/:project_id/inboxes/:id
       → Delete inbox and all its emails
       → Response: 204 No Content
```

#### 3.1.2 Email Endpoints

```
GET    /admin/projects/:project_id/inboxes/:inbox_id/emails
       → List emails in an inbox (paginated)
       → Params: limit, after (cursor)
       → Response: { data: EmailSummary[], meta: { has_more, next_cursor, total_count } }

GET    /admin/emails/:id
       → Full email detail with attachments
       → Response: { data: EmailDetail }

GET    /admin/emails/:id/raw
       → Raw MIME source
       → Content-Type: message/rfc822
       → Response: raw text body

DELETE /admin/emails/:id
       → Delete single email
       → Response: 204 No Content

DELETE /admin/projects/:project_id/inboxes/:inbox_id/emails
       → Purge all emails in inbox
       → Response: { data: { deleted_count: N } }
```

#### 3.1.3 Attachment Endpoints

```
GET    /admin/emails/:email_id/attachments
       → List attachments for an email
       → Response: { data: Attachment[] }

GET    /admin/attachments/:id/download
       → Download attachment binary
       → Content-Type: (attachment's content type)
       → Content-Disposition: attachment; filename="..."
```

#### 3.1.4 Search Endpoint

```
GET    /admin/search
       → Full-text search across ALL projects
       → Params: q (required), limit, after (cursor)
       → Response: { data: SearchResult[], meta: { has_more, next_cursor, total_count } }
       → Difference from /api/v1/search: not scoped to a project
```

#### 3.1.5 Implementation Notes

- **Reuse existing read models:** `InboxList`, `EmailList`, `EmailDetail`, `EmailSearch` — they accept `project_id` as param; admin controllers pass it from the URL
- **Reuse existing serializers:** `EmailListSerializer`, `EmailDetailSerializer` — identical output format
- **Admin::InboxesController** and **Admin::EmailsController** extend `Admin::BaseController` (inherits admin auth + pagination + error handling)
- **Search controller** calls `EmailSearch.search` without project scoping (pass `nil` or add a `search_all` method)
- **No new read models needed** — extend `EmailSearch` with a `search_all(query:, limit:, after:)` class method that omits the `project_id` WHERE clause

#### 3.1.6 Routes

```ruby
# config/routes.rb — additions to existing admin namespace
namespace :admin do
  # ... existing project + api_key routes ...

  resources :projects, only: [] do
    resources :inboxes, only: [:index, :show, :destroy], controller: "admin/inboxes" do
      resources :emails, only: [:index], controller: "admin/emails" do
        delete "", on: :collection, action: :purge
      end
    end
  end

  resources :emails, only: [:show, :destroy], controller: "admin/emails" do
    get :raw, on: :member
    resources :attachments, only: [:index], controller: "admin/attachments"
  end

  resources :attachments, only: [], controller: "admin/attachments" do
    get :download, on: :member
  end

  get :search, to: "admin/search#show"
end
```

### 3.2 ActionCable Channels (Rails)

Real-time push for the dashboard. See ADR-011 for full architecture.

#### 3.2.1 Connection Authentication

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :admin_authenticated

    def connect
      token = request.params[:token]
      admin_token = ENV["INBOXED_ADMIN_TOKEN"]
      reject_unauthorized_connection unless token.present? &&
        ActiveSupport::SecurityUtils.secure_compare(token, admin_token)
      self.admin_authenticated = true
    end
  end
end
```

#### 3.2.2 Channels

```ruby
# app/channels/inbox_channel.rb
class InboxChannel < ApplicationCable::Channel
  def subscribed
    stream_from "inbox_#{params[:inbox_id]}"
  end
end

# app/channels/project_channel.rb
class ProjectChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project_#{params[:project_id]}"
  end
end
```

#### 3.2.3 Event Store Subscribers

Wire domain events to ActionCable broadcasts. Add to the event subscriptions initializer:

```ruby
# config/initializers/event_subscriptions.rb (additions)
Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailReceived) do |event|
  email = EmailRecord.find_by(id: event.data[:email_id])
  next unless email

  payload = EmailListSerializer.render(email)

  ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
    type: "email_received",
    email: payload
  })

  ActionCable.server.broadcast("project_#{email.inbox_record.project_id}", {
    type: "inbox_updated",
    inbox_id: event.data[:inbox_id],
    email_count_delta: 1
  })
end

Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailDeleted) do |event|
  ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
    type: "email_deleted",
    email_id: event.data[:email_id]
  })
end

Inboxed::EventStore::Bus.subscribe(Inboxed::Events::InboxPurged) do |event|
  ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
    type: "inbox_purged",
    deleted_count: event.data[:deleted_count]
  })
end

Inboxed::EventStore::Bus.subscribe(Inboxed::Events::InboxCreated) do |event|
  inbox = InboxRecord.find_by(id: event.data[:inbox_id])
  next unless inbox

  ActionCable.server.broadcast("project_#{inbox.project_id}", {
    type: "inbox_created",
    inbox: { id: inbox.id, address: inbox.address, email_count: 0,
             created_at: inbox.created_at.iso8601 }
  })
end
```

#### 3.2.4 WebSocket Route

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  # ... existing routes ...
end
```

### 3.3 Dashboard SvelteKit Application

#### 3.3.1 Routing Structure

Replace the current single-page layout with file-based routing:

```
src/routes/
├── +layout.svelte                    → root layout (auth guard, sidebar)
├── +page.svelte                      → / redirect to /projects
├── login/
│   └── +page.svelte                  → /login (existing, refactored)
├── projects/
│   ├── +page.svelte                  → /projects (project list)
│   └── [projectId]/
│       ├── +page.svelte              → /projects/:id (project detail + API keys)
│       ├── +layout.svelte            → project context layout
│       ├── inboxes/
│       │   └── [inboxId]/
│       │       └── +page.svelte      → /projects/:id/inboxes/:iid (email list)
│       └── emails/
│           └── [emailId]/
│               └── +page.svelte      → /projects/:id/emails/:eid (email detail)
└── search/
    └── +page.svelte                  → /search (cross-project search)
```

#### 3.3.2 Feature Module Structure

Extend the existing feature-based architecture (ADR-004):

```
src/features/
├── auth/                             → (existing, no changes)
│   ├── LoginForm.svelte
│   ├── auth.service.ts
│   └── auth.types.ts
├── projects/                         → NEW
│   ├── ProjectList.svelte            → project cards/table
│   ├── ProjectDetail.svelte          → project info + API keys section
│   ├── ApiKeyManager.svelte          → create/revoke API keys
│   ├── projects.service.ts           → admin API calls
│   ├── projects.store.svelte.ts      → project state
│   └── projects.types.ts             → interfaces
├── inboxes/                          → NEW
│   ├── InboxList.svelte              → inbox table for a project
│   ├── inboxes.service.ts            → admin API calls
│   ├── inboxes.store.svelte.ts       → inbox state
│   └── inboxes.types.ts              → interfaces
├── emails/                           → REPLACES messages/
│   ├── EmailList.svelte              → email list with selection
│   ├── EmailDetail.svelte            → full email view
│   ├── EmailPreview.svelte           → HTML email sandboxed iframe
│   ├── EmailRaw.svelte               → raw MIME source viewer
│   ├── EmailHeaders.svelte           → expandable headers section
│   ├── AttachmentList.svelte         → attachment download links
│   ├── OtpBanner.svelte              → OTP detection + copy button
│   ├── emails.service.ts             → admin API calls
│   ├── emails.store.svelte.ts        → email state with real-time
│   └── emails.types.ts               → interfaces
├── search/                           → NEW
│   ├── SearchPage.svelte             → search input + results
│   ├── SearchResultItem.svelte       → individual result row
│   ├── search.service.ts             → admin API calls
│   ├── search.store.svelte.ts        → search state
│   └── search.types.ts               → interfaces
├── realtime/                         → NEW
│   ├── cable-client.ts               → ActionCable WebSocket wrapper
│   ├── realtime.store.svelte.ts      → connection state
│   └── realtime.types.ts             → message interfaces
└── system/                           → (existing, minor updates)
    ├── StatusPanel.svelte
    ├── system.service.ts
    └── system.types.ts
```

#### 3.3.3 Root Layout + Auth Guard

```svelte
<!-- src/routes/+layout.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { isAuthenticated } from '$lib/api-client';
  import Sidebar from '$lib/components/Sidebar.svelte';
  import { onMount } from 'svelte';

  let { children } = $props();
  let ready = $state(false);

  onMount(() => {
    if (!isAuthenticated() && $page.url.pathname !== '/login') {
      goto('/login');
      return;
    }
    ready = true;
  });
</script>

{#if $page.url.pathname === '/login'}
  {@render children()}
{:else if ready}
  <div class="flex h-screen">
    <Sidebar />
    <main class="flex-1 overflow-auto">
      {@render children()}
    </main>
  </div>
{/if}
```

#### 3.3.4 Sidebar Updates

Replace the current hardcoded sidebar with dynamic project navigation:

```svelte
<!-- src/lib/components/Sidebar.svelte (updated) -->
<!-- Structure: -->
<!-- Logo + branding -->
<!-- Navigation:
     - 🔍 Search (link to /search)
     - Projects section:
       - Collapsible project list
       - Each project shows name + inbox count
       - Clicking a project navigates to /projects/:id
     - Settings (future)
-->
<!-- Bottom:
     - StatusPanel (API connection)
     - Theme toggle
-->
```

Key changes from current sidebar:
- Remove hardcoded "Inbox", "Sent", "Trash" navigation items
- Add dynamic project list loaded from `/admin/projects`
- Add search link
- Keep theme toggle and StatusPanel

### 3.4 Views (Page Components)

#### 3.4.1 Project List (`/projects`)

Displays all projects with summary statistics.

```
┌─────────────────────────────────────────────────────┐
│  Projects                          [+ New Project]  │
├─────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐          │
│  │ my-saas-app     │  │ staging-env     │          │
│  │ 3 inboxes       │  │ 1 inbox         │          │
│  │ 47 emails       │  │ 12 emails       │          │
│  │ TTL: 168h       │  │ TTL: 24h        │          │
│  │ Created 3d ago  │  │ Created 1d ago  │          │
│  └─────────────────┘  └─────────────────┘          │
└─────────────────────────────────────────────────────┘
```

- Fetches `GET /admin/projects`
- Card grid layout (responsive: 1-3 columns)
- Click navigates to `/projects/:id`
- **Create project modal:** name, slug (auto-generated from name), default TTL, max inbox count
- Uses `Inboxed::Services::CreateProject` via `POST /admin/projects`

#### 3.4.2 Project Detail (`/projects/:id`)

Two sections: project info + API key management.

```
┌─────────────────────────────────────────────────────────┐
│  ← Projects / my-saas-app                    [Delete]   │
├─────────────────────────────────────────────────────────┤
│  Slug: my-saas-app                                      │
│  Default TTL: 168 hours                                 │
│  Max Inboxes: 100                                       │
│  Created: 2026-03-15                        [Edit]      │
├─────────────────────────────────────────────────────────┤
│  API Keys                           [+ Generate Key]   │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Label          │ Prefix    │ Last Used  │        │   │
│  │ CI Pipeline    │ inx_ci_*  │ 2m ago     │ [🗑️]  │   │
│  │ Local Dev      │ inx_lo_*  │ never      │ [🗑️]  │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  Inboxes                                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Address                  │ Emails │ Created      │   │
│  │ user-signup@my-saas.test │ 23     │ 3d ago       │   │
│  │ alerts@my-saas.test      │ 8      │ 1d ago       │   │
│  │ reset@my-saas.test       │ 16     │ 2d ago       │   │
│  └──────────────────────────────────────────────────┘   │
│                                      [Load more...]     │
└─────────────────────────────────────────────────────────┘
```

- **API key generation:** on create, show the full token **once** in a modal with copy button. Warn that it won't be shown again.
- **Inbox table:** click navigates to `/projects/:id/inboxes/:iid`
- **Real-time:** subscribe to `ProjectChannel` for inbox count updates + new inbox notifications
- **Delete project:** confirmation modal, warns about cascading deletion of all inboxes and emails

#### 3.4.3 Inbox Email List (`/projects/:id/inboxes/:iid`)

Master view showing emails in the selected inbox.

```
┌──────────────────────────────────────────────────────────────┐
│  ← my-saas-app / user-signup@my-saas.test    [Purge] [🗑️]  │
│  23 emails                                                   │
├──────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐    │
│  │ ● auth-service@cloud.io                    2m ago   │    │
│  │   Your verification code: 8829-X                    │    │
│  │   Use the following code to verify your...          │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │   github-noreply@github.com               15m ago   │    │
│  │   [GitHub] Please verify your email address         │    │
│  │   Click the link below to verify your...            │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │   billing@stripe.com                      1h ago    │    │
│  │   Your invoice #INV-2024-001                        │    │
│  │   Amount: $29.00. Payment due...                    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                      [Load more...]          │
└──────────────────────────────────────────────────────────────┘
```

- Fetches `GET /admin/projects/:id/inboxes/:iid/emails` with cursor pagination
- Click email navigates to `/projects/:id/emails/:eid`
- **Real-time:** subscribe to `InboxChannel` — new emails prepend to list, deleted emails fade out
- **New email indicator:** dot (●) on unread (emails received after page load)
- **Purge button:** confirmation modal → `DELETE /admin/projects/:pid/inboxes/:iid/emails` → clear list
- **Delete inbox:** confirmation modal → `DELETE /admin/projects/:pid/inboxes/:iid`
- **Infinite scroll:** load more on scroll to bottom using cursor pagination

#### 3.4.4 Email Detail (`/projects/:id/emails/:eid`)

Full email view with tabs for HTML, text, raw source.

```
┌──────────────────────────────────────────────────────────────┐
│  ← user-signup@my-saas.test                        [🗑️]    │
├──────────────────────────────────────────────────────────────┤
│  ┌── OTP DETECTED ─────────────────────────────────────┐    │
│  │  Code: 8829-X                          [📋 Copy]    │    │
│  └─────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────┤
│  From:    auth-service@cloud.io                              │
│  To:      user-signup@my-saas.test                           │
│  CC:      (none)                                             │
│  Subject: Your verification code: 8829-X                     │
│  Date:    2026-03-15 14:32:01 UTC                            │
│  [▶ Show all headers]                                        │
├──────────────────────────────────────────────────────────────┤
│  [HTML]  [Text]  [Raw]  [Headers]                            │
├──────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                                                     │    │
│  │   (sandboxed iframe with HTML email body)           │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────┤
│  Attachments (2)                                             │
│  📎 invoice.pdf (42 KB)                    [Download]        │
│  📎 logo.png (3 KB, inline)                [Download]        │
├──────────────────────────────────────────────────────────────┤
│  Expires: 2026-03-22 14:32:01 UTC (in 7 days)               │
└──────────────────────────────────────────────────────────────┘
```

Components:

**OtpBanner** — OTP detection and copy:
- Client-side regex scan of subject + body_text for common OTP patterns:
  ```
  /\b(\d{4,8})\b/                  → numeric codes (4-8 digits)
  /\b([A-Z0-9]{4,8}(?:-[A-Z0-9]{4,8})*)\b/  → alphanumeric with dashes
  /(?:code|otp|pin|token)[:\s]+([A-Z0-9-]{4,12})/i  → labeled codes
  ```
- Shows first match in a prominent banner with one-click copy
- If no OTP detected, banner is hidden

**EmailPreview (HTML tab)** — sandboxed HTML rendering:
- Uses `<iframe sandbox="allow-same-origin" srcdoc={html}>` to render HTML body
- `sandbox` attribute blocks scripts, forms, popups, navigation
- Inline styles preserved. External resources blocked by sandbox.
- Auto-resize iframe height to content via `postMessage` height observer
- Fallback: if no HTML body, show text body in `<pre>`

**EmailRaw (Raw tab)** — MIME source viewer:
- Fetches `GET /admin/emails/:id/raw` on tab activation (lazy load)
- Renders in `<pre><code>` with monospace font
- Copy button for full raw source

**EmailHeaders (Headers tab)** — all MIME headers:
- Parses `raw_headers` JSON from email detail
- Key-value table with horizontal scroll for long values

**AttachmentList** — download links:
- Lists all attachments from email detail response
- Download link points to `GET /admin/attachments/:id/download`
- Shows filename, content type, size (human-readable), inline badge

#### 3.4.5 Search (`/search`)

Cross-project full-text search.

```
┌──────────────────────────────────────────────────────────────┐
│  Search                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 🔍  verification code                               │    │
│  └─────────────────────────────────────────────────────┘    │
│  3 results                                                   │
├──────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Your verification code: 8829-X                      │   │
│  │ auth-service@cloud.io → user-signup@my-saas.test    │   │
│  │ my-saas-app • 2m ago                                │   │
│  │ Use the following code to verify your account...    │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ Please verify your email address                    │   │
│  │ github-noreply@github.com → dev@staging.test        │   │
│  │ staging-env • 15m ago                               │   │
│  │ Click the link below to verify...                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                      [Load more...]          │
└──────────────────────────────────────────────────────────────┘
```

- Fetches `GET /admin/search?q=...` with debounced input (300ms)
- Results show: subject, from → inbox address, project name, time, preview
- Click navigates to email detail: `/projects/:pid/emails/:eid`
- Cursor pagination for more results
- Empty state when no query or no results

### 3.5 ActionCable Client (Svelte)

#### 3.5.1 Cable Client Wrapper

```typescript
// src/features/realtime/cable-client.ts

interface CableMessage {
  type: string;
  [key: string]: unknown;
}

interface CableOptions {
  token: string;
  onConnect?: () => void;
  onDisconnect?: () => void;
}

export function createCable(options: CableOptions) {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const host = window.location.host;
  const url = `${protocol}//${host}/cable?token=${encodeURIComponent(options.token)}`;

  let ws: WebSocket | null = null;
  let reconnectAttempts = 0;
  let maxReconnectAttempts = 10;
  let subscriptions = new Map<string, (msg: CableMessage) => void>();

  function connect() {
    ws = new WebSocket(url);

    ws.onopen = () => {
      reconnectAttempts = 0;
      options.onConnect?.();

      // Resubscribe after reconnection
      for (const [identifier] of subscriptions) {
        ws!.send(JSON.stringify({ command: 'subscribe', identifier }));
      }
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      // ActionCable protocol: ignore ping, welcome, confirm_subscription
      if (data.type === 'ping' || data.type === 'welcome' ||
          data.type === 'confirm_subscription') return;

      if (data.identifier && data.message) {
        const handler = subscriptions.get(data.identifier);
        handler?.(data.message);
      }
    };

    ws.onclose = () => {
      options.onDisconnect?.();
      scheduleReconnect();
    };
  }

  function scheduleReconnect() {
    if (reconnectAttempts >= maxReconnectAttempts) return;
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
    reconnectAttempts++;
    setTimeout(connect, delay);
  }

  function subscribe(channel: string, params: Record<string, string>,
                     handler: (msg: CableMessage) => void) {
    const identifier = JSON.stringify({ channel, ...params });
    subscriptions.set(identifier, handler);
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ command: 'subscribe', identifier }));
    }
    return () => {
      subscriptions.delete(identifier);
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ command: 'unsubscribe', identifier }));
      }
    };
  }

  function disconnect() {
    subscriptions.clear();
    ws?.close();
    ws = null;
  }

  connect();

  return { subscribe, disconnect };
}
```

#### 3.5.2 Realtime Store

```typescript
// src/features/realtime/realtime.store.svelte.ts

import { createCable } from './cable-client';
import { getStoredToken } from '$lib/api-client';

let cable: ReturnType<typeof createCable> | null = null;
let connected = $state(false);

export function getRealtimeStore() {
  return {
    get connected() { return connected; },

    connect() {
      const token = getStoredToken();
      if (!token || cable) return;

      cable = createCable({
        token,
        onConnect: () => { connected = true; },
        onDisconnect: () => { connected = false; }
      });
    },

    subscribeToInbox(inboxId: string, handler: (msg: any) => void) {
      if (!cable) return () => {};
      return cable.subscribe('InboxChannel', { inbox_id: inboxId }, handler);
    },

    subscribeToProject(projectId: string, handler: (msg: any) => void) {
      if (!cable) return () => {};
      return cable.subscribe('ProjectChannel', { project_id: projectId }, handler);
    },

    disconnect() {
      cable?.disconnect();
      cable = null;
      connected = false;
    }
  };
}
```

#### 3.5.3 Usage in Inbox View

```svelte
<!-- Usage example in inbox email list page -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { getRealtimeStore } from '../../features/realtime/realtime.store.svelte';
  import { getEmailsStore } from '../../features/emails/emails.store.svelte';

  const { inboxId } = $props();
  const realtime = getRealtimeStore();
  const emails = getEmailsStore();
  let unsubscribe: (() => void) | undefined;

  onMount(() => {
    realtime.connect();
    unsubscribe = realtime.subscribeToInbox(inboxId, (msg) => {
      if (msg.type === 'email_received') {
        emails.prepend(msg.email);
      } else if (msg.type === 'email_deleted') {
        emails.remove(msg.email_id);
      } else if (msg.type === 'inbox_purged') {
        emails.clear();
      }
    });
  });

  onDestroy(() => {
    unsubscribe?.();
  });
</script>
```

### 3.6 Vite Proxy Updates

Add WebSocket proxy for ActionCable in development:

```typescript
// vite.config.ts — add to proxy config
'/cable': {
  target: 'ws://localhost:3100',
  ws: true
}
```

### 3.7 Caddy Updates

Add WebSocket proxy for ActionCable in production:

```caddyfile
# Caddyfile additions
handle /cable {
    reverse_proxy api:3100
}
```

### 3.8 Delete `features/messages/`

Remove the old mock `messages/` feature module entirely. It's replaced by `features/emails/` which uses real API data. Files to delete:

- `src/features/messages/MessageList.svelte`
- `src/features/messages/MessagePreview.svelte`
- `src/features/messages/messages.service.ts`
- `src/features/messages/messages.store.svelte.ts`
- `src/features/messages/messages.types.ts`

---

## 4. Technical Decisions

### 4.1 Shared Read Models Between Admin and API v1

Admin controllers reuse the same read models and serializers as API v1 controllers. The only difference is:
- **Auth:** admin token vs API key
- **Scope:** admin can access any project; API v1 is scoped to the authenticated project
- **Search:** admin search is cross-project; API v1 search is project-scoped

This is achieved by passing `project_id` as a parameter to read models. Admin controllers get it from the URL; API v1 controllers get it from `@current_project`.

### 4.2 HTML Email Preview Security

HTML emails are rendered in a sandboxed iframe using `srcdoc`:
- `sandbox="allow-same-origin"` — allows same-origin access for height measurement but blocks scripts, forms, popups, navigation, and top-level navigation
- No `allow-scripts` — JavaScript in emails never executes
- No `allow-popups` — links in emails don't open popups
- External resources (images, CSS) are blocked by the sandbox by default
- Inline styles and inline images (base64 data URIs from MIME parsing) work correctly

### 4.3 OTP Detection Strategy

OTP extraction is purely client-side (no backend logic):
1. Check `subject` first — many verification emails include the code in the subject line
2. Check `body_text` — scan plain text body for common patterns
3. Patterns are ordered by specificity: labeled codes first, then numeric codes
4. Only the first match is shown in the banner
5. No false positive filtering — in a dev tool, showing a possible OTP is always useful

### 4.4 Routing: SPA with File-Based Routes

SvelteKit with `adapter-static` and `fallback: 'index.html'` generates a pure client-side SPA:
- All routes resolve client-side — no SSR, no server functions
- Deep linking works because Caddy serves `index.html` for all unmatched routes
- `$page.params` provides route parameters (`projectId`, `inboxId`, `emailId`)
- Navigation uses SvelteKit's `goto()` and `<a>` tags — no full page reloads

### 4.5 State Management with Svelte 5 Runes

Each feature module has a `.store.svelte.ts` using Svelte 5 `$state` runes:
- Stores are singletons created via `getXxxStore()` factory functions
- State is reactive via `$state()` — components automatically re-render when state changes
- No external state management library needed
- Real-time messages mutate store state directly (prepend, remove, clear)

---

## 5. Implementation Plan

### Step 1: Admin Read Endpoints (Rails)

1. Create `Admin::InboxesController` with `index`, `show`, `destroy`
2. Create `Admin::EmailsController` with `index`, `show`, `raw`, `destroy`, `purge`
3. Create `Admin::AttachmentsController` with `index`, `download`
4. Create `Admin::SearchController` with `show` (cross-project search)
5. Extend `EmailSearch.search_all` for cross-project queries
6. Add routes under `namespace :admin`
7. Write request specs for all new admin endpoints

### Step 2: ActionCable Channels (Rails)

1. Implement `ApplicationCable::Connection` with admin token auth
2. Create `InboxChannel` and `ProjectChannel`
3. Add event store subscribers for `EmailReceived`, `EmailDeleted`, `InboxPurged`, `InboxCreated`
4. Add WebSocket mount to routes (`/cable`)
5. Write channel specs (connection auth, subscription, broadcast)

### Step 3: Dashboard Routing + Layout

1. Restructure `src/routes/` with file-based routing
2. Update `+layout.svelte` with auth guard + sidebar
3. Update `Sidebar.svelte` with dynamic project navigation
4. Add `/$page.params` extraction in route pages
5. Set up `goto()` navigation between views
6. Delete `features/messages/` (replaced by `features/emails/`)

### Step 4: Projects Feature

1. Create `projects.service.ts` → API calls to `/admin/projects`
2. Create `projects.store.svelte.ts` → project list state
3. Create `ProjectList.svelte` → project cards with stats
4. Create `ProjectDetail.svelte` → info + edit + delete
5. Create `ApiKeyManager.svelte` → generate, revoke, copy token

### Step 5: Inboxes + Emails Features

1. Create `inboxes.service.ts` → API calls to `/admin/projects/:id/inboxes`
2. Create `InboxList.svelte` → inbox table with email counts
3. Create `emails.service.ts` → API calls to email admin endpoints
4. Create `EmailList.svelte` → email list with infinite scroll
5. Create `EmailDetail.svelte` → tabs (HTML, text, raw, headers)
6. Create `EmailPreview.svelte` → sandboxed iframe for HTML
7. Create `EmailRaw.svelte` → raw MIME viewer
8. Create `EmailHeaders.svelte` → header key-value table
9. Create `AttachmentList.svelte` → attachment download links
10. Create `OtpBanner.svelte` → OTP detection + copy

### Step 6: Search Feature

1. Create `search.service.ts` → API calls to `/admin/search`
2. Create `SearchPage.svelte` → debounced input + results list
3. Create `SearchResultItem.svelte` → result row with project context
4. Cursor pagination for search results

### Step 7: Real-time Integration

1. Create `cable-client.ts` → ActionCable WebSocket wrapper
2. Create `realtime.store.svelte.ts` → connection state + subscriptions
3. Wire inbox view to `InboxChannel` (prepend/remove/clear emails)
4. Wire project view to `ProjectChannel` (inbox count updates)
5. Add WebSocket connection indicator to StatusPanel
6. Update Vite proxy config for `/cable` WebSocket
7. Update Caddyfile for `/cable` proxy

### Step 8: Polish + Testing

1. Verify deep linking works (navigate directly to `/projects/:id/emails/:eid`)
2. Test real-time flow: send email via SMTP → appears in dashboard
3. Test OTP detection with common email patterns
4. Test HTML email preview with complex layouts
5. Test attachment download
6. Verify auth guard on all routes
7. Verify WebSocket reconnection on disconnect
8. Run full ESLint + svelte-check
9. Test responsive layout (sidebar collapse on mobile)

---

## 6. Exit Criteria

### Backend (Rails)

- [ ] **EC-001:** `GET /admin/projects/:id/inboxes` returns paginated inbox list with email counts
- [ ] **EC-002:** `GET /admin/projects/:pid/inboxes/:iid/emails` returns paginated email list
- [ ] **EC-003:** `GET /admin/emails/:id` returns full email detail with attachments
- [ ] **EC-004:** `GET /admin/emails/:id/raw` returns raw MIME source with correct Content-Type
- [ ] **EC-005:** `DELETE /admin/emails/:id` deletes email and returns 204
- [ ] **EC-006:** `DELETE /admin/projects/:pid/inboxes/:iid/emails` purges inbox and returns deleted count
- [ ] **EC-007:** `DELETE /admin/projects/:pid/inboxes/:iid` deletes inbox cascade
- [ ] **EC-008:** `GET /admin/emails/:eid/attachments` returns attachment list
- [ ] **EC-009:** `GET /admin/attachments/:id/download` returns binary with correct headers
- [ ] **EC-010:** `GET /admin/search?q=...` returns cross-project search results
- [ ] **EC-011:** All admin read endpoints return 401 without valid admin token
- [ ] **EC-012:** ActionCable connection rejects unauthenticated WebSocket
- [ ] **EC-013:** `InboxChannel` broadcasts `email_received` when email is processed
- [ ] **EC-014:** `InboxChannel` broadcasts `email_deleted` on email deletion
- [ ] **EC-015:** `ProjectChannel` broadcasts `inbox_created` when new inbox appears
- [ ] **EC-016:** Request specs pass for all new admin endpoints
- [ ] **EC-017:** Channel specs pass for connection auth and subscriptions

### Dashboard (SvelteKit)

- [ ] **EC-018:** Login flow authenticates with admin token and redirects to `/projects`
- [ ] **EC-019:** Unauthenticated access to any route redirects to `/login`
- [ ] **EC-020:** `/projects` displays project list from API
- [ ] **EC-021:** Create project modal creates project and refreshes list
- [ ] **EC-022:** `/projects/:id` displays project detail with API keys and inboxes
- [ ] **EC-023:** Generate API key shows full token once, copy button works
- [ ] **EC-024:** Revoke API key removes it from list after confirmation
- [ ] **EC-025:** `/projects/:id/inboxes/:iid` displays paginated email list
- [ ] **EC-026:** Infinite scroll loads more emails via cursor pagination
- [ ] **EC-027:** Click email navigates to `/projects/:id/emails/:eid`
- [ ] **EC-028:** Email detail shows HTML tab with sandboxed iframe preview
- [ ] **EC-029:** Email detail shows Text tab with plain text body
- [ ] **EC-030:** Email detail shows Raw tab with MIME source (lazy loaded)
- [ ] **EC-031:** Email detail shows Headers tab with expandable key-value pairs
- [ ] **EC-032:** OTP banner appears when verification code detected in subject or body
- [ ] **EC-033:** OTP copy button copies code to clipboard
- [ ] **EC-034:** Attachment list shows files with download links
- [ ] **EC-035:** Attachment download works (correct file, filename, content type)
- [ ] **EC-036:** Delete email removes it and navigates back to inbox
- [ ] **EC-037:** Purge inbox clears all emails after confirmation
- [ ] **EC-038:** `/search` performs cross-project search with debounced input
- [ ] **EC-039:** Search results navigate to correct email detail page
- [ ] **EC-040:** Deep linking works — direct navigation to any route loads correctly

### Real-time

- [ ] **EC-041:** WebSocket connects on dashboard load with admin token
- [ ] **EC-042:** New email appears in inbox list within 2 seconds of SMTP receipt
- [ ] **EC-043:** Deleted email disappears from inbox list in real-time
- [ ] **EC-044:** Inbox purge clears the list in real-time
- [ ] **EC-045:** WebSocket reconnects automatically after disconnection
- [ ] **EC-046:** WebSocket status indicator shows connected/disconnected state

### Integration

- [ ] **EC-047:** E2E: send email via `swaks` → appears in dashboard inbox view within 2 seconds
- [ ] **EC-048:** ESLint and svelte-check pass with zero errors
- [ ] **EC-049:** Old `features/messages/` directory is deleted

---

## 7. Open Questions

None — all architectural decisions resolved via ADR-011 (ActionCable) and ADR-012 (admin auth).
