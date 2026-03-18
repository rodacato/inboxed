# 012 — Inbound Email (Cloudflare Email Routing)

> Receive real emails from external senders (Gmail, Outlook, etc.) via Cloudflare Email Routing and deliver them to existing inboxes.

**Phase:** Post-MVP
**Status:** draft
**Release:** —
**Depends on:** [002 — SMTP & Persistence](002-smtp-persistence.md), [003 — REST API](003-rest-api.md)
**ADRs:** [ADR-030 Cloudflare Email Routing](../adrs/030-cloudflare-email-routing.md)

---

## 1. Objective

Enable Inboxed to receive **real inbound email** from external senders (Gmail, Outlook, corporate mail servers) and deliver them to existing inboxes. A Cloudflare Email Worker catches all mail sent to `*@mail.notdefined.dev`, POSTs the raw RFC 5322 message to the Inboxed API, and the system fans out to every existing inbox matching the recipient address.

**Use cases:**

- Testing email-triggered flows (e.g., "reply to this email to close the ticket")
- Receiving OTPs or verification emails from third-party services during E2E tests
- Debugging email forwarding rules or inspecting what a real provider's email looks like
- Validating that your application correctly parses inbound email content

**Key insight:** This is a zero-setup feature. If an inbox already exists (created by relay), inbound email to that address just works. No watches, no registration, no extra configuration.

## 2. Current State

- SMTP relay is fully operational — applications send test emails to Inboxed via authenticated SMTP (spec 002)
- REST API provides full CRUD access to projects, inboxes, and emails (spec 003)
- `ReceiveEmailJob` processes incoming email asynchronously via Solid Queue
- `ParseMime` service handles MIME parsing via the `mail` gem
- `inboxes.address` has a **global UNIQUE constraint** — each address can only exist once across all projects
- No mechanism exists to receive email from external senders (Gmail, Outlook, etc.)
- Cloudflare Email Routing is active on `notdefined.dev` for personal email; `mail.notdefined.dev` subdomain is available

## 3. What This Spec Delivers

### 3.1 Cloudflare Email Worker

A minimal TypeScript Worker that receives email at `*@mail.notdefined.dev` and POSTs the raw RFC 5322 message to the Inboxed API.

### 3.2 Inbound Webhook Endpoint

An internal webhook endpoint (`POST /hooks/inbound`) that authenticates the Worker via shared secret, extracts the envelope, and triggers fan-out delivery.

### 3.3 Fan-Out Delivery

Automatic delivery of inbound email to ALL existing inboxes matching the recipient address, across all projects. One inbound message, N deliveries.

### 3.4 Feature Flag Gating

Full email content gated behind `INBOXED_FEATURE_INBOUND_EMAIL`. When disabled (default), emails are stored with redacted body — preserving sender, subject, and timestamp but replacing body with an explanation message.

### 3.5 Schema Migration

Change `inboxes.address` from globally unique to per-project unique `(project_id, address)`, enabling the same address to exist across multiple projects.

### 3.6 Source Type Badges

New `source_type` values (`"inbound"` and `"inbound_redacted"`) to distinguish inbound emails from relay emails in the API and dashboard.

---

## 4. Data Model

### 4.1 Schema Change: Inbox Address Uniqueness

The existing global UNIQUE constraint on `inboxes.address` must change to a per-project compound unique constraint. This is the riskiest part of the implementation.

```ruby
# db/migrate/xxx_change_inbox_address_uniqueness.rb
class ChangeInboxAddressUniqueness < ActiveRecord::Migration[8.0]
  def change
    remove_index :inboxes, :address  # drop global unique
    add_index :inboxes, [:project_id, :address], unique: true  # unique per project
    add_index :inboxes, :address  # non-unique, for fan-out lookups
  end
end
```

**Impact analysis:** Every query that does `InboxRecord.find_by(address:)` without scoping by `project_id` must be reviewed. Affected locations:

| Location | Current Query | Required Change |
|----------|--------------|-----------------|
| `InboxRepository#find_or_create_by_address` | `find_or_create_by!(address:)` | Already scoped by `project_id` — safe |
| SMTP relay `on_rcpt_to_event` | N/A (uses `project_id` from auth context) | Safe — relay always has project context |
| API controllers (`InboxesController`) | `find_by(address:)` scoped to project | Safe — API key scopes to project |
| New inbound fan-out | `where(address:)` across all projects | New code — intentionally cross-project |

