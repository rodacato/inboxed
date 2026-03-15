# 001 — Software Architecture

> Define the architectural patterns, layer boundaries, and conventions for all three services before writing business logic.

**Phase:** Cross-cutting (applies to all phases)
**Status:** approved
**Release:** —

---

## Objective

Establish a clear, documented software architecture for the Inboxed monorepo that:

1. Separates domain logic from infrastructure in the Rails API using rich DDD
2. Provides a custom event store for domain events with correlation, snapshots, and async projections
3. Organizes the Svelte dashboard by features with clean service/store/component separation
4. Keeps the MCP server thin with a tools + ports pattern
5. Is understandable by both human developers and LLM agents

This spec does **not** implement business logic. It defines *where* code goes and *how* layers interact, so that subsequent specs (002-email-model, etc.) have a clear structural foundation.

---

## Context

### Current State

- Foundation (spec 000) complete: Rails API, Svelte dashboard, MCP server skeleton
- No domain models, no business logic yet
- Rails API has two auth strategies working (API key + admin token)
- Dashboard has mock data and login flow
- MCP server is a skeleton with no tools

### Architectural Goals

- **Testability** — domain logic testable without Rails boot or database
- **Clarity** — any file's purpose is obvious from its location
- **Flexibility** — swap persistence, add event consumers, change UI framework without touching domain
- **Learning** — build infrastructure (event store) from scratch to understand internals
- **LLM-friendliness** — consistent patterns, clear naming, predictable file structure

### Constraints

- Must work within Rails 8 conventions where practical (routes, controllers, config)
- Must not over-engineer — architecture serves the domain, not the other way around
- Custom event store must be incremental (phase 1 → 2 → 3), not big-bang

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Clients                               │
│   Dashboard (Svelte)  │  MCP Server (Node)  │  curl / SDKs  │
└──────────┬────────────┴──────────┬──────────┴──────────┬────┘
           │                       │                      │
           ▼                       ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     Rails API (HTTP)                         │
│   Controllers — thin, dispatch to application services       │
├─────────────────────────────────────────────────────────────┤
│                   Application Layer                          │
│   Services — orchestrate domain + infrastructure             │
├─────────────────────────────────────────────────────────────┤
│                     Domain Layer                             │
│   Entities │ Value Objects │ Aggregates │ Events             │
│   Pure Ruby + dry-struct — zero Rails dependencies           │
├─────────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                        │
│   Repositories │ Event Store │ Adapters                      │
│   ActiveRecord models (persistence only)                     │
├─────────────────────────────────────────────────────────────┤
│                     PostgreSQL 16                            │
└─────────────────────────────────────────────────────────────┘
```

### Complexity Distribution

| Service | Architecture | Why |
|---------|-------------|-----|
| **Rails API** | Rich DDD + Event Store | Domain logic lives here. Emails, messages, API keys — all the business rules. |
| **Svelte Dashboard** | Features + Services | UI client. No domain logic, just display and interaction. Organized by feature. |
| **MCP Server** | Tools + Ports | Thin adapter. Translates MCP protocol to API calls. Stateless. |

---

## Rails API — Layer Structure

### Directory Layout

```
apps/api/app/
├── controllers/                 # HTTP layer — thin, delegates to services
│   ├── api/v1/
│   │   ├── base_controller.rb
│   │   └── messages_controller.rb
│   └── admin/
│       ├── base_controller.rb
│       └── messages_controller.rb
│
├── domain/                      # PURE RUBY — no Rails, no ActiveRecord
│   ├── types.rb                 # Dry::Types module + custom types
│   ├── entities/
│   │   └── message.rb           # Rich entity with behavior
│   ├── value_objects/
│   │   ├── email_address.rb     # Immutable, compared by value
│   │   └── message_body.rb
│   ├── aggregates/
│   │   └── message.rb           # Aggregate root with invariant enforcement
│   └── events/
│       ├── base_event.rb        # Base class for all domain events
│       ├── message_received.rb
│       └── message_deleted.rb
│
├── application/                 # Orchestration — loads, calls domain, publishes
│   └── services/
│       ├── receive_message.rb   # Use case: receive an email
│       ├── delete_message.rb    # Use case: delete a message
│       └── list_messages.rb     # Use case: query messages
│
├── infrastructure/              # Adapters to external systems
│   ├── repositories/
│   │   └── message_repository.rb  # AR ↔ Domain mapping
│   ├── event_store/
│   │   ├── store.rb             # Append events, read streams
│   │   ├── bus.rb               # Publish/subscribe dispatch
│   │   ├── aggregate_root.rb    # Base module for event-sourced aggregates
│   │   ├── event_record.rb      # ActiveRecord model for events table
│   │   ├── snapshot_store.rb    # Phase 2: snapshot persistence
│   │   └── projector.rb         # Phase 3: async projection base
│   └── adapters/
│       └── smtp_adapter.rb      # Future: SMTP reception adapter
│
├── models/                      # ActiveRecord — PERSISTENCE ONLY
│   ├── application_record.rb
│   ├── message_record.rb        # DB mapping, associations, scopes
│   └── event_record.rb          # Events table AR model
│
└── read_models/                 # Denormalized views for queries
    └── message_list_item.rb     # Optimized for list display
