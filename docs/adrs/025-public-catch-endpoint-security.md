# ADR-025: Public Catch Endpoint Security Model

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Security Engineer, API Design Architect, DevOps Engineer

## Context

The HTTP catcher exposes a public endpoint — `POST/GET/... /hook/:token` — that receives HTTP requests from external services (Stripe, GitHub, cron jobs, etc.). By design, this endpoint requires **no API key authentication** — the token in the URL *is* the credential.

This is fundamentally different from the management API (`/api/v1/endpoints/...`), which requires Bearer token authentication. The public catch endpoint must be open enough to receive requests from any source, yet hardened against abuse.

### Threat Model

| Threat | Impact | Likelihood |
|---|---|---|
| **Token brute-force** | Attacker finds valid tokens, reads captured data | Low (44-char tokens = 256 bits entropy) |
| **Storage exhaustion** | Attacker floods endpoint with large bodies | Medium (public URL, no auth) |
| **Request flooding** | DDoS via high request volume | Medium |
| **Data exfiltration** | Attacker reads captured requests via public endpoint | None (public endpoint only *writes*, reading requires API key) |
| **Token enumeration** | Timing attacks on token lookup | Low |
| **IP spoofing in headers** | Attacker fakes X-Forwarded-For | Low (cosmetic — stored IP, not used for auth) |

### Options Considered

**A: Token-only security (minimal)**
- Token entropy provides authentication
- Rate limiting per token
- Body size cap
- Pro: Simplest — external services just hit the URL
- Con: No IP restriction, no request validation

**B: Token + optional IP allowlist**
- Everything in A, plus optional per-endpoint IP allowlist
- Pro: Extra layer for known sources (Stripe, GitHub publish their IPs)
- Con: IP lists change — maintenance burden on user