### 4.2 Source Type Extension

The `emails.source_type` column already exists (spec 002) with value `"relay"`. This spec adds two new values:

| Source Type | Meaning |
|------------|---------|
| `relay` | Email received via authenticated SMTP relay (existing) |
| `inbound` | Email received from external sender, feature enabled, full content stored |
| `inbound_redacted` | Email received from external sender, feature disabled, body redacted |

No migration needed — `source_type` is a string column, not an enum.

### 4.3 Domain Layer

No new entities are required. Inbound emails reuse the existing `Email` entity and `InboxAggregate`. The `ReceiveInboundEmail` service is an application-layer orchestrator.

---

## 5. API Endpoint

### 5.1 `POST /hooks/inbound`

This is an **internal webhook**, not a public API endpoint. It is intentionally placed outside `/api/v1/` to signal that it is not for end users and can change without API versioning concerns.

**Request:**

```http
POST /hooks/inbound HTTP/1.1
Authorization: Bearer <INBOUND_WEBHOOK_SECRET>
Content-Type: message/rfc822
X-Envelope-From: sender@gmail.com
X-Envelope-To: test123@mail.notdefined.dev

<raw RFC 5322 message body>
```

**Response — 202 Accepted:**

```json
{
  "data": {
    "delivered_to": 2,
    "redacted": 1
  }
}
```

**Response — 401 Unauthorized (bad or missing secret):**

```json
{
  "error": "unauthorized"
}
```

**Response — 422 Unprocessable Entity (missing headers):**

```json
{
  "error": "missing X-Envelope-To header"
}
```

**Authentication:** The `Authorization: Bearer` header must contain the `INBOUND_WEBHOOK_SECRET` env var, compared using `ActiveSupport::SecurityUtils.secure_compare` (constant-time) to prevent timing attacks.

**Note:** The response is always 202 even if zero inboxes match. The Worker does not need to know whether delivery occurred — that is an internal concern. Returning 202 with `delivered_to: 0` prevents information leakage about which addresses exist.

---

## 6. Pipeline Architecture

### 6.1 End-to-End Flow

```
Gmail user sends to: test123@mail.notdefined.dev
    |
    v
Cloudflare MX (route{1,2,3}.mx.cloudflare.net)
    |
    v
Cloudflare Email Worker (*@mail.notdefined.dev)
    |  POST /hooks/inbound
    |  Authorization: Bearer <secret>
    |  Content-Type: message/rfc822
    |  X-Envelope-From / X-Envelope-To headers
    |
    v
Inboxed API (via existing cloudflared tunnel)
    |
    +-- Authenticate Worker (shared secret, constant-time compare)
    +-- Extract envelope_to from X-Envelope-To header
    +-- Parse raw RFC 5322 ONCE (not N times)
    +-- Find ALL inboxes where address = envelope_to
    +-- Apply fan-out limit (max 10 projects)
    |
    +-- Inbox in Project A (feature ON) --> ReceiveEmailJob (source: "inbound")
    |   Full email: body, headers, attachments, raw source
    |
    +-- Inbox in Project B (feature ON) --> ReceiveEmailJob (source: "inbound")
    |   Full email: body, headers, attachments, raw source
    |
    +-- Inbox in Project C (feature OFF) -> ReceiveEmailJob (source: "inbound_redacted")
    |   Redacted: sender + subject + explanation, no body/attachments
    |
    +-- No inboxes found? -> silently drop (no bounce, no auto-creation)
```

### 6.2 Cloudflare Email Worker

Minimal TypeScript Worker deployed to Cloudflare. All parsing and storage logic stays in Rails.

```typescript
// cloudflare-email-worker/src/index.ts

interface Env {
  INBOXED_API_URL: string;
  INBOUND_WEBHOOK_SECRET: string;
}

interface EmailMessage {
  from: string;
  to: string;
  raw: ReadableStream;
}

export default {
  async email(message: EmailMessage, env: Env) {
    const rawEmail = await streamToArrayBuffer(message.raw);

    const response = await fetch(`${env.INBOXED_API_URL}/hooks/inbound`, {
      method: "POST",
      headers: {
        "Content-Type": "message/rfc822",
        "Authorization": `Bearer ${env.INBOUND_WEBHOOK_SECRET}`,
        "X-Envelope-From": message.from,
        "X-Envelope-To": message.to,
      },
      body: rawEmail,
    });

    if (!response.ok) {
      throw new Error(`Inboxed API returned ${response.status}`);
    }
  },
};

async function streamToArrayBuffer(stream: ReadableStream): Promise<ArrayBuffer> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
  }
  return new Blob(chunks).arrayBuffer();
}
```

