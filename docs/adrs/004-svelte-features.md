# ADR-004: Feature-based Svelte Architecture

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The Svelte dashboard is a client of the Rails API. It doesn't need DDD — that would be over-engineering. But it does need a clear organizational pattern that scales beyond the current 3-component prototype.

The default SvelteKit convention is route-based (`src/routes/`). This works for page structure but doesn't address where to put shared state, API calls, types, and business logic that isn't tied to a specific route.

## Decision

Adopt a **feature-based architecture** that separates UI components from logic:

### Directory Structure

```
apps/dashboard/src/
├── features/                    # Feature modules
│   ├── messages/
│   │   ├── MessageList.svelte       # UI component
│   │   ├── MessageDetail.svelte     # UI component
│   │   ├── messages.service.ts      # API calls + data transformation
│   │   ├── messages.store.ts        # Reactive state (Svelte 5 runes)
│   │   └── messages.types.ts        # TypeScript interfaces
│   ├── auth/
│   │   ├── LoginForm.svelte
│   │   ├── auth.service.ts
│   │   ├── auth.store.ts
│   │   └── auth.types.ts
│   └── system/
│       ├── StatusPanel.svelte
│       ├── system.service.ts
│       └── system.types.ts
├── lib/
│   ├── api-client.ts            # Generic HTTP client (fetch wrapper)
│   ├── event-source.ts          # SSE/WebSocket for real-time updates
│   └── components/              # Shared/generic UI components
│       ├── Layout.svelte
│       ├── Sidebar.svelte
│       └── Header.svelte
├── routes/                      # SvelteKit routes (thin, delegate to features)
│   ├── +layout.svelte
│   ├── +page.svelte             # → uses messages/ feature
│   └── login/
│       └── +page.svelte         # → uses auth/ feature
└── app.css                      # Tailwind theme tokens
```

### Rules

1. **Features are self-contained modules** — each has its own components, service, store, and types.
2. **Components are dumb** — they receive props and emit events. No direct API calls.
3. **Services handle all external communication** — API calls, data transformation, error mapping.
4. **Stores hold reactive state** — use Svelte 5 runes (`$state`, `$derived`, `$effect`). Stores are the single source of truth for feature state.
5. **Routes are thin** — they compose feature components and connect stores. Minimal logic.
6. **`lib/` is for shared infrastructure** — API client, generic components, utilities. Not feature logic.
7. **Features can import from `lib/` but not from other features** — if two features need to share, extract to `lib/`.

### Example: messages feature

```typescript
// messages.types.ts
export interface Message {
  id: string;
  from: string;
  to: string[];
  subject: string;
  body_html: string | null;
  body_text: string | null;
  received_at: string;
}

// messages.service.ts
import { apiClient } from '$lib/api-client';
import type { Message } from './messages.types';

export async function fetchMessages(): Promise<Message[]> { ... }
export async function fetchMessage(id: string): Promise<Message> { ... }

// messages.store.ts
import { fetchMessages } from './messages.service';
import type { Message } from './messages.types';

let messages = $state<Message[]>([]);
let selected = $state<Message | null>(null);
let loading = $state(false);

export function getMessagesStore() {
  return {
    get messages() { return messages; },
    get selected() { return selected; },
    get loading() { return loading; },
    async load() { ... },
    select(id: string) { ... }
  };
}
```

## Consequences

### Easier

- **Finding code** — need to change message behavior? Look in `features/messages/`
- **Adding features** — copy the pattern, create a new folder
- **Testing** — services are pure functions, stores are isolated state
- **Code review** — a feature change is contained within its folder
- **LLM navigation** — clear, predictable file structure

### Harder

- **Initial overhead** — 4 files per feature vs 1 component with everything inline
- **Prop drilling** — dumb components need data passed down explicitly
- **Feature boundaries** — deciding what constitutes a "feature" vs a shared component

### Mitigations

- Only create features for things with their own state + API surface. A reusable button is a `lib/component`, not a feature
- Svelte 5 runes make stores lightweight — no boilerplate compared to Svelte 4 stores