```

### Layer Rules

These rules are **non-negotiable** and must be enforced in code reviews and by LLM agents:

| Rule | Description |
|------|-------------|
| **D1** | `domain/` has **zero** `require` statements for Rails, ActiveRecord, or any gem except `dry-types` and `dry-struct`. |
| **D2** | Entities and value objects are **immutable** (`Dry::Struct`). To change state, create a new instance. |
| **D3** | Only **aggregate roots** can be loaded/saved via repositories. Child entities are accessed through the root. |
| **D4** | Domain events are **past-tense facts** (`MessageReceived`, not `ReceiveMessage`). They carry data, not behavior. |
| **A1** | Application services **orchestrate only** — no business logic. If you're writing an `if` that checks a business rule, it belongs in the domain. |
| **A2** | Application services receive **primitive arguments** (strings, IDs) from controllers and return domain objects or result types. |
| **I1** | Repositories **translate** between domain entities and AR models. The domain never sees `ActiveRecord::Base`. |
| **I2** | The event store is **append-only**. Events are never updated or deleted. |
| **I3** | AR models in `models/` have **no business methods**. Only scopes, associations, and validations for DB constraints. |
| **C1** | Controllers are **thin** — parse params, call an application service, serialize the response. No business logic. |
| **R1** | Read models in `read_models/` are **query-optimized**. They can use AR directly and don't need to go through repositories. |

### Data Flow Examples

**Receiving an email (command):**
```
POST /api/v1/messages
  → MessagesController#create
    → ReceiveMessage service
      → MessageRepository.find_or_initialize(...)
      → message_aggregate.receive(email_data)  # domain logic
      → EventStore.publish(MessageReceived)
      → MessageRepository.save(aggregate)
    ← { message: serialized_entity }
  ← 201 Created
```

**Listing messages (query):**
```
GET /api/v1/messages
  → MessagesController#index
    → ListMessages service (or direct read model query)
      → MessageListItem.where(...).order(...).limit(...)
    ← [{ id, from, subject, received_at }, ...]
  ← 200 OK
```

**Event handling (async, Phase 3):**
```
MessageReceived event published
  → EventBus dispatches to sync subscribers
    → UpdateMessageReadModel handler
  → Solid Queue picks up async projectors
    → DashboardNotificationProjector
    → SearchIndexProjector
```

---

## Custom Event Store — Implementation Plan

See [ADR-002](../adrs/002-custom-event-store.md) for the full decision record.

### Phase 1: Core (implement with this spec)

**Goal:** Working event store with publish, subscribe, replay, and correlation tracking.

#### Components

| File | Responsibility |
|------|---------------|
| `infrastructure/event_store/store.rb` | Append events to streams, read streams, read by correlation. Uses `EventRecord` AR model. |
| `infrastructure/event_store/bus.rb` | Sync publish/subscribe. Registry of handlers per event type. Dispatches after store persistence. |
| `infrastructure/event_store/aggregate_root.rb` | Module mixed into aggregates. Provides `apply(event)`, `pending_events`, and replay-from-stream. |
| `infrastructure/event_store/event_record.rb` | AR model for `events` table. Handles serialization/deserialization of event data. |
| `domain/events/base_event.rb` | Base `Dry::Struct` for all events. Defines `event_type`, `data`, `metadata` (correlation_id, causation_id, timestamp). |

#### Schema

```ruby
# db/migrate/xxx_create_events.rb
create_table :events do |t|
  t.string   :stream_name,     null: false
  t.integer  :stream_position,  null: false
  t.string   :event_type,      null: false
  t.jsonb    :data,            null: false, default: {}
  t.jsonb    :metadata,        null: false, default: {}
  t.datetime :created_at,      null: false, default: -> { "CURRENT_TIMESTAMP" }
end

