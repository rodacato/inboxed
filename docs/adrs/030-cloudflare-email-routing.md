# ADR-030: Inbound Email via Cloudflare Email Routing

**Status:** proposed
**Date:** 2026-03-17
**Deciders:** Project owner
**Panel consulted:** Email Infrastructure Engineer, Security Engineer, DevOps Engineer, API Design Architect, Product Manager

## Context

Inboxed's SMTP server currently operates in **relay mode only** — applications must configure their SMTP settings to point directly at Inboxed and authenticate with an API key. This covers the primary use case (catching outbound test emails from your app).

However, some development workflows require **receiving real inbound email** from external senders (Gmail, Outlook, etc.):

- Testing email-triggered flows (e.g., "reply to this email to close the ticket")
- Receiving OTPs or verification emails from third-party services during E2E tests
- Debugging email forwarding rules or filters
- Inspecting what a real email from a provider looks like before parsing it

External mail servers (Gmail, etc.) deliver email via **standard SMTP on port 25** without authentication. They resolve the recipient domain's MX record and connect directly. This creates two infrastructure challenges:

1. **Port 25** is blocked by many cloud providers and hosting companies
2. The Inboxed SMTP server requires **API key authentication**, which external senders cannot provide

### Current DNS State

```
notdefined.dev      MX → route{1,2,3}.mx.cloudflare.net  (personal email)
mail.notdefined.dev A  → 89.167.84.80                    (Inboxed VPS)
```

The domain `notdefined.dev` already uses **Cloudflare Email Routing** for personal email. We must not interfere with that.

### Options Considered

**A: Open port 25 on VPS, direct MX record**
- Pro: Standard approach, no middleware
- Con: Port 25 often blocked by providers (Hetzner allows it after request)
- Con: Requires running SMTP on port 25 without auth (open relay risk)
- Con: No DDoS protection on raw SMTP
- Con: Must handle SPF/DKIM/DMARC validation ourselves

**B: Cloudflare Email Routing + Email Worker**
- Pro: Cloudflare handles MX, TLS, connection management, and basic spam filtering
- Pro: No port 25 needed on VPS — Worker POSTs to HTTPS API
- Pro: Free (included with Cloudflare Email Routing)
- Pro: Personal email on `notdefined.dev` stays untouched
- Pro: Cloudflare's infrastructure handles the hard parts of receiving internet email
- Con: Adds Cloudflare as a dependency for this feature
- Con: 25 MiB message size limit (acceptable for dev tool)
- Con: Email Worker execution limits (10ms CPU on free plan — sufficient for forwarding)

**C: Cloudflare Tunnel (cloudflared) for SMTP**
- Not viable: Cloudflare Tunnels only support HTTP/HTTPS, not raw TCP/SMTP

## Decision

**Option B** — Cloudflare Email Routing with an Email Worker for `mail.notdefined.dev`.

### Expert Panel Input

**Email Infrastructure Engineer:**
> "Using Cloudflare as the MX endpoint is smart for a dev tool. You get TLS termination, connection handling, and basic spam filtering for free. The Worker is just a thin bridge — receive the raw email, POST it to your API. Keep the Worker as dumb as possible; all parsing and storage logic stays in Rails where it belongs. Preserve the raw RFC 5322 message intact — don't let the Worker mangle headers. The fan-out to existing inboxes is the right call — in email, the same address can exist in multiple mailboxes. Think of it like a mailing list: one message, multiple deliveries."

**Security Engineer:**
> "The fan-out introduces a privacy surface: User A and User B both have an inbox for `test@mail.notdefined.dev`, so both see the same inbound emails. For a dev tool with shared test addresses this is acceptable, but it must be controlled via a feature flag — disabled by default. When disabled, still store the email record but replace the body with an explanation message. This prevents the feature from being used as an anonymous email reader. The inbound endpoint itself must authenticate the Worker via shared secret and rate-limit aggressively."

**DevOps Engineer:**
> "Cloudflare Email Routing for subdomains is straightforward — enable it in the dashboard, Cloudflare adds the MX records for `mail.notdefined.dev` automatically. The Worker is a few lines of code. The HTTPS POST to your API goes through the existing cloudflared tunnel, so no new ports to open. One POST from the Worker triggers multiple inbox deliveries server-side — don't make the Worker loop over recipients."

