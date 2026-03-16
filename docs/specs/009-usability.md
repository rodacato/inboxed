# Spec 009 — Usability & UI Scalability

> Prepare the dashboard UI/UX to grow from email-only to the full dev inbox vision (hooks, forms, heartbeats, multi-tenancy) without increasing complexity. Reusable layout primitives, modular navigation, extensible auth, and developer-first UX patterns.

**Phase:** Cross-cutting (prepares for Phases 8 + 9)
**Status:** accepted
**Created:** 2026-03-16
**Depends on:** [004 — Dashboard](004-dashboard.md) (implemented)
**Informs:** [VISION.md](../VISION.md) modules, [ROADMAP.md](../ROADMAP.md) Phase 8 (HTTP Catcher), Phase 9 (Cloud)
**Expert panel:** UX/UI Designer + Full-Stack Engineer + API Design Architect + Product Manager

---

## 1. Objective

The dashboard was built for email inspection (spec 004). The VISION.md describes a multi-module dev inbox (Mail, Hooks In, Forms, Heartbeats). Phase 9 adds multi-tenancy with users and projects.

This spec defines the structural changes needed **now** so that adding each new module or the cloud auth layer is additive — no layout rewrites, no navigation redesigns, no breaking route changes.

**Guiding principle:** Every module is "catch, inspect, assert" with the same UX pattern. Build the pattern once, vary the content per module.

---

## 2. Current State

### What exists (from spec 004 implementation)

- **Routing:** `/projects/[id]/emails`, `/projects/[id]/inboxes/[id]`, `/search`
- **Sidebar:** Static project list with inbox counts, search link, theme toggle, WebSocket status
- **Split view:** Hardcoded in email pages (left: email list, right: email preview)
- **Auth:** Single `INBOXED_ADMIN_TOKEN`, stored in localStorage, no user concept
- **Real-time:** ActionCable WebSocket with InboxChannel and ProjectChannel
- **Components:** `Sidebar.svelte`, `EmailPreview.svelte` — tightly coupled to email domain
- **Features:** `auth/`, `emails/`, `inboxes/`, `projects/`, `realtime/`, `search/`, `system/`
- **Empty states:** Generic text ("Create one to get started")
- **No toast notifications** — real-time updates are silent list mutations
- **No command palette** — navigation is click-only
- **No responsive collapse** — sidebar is fixed width, split view doesn't adapt to mobile

### What's missing for the vision

| Gap | Blocks |
|-----|--------|
| Routes are email-specific (`/emails`) | Phase 8 modules need their own routes |
| Split view is not a reusable component | Every module will need the same layout |
| Sidebar shows only project inbox counts | Modules need per-project sections |
| Auth is admin-only, no user abstraction | Phase 9 cloud mode needs user sessions |
| Empty states don't guide developers | First-time UX is weak |
| No notification system | Real-time events are invisible unless you're looking at the right list |
| No keyboard navigation | Developer tool should be keyboard-first |
| No mobile adaptation | Split view breaks on small screens |

---

## 3. What This Spec Delivers

Nine workstreams, ordered by dependency. Each is independently shippable.

### 3.1 Reusable Layout Primitives

Extract the hardcoded split-view pattern into composable components.

#### 3.1.1 `SplitPane.svelte`

Two-panel layout with resizable divider. Used by every module's list+detail view.

```svelte
<!-- $lib/components/SplitPane.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    listWidth?: string;       // default: 'w-96'
    showDetail?: boolean;     // controls right panel visibility
    list: Snippet;
    detail: Snippet;
    empty?: Snippet;          // shown when showDetail is false
  }

  let { listWidth = 'w-96', showDetail = false, list, detail, empty }: Props = $props();
</script>

<div class="flex h-full">
  <!-- Left panel: list -->
  <div class="{listWidth} flex-shrink-0 border-r border-border overflow-y-auto
              max-md:w-full max-md:{showDetail ? 'hidden' : ''}">
    {@render list()}
  </div>

  <!-- Right panel: detail or empty state -->
  <div class="flex-1 overflow-y-auto max-md:w-full max-md:{!showDetail ? 'hidden' : ''}">
    {#if showDetail}
      {@render detail()}
    {:else if empty}
      {@render empty()}
    {:else}
      <div class="flex items-center justify-center h-full text-text-dim font-mono text-sm">
        Select an item to inspect
      </div>
    {/if}
  </div>
</div>
```

