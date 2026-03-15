# 008 — Webhooks

> HTTP push notifications when emails are received, with retry logic and HMAC signing.

**Phase:** Phase 7 — Post-MVP
**Status:** accepted
**Release:** —
**Depends on:** [002 — SMTP & Persistence](002-smtp-persistence.md) (domain events), [003 — REST API](003-rest-api.md) (API patterns)
**ADRs:** [ADR-002 Custom Event Store](../adrs/002-custom-event-store.md), [ADR-020 Webhook Delivery Strategy](../adrs/020-webhook-delivery-strategy.md)

---

## 1. Objective

Enable external systems (CI/CD pipelines, n8n, Zapier, custom scripts) to react to Inboxed events via HTTP push notifications. Instead of polling the API or using the long-poll `wait` endpoint, consumers register a URL and receive a POST request when an email arrives.

**Use cases:**
- CI pipeline step that continues when a verification email arrives
- n8n/Zapier workflow triggered by incoming test emails
- Custom monitoring that alerts when specific emails are received
- Slack notification when a test email arrives in a shared inbox

## 2. Current State

- The event store (ADR-002) is fully operational with domain events: `EmailReceived`, `EmailDeleted`, `InboxCreated`, `InboxPurged`
- The event bus (`EventStore::Bus`) already dispatches events to subscribers (ActionCable broadcasts in `event_subscriptions.rb`)
- Solid Queue is configured for async job processing
- API authentication (Bearer token) and rate limiting (Rack::Attack) are in place
- No webhook infrastructure exists yet

## 3. What This Spec Delivers

### 3.1 Webhook Endpoint Management API

CRUD endpoints for registering, updating, and deleting webhook endpoints, scoped to projects.

### 3.2 Webhook Delivery Pipeline

Event bus subscriber → delivery job → HTTP POST with retries and exponential backoff.

### 3.3 Delivery Log

Persistent log of every delivery attempt with status, HTTP response, and timing — accessible via API.

### 3.4 HMAC Payload Signing

Every webhook request is signed with HMAC-SHA256 for authenticity verification.

---

## 4. Data Model

### 4.1 `webhook_endpoints`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `project_id` | UUID | FK to projects |
| `url` | String | Target HTTPS URL |
| `event_types` | String[] | Events to subscribe to (e.g., `["email_received"]`) |
| `status` | String | `active`, `failing`, `disabled` |
| `secret` | String | HMAC-SHA256 signing key (32 bytes, hex-encoded) |
| `description` | String | Optional label (e.g., "CI pipeline", "Slack alert") |
| `failure_count` | Integer | Consecutive failures (resets on success) |
| `created_at` | DateTime | — |
| `updated_at` | DateTime | — |

**Indexes:** `(project_id, status)`, `project_id`

**Status transitions:**
```
active → failing    (3 consecutive failures)
failing → active   (successful delivery)
failing → disabled (10 consecutive failures)
disabled → active  (manual re-enable via API)
```

### 4.2 `webhook_deliveries`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `webhook_endpoint_id` | UUID | FK to webhook_endpoints |
| `event_type` | String | e.g., `email_received` |
| `event_id` | String | Unique event identifier (for idempotency) |
| `payload` | JSONB | Full webhook payload |
| `status` | String | `pending`, `delivered`, `failed` |
| `http_status` | Integer | Response status code (nullable) |
| `response_body` | Text | First 1KB of response (nullable) |
| `attempt_count` | Integer | Number of attempts made |
| `last_attempted_at` | DateTime | Last attempt timestamp (nullable) |
| `next_retry_at` | DateTime | When to retry next (nullable) |
| `created_at` | DateTime | — |

**Indexes:** `(webhook_endpoint_id, status)`, `(webhook_endpoint_id, created_at)`, `(status, next_retry_at)` for retry queue

**Retention:** Delivery records are auto-deleted after 7 days (same TTL as emails).

### 4.3 Domain Layer

```ruby
# app/domain/entities/webhook_endpoint.rb
class Inboxed::Entities::WebhookEndpoint < Dry::Struct
  attribute :id, Types::UUID
  attribute :project_id, Types::UUID
  attribute :url, Types::String
  attribute :event_types, Types::Array.of(Types::String)
  attribute :status, Types::String.enum("active", "failing", "disabled")
  attribute :secret, Types::String
  attribute :description, Types::String.optional
  attribute :failure_count, Types::Integer
end
```

