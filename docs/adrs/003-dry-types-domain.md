# ADR-003: dry-types + dry-struct for Domain Layer

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

ADR-001 establishes that domain entities are POROs separated from ActiveRecord. We need a way to define typed, immutable domain objects without reinventing attribute declaration, type coercion, and validation.

Options considered:

1. **Plain Ruby classes** — `attr_reader` + manual `initialize`. Maximum simplicity, no dependencies. But: no type checking, no immutability guarantees, verbose boilerplate.
2. **Data class (Ruby 3.2+)** — Built-in immutable value objects. Clean syntax. But: no type coercion, no nested types, no optional/default values, limited for complex domains.
3. **dry-types + dry-struct** — Mature library for typed, immutable structs. Type coercion, optional attributes, nested types, custom types, composition. Used widely in the Ruby DDD community.
4. **Virtus / ActiveModel::Attributes** — Heavier, tied to ActiveModel. Fights the "no Rails in domain" rule.

## Decision

Use **dry-types** and **dry-struct** for all domain layer objects (entities, value objects, events):

### Type Module

```ruby
# app/domain/types.rb
module Inboxed
  module Types
    include Dry.Types()

    # Custom domain types
    Email    = String.constrained(format: /\A[^@\s]+@[^@\s]+\z/)
    UUID     = String.constrained(format: /\A[0-9a-f-]{36}\z/)
    NonEmpty = String.constrained(min_size: 1)
  end
end
```

### Value Objects

```ruby
# app/domain/value_objects/email_address.rb
module Inboxed
  module ValueObjects
    class EmailAddress < Dry::Struct
      attribute :address, Types::Email
      attribute :display_name, Types::String.optional.default(nil)

      def to_s
        display_name ? "#{display_name} <#{address}>" : address
      end

      def domain
        address.split("@").last
      end
    end
  end
end
```

### Entities

```ruby
# app/domain/entities/message.rb
module Inboxed
  module Entities
    class Message < Dry::Struct
      attribute :id, Types::UUID
      attribute :from, ValueObjects::EmailAddress
      attribute :to, Types::Array.of(ValueObjects::EmailAddress)
      attribute :subject, Types::String
      attribute :received_at, Types::DateTime

      # Rich behavior
      def addressed_to?(address)
        to.any? { |recipient| recipient.address == address }
      end
    end
  end
end
```

### Events

```ruby
# app/domain/events/message_received.rb
module Inboxed
  module Events
    class MessageReceived < Dry::Struct
      attribute :message_id, Types::UUID
      attribute :from, Types::String
      attribute :to, Types::Array.of(Types::String)
      attribute :subject, Types::String
      attribute :received_at, Types::DateTime
    end
  end
end
```

### Conventions

- All domain objects inherit from `Dry::Struct` (immutable by default)
- Use `new()` to create — dry-struct provides the constructor
- To "modify" an immutable entity, use `new(**attributes, field: new_value)` pattern
- Custom types go in `app/domain/types.rb`
- Value objects have no identity — compared by value
- Entities have identity (`id` attribute) — compared by ID

## Consequences

### Easier

- **Type safety at the domain boundary** — catch bad data early, before it hits the DB
- **Immutability by default** — no accidental state mutation, safe to pass around
- **Self-documenting** — reading a struct definition tells you exactly what the entity contains and accepts
- **Testable** — `Dry::Struct.new(attrs)` in tests, no factories needed for simple cases
- **Composable types** — build complex types from simple ones (`Types::Array.of(EmailAddress)`)

### Harder

- **Another dependency** — dry-types and dry-struct gems to maintain
- **Learning curve** — dry-rb has its own idioms (type constructors, `optional`, `default`)
- **Immutability friction** — updating a deeply nested struct requires rebuilding parent objects
- **Serialization** — need explicit mapping to/from JSON and AR models

### Mitigations

- dry-types/dry-struct are stable, well-maintained gems with minimal dependencies
- The project owner already has experience with dry-monads — the dry-rb ecosystem is familiar
- Repository layer handles all AR ↔ domain mapping (ADR-001)
