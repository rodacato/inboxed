# ADR-010: Rate Limiting with Rack::Attack

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The REST API is exposed to the network and needs protection against abuse, accidental tight loops in test scripts, and brute-force API key guessing. Rate limiting needs to be:

1. **Per API key** for authenticated endpoints — each project gets its own budget
2. **Per IP** for unauthenticated endpoints — protects login/auth attempts
3. **Simple to configure** — self-hosters should be able to adjust limits via env vars
4. **Transparent** — clients must know their limits and remaining budget via headers

### Options Considered

**A: Rack::Attack middleware**
- Pro: Battle-tested, in-process, works with any Rack app. Supports throttle, blocklist, safelist. Uses Rails cache backend.
- Con: In-process only (not distributed). Resets on deploy.

**B: Custom middleware with PostgreSQL**
- Pro: Shared state across processes.
- Con: DB round-trip per request. Counter contention under load. Reinventing the wheel.

**C: External rate limiter (nginx/Caddy)**
- Pro: Handles rate limiting before it hits the app.
- Con: Can't rate-limit per API key (doesn't have auth context). Only per-IP.

**D: Redis-backed Rack::Attack**
- Pro: Distributed counters, survives deploys.
- Con: Adds Redis dependency for rate limiting alone. Redis is already in the stack for ActionCable, but coupling rate limiting to it adds operational concern.

## Decision

**Rack::Attack (A)** with Rails' built-in cache backend. Start simple, move to Redis-backed (D) only if needed.

### Configuration

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # --- Throttles ---

  # Per API key: 300 requests per minute (5/sec sustained)
  throttle("api/key", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/") && req.env["inboxed.api_key_id"]
      req.env["inboxed.api_key_id"]
    end
  end

  # Per IP for admin endpoints: 60 requests per minute
  throttle("admin/ip", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/admin/")
      req.ip
    end
  end

  # Auth endpoint protection: 5 failed attempts per 5 minutes per IP
  throttle("auth/ip", limit: 5, period: 5.minutes) do |req|
    if req.path.start_with?("/api/v1/") && req.env["inboxed.auth_failed"]
      req.ip
    end
  end

  # --- Response ---

  self.throttled_responder = lambda do |matched, period, limit, count|
    retry_after = (period - (Time.current.to_i % period)).to_s
    [
      429,
      {
        "Content-Type" => "application/problem+json",
        "Retry-After" => retry_after,
        "X-RateLimit-Limit" => limit.to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (Time.current.to_i + retry_after.to_i).to_s
      },
      [{
        type: "https://docs.inboxed.dev/errors/rate-limited",
        title: "Rate limit exceeded",
        detail: "You've exceeded #{limit} requests per #{period} seconds. Retry after #{retry_after} seconds.",
        status: 429
      }.to_json]
    ]
  end
end
```

### Rate Limit Headers

All API responses include rate limit headers:

```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 287
X-RateLimit-Reset: 1710504000
```

These are set by an `after_action` callback in `Api::V1::BaseController`.

### Default Limits

| Scope | Limit | Period | Configurable via |
|-------|-------|--------|-----------------|
| Per API key | 300 | 1 minute | `RATE_LIMIT_API` |
| Per IP (admin) | 60 | 1 minute | `RATE_LIMIT_ADMIN` |
| Auth failures per IP | 5 | 5 minutes | `RATE_LIMIT_AUTH` |

### Wait Endpoint Exception

The `POST /api/v1/emails/wait` endpoint uses long-polling (up to 30s). This counts as a single request against the rate limit, not 30. The timeout is server-side, not repeated client requests.

## Consequences

### Easier

- **Protection from abuse** — tight loops in test scripts won't overwhelm the API
- **Brute-force prevention** — API key guessing is throttled per IP
- **Self-documenting** — rate limit headers let clients self-regulate
- **Simple deployment** — no external dependencies, works with Rails cache

### Harder

- **Not distributed** — each process has its own counters. Acceptable for a dev tool that typically runs as a single instance
- **Resets on deploy** — counters are lost. Acceptable for dev tool use case
- **Tuning** — limits need testing under real workloads to find the right balance

### Revisit When

- Multi-instance deployment where distributed counters matter → switch to Redis-backed Rack::Attack
- Self-hosters report limits are too restrictive or too permissive → adjust defaults