**Mobile behavior:** On screens `< md`, show only one panel at a time. List by default, detail when an item is selected. Back button returns to list.

#### 3.1.2 `FilterableList.svelte`

Reusable list with filter chips, pagination, and empty state. Used by emails, hooks, forms, heartbeats.

```svelte
<!-- $lib/components/FilterableList.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface FilterChip {
    id: string;
    label: string;
    count?: number;
    active?: boolean;
  }

  interface Props {
    title: string;
    totalCount: number;
    filters?: FilterChip[];
    onFilterChange?: (filterId: string) => void;
    hasMore?: boolean;
    onLoadMore?: () => void;
    actions?: Snippet;          // header action buttons (purge, delete, etc.)
    items: Snippet;             // the list items
    emptyState?: Snippet;       // shown when totalCount is 0
  }
</script>
```

#### 3.1.3 `DetailPanel.svelte`

Generic detail view with header, tabs, metadata, and actions. Used by email detail, request detail, form detail, heartbeat detail.

```svelte
<!-- $lib/components/DetailPanel.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Tab {
    id: string;
    label: string;
    badge?: string;
  }

  interface Props {
    title: string;
    tabs: Tab[];
    activeTab?: string;
    onTabChange?: (tabId: string) => void;
    banner?: Snippet;           // OTP banner, status banner, etc.
    metadata: Snippet;          // from/to, method/url, etc.
    content: Snippet;           // tab content area
    actions?: Snippet;          // delete, download, replay, etc.
    footer?: Snippet;           // attachments, expiry info, etc.
  }
</script>
```

#### 3.1.4 Refactor existing email views

- `EmailPreview.svelte` becomes a wrapper that uses `DetailPanel` with email-specific tabs (HTML, Text, Raw, Headers)
- Inbox email list page uses `SplitPane` + `FilterableList`
- Project emails page uses `SplitPane` + `FilterableList` with inbox chips as filters
- No visible UX change — same layout, extracted into composable parts

### 3.2 Route Restructuring

Rename routes to align with VISION.md module naming and prepare slots for future modules.

#### Current → New route mapping

```
/projects                              → /projects                  (unchanged)
/projects/[id]                         → /projects/[id]/settings    (explicit)
/projects/[id]/emails                  → /projects/[id]/mail        (module name)
/projects/[id]/emails/[emailId]        → /projects/[id]/mail/[emailId]
/projects/[id]/inboxes/[inboxId]       → /projects/[id]/mail/inbox/[inboxId]
/search                                → /search                    (unchanged)
```

#### Future routes (not implemented in this spec, but structure supports)

```
/projects/[id]/hooks                   → Phase 8: webhook endpoints + captured requests
/projects/[id]/hooks/[endpointId]      → Endpoint detail with request list
/projects/[id]/forms                   → Phase 8: form endpoints
/projects/[id]/heartbeats              → Phase 8: heartbeat monitors
/projects/[id]/activity                → 3.7: activity feed
/register                              → Phase 9: cloud registration
/dashboard                             → Phase 9: user dashboard
```

#### File structure

```
src/routes/
├── +layout.svelte                         → auth guard, sidebar, toast container
├── +page.svelte                           → redirect to /projects
├── login/+page.svelte
├── projects/
│   ├── +page.svelte                       → project list
│   └── [projectId]/
│       ├── +layout.svelte                 → project context, module nav
│       ├── settings/+page.svelte          → project config, API keys, inboxes
│       └── mail/
│           ├── +page.svelte               → all project emails (split view)
│           ├── [emailId]/+page.svelte     → email detail (full page)
│           └── inbox/
│               └── [inboxId]/+page.svelte → inbox emails (split view)
└── search/+page.svelte
```

#### Redirects

Add client-side redirects for old routes during transition:
- `/projects/[id]` → `/projects/[id]/settings`
- `/projects/[id]/emails` → `/projects/[id]/mail`
- `/projects/[id]/emails/[eid]` → `/projects/[id]/mail/[eid]`
- `/projects/[id]/inboxes/[iid]` → `/projects/[id]/mail/inbox/[iid]`

### 3.3 Module-Aware Sidebar

Refactor sidebar to show per-project module sections, preparing for multi-module navigation.

#### Structure