add_index :events, [:stream_name, :stream_position], unique: true
add_index :events, :event_type
add_index :events, :created_at
add_index :events, "(metadata->>'correlation_id')", name: "idx_events_correlation_id", using: :btree
add_index :events, "(metadata->>'causation_id')", name: "idx_events_causation_id", using: :btree
```

#### Public API

```ruby
# Publish an event to a stream
Inboxed::EventStore::Store.publish(
  stream: "Message-#{uuid}",
  event: MessageReceived.new(data),
  metadata: { correlation_id: request_id, causation_id: nil }
)

# Subscribe to an event type (sync)
Inboxed::EventStore::Bus.subscribe(MessageReceived) do |event|
  # handle event
end

# Read all events in a stream (for replay)
events = Inboxed::EventStore::Store.read_stream("Message-#{uuid}")

# Read events by correlation ID (for tracing)
events = Inboxed::EventStore::Store.read_by_correlation(correlation_id)

# Load an aggregate from its event stream
aggregate = Inboxed::EventStore::Store.load_aggregate(
  MessageAggregate, uuid
)
```

### Phase 2: Snapshots (implement during spec 002)

**Goal:** Avoid replaying full event history for aggregates with many events.

#### Additional Schema

```ruby
create_table :snapshots do |t|
  t.string   :stream_name,     null: false
  t.integer  :stream_position,  null: false  # position at snapshot time
  t.string   :aggregate_type,  null: false
  t.integer  :schema_version,  null: false, default: 1
  t.jsonb    :state,           null: false
  t.datetime :created_at,      null: false, default: -> { "CURRENT_TIMESTAMP" }
end

add_index :snapshots, [:stream_name], unique: true
```

#### Behavior

- `Store.load_aggregate` checks for a snapshot first
- If found: deserialize state, then replay only events after `stream_position`
- If not found: replay all events from the beginning
- Snapshots are created every N events (configurable, default: 50)
- Snapshot includes `schema_version` — if version doesn't match current aggregate, discard and full-replay

### Phase 3: Async Projections (implement when dashboard needs read models)

**Goal:** Build read-optimized views from events asynchronously.

#### Additional Schema

```ruby
create_table :projector_positions do |t|
  t.string  :projector_name, null: false
  t.bigint  :last_event_id,  null: false, default: 0
  t.string  :status,         null: false, default: "running" # running | paused | error
  t.text    :error_message
  t.datetime :updated_at,    null: false
end

