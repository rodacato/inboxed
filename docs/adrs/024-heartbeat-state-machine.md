# ADR-024: Heartbeat State Machine & Alerting

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** API Design Architect, DevOps Engineer, Full-Stack Engineer

## Context

Heartbeat endpoints are HTTP catcher endpoints with an `expected_interval` — a periodic ping is expected (e.g., every 5 minutes from a cron job). When pings stop arriving, the endpoint transitions through degraded states and eventually triggers an alert.

This ADR defines the state machine, transition logic, and alerting strategy for heartbeat monitoring.

### Requirements

1. Developer configures an expected interval (e.g., "5m", "1h", "24h")
2. Each HTTP request to the endpoint counts as a "ping"
3. If no ping arrives within the expected interval, the endpoint is "late"
4. If no ping arrives within 2x the expected interval, the endpoint is "down"
5. When status transitions to `down`, fire a webhook notification (reuses Phase 7 webhook delivery infrastructure)
6. Recovery is automatic — next ping transitions back to `healthy`

### Options Considered

**A: Polling-based status check (cron job evaluates all heartbeats periodically)**
- Pro: Simple — one background job checks all heartbeats every minute
- Pro: No complex scheduling — just `WHERE last_ping_at < NOW() - expected_interval`
- Con: Detection latency up to the poll interval (e.g., up to 60s late for a 1-minute check)
- Con: Scales linearly with number of heartbeat endpoints

**B: Per-endpoint scheduled job (schedule a "check missed" job for each heartbeat)**
- Pro: Exact timing — the check fires precisely at `last_ping_at + expected_interval`
- Pro: No wasted checks on healthy endpoints
- Con: Many scheduled jobs — one per heartbeat endpoint, rescheduled on every ping
- Con: Job cleanup complexity if endpoint is deleted

**C: Hybrid — polling with adaptive interval**
- Pro: Single job, but poll frequency adapts based on soonest expected deadline
- Con: Over-engineered for the expected scale (< 100 heartbeats per deployment)

## Decision

**Option A** — polling-based status check via a recurring Solid Queue job.

### Why Polling Over Per-Endpoint Jobs?

Inboxed is a dev/testing tool, not a production monitoring platform. The expected scale is 1-50 heartbeat endpoints per deployment. A single job that checks all heartbeats every 30 seconds is trivially cheap and eliminates the complexity of managing per-endpoint scheduled jobs.

The 30-second poll interval means worst-case detection latency is 30 seconds. For a tool monitoring cron jobs in development, this is more than acceptable.

### State Machine

```
                    ┌──────────┐
          create    │ pending  │
       ─────────►   │          │
                    └────┬─────┘
                         │ first ping
                         ▼
                    ┌──────────┐
          ping      │ healthy  │◄────────────────────┐
       ─────────►   │          │                     │
                    └────┬─────┘                     │
                         │ no ping for 1x interval   │ ping
                         ▼                           │
                    ┌──────────┐                     │
                    │  late    │─────────────────────►┘
                    │          │
                    └────┬─────┘
                         │ no ping for 2x interval
                         ▼
                    ┌──────────┐
                    │  down    │─────────────────────►(healthy on ping)
                    │          │
                    └──────────┘
                         │
                         ▼
                    fire alert (webhook notification)
```

### States

| State | Meaning | Entered when |
|---|---|---|
| `pending` | Endpoint created, no pings received yet | Creation |
| `healthy` | Last ping within expected interval | Ping received |
| `late` | Last ping between 1x and 2x expected interval | Poll job detects overdue |
| `down` | Last ping beyond 2x expected interval | Poll job detects severely overdue |

### Transitions

```ruby
# Domain logic — pure, no side effects
def evaluate_status(last_ping_at:, expected_interval:, now: Time.current)
  return :pending if last_ping_at.nil?

  elapsed = now - last_ping_at

  if elapsed <= expected_interval
    :healthy
  elsif elapsed <= expected_interval * 2
    :late
  else
    :down
  end
end
```

### The Check Job

```ruby
# app/application/jobs/heartbeat_check_job.rb
class HeartbeatCheckJob < ApplicationJob
  queue_as :default

  # Runs every 30 seconds via Solid Queue recurring schedule
  def perform
    Inboxed::Application::Services::CheckHeartbeats.call
  end
end
```

The service:
1. Loads all heartbeat endpoints with `heartbeat_status != 'pending'` (pending endpoints haven't received a first ping — nothing to check)
2. Evaluates current status based on `last_ping_at` and `expected_interval_seconds`
3. For endpoints where status changed: updates the record and publishes a `HeartbeatStatusChanged` domain event
4. The event handler fires a webhook notification (via Phase 7 infrastructure) when status transitions to `down`

### Alert Strategy

Alerts reuse the **existing webhook delivery infrastructure** from Phase 7 (spec 008, ADR-020):

- When a heartbeat transitions to `down`, publish a `HeartbeatDown` event
- The project's webhook endpoints (Phase 7 — outbound webhooks) that subscribe to `heartbeat_down` receive the notification
- Same HMAC signing, same retry logic, same delivery log

New event types added to the webhook subscription system:
- `heartbeat_down` — fired when status transitions to `down`
- `heartbeat_recovered` — fired when status transitions from `down`/`late` to `healthy`

### Solid Queue Recurring Schedule

```yaml
# config/recurring.yml
heartbeat_check:
  class: HeartbeatCheckJob
  schedule: every 30 seconds
```

### Dashboard Integration

The heartbeat detail view shows:
- Current status badge (green/yellow/red)
- Last ping timestamp and "X ago" relative time
- Expected interval
- Next expected ping deadline
- Timeline of recent pings (last 24h) as a simple bar chart
- Status transition history (from events)

### MCP Tool

```
check_heartbeat(endpoint_token)
→ { status: "healthy", last_ping_at: "...", expected_interval: "5m", next_expected_at: "..." }
```

## Consequences

### Easier

- **Simple implementation** — one recurring job, one SQL query, pure domain logic for status evaluation
- **No new dependencies** — reuses Solid Queue recurring schedule and Phase 7 webhook delivery
- **Predictable** — poll interval is fixed, status evaluation is deterministic
- **Observable** — status transitions are domain events, visible in event store and dashboard

### Harder

- **Detection latency** — up to 30 seconds delay between actual miss and status change. Acceptable for dev tool use case.
- **Poll overhead** — the job runs every 30 seconds even if there are no heartbeat endpoints. Mitigated by early return when count is zero.

### Mitigations

- Job skips immediately if no heartbeat endpoints exist (`return if count.zero?`)
- Batch update in single query: `UPDATE http_endpoints SET heartbeat_status = CASE ... WHERE endpoint_type = 'heartbeat'`
- Alert deduplication: only fire webhook on state *transition*, not on every check that finds `down`