```
┌─────────────────────────────────┐
│  [@] inboxed                    │
│─────────────────────────────────│
│  🔍 Search                      │
│                                 │
│  PROJECT: my-app           [⚙]  │
│    📧 Mail              (12)    │  ← active module highlight
│    🔗 Hooks In           (—)    │  ← future: Phase 8 (hidden until enabled)
│    📋 Forms              (—)    │  ← future: Phase 8 (hidden until enabled)
│    💓 Heartbeats         (—)    │  ← future: Phase 8 (hidden until enabled)
│                                 │
│  PROJECT: staging          [⚙]  │
│    📧 Mail               (5)   │
│                                 │
│  + New Project                  │
│─────────────────────────────────│
│  [🌙]  [● Connected]  [Logout] │
└─────────────────────────────────┘
```

#### Implementation

```typescript
// Module registry — extensible for future modules
interface SidebarModule {
  id: string;                    // 'mail' | 'hooks' | 'forms' | 'heartbeats'
  label: string;                 // 'Mail' | 'Hooks In' | 'Forms' | 'Heartbeats'
  icon: string;                  // Material icon name
  route: (projectId: string) => string;
  countKey: string;              // key in project stats response
  enabled: boolean;              // feature flag — only Mail is true initially
}

const MODULES: SidebarModule[] = [
  {
    id: 'mail',
    label: 'Mail',
    icon: 'mail',
    route: (pid) => `/projects/${pid}/mail`,
    countKey: 'email_count',
    enabled: true
  },
  // Future modules registered here when Phase 8 ships:
  // { id: 'hooks', label: 'Hooks In', icon: 'webhook', ... enabled: false },
  // { id: 'forms', label: 'Forms', icon: 'description', ... enabled: false },
  // { id: 'heartbeats', label: 'Heartbeats', icon: 'favorite', ... enabled: false },
];
```

#### Key changes from current sidebar

- Projects are expandable sections (not just links)
- Each project shows its enabled modules with counts
- Settings icon `[⚙]` links to `/projects/[id]/settings`
- Active module has phosphor highlight (current: just active project)
- "New Project" button at bottom of project list
- Module list filters by `enabled` flag — today only Mail shows

#### Collapsible sidebar

- Toggle button to collapse sidebar to icon-only mode (48px width)
- Collapsed shows: logo icon, search icon, project initials with module icons
- State persisted in localStorage
- On mobile (`< md`): sidebar becomes a slide-out drawer with overlay

### 3.4 Project Layout with Module Tabs

New layout at `/projects/[id]/+layout.svelte` that wraps all project routes with module navigation.

```svelte
<!-- src/routes/projects/[projectId]/+layout.svelte -->
<script lang="ts">
  import { page } from '$app/stores';

  let { children } = $props();
  const projectId = $derived($page.params.projectId);

  // Module tabs shown below project header
  const tabs = [
    { id: 'mail', label: 'Mail', href: `/projects/${projectId}/mail`, icon: 'mail' },
    // Future: hooks, forms, heartbeats
    { id: 'settings', label: 'Settings', href: `/projects/${projectId}/settings`, icon: 'settings' },
  ];
</script>

<div class="flex flex-col h-full">
  <!-- Module tab bar -->
  <nav class="flex border-b border-border bg-surface px-4">
    {#each tabs as tab}
      <a
        href={tab.href}
        class="px-4 py-3 font-mono text-sm border-b-2 transition-colors
               {isActive(tab) ? 'border-phosphor text-phosphor' : 'border-transparent text-text-secondary hover:text-text-primary'}"
      >
        <span class="material-symbols-outlined text-base mr-1">{tab.icon}</span>
        {tab.label}
      </a>
    {/each}
  </nav>

  <!-- Module content -->
  <div class="flex-1 overflow-hidden">
    {@render children()}
  </div>
</div>
```

This provides dual navigation: sidebar for project switching, tab bar for module switching within a project. When Phase 8 ships, adding a module is one line in the `tabs` array.

### 3.5 Empty States

Replace generic empty states with actionable, context-specific onboarding.

#### 3.5.1 `EmptyState.svelte`

```svelte
<!-- $lib/components/EmptyState.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    icon: string;
    title: string;
    description?: string;
    content?: Snippet;           // custom content (code snippets, etc.)
    action?: Snippet;            // action button
  }
</script>

<div class="flex flex-col items-center justify-center py-16 px-8 text-center">
  <span class="material-symbols-outlined text-5xl text-text-dim mb-4">{icon}</span>
  <h3 class="font-display text-xl text-text-primary mb-2">{title}</h3>
  {#if description}
    <p class="text-text-secondary text-sm max-w-md mb-6">{description}</p>
  {/if}
  {#if content}
    {@render content()}
  {/if}
  {#if action}
    <div class="mt-6">{@render action()}</div>
  {/if}
</div>
```