add_index :projector_positions, :projector_name, unique: true
```

#### Behavior

- Projectors inherit from `Inboxed::EventStore::Projector`
- Each projector declares which event types it handles
- Solid Queue job runs periodically, fetches events since `last_event_id`, dispatches to projector
- Projector updates its read model tables and advances its position
- Projectors must be **idempotent** — same event processed twice = same result
- On error: retry with exponential backoff, pause after 3 failures, log error

---

## Svelte Dashboard — Feature Architecture

See [ADR-004](../adrs/004-svelte-features.md) for the full decision record.

### Directory Layout

```
apps/dashboard/src/
├── features/
│   ├── messages/
│   │   ├── MessageList.svelte
│   │   ├── MessageDetail.svelte
│   │   ├── messages.service.ts
│   │   ├── messages.store.ts
│   │   └── messages.types.ts
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
│   ├── api-client.ts
│   ├── event-source.ts
│   └── components/
│       ├── Layout.svelte
│       ├── Sidebar.svelte
│       └── Header.svelte
├── routes/
│   ├── +layout.svelte
│   ├── +page.svelte
│   └── login/
│       └── +page.svelte
└── app.css
```

### Conventions

| Convention | Rule |
|-----------|------|
| **Components** | Dumb. Props in, events out. No API calls. |
| **Services** | All external communication. Returns typed data. |
| **Stores** | Svelte 5 runes (`$state`, `$derived`). Single source of truth per feature. |
| **Routes** | Thin. Compose features. Minimal logic. |
| **Types** | One `*.types.ts` per feature. Shared types in `lib/`. |
| **Feature isolation** | Features import from `lib/`, never from other features. |

---

## MCP Server — Tools + Ports

See [ADR-005](../adrs/005-mcp-hexagonal.md) for the full decision record.

### Directory Layout

```
apps/mcp/src/
├── tools/
│   ├── list-messages.ts
│   ├── get-message.ts
│   ├── search-messages.ts
│   ├── wait-for-email.ts
│   ├── extract-otp.ts
│   └── extract-link.ts
├── ports/
│   └── inboxed-api.ts
├── types/
│   └── index.ts
├── server.ts
└── index.ts
```

### Conventions

| Convention | Rule |
|-----------|------|
| **Tools** | One file per tool. Exports `toolDefinition` + `execute(input, api)`. |
| **Ports** | One class per external system. Only file that knows HTTP. |
| **State** | None. Each tool invocation is independent. |
| **Types** | Shared in `types/`. Tool-specific types colocated. |

---

## Technical Decisions

### Decision: Domain objects use `Inboxed::` namespace

- **Options:** Top-level classes, `App::` namespace, `Inboxed::` namespace
- **Chosen:** `Inboxed::` namespace
- **Why:** Matches the project name, avoids collisions, clear when reading stack traces. `Inboxed::Entities::Message`, `Inboxed::Events::MessageReceived`.

### Decision: Read models bypass repositories

- **Options:** (A) All queries go through repositories. (B) Read models query AR directly.
- **Chosen:** B — read models query AR directly
- **Why:** Repositories exist to protect domain invariants on writes. Reads don't mutate state — adding repository indirection for queries is ceremony without benefit. Read models can use AR scopes, joins, and SQL directly for performance.
- **Trade-offs:** Two paths to the data (write: repository → domain, read: AR direct). Acceptable because the paths serve different purposes.

### Decision: Events table in primary database (not separate store)

- **Options:** (A) Events in primary PostgreSQL. (B) Separate database. (C) Dedicated EventStoreDB.
- **Chosen:** A — same PostgreSQL database
- **Why:** Simplicity. One database to manage, backup, and deploy. Transactional consistency between events and projections. For Inboxed's scale, a separate store is unnecessary overhead.
- **Trade-offs:** Events table could grow large. Mitigated by archiving old events (future) and indexing strategy.

### Decision: Sync event dispatch by default, async projections opt-in

- **Options:** (A) All async. (B) All sync. (C) Sync by default, async projections.
- **Chosen:** C
- **Why:** Sync handlers are simpler to reason about and debug. Critical side-effects (like updating the aggregate) must be synchronous. Async is only needed for read model projections where eventual consistency is acceptable.
- **Trade-offs:** Sync handlers block the request. Mitigated by keeping handlers fast — heavy work goes to async projections.

---

## LLM Agent Guidelines

> These guidelines help AI agents (Claude, Copilot, etc.) generate code that fits the architecture.

### Where does this code go?

| I'm writing... | Put it in... |
|----------------|-------------|
| A business rule or invariant | `domain/entities/` or `domain/aggregates/` |
| An immutable data holder (no ID) | `domain/value_objects/` |
| A fact that happened in the domain | `domain/events/` |
| A use case that orchestrates steps | `application/services/` |
| Code that talks to the database | `infrastructure/repositories/` |
| Code that talks to an external API | `infrastructure/adapters/` |
| An ActiveRecord model | `models/` — persistence only, no business methods |
| A query-optimized view | `read_models/` |
| An HTTP endpoint | `controllers/` — thin, delegates to service |
| A dashboard UI component | `features/<name>/Component.svelte` |
| An API call from the dashboard | `features/<name>/<name>.service.ts` |
| Dashboard reactive state | `features/<name>/<name>.store.ts` |
| An MCP tool | `tools/<tool-name>.ts` |
| An HTTP call from MCP to API | `ports/inboxed-api.ts` |

### Code generation rules

1. **Never add business logic to controllers or AR models.** If you're tempted to add an `if` in a controller, it belongs in an application service or domain entity.
2. **Never import ActiveRecord in the domain layer.** If a domain file needs data from the DB, it should receive it as a parameter from the application service.
3. **All domain events are `Dry::Struct` subclasses.** They must be serializable to JSON.
4. **Application services follow the pattern:** load aggregate → call domain method → publish events → save.
5. **Svelte components never call APIs directly.** They use services from their feature module.
6. **MCP tools never make HTTP calls directly.** They use the port.
7. **When adding a new entity:** create the entity in `domain/`, the AR model in `models/`, and the repository in `infrastructure/repositories/`.
8. **When adding a new event:** create the event struct in `domain/events/`, add handlers in the bus configuration, update the aggregate's `apply` method.
9. **When adding a new MCP tool:** create the tool file in `tools/`, add any needed methods to the port, register in `server.ts`.
10. **When adding a new dashboard feature:** create the feature folder with `.svelte`, `.service.ts`, `.store.ts`, and `.types.ts` files.

### Testing conventions

| Layer | Test type | Location | Needs Rails? |
|-------|-----------|----------|-------------|
| Domain | Unit | `spec/domain/` | No |
| Application services | Integration | `spec/application/` | Yes (DB) |
| Repositories | Integration | `spec/infrastructure/` | Yes (DB) |
| Event Store | Integration | `spec/infrastructure/event_store/` | Yes (DB) |
| Controllers | Request | `spec/requests/` | Yes (full stack) |
| Svelte features | Component | `src/features/**/*.test.ts` | No |
| MCP tools | Unit | `src/tools/**/*.test.ts` | No (mock port) |

---

## Implementation Plan

### Step 1: Directory structure

Create the directory layout in `apps/api/app/` with placeholder `.keep` files:

```
domain/types.rb
domain/entities/.keep
domain/value_objects/.keep
domain/aggregates/.keep
domain/events/base_event.rb
application/services/.keep
infrastructure/repositories/.keep
infrastructure/event_store/store.rb
infrastructure/event_store/bus.rb
infrastructure/event_store/aggregate_root.rb
infrastructure/adapters/.keep
read_models/.keep
```

### Step 2: Install gems

Add to Gemfile:
```ruby
gem "dry-types", "~> 1.7"
gem "dry-struct", "~> 1.6"
```

### Step 3: Core domain types

Implement `app/domain/types.rb` with base types (Email, UUID, NonEmpty, etc.).

### Step 4: Event Store Phase 1

1. Create migration for `events` table
2. Implement `EventRecord` AR model
3. Implement `Store` (publish, read_stream, read_by_correlation, load_aggregate)
4. Implement `Bus` (subscribe, dispatch)
5. Implement `AggregateRoot` module
6. Implement `BaseEvent` dry-struct

### Step 5: Test infrastructure

Write tests for:
- Event Store: publish, read, replay, correlation tracking
- Bus: subscribe, dispatch, multiple handlers
- AggregateRoot: apply events, track pending events, rebuild from stream

### Step 6: Dashboard restructure

Move existing components into feature-based structure:
- `features/auth/` — login flow
- `features/messages/` — email list + preview (currently mock data)
- `features/system/` — status panel
- `lib/components/` — Layout, Sidebar, Header

### Step 7: MCP restructure

Prepare the tools + ports structure:
- Create `ports/inboxed-api.ts`
- Create `types/index.ts`
- Refactor `index.ts` into `server.ts` + `index.ts`

### Step 8: Update documentation

- Update AGENTS.md with architecture conventions
- Update docs/INDEX.md with ADR references

---

## Exit Criteria

### Rails API
- [ ] Directory structure exists with all layers (`domain/`, `application/`, `infrastructure/`, `read_models/`)
- [ ] `dry-types` and `dry-struct` installed and `Inboxed::Types` module works
- [ ] `events` table migration exists and runs
- [ ] Event Store Phase 1 working: publish, read_stream, read_by_correlation
- [ ] Event Bus working: subscribe, dispatch to multiple handlers
- [ ] AggregateRoot module working: apply events, pending events, rebuild from stream
- [ ] All event store tests pass (`spec/infrastructure/event_store/`)
- [ ] Domain types test pass without booting Rails (`spec/domain/`)
- [ ] Existing 5 foundation tests still pass

### Svelte Dashboard
- [ ] Feature-based directory structure in place
- [ ] Existing components moved to features (auth, messages, system)
- [ ] API client in `lib/api-client.ts`
- [ ] Dashboard builds and works as before

### MCP Server
- [ ] Tools + ports directory structure in place
- [ ] `ports/inboxed-api.ts` stub exists
- [ ] `server.ts` separated from `index.ts`
- [ ] MCP server compiles and starts as before

### Documentation
- [ ] All 5 ADRs written and indexed
- [ ] AGENTS.md updated with architecture layer rules
- [ ] Spec 001 approved

---

## Open Questions

1. **Autoloading domain layer** — Rails autoloader (Zeitwerk) expects `app/` subdirectories to follow naming conventions. `app/domain/entities/message.rb` should define `Domain::Entities::Message` by Zeitwerk rules, but we want `Inboxed::Entities::Message`. Options: (A) Follow Zeitwerk naming. (B) Configure custom inflections. (C) Move domain outside `app/` to `lib/domain/` and manually require. Recommendation: explore Zeitwerk namespacing first, fall back to `lib/` if needed.

2. **Event serialization format** — Should events store their full `Dry::Struct` as JSON, or should we define explicit `#to_data` / `.from_data` methods? Recommendation: use `Dry::Struct#to_h` for serialization and `.new(hash)` for deserialization. Simpler, and dry-struct handles coercion.

3. **Aggregate identity** — Should aggregates use UUIDs or sequential IDs? UUIDs are better for distributed systems and event streams, sequential IDs are simpler. Recommendation: UUIDs — they can be generated client-side and used as stream names (`Message-{uuid}`).