---

## 5. Supported Events

| Event | Trigger | Payload includes |
|-------|---------|-----------------|
| `email_received` | New email stored | `email_id`, `inbox_id`, `inbox_address`, `from`, `to`, `subject`, `received_at` |
| `email_deleted` | Email deleted | `email_id`, `inbox_id` |
| `inbox_created` | New inbox created (first email to an address) | `inbox_id`, `inbox_address`, `project_id` |
| `inbox_purged` | All emails in an inbox deleted | `inbox_id`, `deleted_count` |

**`email_received` is the primary use case.** Other events are available but optional — endpoints subscribe to specific event types.

---

## 6. Webhook Payload Format

### 6.1 Request

```http
POST https://example.com/webhook HTTP/1.1
Content-Type: application/json
X-Inboxed-Event: email_received
X-Inboxed-Delivery: d4f5a6b7-...
X-Inboxed-Timestamp: 1742068800
X-Inboxed-Signature: sha256=a1b2c3d4...
User-Agent: Inboxed-Webhook/1.0
```

### 6.2 Body (`email_received`)

```json
{
  "event": "email_received",
  "event_id": "evt_a1b2c3d4",
  "timestamp": "2026-03-15T20:00:00Z",
  "data": {
    "email_id": "e5f6a7b8-...",
    "inbox_id": "i1j2k3l4-...",
    "inbox_address": "test@mail.inboxed.dev",
    "from": "app@example.com",
    "to": ["test@mail.inboxed.dev"],
    "subject": "Verify your account",
    "preview": "Your verification code is 847291...",
    "received_at": "2026-03-15T20:00:00Z"
  }
}
```

### 6.3 Body (`email_deleted`)

```json
{
  "event": "email_deleted",
  "event_id": "evt_x9y8z7w6",
  "timestamp": "2026-03-15T20:01:00Z",
  "data": {
    "email_id": "e5f6a7b8-...",
    "inbox_id": "i1j2k3l4-..."
  }
}
```

### 6.4 Signature Verification

Consumers verify authenticity by computing the HMAC-SHA256 signature:

```ruby
# Ruby
timestamp = request.headers["X-Inboxed-Timestamp"]
signature = request.headers["X-Inboxed-Signature"]
payload = "#{timestamp}.#{request.body.read}"
expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
valid = ActiveSupport::SecurityUtils.secure_compare(signature, expected)
```

```typescript
// TypeScript
const timestamp = req.headers["x-inboxed-timestamp"];
const signature = req.headers["x-inboxed-signature"];
const payload = `${timestamp}.${req.body}`;
const expected = "sha256=" + crypto.createHmac("sha256", secret).update(payload).digest("hex");
const valid = crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
```

Including the timestamp in the signed payload prevents replay attacks. Consumers should reject requests where the timestamp is more than 5 minutes old.

---

## 7. API Endpoints

All endpoints are project-scoped (auth: Bearer token) under `/api/v1/`.

### 7.1 `POST /api/v1/webhooks`

Create a new webhook endpoint.

```json
// Request
{
  "url": "https://example.com/webhook",
  "event_types": ["email_received"],
  "description": "CI pipeline notification"
}

// Response 201
{
  "data": {
    "id": "w1x2y3z4-...",
    "url": "https://example.com/webhook",
    "event_types": ["email_received"],
    "status": "active",
    "secret": "whsec_a1b2c3d4e5f6...",
    "description": "CI pipeline notification",
    "created_at": "2026-03-15T20:00:00Z"
  }
}
```

**Notes:**
- `secret` is auto-generated (32 bytes, hex) and returned **only on creation**. Store it immediately.
- `url` must be HTTPS (reject HTTP unless the host is `localhost` or `127.0.0.1` for local development).
- `event_types` must contain at least one valid event type.

### 7.2 `GET /api/v1/webhooks`

List all webhook endpoints for the project.

```json
// Response 200
{
  "data": [
    {
      "id": "w1x2y3z4-...",
      "url": "https://example.com/webhook",
      "event_types": ["email_received"],
      "status": "active",
      "description": "CI pipeline notification",
      "failure_count": 0,
      "created_at": "2026-03-15T20:00:00Z"
    }
  ],
  "meta": { "total_count": 1, "next_cursor": null }
}
```

