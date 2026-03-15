# ADR-020: Webhook Delivery & Retry Strategy

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed webhooks notify external systems when emails are received. Webhook delivery is inherently unreliable — the receiving server may be down, slow, or return errors. We need a strategy for handling failures.

### Options Considered

**A: Fire-and-forget (no retries)**
- Pro: Simplest implementation
- Con: A single network blip loses the event permanently
- Con: Unacceptable for CI/CD pipelines that depend on the notification

**B: Exponential backoff retries with Solid Queue**
- Pro: Uses existing job infrastructure (no new dependencies)
- Pro: Exponential backoff prevents hammering a failing endpoint
- Pro: Delivery log provides visibility into failures
- Con: Failed deliveries consume queue resources

**C: External webhook delivery service (e.g., Svix, Hookdeck)**
- Pro: Battle-tested delivery infrastructure, UI for monitoring
- Con: External dependency for a self-hosted tool — contradicts the project's philosophy
- Con: Cost, complexity, another service to configure

## Decision

**Option B** — exponential backoff retries using Solid Queue, with a delivery log for observability.

### Retry Schedule

| Attempt | Delay | Cumulative |
|---------|-------|-----------|
| 1 | Immediate | 0 |
| 2 | 1 minute | 1 min |
| 3 | 5 minutes | 6 min |
| 4 | 30 minutes | 36 min |
| 5 | 2 hours | ~2.5 hr |
| 6 | 12 hours | ~14.5 hr |

After 6 failed attempts, the delivery is marked as `failed` permanently. The webhook endpoint status transitions to `failing` after 3 consecutive failures across any deliveries, and `disabled` after 10 consecutive failures.

### Delivery Guarantees

- **At-least-once delivery** — a webhook may be delivered more than once if the receiving server responds slowly. Consumers must handle duplicates via the `event_id` field.
- **Ordering not guaranteed** — deliveries may arrive out of order due to retries. Consumers should use `timestamp` for ordering.

### Payload Signing

Every webhook request is signed with HMAC-SHA256 using the endpoint's secret key:

```
X-Inboxed-Signature: sha256=<hex_digest>
X-Inboxed-Event: email_received
X-Inboxed-Delivery: <delivery_id>
X-Inboxed-Timestamp: <unix_timestamp>
```

The signature covers: `"#{timestamp}.#{raw_json_body}"` to prevent replay attacks.

### Timeout

- HTTP request timeout: **10 seconds**
- If the receiving server doesn't respond within 10s, the delivery is marked as failed and retried
- Successful delivery: any 2xx HTTP status code

## Consequences

### Easier

- **No new dependencies** — uses Solid Queue already in the stack
- **Observable** — delivery log tracks every attempt with status, HTTP response, timing
- **Self-healing** — transient failures recover automatically via retries
- **Secure** — HMAC signing prevents spoofing, timestamp prevents replay

### Harder

- **At-least-once semantics** — consumers must handle duplicates
- **Queue pressure** — many failing webhooks could fill the job queue (mitigated by max 6 attempts and endpoint disabling)

### Mitigations

- Auto-disable endpoints after 10 consecutive failures
- Admin can view delivery log and re-enable endpoints
- Delivery records auto-expire after 7 days (same TTL as emails)