#### 3.5.2 Context-specific empty states

**No projects:**
```
📦 No projects yet
Create a project to start catching emails.
[+ Create Project]
```

**Project with no emails:**
```
📧 No emails yet
Configure your app's SMTP to point at Inboxed:

┌─────────────────────────────────────┐
│ SMTP_HOST=localhost                  │
│ SMTP_PORT=2525                       │
│ SMTP_USER=inx_abc1...               │  ← actual API key prefix
│ SMTP_PASS=<your-api-key>            │
└─────────────────────────────────────┘ [Copy]

Or test with swaks:
┌─────────────────────────────────────────────────┐
│ swaks --to test@myapp.test \                    │
│   --server localhost:2525 \                      │
│   --au inx_abc1... --ap <your-api-key>          │
└─────────────────────────────────────────────────┘ [Copy]

📖 Setup guide
```

**Project with no API keys:**
```
🔑 No API keys yet
Generate an API key to authenticate SMTP connections and API requests.
[+ Generate API Key]
```

**Search with no results:**
```
🔍 No results for "{{query}}"
Try a different search term. Search covers email subjects and body text.
```

**Search initial state:**
```
🔍 Search across all projects
Type to search email subjects and body text.
Tip: Use Cmd+K from anywhere to jump here.
```

#### 3.5.3 Implementation

Each feature module provides its own empty state content. The `EmptyState` component is the layout primitive. Smart content (like actual API key prefix, SMTP config) is computed from project context.

### 3.6 Toast Notification System

Surface real-time events as transient notifications so the user knows something happened even when they're not looking at the relevant list.

#### 3.6.1 Toast Store

```typescript
// src/lib/stores/toast.store.svelte.ts

interface Toast {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  title: string;
  description?: string;
  action?: { label: string; href: string };  // e.g. "View" → navigate to email
  duration?: number;                          // ms, default 5000, 0 = persistent
}

let toasts = $state<Toast[]>([]);

export const toastStore = {
  get items() { return toasts; },

  add(toast: Omit<Toast, 'id'>) {
    const id = crypto.randomUUID();
    toasts = [...toasts, { ...toast, id }];
    const duration = toast.duration ?? 5000;
    if (duration > 0) {
      setTimeout(() => this.dismiss(id), duration);
    }
    return id;
  },

  dismiss(id: string) {
    toasts = toasts.filter(t => t.id !== id);
  },

  clear() {
    toasts = [];
  }
};
```

#### 3.6.2 `ToastContainer.svelte`

```svelte
<!-- $lib/components/ToastContainer.svelte -->
<!-- Fixed bottom-right, stacked vertically, animated enter/exit -->
<!-- Positioned in root +layout.svelte, outside main content -->

<div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm">
  {#each toastStore.items as toast (toast.id)}
    <div
      class="bg-surface border border-border rounded-lg p-3 shadow-lg
             flex items-start gap-3 animate-slide-in"
      role="alert"
    >
      <!-- Icon by type: success=phosphor, warning=amber, error=error, info=cyan -->
      <span class="material-symbols-outlined text-{colorForType(toast.type)}">
        {iconForType(toast.type)}
      </span>
      <div class="flex-1 min-w-0">
        <p class="font-mono text-sm text-text-primary">{toast.title}</p>
        {#if toast.description}
          <p class="text-xs text-text-secondary mt-0.5 truncate">{toast.description}</p>
        {/if}
        {#if toast.action}
          <a href={toast.action.href} class="text-xs text-phosphor hover:underline mt-1 inline-block">
            {toast.action.label} →
          </a>
        {/if}
      </div>
      <button onclick={() => toastStore.dismiss(toast.id)} class="text-text-dim hover:text-text-secondary">
        <span class="material-symbols-outlined text-base">close</span>
      </button>
    </div>
  {/each}
</div>
```

#### 3.6.3 Wiring to real-time events

Connect existing WebSocket event handlers to toasts:

```typescript
// In realtime event handlers (existing subscriptions)

// When email_received:
toastStore.add({
  type: 'success',
  title: 'New email received',
  description: `${email.subject} → ${email.to}`,
  action: { label: 'View', href: `/projects/${projectId}/mail/${email.id}` }
});

// When inbox_purged:
toastStore.add({
  type: 'info',
  title: 'Inbox purged',
  description: `${deletedCount} emails deleted`
});

// Future (Phase 8):
// When request_received on hook endpoint:
// toastStore.add({ type: 'success', title: 'Webhook received', description: 'POST /stripe' });
// When heartbeat missed:
// toastStore.add({ type: 'warning', title: 'Heartbeat missed', description: 'cleanup-cron is late' });
```

