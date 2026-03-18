# ADR-032: API Envelope Standardization

**Status:** accepted
**Date:** 2026-03-18
**Deciders:** Project owner
**Supersedes:** Partially amends ADR-008 (enforcement, not design)

## Context

ADR-008 established the API response format: resource-named envelope keys for success responses, RFC 7807 for errors. The design was correct, but implementation drifted during Phases 7-8.

Endpoints built in Phase 1-2 (inboxes, emails, search) follow ADR-008:
```json
{ "emails": [...], "pagination": { "has_more": true, "next_cursor": "...", "total_count": 128 } }
```

Endpoints built in Phase 7-8 (endpoints, webhooks, deliveries) use a different pattern:
```json
{ "data": [...], "meta": { "has_more": true, "next_cursor": "..." } }
```

This inconsistency caused the MCP server to crash in production. The MCP client had to implement a `normalizePaginated()` workaround, which failed when the response didn't match either pattern.

Error responses use `{ "error": "...", "detail": "..." }` instead of the RFC 7807 format specified in ADR-008.

### Options Considered

**A: Standardize on resource-named keys (enforce ADR-008)**
- Pro: Already the documented standard. Self-describing responses. No ADR change needed.
- Con: Requires updating all Phase 7-8 controllers and their tests.

**B: Standardize on generic `data`/`meta` keys**
- Pro: Generic client code — one parser for all endpoints.
- Con: Violates ADR-008. Responses are not self-describing. Must rewrite Phase 1-2 controllers too.

**C: Keep both, normalize in clients**
- Pro: No API changes needed.
- Con: Every client must implement normalization. Already proven to cause bugs.

## Decision

**Option A: Enforce ADR-008 as written.** Resource-named envelope keys everywhere.

No external consumers exist — the only clients are the dashboard and MCP server, both under our control. This is the last moment to fix this before the API goes public.

### Enforcement mechanism

Create an `ApiRenderable` concern with `render_collection` and `render_resource` helpers. Controllers must use these helpers instead of manual `render json:`. This makes it structurally impossible to use the wrong envelope format.

```ruby
# Instead of:
render json: { data: records.map { |r| serialize(r) }, meta: pagination_meta(result) }

# Use:
render_collection(:endpoints, result[:records], result, serializer: HttpEndpointSerializer)
```

### Pagination contract

Every paginated response includes all three fields:
```json
{
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJ...",
    "total_count": 128
  }
}
```

No partial `meta` objects. No raw IDs as cursors. Always encoded cursors from `Paginatable#encode_cursor`.

### Error contract

All errors follow RFC 7807 with `Content-Type: application/problem+json`:
```json
{
  "type": "https://docs.inboxed.dev/errors/not-found",
  "title": "Resource not found",
  "detail": "No inbox with ID 'abc-123' exists in this project.",
  "status": 404
}
```

## Consequences

### Easier

- MCP server can delete `normalizePaginated()` and trust the API shape
- Dashboard hooks service uses the same parsing logic as all other services
- Future API clients (SDK, CLI) have one format to implement
- OpenAPI spec has one response schema pattern

### Harder

- Must update ~6 controllers and their tests in one commit (breaking change)
- Dashboard hooks service must be updated simultaneously

### Mitigations

- No external consumers — breaking change affects only our codebase
- Ship API + dashboard + MCP changes together in one deploy