**Cloudflare configuration:**
- Bind to catch-all route: `*@mail.notdefined.dev` -> Worker
- Worker secrets: `INBOXED_API_URL`, `INBOUND_WEBHOOK_SECRET`
- Execution limits: 10ms CPU on free plan (sufficient for forwarding)
- Message size limit: 25 MiB (Cloudflare-imposed, acceptable for dev tool)

### 6.3 Inbound Controller

```ruby
# app/controllers/hooks/inbound_controller.rb
module Hooks
  class InboundController < ApplicationController
    skip_before_action :authenticate_api_key!

    before_action :authenticate_webhook_secret!
    before_action :validate_envelope_headers!

    # POST /hooks/inbound
    def create
      result = Inboxed::Services::ReceiveInboundEmail.new.call(
        envelope_to: request.headers["X-Envelope-To"],
        envelope_from: request.headers["X-Envelope-From"],
        raw_source: request.body.read
      )

      render json: { data: result }, status: :accepted
    end

    private

    def authenticate_webhook_secret!
      token = request.headers["Authorization"]&.delete_prefix("Bearer ")

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(
        token, ENV.fetch("INBOUND_WEBHOOK_SECRET")
      )
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def validate_envelope_headers!
      unless request.headers["X-Envelope-To"].present?
        render json: { error: "missing X-Envelope-To header" }, status: :unprocessable_entity
      end
    end
  end
end
```

### 6.4 ReceiveInboundEmail Service (Fan-Out Logic)

```ruby
# app/application/services/receive_inbound_email.rb
module Inboxed
  module Services
    class ReceiveInboundEmail
      MAX_FAN_OUT = 10

      def initialize(feature_flags: Inboxed::FeatureFlags)
        @feature_flags = feature_flags
      end

      def call(envelope_to:, envelope_from:, raw_source:)
        inboxes = InboxRecord.where(address: envelope_to)
                             .includes(:project)
                             .limit(MAX_FAN_OUT)

        return { delivered_to: 0, redacted: 0 } if inboxes.empty?

        delivered = 0
        redacted = 0

        inboxes.each do |inbox|
          if @feature_flags.enabled?(:inbound_email)
            # Full delivery — same pipeline as relay emails
            ReceiveEmailJob.perform_later(
              project_id: inbox.project_id,
              envelope_from: envelope_from,
              envelope_to: [envelope_to],
              raw_source: raw_source,
              source_type: "inbound"
            )
            delivered += 1
          else
            # Teaser — store email with redacted body
            ReceiveEmailJob.perform_later(
              project_id: inbox.project_id,
              envelope_from: envelope_from,
              envelope_to: [envelope_to],
              raw_source: redact_email_source(raw_source, envelope_from),
              source_type: "inbound_redacted"
            )
            redacted += 1
          end
        end

        { delivered_to: delivered, redacted: redacted }
      end

      private

      def redact_email_source(raw_source, envelope_from)
        parsed = Mail.new(raw_source)
        redacted = Mail.new
        redacted.from = parsed.from
        redacted.to = parsed.to
        redacted.subject = parsed.subject
        redacted.date = parsed.date
        redacted.message_id = parsed.message_id
        redacted.body = <<~TEXT
          [Inboxed] This email was received from #{envelope_from} but its content
          is not available because inbound email is not enabled for this project.

          To view the full content of inbound emails, enable the inbound email
          feature flag for this project:

            INBOXED_FEATURE_INBOUND_EMAIL=true

          What you can see:
            - From: #{parsed.from}
            - Subject: #{parsed.subject}
            - Received at: #{Time.current.utc.iso8601}

          The original email contained #{parsed.attachments.size} attachment(s)
          and was #{raw_source.bytesize} bytes.
        TEXT
        redacted.to_s
      end
    end
  end
end
```

**Key design decisions in the fan-out logic:**