#### 3.6.4 User preference

Toast notifications for real-time events can be toggled via a preference stored in localStorage. Default: enabled. Toggle in sidebar settings or via command palette.

### 3.7 Command Palette

Keyboard-first navigation via `Cmd+K` (Mac) / `Ctrl+K` (Win/Linux).

#### 3.7.1 `CommandPalette.svelte`

```
┌──────────────────────────────────────────┐
│  🔍 Type a command or search...           │
│──────────────────────────────────────────│
│  NAVIGATION                              │
│  > Go to project "my-app"                │
│  > Go to project "staging"               │
│  > Search emails                         │
│──────────────────────────────────────────│
│  ACTIONS                                 │
│  > Create new project                    │
│  > Copy API key for "my-app"             │
│  > Toggle dark mode                      │
│  > Toggle notifications                  │
│──────────────────────────────────────────│
│  RECENT                                  │
│  > my-app / Mail                         │
│  > staging / Settings                    │
└──────────────────────────────────────────┘
```

#### 3.7.2 Command Registry

```typescript
// $lib/stores/commands.store.svelte.ts

interface Command {
  id: string;
  label: string;
  category: 'navigation' | 'action' | 'recent';
  icon?: string;
  keywords?: string[];          // for fuzzy search
  execute: () => void;          // typically goto() or action
}

let commands = $state<Command[]>([]);

export const commandStore = {
  get items() { return commands; },

  register(command: Command) {
    commands = [...commands.filter(c => c.id !== command.id), command];
  },

  unregister(id: string) {
    commands = commands.filter(c => c.id !== id);
  },

  search(query: string): Command[] {
    if (!query) return commands;
    const q = query.toLowerCase();
    return commands.filter(c =>
      c.label.toLowerCase().includes(q) ||
      c.keywords?.some(k => k.toLowerCase().includes(q))
    );
  }
};
```

#### 3.7.3 Features register commands

Each feature module registers its commands on mount. This is the extensibility pattern — when Phase 8 adds hooks, that module registers its own commands.

```typescript
// In projects feature (on load):
projects.forEach(p => {
  commandStore.register({
    id: `goto-project-${p.id}`,
    label: `Go to project "${p.name}"`,
    category: 'navigation',
    icon: 'folder',
    keywords: [p.name, p.slug],
    execute: () => goto(`/projects/${p.id}/mail`)
  });
});

// In search feature:
commandStore.register({
  id: 'search-emails',
  label: 'Search emails',
  category: 'navigation',
  icon: 'search',
  keywords: ['find', 'query'],
  execute: () => goto('/search')
});
```

#### 3.7.4 Keyboard handling

- `Cmd+K` / `Ctrl+K`: Toggle palette
- `Escape`: Close palette
- `↑`/`↓`: Navigate items
- `Enter`: Execute selected command
- Type to filter commands (fuzzy match on label + keywords)

### 3.8 Auth Abstraction for Multi-Tenancy

Prepare the auth layer so Phase 9 (Cloud mode with users) is additive, not a rewrite.

#### 3.8.1 Auth Store Abstraction

```typescript
// src/features/auth/auth.store.svelte.ts

interface AuthState {
  isAuthenticated: boolean;
  mode: 'admin' | 'user';                    // 'admin' today, 'user' in cloud
  token: string | null;

  // Present only in cloud mode (Phase 9):
  user?: {
    id: string;
    email: string;
    verified: boolean;
  };

  // Derived from mode:
  permissions: Set<string>;                   // Set(['admin']) today
  canManageAllProjects: boolean;              // true for admin, false for user
  projectIds?: string[];                      // null for admin (all), list for user
}
```

#### 3.8.2 What changes now

1. **Extract auth logic** from scattered localStorage calls into a single `authStore`
2. **All components** read auth state from `authStore`, never from localStorage directly
3. **API client** reads token from `authStore`, not localStorage
4. **Route guard** in root layout uses `authStore.isAuthenticated`
5. **Mode detection:** Read from API response — `/admin/status` already returns; extend to include `{ mode: 'standalone' | 'cloud' }` so the frontend knows which auth flow to show

#### 3.8.3 What changes in Phase 9 (not this spec)