**Note:** `secret` is never returned in list responses.

### 7.3 `GET /api/v1/webhooks/:id`

Get webhook endpoint details including recent delivery stats.

```json
// Response 200
{
  "data": {
    "id": "w1x2y3z4-...",
    "url": "https://example.com/webhook",
    "event_types": ["email_received"],
    "status": "active",
    "description": "CI pipeline notification",
    "failure_count": 0,
    "created_at": "2026-03-15T20:00:00Z",
    "stats": {
      "total_deliveries": 42,
      "successful": 40,
      "failed": 2,
      "pending": 0
    }
  }
}
```

### 7.4 `PATCH /api/v1/webhooks/:id`

Update webhook endpoint (url, event_types, description, status).

```json
// Request — re-enable a disabled endpoint
{
  "status": "active"
}

// Response 200
{ "data": { ... } }
```

### 7.5 `DELETE /api/v1/webhooks/:id`

Delete webhook endpoint and all its delivery records.

### 7.6 `POST /api/v1/webhooks/:id/test`

Send a test delivery with a synthetic `email_received` event to verify the endpoint is reachable.

```json
// Response 200 (endpoint responded with 2xx)
{
  "data": {
    "success": true,
    "http_status": 200,
    "duration_ms": 145
  }
}

// Response 200 (endpoint failed)
{
  "data": {
    "success": false,
    "http_status": 500,
    "error": "Internal Server Error"
  }
}
```

### 7.7 `GET /api/v1/webhooks/:id/deliveries`

List delivery attempts for a webhook endpoint (paginated, newest first).

```json
// Response 200
{
  "data": [
    {
      "id": "d1e2f3g4-...",
      "event_type": "email_received",
      "event_id": "evt_a1b2c3d4",
      "status": "delivered",
      "http_status": 200,
      "attempt_count": 1,
      "created_at": "2026-03-15T20:00:01Z",
      "last_attempted_at": "2026-03-15T20:00:01Z"
    }
  ],
  "meta": { "total_count": 42, "next_cursor": "..." }
}
```

---

## 8. Delivery Pipeline

### 8.1 Architecture

```
EmailReceived event published
  → EventStore::Bus dispatches to WebhookDispatcher
    → Find active webhook endpoints for this project + event type
    → For each endpoint:
      → Create WebhookDelivery record (status: pending)
      → Enqueue WebhookDeliveryJob (Solid Queue)

WebhookDeliveryJob executes:
  → Build payload JSON
  → Compute HMAC-SHA256 signature
  → POST to endpoint URL (10s timeout)
  → On 2xx: mark delivered, reset endpoint failure_count
  → On non-2xx or timeout: increment attempt_count
    → If attempts < 6: schedule retry with backoff
    → If attempts == 6: mark failed, increment endpoint failure_count
    → If endpoint failure_count >= 3: set status to "failing"
    → If endpoint failure_count >= 10: set status to "disabled"
```

### 8.2 Event Subscription

```ruby
# config/initializers/event_subscriptions.rb (addition)
Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailReceived) do |event|
  Inboxed::Services::DispatchWebhooks.call(event:)
end

Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailDeleted) do |event|
  Inboxed::Services::DispatchWebhooks.call(event:)
end

# ... same for InboxCreated, InboxPurged
```

### 8.3 Dispatch Service

```ruby
# lib/inboxed/services/dispatch_webhooks.rb
module Inboxed::Services
  class DispatchWebhooks
    def self.call(event:)
      project_id = resolve_project_id(event)
      event_type = event.class.name.demodulize.underscore  # "email_received"

      endpoints = WebhookEndpointRepository.active_for(
        project_id:,
        event_type:
      )

      endpoints.each do |endpoint|
        delivery = WebhookDeliveryRepository.create(
          webhook_endpoint_id: endpoint.id,
          event_type:,
          event_id: event.metadata[:event_id],
          payload: build_payload(event),
          status: "pending"
        )

        WebhookDeliveryJob.perform_later(delivery.id)
      end
    end
  end
end
```

### 8.4 Delivery Job

