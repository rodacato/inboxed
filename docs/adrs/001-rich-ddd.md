# ADR-001: Rich DDD over Anemic Models

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The Rails Way encourages "fat models, thin controllers" but in practice this leads to ActiveRecord models that mix persistence, validation, business logic, callbacks, and query scopes into a single class. As models grow, they become hard to test, reason about, and refactor.

The project owner has experience with functional DDD and anemic entities (service objects + dry-monads). While effective, this approach scatters domain logic across many service objects, making it hard to understand what an entity *can do* by looking at it.

Inboxed's domain is well-bounded (emails, messages, conversations, API keys) and small enough to experiment with a richer modeling approach without excessive overhead.

## Decision

Adopt a **purista DDD approach** where domain logic lives in rich entities and aggregates, fully separated from ActiveRecord persistence:

### Layer Separation

```
app/
├── domain/           # Pure Ruby — no Rails, no ActiveRecord
│   ├── entities/     # Rich domain objects with behavior
│   ├── value_objects/ # Immutable, identity-less types
│   ├── aggregates/   # Consistency boundaries
│   └── events/       # Domain event definitions
├── application/      # Use cases / application services
│   └── services/     # Orchestration only — no business logic
├── infrastructure/   # Adapters to external systems
│   ├── repositories/ # Wrap ActiveRecord for persistence
│   ├── event_store/  # Custom event store implementation
│   └── adapters/     # External service clients
└── models/           # ActiveRecord models — persistence ONLY
```

### Rules

1. **Domain layer has zero dependencies on Rails or ActiveRecord.** Entities are POROs (via `dry-struct`). They can be tested without booting Rails.
2. **Behavior lives on entities and aggregates**, not in service objects. An entity knows its own invariants and can enforce them. Example: `message.mark_as_read!` not `MarkMessageAsReadService.call(message)`.
3. **Aggregates are consistency boundaries.** Only the aggregate root can be persisted/loaded via a repository. Child entities are always accessed through the root.
4. **Application services orchestrate** — they load aggregates from repositories, call domain methods, publish events, and persist. They contain no business logic.
5. **Repositories translate** between domain entities and ActiveRecord models. The domain never sees `ActiveRecord::Base`.
6. **ActiveRecord models are persistence-only** — validations, scopes, and associations for DB operations. No business methods.

### Example Flow

```
Controller → ApplicationService → Repository.find(id)
                                    → AR Model → Domain Entity
                                  → entity.do_something()
                                  → EventStore.publish(event)
                                  → Repository.save(entity)
                                    → Domain Entity → AR Model
```

## Consequences

### Easier

- **Testing domain logic** — no database, no Rails boot, fast unit tests
- **Understanding behavior** — look at the entity to see what it can do
- **Swapping persistence** — repositories abstract ActiveRecord completely
- **Reasoning about invariants** — aggregates enforce consistency
- **Onboarding (for LLMs and humans)** — clear layer separation, each file has one job

### Harder

- **More files and indirection** — a simple CRUD operation touches 4+ layers
- **Mapping overhead** — converting between AR models and domain entities
- **Rails ecosystem friction** — gems expect ActiveRecord models with behavior; some won't work out of the box
- **Learning curve** — contributors familiar with Rails Way need to understand the layer rules
- **Risk of over-engineering** — must resist creating abstractions for things that don't need them yet

### Mitigations

- Start with one aggregate (Message) and prove the pattern before expanding
- Keep AR models as thin mappers — don't fight Rails, just isolate the domain from it
- Document layer rules in AGENTS.md so AI agents follow the architecture