- **Parse once, store N copies** — the raw source is passed to `ReceiveEmailJob` per inbox, but the MIME parsing happens inside the existing job pipeline. The Worker POST only happens once.
- **Fan-out limit (MAX_FAN_OUT = 10)** — prevents amplification attacks where one email creates hundreds of copies if an address exists in many projects.
- **No auto-creation of inboxes** — only delivers to existing inboxes. If no inbox matches, the email is silently dropped.
- **No bounce** — unmatched addresses are dropped silently to avoid backscatter spam.
- **Preserve original `Received:` headers** — the raw source is passed through intact, preserving the external SMTP chain for debugging delivery issues.

---

## 7. Technical Decisions

### 7.1 Decision: Cloudflare Email Routing as MX Endpoint

See [ADR-030](../adrs/030-cloudflare-email-routing.md). Cloudflare handles MX, TLS termination, connection management, and basic spam filtering. The Worker is a thin bridge that POSTs raw email to the Inboxed API. No port 25 needed on the VPS.

### 7.2 Decision: Internal Webhook Endpoint (`/hooks/inbound`) instead of `/api/v1/inbound`

- **Options considered:** (A) `POST /api/v1/inbound` with API versioning, (B) `POST /hooks/inbound` as internal webhook, (C) `POST /internal/inbound`
- **Chosen:** B — `/hooks/inbound`
- **Why:** The inbound endpoint is an internal webhook consumed only by the Cloudflare Worker, not a public API for end users. Placing it under `/api/v1/` implies it follows API versioning and stability guarantees. `/hooks/inbound` makes it clear this is infrastructure plumbing that can change without versioning concerns.
- **Trade-offs:** Introduces a new route namespace (`/hooks/`). Acceptable — keeps the public API clean.

### 7.3 Decision: Shared Secret Authentication (not API key)

- **Options considered:** (A) Reuse project API key auth, (B) Dedicated shared secret via `INBOUND_WEBHOOK_SECRET`
- **Chosen:** B — shared secret
- **Why:** The Worker is not scoped to any project — it forwards email that may fan out to multiple projects. Project API keys are per-project credentials; using one would incorrectly scope the inbound endpoint. A dedicated shared secret is simpler and matches the webhook pattern.
- **Trade-offs:** One more env var to manage. Acceptable.

### 7.4 Decision: Per-Project Unique Address (not Global)

- **Options considered:** (A) Keep global unique constraint, reject duplicate addresses, (B) Per-project unique `(project_id, address)`
- **Chosen:** B — per-project unique
- **Why:** Fan-out requires the same address to exist in multiple projects. A global unique constraint would prevent this. Per-project uniqueness still prevents duplicate inboxes within a single project.
- **Trade-offs:** Requires reviewing all queries that assume global uniqueness. See section 4.1 for the impact analysis.

### 7.5 Decision: Feature Flag (not Paid/Free Tiers)

- **Options considered:** (A) Paid-tier feature, (B) Environment variable feature flag
- **Chosen:** B — feature flag (`INBOXED_FEATURE_INBOUND_EMAIL`)
- **Why:** Inboxed is a self-hosted dev tool with no billing system. A simple env var flag lets operators make a conscious decision to enable inbound email, understanding the privacy implications. The redacted teaser when disabled demonstrates the feature works without exposing email content.
- **Trade-offs:** Global flag (not per-project). Can be extended to per-project in the future.

### 7.6 Decision: Silent Drop for Unmatched Addresses

- **Options considered:** (A) Bounce with DSN, (B) Silent drop, (C) Auto-create inbox
- **Chosen:** B — silent drop
- **Why:** Bouncing creates backscatter spam (an internet anti-pattern). Auto-creating inboxes from inbound would let anyone create inboxes in the system by sending email to arbitrary addresses. Silent drop is the safest default.
- **Trade-offs:** Sender gets no feedback that the address doesn't exist. Acceptable for a dev tool.

---

## 8. Expert Panel Input

**Email Infrastructure Engineer:**
> "The fan-out model is correct for a dev tool. One inbound message, N deliveries to existing inboxes. The key insight is: DON'T parse the email N times. Parse once, store N copies. The raw source goes through `ReceiveEmailJob` per inbox, but the Worker POST only happens once. Also: preserve the original `Received:` headers from the external SMTP chain — they're invaluable for debugging delivery issues."