- Add `/register` route, `RegistrationForm.svelte`, session-based auth
- `authStore` populates `user` field from session endpoint
- Route guard checks `authStore.mode` to decide redirect target (`/login` vs `/register`)
- Sidebar shows user email instead of "Admin" label
- Project list filtered by `authStore.projectIds`

#### 3.8.4 API response preparation

Extend `GET /admin/status` response:

```json
{
  "status": "ok",
  "version": "1.0.0",
  "mode": "standalone",
  "features": {
    "mail": true,
    "hooks": false,
    "forms": false,
    "heartbeats": false,
    "mcp": true
  }
}
```

The `features` map drives which modules appear in the sidebar and tab bar. Today all are hardcoded; this response makes it server-driven so the backend can control feature availability per deployment mode.

### 3.9 Responsive Design

Make the dashboard usable on tablets and phones.

#### 3.9.1 Breakpoints

| Breakpoint | Sidebar | Split view | Tab bar |
|------------|---------|------------|---------|
| `>= lg` (1024px) | Full sidebar (240px) | Both panels visible | Horizontal tabs |
| `md` (768-1023px) | Collapsed sidebar (48px, icons only) | Both panels, narrower list | Horizontal tabs |
| `< md` (< 768px) | Hidden, slide-out drawer | Single panel (list OR detail) | Scrollable horizontal |

#### 3.9.2 Sidebar drawer (mobile)

```svelte
<!-- In root layout, mobile sidebar -->
{#if isMobile}
  <!-- Hamburger button in top bar -->
  <button onclick={() => sidebarOpen = true} class="md:hidden p-2">
    <span class="material-symbols-outlined">menu</span>
  </button>

  <!-- Drawer overlay -->
  {#if sidebarOpen}
    <div class="fixed inset-0 z-40 bg-black/50" onclick={() => sidebarOpen = false}></div>
    <aside class="fixed inset-y-0 left-0 z-50 w-72 bg-surface border-r border-border">
      <Sidebar onNavigate={() => sidebarOpen = false} />
    </aside>
  {/if}
{:else}
  <Sidebar collapsed={isTablet} />
{/if}
```

#### 3.9.3 Split view mobile adaptation

When in single-panel mode (`< md`):
- Default: show list panel
- Select item: hide list, show detail with back button
- Back button: hide detail, show list
- URL updates normally — deep links to detail show detail panel directly

#### 3.9.4 Mobile top bar

On `< md`, add a top bar with:
- Hamburger menu (opens sidebar drawer)
- Current context breadcrumb (project name > module name)
- Action button (search, create, etc.)

---

## 4. Technical Decisions

### 4.1 Layout Components vs CSS-only Approach

- **Options:** A) Pure CSS (responsive classes only), B) Reusable Svelte layout components
- **Chosen:** B — Svelte layout components
- **Why:** Each module needs identical split-view + filterable-list + detail-panel patterns. CSS-only would mean duplicating 100+ lines of layout markup per module. Components enforce consistency and reduce per-module code to ~20 lines.
- **Trade-offs:** Slightly more abstraction upfront, but every Phase 8 module ships faster.

### 4.2 Route Rename Strategy

- **Options:** A) Keep `/emails` routes forever, B) Rename to `/mail` with redirects, C) Rename with no redirects
- **Chosen:** B — Rename with client-side redirects
- **Why:** `/mail` aligns with VISION.md naming ("Inboxed Mail"). Redirects maintain backward compatibility for bookmarks and shared links. The dashboard is an SPA with no external link economy, so the redirect cost is minimal.
- **Trade-offs:** Temporary redirect logic to maintain, but it's < 10 lines.

### 4.3 Module Discovery: Hardcoded vs Server-Driven

- **Options:** A) Hardcode module list in frontend, B) Backend returns enabled modules via API
- **Chosen:** B — Server-driven via `/admin/status` features map
- **Why:** Cloud mode (Phase 9) will disable certain modules per tier. Server-driven means the frontend doesn't need `if (mode === 'cloud')` conditionals — it just reads the feature map.
- **Trade-offs:** Extra API field, but it's one object in an existing endpoint.

### 4.4 Command Palette Implementation

- **Options:** A) Use a library (cmdk-sv), B) Custom implementation
- **Chosen:** B — Custom implementation
- **Why:** The command palette is simple (fuzzy search + keyboard nav + execute). A library adds a dependency for ~150 lines of custom code. The Inboxed branding (phosphor theme, terminal aesthetic) is easier to apply without fighting a library's styles.
- **Trade-offs:** More code, but full control over UX and styling.

