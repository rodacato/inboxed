# ADR-023: Endpoint Type Polymorphism — Single Table for Webhooks, Forms, and Heartbeats

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** API Design Architect, Full-Stack Engineer, Database Engineer

## Context

Phase 8 introduces three flavors of HTTP catching: **webhooks**, **forms**, and **heartbeats**. All three share the same fundamental behavior — receive an HTTP request at a unique URL, store it, make it inspectable. They differ in:

| | Webhooks | Forms | Heartbeats |
|---|---|---|---|
| **Typical method** | POST/PUT/PATCH | POST | POST/GET |
| **Typical content type** | application/json | application/x-www-form-urlencoded, multipart/form-data | Any (body often empty) |
| **Response behavior** | `200 {"ok": true}` | Redirect or thank-you HTML page | `200 {"ok": true}` |
| **Dashboard UI** | JSON pretty-print, headers | Field table (key → value), file uploads | Status badge, timeline, last ping |
| **Extra state** | None | `response_redirect_url` | `expected_interval`, `status`, `last_ping_at` |
| **Alerting** | None | None | Webhook notification on status transition to `down` |

### Options Considered

**A: Separate tables per type (`webhook_endpoints`, `form_endpoints`, `heartbeat_endpoints`)**
- Pro: Each table has only the columns it needs — clean schema
- Pro: No nullable columns for type-specific fields
- Con: Three sets of migrations, models, repositories, controllers, serializers
- Con: The public catch endpoint (`/hook/:token`) needs to look up three tables to find a token
- Con: Shared behavior (token generation, TTL, rate limiting) must be duplicated or extracted to a concern

**B: Single `http_endpoints` table with `endpoint_type` column (STI-style, but at domain level)**
- Pro: One table, one repository, one token lookup — simple public endpoint routing
- Pro: Shared behavior (token, TTL, cleanup, rate limiting) lives in one place
- Pro: Adding a new type is one enum value, not a new table
- Pro: Dashboard sidebar counts come from one query
- Con: Some columns are nullable (heartbeat-only: `expected_interval`, `status`, `last_ping_at`; form-only: `response_redirect_url`)
- Con: Domain entity needs type-specific behavior branching

**C: Single table with JSONB `config` column for type-specific fields**
- Pro: Same as B, but no nullable columns — type-specific fields live in JSONB
- Pro: Adding a field to one type doesn't require a migration
- Con: JSONB fields can't have DB-level constraints (NOT NULL, CHECK)
- Con: Indexing JSONB for queries (e.g., heartbeat status) is less efficient
- Con: Schema is implicit — harder to reason about

## Decision

**Option B** — single `http_endpoints` table with `endpoint_type` enum column and explicit nullable columns for type-specific fields.

### Why Not JSONB (Option C)?

The heartbeat `status` field needs to be indexed and queried efficiently (e.g., "find all endpoints where status = 'down'"). The `expected_interval` needs a CHECK constraint to ensure it's positive. These are better served by real columns than JSONB.

The number of type-specific columns is small (4 total across all types). The cost of a few nullable columns is far less than the complexity of JSONB schema management.

### Schema

```sql
CREATE TABLE http_endpoints (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  endpoint_type   VARCHAR NOT NULL DEFAULT 'webhook',  -- 'webhook', 'form', 'heartbeat'
  token           VARCHAR NOT NULL,                     -- SecureRandom.urlsafe_base64(32)
  label           VARCHAR,
  description     TEXT,

  -- Request capture config (all types)
  allowed_methods VARCHAR[] DEFAULT '{POST}',           -- restrict which methods are accepted
  max_body_bytes  INTEGER DEFAULT 262144,               -- 256KB default

  -- Form-specific
  response_mode   VARCHAR,                              -- NULL for non-form; 'json' | 'redirect' | 'html'
  response_redirect_url VARCHAR,                        -- redirect target for form submissions
  response_html   TEXT,                                 -- custom thank-you page HTML

  -- Heartbeat-specific
  expected_interval_seconds INTEGER,                    -- NULL for non-heartbeat
  heartbeat_status VARCHAR DEFAULT 'pending',           -- 'pending' | 'healthy' | 'late' | 'down'
  last_ping_at    TIMESTAMPTZ,
  status_changed_at TIMESTAMPTZ,

  -- Counters and metadata
  request_count   INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT http_endpoints_token_unique UNIQUE (token),
  CONSTRAINT http_endpoints_type_check CHECK (endpoint_type IN ('webhook', 'form', 'heartbeat')),
  CONSTRAINT http_endpoints_heartbeat_interval CHECK (
    endpoint_type != 'heartbeat' OR expected_interval_seconds > 0
  ),
  CONSTRAINT http_endpoints_response_mode_check CHECK (
    response_mode IS NULL OR response_mode IN ('json', 'redirect', 'html')
  )
);

CREATE INDEX idx_http_endpoints_project ON http_endpoints(project_id);
CREATE INDEX idx_http_endpoints_token ON http_endpoints(token);
CREATE INDEX idx_http_endpoints_heartbeat_status ON http_endpoints(heartbeat_status)
  WHERE endpoint_type = 'heartbeat';
```

### Domain Modeling

At the domain level, `HttpEndpoint` is a single entity with type-specific value objects:

```ruby
# app/domain/entities/http_endpoint.rb
module Inboxed
  module Domain
    module Entities
      class HttpEndpoint < Dry::Struct
        attribute :id, Types::UUID
        attribute :project_id, Types::UUID
        attribute :endpoint_type, Types::EndpointType  # enum: webhook, form, heartbeat
        attribute :token, Types::String
        attribute :label, Types::String.optional
        attribute :description, Types::String.optional
        attribute :allowed_methods, Types::Array.of(Types::HttpMethod)
        attribute :max_body_bytes, Types::Integer
        attribute :request_count, Types::Integer
        attribute :created_at, Types::Time

        # Type-specific (via value objects)
        attribute :form_config, ValueObjects::FormConfig.optional
        attribute :heartbeat_config, ValueObjects::HeartbeatConfig.optional
      end
    end
  end
end
```

This keeps the entity flat while encapsulating type-specific concerns in value objects. The repository handles mapping nullable DB columns to/from these optional value objects.

## Consequences

### Easier

- **Single token lookup** — `/hook/:token` hits one table, one index, one query
- **Unified management API** — one set of endpoints for CRUD, filtered by `endpoint_type`
- **Shared infrastructure** — TTL cleanup, rate limiting, ActionCable channels work identically for all types
- **Dashboard sidebar** — one query for counts per type: `SELECT endpoint_type, COUNT(*) FROM http_endpoints GROUP BY endpoint_type`

### Harder

- **Nullable columns** — 4 columns that only apply to specific types. Mitigated by CHECK constraints and domain-level validation
- **Domain branching** — some behavior differs by type (heartbeat status transitions, form response mode). Kept in value objects, not `if/else` chains

### Mitigations

- CHECK constraints enforce type-specific invariants at DB level
- Domain value objects (`FormConfig`, `HeartbeatConfig`) encapsulate type-specific logic
- Repository maps nullable columns to optional value objects — the domain never sees raw nulls