**Security Engineer:**
> "Three attack vectors to address: (1) Worker impersonation — shared secret MUST be constant-time compared. (2) Payload injection — the raw body is untrusted internet email, ensure the MIME parser handles malicious content (zip bombs, oversized headers, charset tricks). The existing `ParseMime` already handles this via the `mail` gem. (3) Fan-out amplification — if an address exists in 100 projects, one email creates 100 copies. Add a fan-out limit (max 10 projects per inbound email)."

**Full-Stack Engineer:**
> "The schema change from global-unique to per-project-unique inbox addresses is the riskiest part. Every query that does `InboxRecord.find_by(address:)` needs review — some may need to be scoped by project_id now. Check controllers, repositories, and the existing SMTP relay flow."

**API Design Architect:**
> "The inbound endpoint is an internal webhook, not a public API. Don't version it under `/api/v1/` — use `/internal/inbound` or `/hooks/inbound`. This makes it clear it's not for end users and can change without a versioning concern. Response should be minimal: 202 with delivery count."

**Product Manager:**
> "This is a differentiator. Frame it as 'receive real emails in your dev inbox' — not as infrastructure plumbing. The redacted teaser when the feature is off is smart marketing: users see it works but need to enable the flag. The dashboard should show inbound emails with a badge/tag so users can distinguish them from relay emails."

---

## 9. Security Measures

| Measure | Implementation |
|---------|---------------|
| **Worker authentication** | `INBOUND_WEBHOOK_SECRET` env var, checked via `Authorization: Bearer` header with constant-time comparison |
| **Rate limiting** | Rack::Attack rule: 30 req/min on `/hooks/inbound` per IP |
| **Fan-out limit** | Max 10 projects per inbound email (prevents amplification) |
| **Email limits** | Enforce `INBOXED_MAX_EMAILS_PER_PROJECT` before storing |
| **Message size** | Reject > `INBOXED_MAX_MESSAGE_SIZE_MB` at API level |
| **Source type tracking** | `source_type: "inbound"` or `"inbound_redacted"` to distinguish from relay |
| **No open relay** | Inboxed's SMTP port is NOT exposed to the internet — Cloudflare is the only inbound ingress |
| **Feature flag** | Full content requires explicit opt-in (`INBOXED_FEATURE_INBOUND_EMAIL=true`) |
| **No bounce** | Unmatched addresses are silently dropped — never bounce to avoid backscatter spam |
| **No auto-creation** | Emails to addresses with no existing inbox are silently dropped — no inbox auto-creation from inbound |
| **MIME safety** | Existing `ParseMime` (via `mail` gem) handles malicious content: zip bombs, oversized headers, charset tricks |

### Rate Limiting Configuration

```ruby
# config/initializers/rack_attack.rb (addition)
Rack::Attack.throttle("inbound_webhook", limit: 30, period: 60) do |req|
  req.ip if req.path == "/hooks/inbound" && req.post?
end
```

---

## 10. Implementation Plan

### Step 1: Schema Migration — Change Inbox Address Uniqueness

Change `inboxes.address` from globally unique to per-project unique. This is the foundation for fan-out delivery.

```ruby
remove_index :inboxes, :address  # drop global unique
add_index :inboxes, [:project_id, :address], unique: true  # unique per project
add_index :inboxes, :address  # non-unique, for fan-out lookups
```

### Step 2: Update Existing Queries

Audit and update all code that relies on global address uniqueness. Verify that every `InboxRecord.find_by(address:)` is properly scoped by `project_id` or intentionally cross-project (fan-out only). Key locations:

- `InboxRepository#find_or_create_by_address` — verify it scopes by `project_id`
- `InboxesController` — verify project-scoped lookups
- SMTP relay flow — verify project context from AUTH is used

### Step 3: Create `ReceiveInboundEmail` Service

Implement the fan-out orchestration service (section 6.4):
- Query all inboxes matching the envelope address
- Apply fan-out limit (max 10)
- Check feature flag per delivery
- Enqueue `ReceiveEmailJob` for each inbox with appropriate `source_type`
- Implement `redact_email_source` for disabled-feature deliveries

### Step 4: Create `InboundController`

Implement the webhook endpoint (section 6.3):
- Route: `POST /hooks/inbound`
- Authenticate via shared secret (constant-time compare)
- Validate `X-Envelope-To` header
- Read raw body as RFC 5322
- Call `ReceiveInboundEmail` service
- Return 202 with delivery counts