### 4.5 Toast Placement

- **Options:** A) Bottom-right, B) Top-right, C) Top-center
- **Chosen:** A — Bottom-right
- **Why:** The email list (primary content) is top-left. Toasts in bottom-right minimize visual interference. This matches Linear, Vercel, and other dev tool conventions.
- **Trade-offs:** None significant.

---

## 5. Implementation Plan

### Step 1: Layout Primitives (no visible change)

1. Create `$lib/components/SplitPane.svelte`
2. Create `$lib/components/FilterableList.svelte`
3. Create `$lib/components/DetailPanel.svelte`
4. Refactor `/projects/[id]/emails/+page.svelte` to use `SplitPane` + `FilterableList`
5. Refactor `/projects/[id]/inboxes/[inboxId]/+page.svelte` to use `SplitPane` + `FilterableList`
6. Refactor `EmailPreview.svelte` to use `DetailPanel`
7. Verify: zero visual regressions, same behavior

### Step 2: Route Restructuring

1. Create new route structure under `/projects/[id]/mail/`
2. Move email pages to new locations
3. Create `/projects/[id]/settings/+page.svelte` (move from `/projects/[id]/+page.svelte`)
4. Add redirect pages at old route locations
5. Update all internal `goto()` and `<a href>` references
6. Create `/projects/[id]/+layout.svelte` with module tab bar
7. Verify: all navigation works, deep links resolve

### Step 3: Sidebar Refactor

1. Create module registry (`$lib/config/modules.ts`)
2. Refactor `Sidebar.svelte` with expandable project sections
3. Add module links per project (only Mail for now)
4. Add collapsible sidebar toggle with localStorage persistence
5. Add "New Project" link in sidebar
6. Verify: sidebar shows projects with Mail module, active state highlights correctly

### Step 4: Empty States

1. Create `$lib/components/EmptyState.svelte`
2. Create context-specific empty states:
   - No projects → create project CTA
   - No emails → SMTP config with real API key prefix
   - No API keys → generate key CTA
   - Search no results → helpful text
   - Search initial → hint with Cmd+K tip
   - Split view no selection → "Select an item"
3. Wire each empty state to its page/component
4. Verify: each empty state renders correctly with real project data

### Step 5: Toast Notifications

1. Create `$lib/stores/toast.store.svelte.ts`
2. Create `$lib/components/ToastContainer.svelte`
3. Add `<ToastContainer />` to root `+layout.svelte`
4. Add CSS animation (`animate-slide-in`)
5. Wire `email_received` realtime events to toast
6. Wire `inbox_purged` realtime events to toast
7. Add notification preference toggle (localStorage)
8. Verify: send email via SMTP → toast appears within 2s

### Step 6: Auth Abstraction

1. Create centralized `authStore` in `auth.store.svelte.ts`
2. Migrate all `localStorage` token access to `authStore`
3. Update `api-client.ts` to read token from `authStore`
4. Update root layout auth guard to use `authStore`
5. Add `mode` and `features` to `/admin/status` API response
6. Read `features` in frontend, expose via `authStore` or feature store
7. Wire sidebar module visibility to `features` map
8. Verify: auth flow unchanged, feature map controls module visibility

### Step 7: Command Palette

1. Create `$lib/stores/commands.store.svelte.ts`
2. Create `$lib/components/CommandPalette.svelte`
3. Add keyboard listener for `Cmd+K` / `Ctrl+K` in root layout
4. Register navigation commands (projects, search, settings)
5. Register action commands (create project, toggle theme)
6. Add fuzzy search filtering
7. Add keyboard navigation (↑↓ Enter Escape)
8. Verify: Cmd+K opens palette, navigation works, actions execute

### Step 8: Responsive Design

1. Add responsive classes to `SplitPane` (single-panel mode < md)
2. Add back button to detail panel in mobile mode
3. Create mobile top bar component
4. Convert sidebar to slide-out drawer on mobile
5. Add collapsed sidebar mode for tablet
6. Add scrollable tab bar for mobile
7. Verify: test at 375px (phone), 768px (tablet), 1280px (desktop)

### Step 9: Polish & Integration Testing

1. Verify all route transitions with real data
2. Test real-time flow end-to-end: SMTP → toast + list update
3. Test command palette with projects loaded
4. Test empty states with fresh install (no data)
5. Test responsive at all breakpoints
6. Test sidebar collapse/expand persistence
7. Run `svelte-check` and ESLint — zero errors
8. Test dark/light mode with all new components