```ruby
# app/jobs/webhook_delivery_job.rb
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :polynomially_longer, attempts: 6

  TIMEOUT = 10.seconds
  RETRY_DELAYS = [1.minute, 5.minutes, 30.minutes, 2.hours, 12.hours].freeze

  def perform(delivery_id)
    delivery = WebhookDeliveryRepository.find(delivery_id)
    endpoint = WebhookEndpointRepository.find(delivery.webhook_endpoint_id)

    return if endpoint.status == "disabled"

    timestamp = Time.current.to_i
    body = delivery.payload.to_json
    signature = compute_signature(endpoint.secret, timestamp, body)

    response = make_request(endpoint.url, body, timestamp, signature)

    if response.success?
      mark_delivered(delivery, response)
      reset_endpoint_failures(endpoint)
    else
      mark_attempt_failed(delivery, response)
      increment_endpoint_failures(endpoint)
      schedule_retry(delivery) if delivery.attempt_count < 6
    end
  end
end
```

---

## 9. Technical Decisions

### 9.1 Decision: Exponential Backoff Retries via Solid Queue

See [ADR-020](../adrs/020-webhook-delivery-strategy.md). At-least-once delivery with 6 attempts over ~14.5 hours. No external dependencies.

### 9.2 Decision: HMAC-SHA256 Signing

- **Options considered:** (A) No signing, (B) HMAC-SHA256, (C) Ed25519 asymmetric
- **Chosen:** B — HMAC-SHA256
- **Why:** Industry standard (GitHub, Stripe, Shopify all use HMAC-SHA256). Simple to verify in any language. Symmetric key is fine when the endpoint owner is also the project owner.
- **Trade-offs:** Shared secret must be stored securely. Acceptable for a dev tool.

### 9.3 Decision: HTTPS Required (except localhost)

- **Options considered:** (A) Allow HTTP anywhere, (B) HTTPS only, (C) HTTPS with localhost exception
- **Chosen:** C — HTTPS required, HTTP allowed only for `localhost`/`127.0.0.1`
- **Why:** Webhook payloads may contain email content (subjects, previews). Sending over HTTP in production leaks data. Localhost exception enables local development.

### 9.4 Decision: Separate Solid Queue for Webhooks

- **Options considered:** (A) Use default queue, (B) Dedicated `:webhooks` queue
- **Chosen:** B — dedicated queue
- **Why:** Webhook retries (up to 6 per delivery) could flood the default queue and delay email processing jobs. A separate queue isolates webhook work.

### 9.5 Decision: Admin Webhook Management via Dashboard

- Webhook endpoints will also be manageable via the admin dashboard (Phase 3 extension)
- The API endpoints (section 7) are the primary interface; the dashboard adds a UI layer
- Dashboard webhook management is a future enhancement, not part of this spec

---

## 10. Implementation Plan

### Step 1: Database Migrations

Create `webhook_endpoints` and `webhook_deliveries` tables with all columns and indexes from section 4.

### Step 2: Domain Layer

Create:
- `Inboxed::Entities::WebhookEndpoint` (Dry::Struct)
- `Inboxed::Entities::WebhookDelivery` (Dry::Struct)
- ActiveRecord models: `WebhookEndpoint`, `WebhookDelivery` (persistence only)

### Step 3: Repositories

Create:
- `WebhookEndpointRepository` — CRUD, `active_for(project_id:, event_type:)`
- `WebhookDeliveryRepository` — create, update status, find pending retries

### Step 4: Webhook Signing

Create `Inboxed::Webhooks::Signer`:
- `sign(secret, timestamp, body)` → `"sha256=<hex>"`
- `verify(secret, timestamp, body, signature)` → boolean

### Step 5: Dispatch Service

Create `Inboxed::Services::DispatchWebhooks`:
- Find active endpoints for project + event type
- Create delivery records
- Enqueue delivery jobs

### Step 6: Delivery Job

Create `WebhookDeliveryJob`:
- Build request with headers and signed body
- HTTP POST with 10s timeout (use `Net::HTTP`)
- Handle success/failure, update delivery and endpoint status
- Schedule retry on failure

### Step 7: Event Bus Subscription

Add webhook dispatch subscribers to `event_subscriptions.rb` for all supported events.

### Step 8: API Controllers

Create `Api::V1::WebhooksController`:
- CRUD for webhook endpoints (sections 7.1-7.5)
- Test endpoint (section 7.6)

Create `Api::V1::Webhooks::DeliveriesController`:
- List deliveries for an endpoint (section 7.7)

### Step 9: Solid Queue Configuration

