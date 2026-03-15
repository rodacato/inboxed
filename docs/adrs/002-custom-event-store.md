# ADR-002: Custom Event Store over Rails Event Store

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The DDD architecture (ADR-001) uses domain events to decouple side effects from business logic. We need an event store to persist, publish, and replay events.

**Rails Event Store (RES)** is the mature, battle-tested option for Ruby. It provides persistence, subscriptions, projections, streams, versioning, correlation IDs, and more.

However, the project owner wants to **learn the internals of event sourcing infrastructure** — understanding ordering, serialization, idempotency, replay, projections, and snapshots at a mechanical level. This knowledge transfers to any event-driven system (Kafka, EventStoreDB, etc.) and informs better architectural decisions regardless of tooling.

## Decision

Build a **custom event store** inspired by Rails Event Store's capabilities, implemented incrementally in three phases:

### Phase 1 — Core (before spec 002)

| Component | Description |
|-----------|-------------|
| **Message Bus** | Sync publish/subscribe. Handlers registered per event type. In-memory dispatch with persistence to Postgres. |
| **Event Store** | Append-only `events` table. Each event belongs to a stream (e.g., `Message-{uuid}`). Global ordering via auto-increment + stream ordering via position. |
| **Event Replay** | Rebuild aggregate state by replaying events from a stream. `AggregateRoot#apply(event)` pattern. |
| **Correlation/Causation IDs** | Every event carries `correlation_id` (ties to original trigger) and `causation_id` (ties to immediate parent event). Two columns, passed through context. |

#### Schema: `events` table

```ruby
create_table :events do |t|
  t.string   :stream_name,    null: false           # e.g., "Message-abc123"
  t.integer  :stream_position, null: false           # position within stream
  t.string   :event_type,     null: false            # e.g., "Inboxed::Events::MessageReceived"
  t.jsonb    :data,           null: false, default: {} # event payload
  t.jsonb    :metadata,       null: false, default: {} # correlation_id, causation_id, timestamp
  t.datetime :created_at,     null: false, default: -> { "CURRENT_TIMESTAMP" }

  t.index [:stream_name, :stream_position], unique: true
  t.index :event_type
  t.index :created_at
  t.index "((metadata->>'correlation_id'))", name: "index_events_on_correlation_id"
end
```

### Phase 2 — Snapshots (during spec 002)

| Component | Description |
|-----------|-------------|
| **Snapshots** | Serialize aggregate state every N events. On load: restore from snapshot + replay remaining events. |
| **Snapshot Store** | `snapshots` table keyed by stream name. Stores serialized state + version (stream position at snapshot time). |
| **Versioning** | Snapshot includes a `schema_version` so we can detect and handle stale snapshots when entities evolve. |

### Phase 3 — Async Projections (when dashboard needs read models)

| Component | Description |
|-----------|-------------|
| **Projectors** | Classes that subscribe to event types and build read-optimized tables/views. |
| **Position Tracking** | `projector_positions` table tracks last processed event ID per projector. |
| **Async Processing** | Projectors run as Solid Queue jobs. Each job processes a batch of events from its last position. |
| **Idempotency** | Projectors must be idempotent — reprocessing the same event produces the same result. Position tracking prevents duplicates under normal operation; idempotency handles edge cases. |
| **Error Handling** | Failed projectors are retried with exponential backoff. Persistent failures pause the projector and alert (log). |

### Public API (Phase 1)

```ruby
# Publishing
Inboxed::EventStore.publish(event, stream: "Message-#{id}")

# Subscribing (sync)
Inboxed::EventBus.subscribe(MessageReceived) do |event|
  # handle
end

# Reading a stream
Inboxed::EventStore.read_stream("Message-#{id}")  # → [Event, Event, ...]

# Replaying to rebuild aggregate
aggregate = Inboxed::EventStore.load_aggregate(Message, id)

# Reading with correlation
Inboxed::EventStore.read_by_correlation(correlation_id)
```

## Consequences

### Easier

- **Deep understanding** of event sourcing mechanics — transferable knowledge
- **Full control** over schema, serialization, and behavior
- **No external dependency** — one less gem to maintain/upgrade
- **Tailored to Inboxed** — only build what we need, when we need it

### Harder

- **3-5x more implementation time** vs using Rails Event Store
- **Bugs that RES already solved** — ordering edge cases, concurrency, serialization
- **Not production-grade** initially — acceptable since the goal is learning
- **Maintenance burden** — we own every bug

### Mitigations

- Phased implementation prevents scope creep — each phase delivers value
- Phase 1 is intentionally minimal (~200-300 lines of Ruby)
- If the custom store becomes a liability, the domain layer (ADR-001) is decoupled enough to swap in RES later
- Comprehensive tests for each phase before moving on