---

## 6. Exit Criteria

### Layout Primitives
- [ ] **EC-001:** `SplitPane` renders two-panel layout with configurable list width
- [ ] **EC-002:** `SplitPane` collapses to single-panel on mobile (< md) with show/hide toggle
- [ ] **EC-003:** `FilterableList` renders title, count, filter chips, items, and load more button
- [ ] **EC-004:** `DetailPanel` renders title, tabs, metadata, content, actions, and footer slots
- [ ] **EC-005:** Existing email list and detail views use new primitives with zero visual regression

### Routes
- [ ] **EC-006:** `/projects/[id]/mail` shows project emails (split view)
- [ ] **EC-007:** `/projects/[id]/mail/[emailId]` shows email detail
- [ ] **EC-008:** `/projects/[id]/mail/inbox/[inboxId]` shows inbox emails
- [ ] **EC-009:** `/projects/[id]/settings` shows project config and API keys
- [ ] **EC-010:** Old routes (`/emails`, `/inboxes`) redirect to new locations
- [ ] **EC-011:** Deep linking works for all new routes

### Sidebar
- [ ] **EC-012:** Sidebar shows projects with expandable module sections
- [ ] **EC-013:** Only enabled modules appear (Mail only, currently)
- [ ] **EC-014:** Active project and module are highlighted with phosphor accent
- [ ] **EC-015:** Sidebar collapses to icon-only mode, state persists in localStorage
- [ ] **EC-016:** On mobile, sidebar is a slide-out drawer

### Empty States
- [ ] **EC-017:** No projects → shows create project CTA
- [ ] **EC-018:** No emails → shows SMTP config with real API key prefix and swaks command
- [ ] **EC-019:** No API keys → shows generate key CTA
- [ ] **EC-020:** Search empty → shows helpful text with Cmd+K hint
- [ ] **EC-021:** Split view no selection → shows "Select an item" placeholder

### Toasts
- [ ] **EC-022:** New email received → toast appears in bottom-right within 2s
- [ ] **EC-023:** Inbox purged → toast shows deleted count
- [ ] **EC-024:** Toast auto-dismisses after 5 seconds
- [ ] **EC-025:** Toast action link navigates to correct email detail
- [ ] **EC-026:** Toast notifications can be disabled via preference

### Auth
- [ ] **EC-027:** All token access goes through `authStore` (no direct localStorage reads elsewhere)
- [ ] **EC-028:** `/admin/status` returns `mode` and `features` fields
- [ ] **EC-029:** Sidebar module visibility is driven by `features` map from API
- [ ] **EC-030:** Auth flow unchanged (admin token login still works)

### Command Palette
- [ ] **EC-031:** `Cmd+K` opens command palette overlay
- [ ] **EC-032:** Typing filters commands by fuzzy match on label and keywords
- [ ] **EC-033:** Arrow keys navigate, Enter executes, Escape closes
- [ ] **EC-034:** Project navigation commands are registered for each loaded project
- [ ] **EC-035:** Action commands work (create project, toggle theme)

### Responsive
- [ ] **EC-036:** At 375px: sidebar is drawer, split view is single-panel, tabs scroll
- [ ] **EC-037:** At 768px: sidebar is collapsed, split view shows both panels
- [ ] **EC-038:** At 1280px: full sidebar, full split view, horizontal tabs
- [ ] **EC-039:** Mobile detail view has back button that returns to list
- [ ] **EC-040:** Mobile top bar shows hamburger + breadcrumb

### Integration
- [ ] **EC-041:** Full flow: send email → toast appears → click toast → email detail loads
- [ ] **EC-042:** `svelte-check` and ESLint pass with zero errors
- [ ] **EC-043:** Dark and light mode render correctly for all new components

---

## 7. Open Questions

1. **Sidebar collapse default on tablet:** Should tablet start collapsed or expanded? Collapsed saves space but hides project names. Recommendation: collapsed, since module tab bar provides context.

2. **Toast rate limiting:** If 50 emails arrive in 10 seconds (load test), should we batch toasts? Recommendation: show max 3 toasts simultaneously, queue the rest with a summary toast ("47 more emails received").

3. **Command palette scope:** Should `Cmd+K` search also include emails (like Spotlight)? Recommendation: not in this spec — keep it for navigation/actions. Email search stays in `/search`. Revisit if users request it.