Configure a dedicated `:webhooks` queue in Solid Queue:
```yaml
# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
  workers:
    - queues: [default]
      threads: 3
    - queues: [webhooks]
      threads: 2
```

### Step 10: Delivery Cleanup Job

Create `WebhookDeliveryCleanupJob`:
- Runs daily via Solid Queue recurring schedule
- Deletes delivery records older than 7 days

### Step 11: Tests

- Unit tests: signer, dispatch service, delivery job (mock HTTP)
- Integration tests: create endpoint → receive email → verify delivery created
- API tests: full CRUD for webhook endpoints, delivery listing
- Retry tests: verify backoff schedule and endpoint status transitions

---

## 11. File Structure (New Files)

```
apps/api/
├── app/
│   ├── domain/entities/
│   │   ├── webhook_endpoint.rb
│   │   └── webhook_delivery.rb
│   ├── models/
│   │   ├── webhook_endpoint_record.rb
│   │   └── webhook_delivery_record.rb
│   ├── controllers/api/v1/
│   │   ├── webhooks_controller.rb
│   │   └── webhooks/
│   │       └── deliveries_controller.rb
│   ├── serializers/
│   │   ├── webhook_endpoint_serializer.rb
│   │   └── webhook_delivery_serializer.rb
│   └── jobs/
│       ├── webhook_delivery_job.rb
│       └── webhook_delivery_cleanup_job.rb
├── lib/inboxed/
│   ├── repositories/
│   │   ├── webhook_endpoint_repository.rb
│   │   └── webhook_delivery_repository.rb
│   ├── services/
│   │   └── dispatch_webhooks.rb
│   └── webhooks/
│       └── signer.rb
├── db/migrate/
│   ├── xxx_create_webhook_endpoints.rb
│   └── xxx_create_webhook_deliveries.rb
└── spec/
    ├── lib/inboxed/services/dispatch_webhooks_spec.rb
    ├── lib/inboxed/webhooks/signer_spec.rb
    ├── jobs/webhook_delivery_job_spec.rb
    └── requests/api/v1/webhooks_spec.rb
```

---

## 12. Exit Criteria

### Webhook Management

- [ ] **EC-001:** `POST /api/v1/webhooks` creates a webhook endpoint with auto-generated secret
- [ ] **EC-002:** `GET /api/v1/webhooks` lists all endpoints for the project
- [ ] **EC-003:** `PATCH /api/v1/webhooks/:id` updates url, event_types, description, status
- [ ] **EC-004:** `DELETE /api/v1/webhooks/:id` removes endpoint and all delivery records
- [ ] **EC-005:** `POST /api/v1/webhooks/:id/test` sends a test delivery and reports result
- [ ] **EC-006:** Webhook URL must be HTTPS (except localhost)

### Delivery Pipeline

- [ ] **EC-007:** When an email is received, all active webhook endpoints for that project receive a POST
- [ ] **EC-008:** Webhook payload includes `event`, `event_id`, `timestamp`, and `data` with email summary
- [ ] **EC-009:** Payload is signed with HMAC-SHA256 via `X-Inboxed-Signature` header
- [ ] **EC-010:** Signature verification example (Ruby and TypeScript) works correctly
- [ ] **EC-011:** Successful delivery (2xx) marks delivery as `delivered`
- [ ] **EC-012:** Failed delivery retries with exponential backoff (6 attempts over ~14.5 hours)
- [ ] **EC-013:** After 6 failed attempts, delivery is marked as `failed` permanently
- [ ] **EC-014:** Endpoint status transitions to `failing` after 3 consecutive failures
- [ ] **EC-015:** Endpoint status transitions to `disabled` after 10 consecutive failures
- [ ] **EC-016:** Disabled endpoints do not receive new deliveries

### Observability

- [ ] **EC-017:** `GET /api/v1/webhooks/:id/deliveries` lists delivery attempts with status and HTTP response
- [ ] **EC-018:** Webhook endpoint show includes delivery stats (total, successful, failed, pending)
- [ ] **EC-019:** Delivery records older than 7 days are automatically cleaned up

### Integration

- [ ] **EC-020:** Webhooks use a dedicated `:webhooks` Solid Queue and don't block the default queue
- [ ] **EC-021:** End-to-end: register webhook → send email via SMTP → receive POST at webhook URL within 5 seconds

## 13. Open Questions

None — all decisions captured in ADR-020.