**API Design Architect:**
> "The inbound endpoint should feel like a webhook — `POST /api/v1/inbound` with the raw message in the body. Use a dedicated `Authorization: Bearer <INBOUND_SECRET>` header, not the project API key scheme. Response: 202 Accepted with the count of deliveries. The fan-out is an internal concern — the Worker doesn't need to know about it."

**Product Manager:**
> "This is a differentiator — Mailpit and Mailtrap don't catch real inbound email from Gmail. The zero-setup approach is key: if the inbox already exists from a relay email, inbound just works. No watches, no registration, no extra steps. Gate full content behind a feature flag for security, but when disabled still show _that_ an email arrived — that's enough to demonstrate value."

## Implementation

### 1. DNS & Cloudflare Setup

Enable Cloudflare Email Routing for `mail.notdefined.dev` subdomain. Cloudflare automatically configures:

```
mail.notdefined.dev  MX → route{1,2,3}.mx.cloudflare.net
```

Personal email on `notdefined.dev` is unaffected.

### 2. Email Worker (Cloudflare)

Minimal Worker that receives email and forwards to Inboxed API:

```typescript
// cloudflare-email-worker/src/index.ts
export default {
  async email(message: EmailMessage, env: Env) {
    const rawEmail = await streamToArrayBuffer(message.raw);

    const response = await fetch(`${env.INBOXED_API_URL}/api/v1/inbound`, {
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

Bind to catch-all route: `*@mail.notdefined.dev` → Worker.

### 3. Inbound API Endpoint (Rails)

```
POST /api/v1/inbound
Authorization: Bearer <INBOUND_WEBHOOK_SECRET>
Content-Type: message/rfc822
X-Envelope-From: sender@gmail.com
X-Envelope-To: test123@mail.notdefined.dev

<raw RFC 5322 message body>
```

**Response:** `202 Accepted`

```json
{
  "data": {
    "delivered_to": 3,
    "redacted": 1
  }
}
```

### 4. Routing: Automatic Fan-Out to Existing Inboxes

No watches, no registration, no extra setup. When an inbound email arrives, the system finds **all existing inboxes** with that address and delivers a copy to each.

#### How it works

1. **Email arrives** at `test123@mail.notdefined.dev`
2. **Find all inboxes** with `address = "test123@mail.notdefined.dev"` across all projects
3. **Fan-out** — for each inbox's project:
   - **Feature enabled** (`INBOXED_FEATURE_INBOUND_EMAIL`): full email stored via existing `ReceiveEmailJob`
   - **Feature disabled**: email stored with body replaced by an explanatory message (teaser)
4. **No matching inboxes** → drop silently (no bounce)

#### Why automatic?

- **Zero friction** — if your app already sends to `test123@mail.notdefined.dev` via relay, the inbox exists. Inbound emails to that address just show up. No extra steps.
- **Shared addresses work naturally** — multiple projects with the same inbox address all get copies.
- **The inbox already existed** — created automatically when the app first sent to that address via SMTP relay. Inbound piggybacks on that.

#### Schema change

The existing `inboxes.address` has a **global UNIQUE constraint**. This must change to allow the same address across multiple projects:

```ruby
# Migration
remove_index :inboxes, :address  # drop global unique
add_index :inboxes, [:project_id, :address], unique: true  # unique per project
add_index :inboxes, :address  # non-unique, for fan-out lookups
```

#### Routing logic

```ruby
# In the inbound service
class ReceiveInboundEmail
  def call(envelope_to:, envelope_from:, raw_source:)
    inboxes = InboxRecord.where(address: envelope_to)

    return { delivered_to: 0, redacted: 0 } if inboxes.empty?

    delivered = 0
    redacted = 0

    inboxes.includes(:project).each do |inbox|
      if inbox.project.feature_enabled?(:inbound_email)
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
    # Preserve headers (From, To, Subject, Date) but replace body
    # with explanation message
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
```

### 5. Feature Flag

Controlled by the existing feature flag system, **disabled by default**:

```bash
# .env
INBOXED_FEATURE_INBOUND_EMAIL=false  # default
```

| State | Behavior |
|-------|----------|
| **Enabled** | Full email stored — body, headers, attachments, raw source. Same experience as relay emails. |
| **Disabled** (default) | Email stored with redacted body. User sees sender, subject, timestamp, and an explanation that the feature is disabled. Original body and attachments are NOT stored. |

The feature flag can be global (env var) or per-project (future). Starting with global is simpler.

#### Why gate this?

> An ungated inbound email viewer on a shared domain is an anonymous email reader. Any user with an inbox at `whatever@mail.notdefined.dev` sees all inbound email to that address. The feature flag ensures the operator makes a conscious decision to enable this, understanding the privacy implications. The redacted teaser demonstrates the feature works without exposing email content.

### 6. Security Measures

| Measure | Implementation |
|---------|---------------|
| **Worker authentication** | `INBOUND_WEBHOOK_SECRET` env var, checked via `Authorization: Bearer` header |
| **Rate limiting** | Rack::Attack rule: 30 req/min on `/api/v1/inbound` per IP |
| **Email limits** | Enforce `INBOXED_MAX_EMAILS_PER_PROJECT` before storing |
| **Message size** | Reject > `INBOXED_MAX_MESSAGE_SIZE_MB` at API level |
| **Source type** | `source_type: "inbound"` or `"inbound_redacted"` to distinguish from relay |
| **No open relay** | Inboxed's SMTP port is NOT exposed to the internet — Cloudflare is the only ingress |
| **Feature flag** | Full content requires explicit opt-in (`INBOXED_FEATURE_INBOUND_EMAIL=true`) |
| **No bounce** | Unmatched addresses are silently dropped — never bounce to avoid backscatter spam |
| **Drop if no inbox** | Emails to addresses with no existing inbox are silently dropped — no auto-creation from inbound |

### 7. Environment Variables

```bash
# .env — new variables
INBOUND_WEBHOOK_SECRET=generate-a-secure-random-token
INBOXED_FEATURE_INBOUND_EMAIL=false
```

The `INBOXED_API_URL` and `INBOUND_WEBHOOK_SECRET` are also configured as Cloudflare Worker secrets.

## Flow Diagram

```
Gmail user sends to: test123@mail.notdefined.dev
    │
    ▼
