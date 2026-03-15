# ADR-008: API Response Format & Error Handling

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The REST API (spec 003) needs a consistent response format for both success and error cases. Developers and AI agents consuming the API should never have to guess the shape of a response.

Key requirements:
- Errors must be self-explanatory without reading documentation
- Successful responses must have a predictable envelope
- The format must work well for both human debugging (`curl`) and programmatic consumption (SDKs, MCP server)
- Attachment downloads and raw MIME source need non-JSON responses

### Options Considered

**A: JSON:API specification**
- Pro: Industry standard, strong tooling ecosystem.
- Con: Verbose, complex relationship handling. Overkill for a dev tool with a small, flat domain. Adds cognitive overhead for `curl` debugging.

**B: Plain JSON with resource envelope**
- Pro: Simple, predictable, easy to `curl`. Each response wraps the resource in a named key. No framework needed.
- Con: No standard for pagination metadata or includes. Must define conventions ourselves.

**C: Flat JSON (no envelope)**
- Pro: Minimal response size.
- Con: Ambiguous — is `{"id": "..."}` a project or an inbox? Hard to extend with metadata (pagination, rate limits) without breaking the shape.

## Decision

**Plain JSON with resource envelope (B)** for success responses, **RFC 7807 Problem Details** for errors.

### Success Responses

Every successful response wraps resources in a named key matching the resource type:

```json
// Single resource
{
  "inbox": {
    "id": "abc-123",
    "address": "test@mail.inboxed.dev",
    "email_count": 42,
    "created_at": "2026-03-15T10:00:00Z"
  }
}

// Collection
{
  "emails": [
    { "id": "def-456", "subject": "Verify your email", "received_at": "..." }
  ],
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJpZCI6ImRlZi00NTYifQ==",
    "total_count": 128
  }
}
```

Why named keys:
- Response is self-describing — you see `"inbox"` not just `{"id": "..."}`
- Can add sibling metadata (`pagination`, `meta`) without breaking the resource shape
- Consistent pattern across all endpoints

### Error Responses (RFC 7807)

All errors follow [RFC 7807 Problem Details](https://www.rfc-editor.org/rfc/rfc7807):

```json
{
  "type": "https://docs.inboxed.dev/errors/not-found",
  "title": "Resource not found",
  "detail": "No inbox with ID 'abc-123' exists in this project.",
  "status": 404,
  "instance": "/api/v1/inboxes/abc-123"
}
```

Content-Type for errors: `application/problem+json`.

Standard error types:

| Type slug | Status | When |
|-----------|--------|------|
| `unauthorized` | 401 | Missing or invalid API key / admin token |
| `forbidden` | 403 | Valid key but wrong project scope |
| `not-found` | 404 | Resource doesn't exist or not in scope |
| `validation-error` | 422 | Invalid request parameters |
| `rate-limited` | 429 | Too many requests |
| `server-error` | 500 | Unexpected internal error |

For validation errors, add an `errors` array:

```json
{
  "type": "https://docs.inboxed.dev/errors/validation-error",
  "title": "Validation failed",
  "detail": "One or more request parameters are invalid.",
  "status": 422,
  "errors": [
    { "field": "name", "message": "can't be blank" },
    { "field": "slug", "message": "has already been taken" }
  ]
}
```

### Non-JSON Responses

Two endpoints return non-JSON:
- `GET /api/v1/emails/:id/raw` — returns `text/plain` (raw MIME source)
- `GET /api/v1/attachments/:id/download` — returns binary with `Content-Disposition: attachment`

### Timestamps

All timestamps in ISO 8601 UTC format: `"2026-03-15T10:30:00Z"`. No local timezone offsets.

### Null vs Absent

Fields that can be null are always present in the response with a `null` value, never omitted. This ensures clients can rely on the response shape.

## Consequences

### Easier

- **Debugging with `curl`** — responses are readable and self-describing
- **Client development** — predictable envelope, no guessing
- **Error handling** — RFC 7807 is a standard; libraries exist for parsing it
- **Future extensibility** — metadata can be added alongside the resource key

### Harder

- **Slightly more verbose** than flat JSON — one extra nesting level
- **No automatic tooling** like JSON:API client generators
- **Must document conventions** ourselves — no external spec to point to

### Mitigations

- Keep serialization logic in dedicated serializer objects, not inline in controllers
- OpenAPI spec (future) will formally document the response shapes