**C: Token + HMAC signature verification**
- Verify incoming webhook signatures (e.g., Stripe's `Stripe-Signature` header)
- Pro: Strongest authentication
- Con: Every webhook provider uses a different signing scheme — impossible to generalize
- Con: Breaks the "just point any HTTP request here" simplicity

## Decision

**Option B** — token-only security as default, with optional IP allowlist per endpoint.

### Why Not HMAC Verification (Option C)?

Inboxed is a *catcher*, not a *consumer*. It doesn't process webhook payloads — it stores them for inspection. Verifying signatures would require per-provider adapters (Stripe, GitHub, Twilio each sign differently). This contradicts the generic "catch anything" design.

Users who need signature verification can do it in their test code after extracting the request via API/MCP.

### Security Measures

#### 1. Token Entropy

Tokens are generated with `SecureRandom.urlsafe_base64(32)` — 256 bits of entropy, producing 43-character URL-safe strings. At 1 billion guesses per second, brute-forcing a single token would take ~3.7 × 10⁶⁸ years.

```ruby
# Token generation
token = SecureRandom.urlsafe_base64(32)
# Example: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
```

Tokens are stored in plaintext (not hashed like API keys) because:
- They are used for URL routing — hashing would require a lookup table
- They are not secrets the user manages — they're generated and displayed once
- The security model is equivalent to a signed URL (like S3 presigned URLs)

#### 2. Rate Limiting

Per-endpoint rate limiting via Rack::Attack (already configured for the API):

```ruby
# Per endpoint token: 120 requests/minute (2/second)
Rack::Attack.throttle("hook/token", limit: 120, period: 60) do |req|
  req.path.match(%r{^/hook/([^/]+)})&.captures&.first if req.path.start_with?("/hook/")
end

# Global catch endpoint: 1000 requests/minute across all tokens
Rack::Attack.throttle("hook/global", limit: 1000, period: 60) do |req|
  "global" if req.path.start_with?("/hook/")
end
```

Rate-limited requests receive `429 Too Many Requests` with `Retry-After` header.

#### 3. Body Size Cap

Maximum body size per request: **256KB** (configurable per endpoint, default in `http_endpoints.max_body_bytes`).

Enforced at two levels:
- **Rack middleware:** Reject requests with `Content-Length > max_body_bytes` before reading the body (413 Payload Too Large)
- **Controller:** Truncate body if streaming without Content-Length header

#### 4. Optional IP Allowlist

Per-endpoint configuration, stored as `allowed_ips` (VARCHAR array) on `http_endpoints`:

```ruby
# Only accept requests from Stripe's webhook IPs
endpoint.update(allowed_ips: ["3.18.12.63", "3.130.192.163", "13.235.14.237"])
```

When `allowed_ips` is NULL or empty, all IPs are accepted (default — zero friction).
When populated, requests from non-listed IPs receive `403 Forbidden`.

IP is extracted from `request.remote_ip` (respects trusted proxies configured in Rails).

#### 5. Response Behavior

The catch endpoint always responds quickly to avoid timeouts in the calling service:

| Endpoint type | Default response |
|---|---|
| Webhook | `200 OK` with `{"ok": true, "id": "<request_id>"}` |
| Form (mode: json) | `200 OK` with `{"ok": true, "id": "<request_id>"}` |
| Form (mode: redirect) | `302 Found` to configured `response_redirect_url` |
| Form (mode: html) | `200 OK` with configured HTML or default thank-you page |
| Heartbeat | `200 OK` with `{"ok": true, "status": "healthy"}` |
| Invalid token | `404 Not Found` with `{"error": "not_found"}` |
| Rate limited | `429 Too Many Requests` with `Retry-After` header |
| Body too large | `413 Payload Too Large` |
| IP not allowed | `403 Forbidden` |
| Method not allowed | `405 Method Not Allowed` (if endpoint restricts methods) |

#### 6. Timing-Safe Token Lookup

Use `ActiveSupport::SecurityUtils.secure_compare` for token comparison in any non-indexed lookup paths. For the primary lookup (SQL `WHERE token = ?`), the database index makes timing attacks impractical — but the 404 response for invalid tokens uses a constant-time check to avoid leaking token existence.

```ruby
# Controller returns 404 for missing tokens — no distinction between
# "token doesn't exist" and "token exists but endpoint is disabled"
def find_endpoint
  @endpoint = HttpEndpointRecord.find_by(token: params[:token])
  head :not_found unless @endpoint
end
```

#### 7. Request Storage Limits

Beyond body size, additional limits prevent storage abuse:

- **Max header size:** 64KB total headers per request
- **Max requests per endpoint:** Configurable (default: unlimited, cleaned by TTL)
- **TTL cleanup:** Same as emails — project TTL applies, `HttpRequestCleanupJob` runs periodically

### Public Endpoint Routing

The catch endpoint lives outside the API namespace and is handled by a dedicated controller:

```
# config/routes.rb
match '/hook/:token',       to: 'hooks#catch', via: :all
match '/hook/:token/*path', to: 'hooks#catch', via: :all
```

The `*path` capture allows endpoints to receive requests at sub-paths (e.g., `/hook/:token/stripe/checkout`), which is stored as part of the request metadata. This is important for services that send webhooks to different paths based on event type.

## Consequences

### Easier

- **Zero friction** — external services just POST to a URL, no auth headers needed
- **Universal compatibility** — works with any service that can make HTTP requests
- **Layered defense** — rate limiting + body cap + optional IP allowlist
- **Familiar model** — same security model as webhook.site, RequestBin, S3 presigned URLs

### Harder

- **Public surface area** — the `/hook/` path is exposed without authentication
- **Abuse potential** — anyone who discovers a token URL can send requests to it (mitigated by: tokens are unguessable, rate limiting, body cap, TTL cleanup)

### Mitigations

- 256-bit token entropy makes brute-force infeasible
- Per-endpoint and global rate limiting prevent flooding
- Body size cap prevents storage exhaustion
- TTL cleanup prevents long-term storage accumulation
- IP allowlist available for users who need it
- Feature flag to disable HTTP catcher entirely for email-only deployments