### Step 5: Create Cloudflare Email Worker

Deploy the TypeScript Worker (section 6.2):
- Create `cloudflare-email-worker/` directory at repo root
- `wrangler.toml` configuration
- `src/index.ts` with email handler
- Bind to `*@mail.notdefined.dev` catch-all route
- Configure Worker secrets: `INBOXED_API_URL`, `INBOUND_WEBHOOK_SECRET`

### Step 6: Add Feature Flag Support

Add `INBOXED_FEATURE_INBOUND_EMAIL` to the feature flag system:
- Default: `false` (disabled)
- When enabled: full email stored (body, headers, attachments, raw source)
- When disabled: email stored with redacted body via `redact_email_source`

### Step 7: Add Source Type Badge to Dashboard

Update the Svelte dashboard to display source type badges on emails:
- `relay` — default, no badge (or subtle "Relay" label)
- `inbound` — green "Inbound" badge
- `inbound_redacted` — amber "Inbound (Limited)" badge

### Step 8: Rate Limiting

Add Rack::Attack throttle rule for `/hooks/inbound`:
- 30 requests per minute per IP
- Returns 429 when exceeded

### Step 9: Tests

| What | Type | Location |
|------|------|----------|
| `ReceiveInboundEmail` service | Unit | `spec/application/services/receive_inbound_email_spec.rb` |
| `ReceiveInboundEmail` fan-out | Integration | `spec/application/services/receive_inbound_email_spec.rb` |
| `ReceiveInboundEmail` redaction | Unit | `spec/application/services/receive_inbound_email_spec.rb` |
| `InboundController` auth | Request | `spec/requests/hooks/inbound_spec.rb` |
| `InboundController` happy path | Request | `spec/requests/hooks/inbound_spec.rb` |
| `InboundController` missing headers | Request | `spec/requests/hooks/inbound_spec.rb` |
| Schema migration | Migration | Verify no broken queries after uniqueness change |
| Fan-out limit | Unit | Verify max 10 deliveries per inbound email |
| Feature flag gating | Unit | Verify `inbound` vs `inbound_redacted` source types |
| Rate limiting | Request | Verify 429 after 30 requests |
| End-to-end | Integration | POST raw RFC 5322 to `/hooks/inbound` -> email appears in inbox |

### Step 10: Environment Variables

Add to `.env.example`:

```bash
# Inbound email (Cloudflare Email Routing)
INBOUND_WEBHOOK_SECRET=generate-a-secure-random-token
INBOXED_FEATURE_INBOUND_EMAIL=false
```

Configure as Cloudflare Worker secrets:

```bash
wrangler secret put INBOXED_API_URL
wrangler secret put INBOUND_WEBHOOK_SECRET
```

---

## 11. File Structure (New Files)

```
inboxed/
├── cloudflare-email-worker/
│   ├── src/
│   │   └── index.ts                    # Email Worker (section 6.2)
│   ├── wrangler.toml                   # Cloudflare Worker config
│   ├── package.json
│   └── tsconfig.json
│
├── apps/api/
│   ├── app/
│   │   ├── controllers/hooks/
│   │   │   └── inbound_controller.rb   # Webhook endpoint (section 6.3)
│   │   └── application/services/
│   │       └── receive_inbound_email.rb # Fan-out service (section 6.4)
│   ├── config/
│   │   └── routes.rb                   # Add: post "/hooks/inbound"
│   ├── db/migrate/
│   │   └── xxx_change_inbox_address_uniqueness.rb
│   └── spec/
│       ├── application/services/
│       │   └── receive_inbound_email_spec.rb
│       └── requests/hooks/
│           └── inbound_spec.rb
│
├── apps/dashboard/
│   └── src/features/emails/
│       └── SourceBadge.svelte          # Inbound/relay badge component
```

**Modified files:**

```
apps/api/config/initializers/rack_attack.rb   # Add inbound throttle rule
apps/api/config/routes.rb                     # Add /hooks/inbound route
.env.example                                  # Add INBOUND_WEBHOOK_SECRET, INBOXED_FEATURE_INBOUND_EMAIL
```

---

## 12. Exit Criteria

### Schema & Data Model