Cloudflare MX (route{1,2,3}.mx.cloudflare.net)
    │
    ▼
Cloudflare Email Worker (*@mail.notdefined.dev)
    │  POST /api/v1/inbound
    │  Authorization: Bearer <secret>
    │  Content-Type: message/rfc822
    │  X-Envelope-From / X-Envelope-To headers
    │
    ▼
Inboxed API (via existing cloudflared tunnel)
    │
    ├─ Authenticate Worker (shared secret)
    ├─ Find ALL inboxes where address = "test123@mail.notdefined.dev"
    │
    ├─ Inbox in Project A (feature ON) ───► ReceiveEmailJob (full)
    │   └─ Full email: body, headers, attachments, raw source
    │
    ├─ Inbox in Project B (feature ON) ───► ReceiveEmailJob (full)
    │   └─ Full email: body, headers, attachments, raw source
    │
    ├─ Inbox in Project C (feature OFF) ──► ReceiveEmailJob (redacted)
    │   └─ Redacted: sender + subject + explanation, no body/attachments
    │
    └─ No inboxes found? → silently drop
```

## Consequences

### Easier

- **Real inbound email** — test email-triggered flows with actual Gmail/Outlook emails
- **Zero setup for users** — if the inbox exists from relay, inbound just works
- **Zero port 25 hassle** — Cloudflare handles internet-facing SMTP
- **Free infrastructure** — Cloudflare Email Routing and Workers included in free plan
- **Personal email untouched** — only `mail.notdefined.dev` subdomain is affected
- **Shared addresses** — multiple projects with same inbox address all get copies
- **Reuses existing pipeline** — fan-out feeds into same `ReceiveEmailJob`
- **Safe by default** — feature disabled by default, redacted teaser shows it works without exposing content

### Harder

- **Cloudflare dependency** — this feature requires Cloudflare (but only for inbound; SMTP relay works anywhere)
- **Schema change** — inbox address uniqueness moves from global to per-project
- **Fan-out complexity** — one inbound email creates N copies (bounded by number of matching inboxes)
- **New trust boundary** — the inbound endpoint is a new attack surface (mitigated by shared secret + rate limiting)

### Future Compatibility

- **Cloud mode (Phase 9):** Wildcard subdomains from ADR-028 (`*.inboxed.dev`) use the same fan-out logic — find inboxes by address, deliver to each
- **Self-hosted users:** Can configure their own Cloudflare Email Worker (or any HTTP-to-SMTP bridge) pointing at `/api/v1/inbound`
- **Alternative bridges:** The endpoint is generic — works with AWS SES inbound, Mailgun routes, Postmark inbound, or anything that can POST raw RFC 5322 messages
- **Per-project feature flag:** Start global, can later be per-project for finer control