- [x] **EC-001:** Migration changes `inboxes.address` from global unique to `(project_id, address)` unique
- [x] **EC-002:** Non-unique index on `inboxes.address` exists for fan-out lookups
- [x] **EC-003:** All existing queries that use `InboxRecord.find_by(address:)` are verified to be correctly scoped
- [x] **EC-004:** Same address can exist in multiple projects without constraint violation

### Inbound Webhook Endpoint

- [x] **EC-005:** `POST /hooks/inbound` with valid secret and raw RFC 5322 body returns 202
- [x] **EC-006:** `POST /hooks/inbound` without `Authorization` header returns 401
- [x] **EC-007:** `POST /hooks/inbound` with invalid secret returns 401
- [x] **EC-008:** `POST /hooks/inbound` without `X-Envelope-To` header returns 422
- [x] **EC-009:** Shared secret is compared using constant-time comparison (`secure_compare`)

### Fan-Out Delivery

- [x] **EC-010:** Inbound email to an address that exists in 3 projects creates 3 email records (one per inbox)
- [x] **EC-011:** Inbound email to an address with no matching inboxes returns `delivered_to: 0` and creates no records
- [x] **EC-012:** Fan-out is limited to 10 projects per inbound email
- [x] **EC-013:** No new inboxes are auto-created from inbound email

### Feature Flag

- [x] **EC-014:** With `INBOXED_FEATURE_INBOUND_EMAIL=true`, inbound email is stored with full body, headers, attachments, and raw source (`source_type: "inbound"`)
- [x] **EC-015:** With `INBOXED_FEATURE_INBOUND_EMAIL=false` (default), inbound email is stored with redacted body containing explanation message (`source_type: "inbound_redacted"`)
- [x] **EC-016:** Redacted emails preserve From, To, Subject, Date, and Message-ID headers
- [x] **EC-017:** Redacted emails do NOT store original body content or attachments

### Cloudflare Email Worker

- [x] **EC-018:** Worker receives email at `*@mail.notdefined.dev` and POSTs raw RFC 5322 to `/hooks/inbound`
- [x] **EC-019:** Worker sends `Authorization`, `Content-Type`, `X-Envelope-From`, and `X-Envelope-To` headers
- [x] **EC-020:** Worker throws on non-2xx response (triggers Cloudflare retry)

### Security

- [x] **EC-021:** Rack::Attack throttles `/hooks/inbound` at 30 req/min per IP
- [x] **EC-022:** Requests exceeding rate limit receive 429 response

### Dashboard

- [ ] **EC-023:** Emails with `source_type: "inbound"` display a distinguishing badge in the dashboard
- [ ] **EC-024:** Emails with `source_type: "inbound_redacted"` display a distinct badge indicating limited content

### Integration

- [x] **EC-025:** End-to-end: POST raw RFC 5322 to `/hooks/inbound` with valid secret -> email appears in matching inbox within 5 seconds
- [x] **EC-026:** Existing SMTP relay flow continues to work after schema migration
- [x] **EC-027:** All existing tests pass after schema migration
- [ ] **EC-028:** CI green

---

## 13. Open Questions

1. **Per-project feature flag** — The current design uses a global env var (`INBOXED_FEATURE_INBOUND_EMAIL`). Should this be per-project from the start, or is global sufficient for the initial implementation? **Recommendation:** start global, extend to per-project when needed. A global flag is simpler and covers the self-hosted single-operator use case.

2. **Fan-out limit tuning** — The limit is set at 10 projects per inbound email. Is this sufficient? Too generous? **Recommendation:** 10 is reasonable for a dev tool. Monitor in production and adjust if needed. The limit exists primarily to prevent abuse, not to restrict legitimate use.

3. **Worker retry behavior** — When the Worker throws on non-2xx, Cloudflare retries automatically. What is the retry cadence and max attempts? **Recommendation:** rely on Cloudflare's default retry behavior (3 attempts). The endpoint is idempotent from the Worker's perspective — duplicate POSTs may create duplicate emails, but this is acceptable for a dev tool. Add deduplication by `Message-ID` header in a future iteration if needed.

4. **Raw source storage for redacted emails** — When the feature is disabled, the redacted email has a synthetic `raw_source` (the redacted version). Should we store a hash of the original raw source for later correlation if the feature is enabled? **Recommendation:** no. Keep it simple. The redacted email is a teaser, not a promise of future recovery. If the operator enables the feature, future emails will be stored in full.
