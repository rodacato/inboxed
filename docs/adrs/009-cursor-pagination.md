# ADR-009: Cursor-based Pagination for API Collections

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The REST API returns collections of emails, inboxes, and other resources. Email lists in active inboxes can grow to hundreds or thousands of records. The API needs a pagination strategy that is:

1. **Efficient** — no `OFFSET` scans on large tables
2. **Stable** — concurrent inserts (new emails arriving) don't cause duplicates or missed items
3. **Simple** — easy to implement and consume from the dashboard, MCP server, and test helpers

### Options Considered

**A: Offset-based (`?page=3&per_page=20`)**
- Pro: Simple concept, trivial to implement.
- Con: `OFFSET N` scans and discards N rows — O(N) for deep pages. Concurrent inserts cause items to shift between pages (duplicates or gaps). Poor for real-time email lists.

**B: Cursor-based (`?limit=20&after=<cursor>`)**
- Pro: Uses `WHERE` clause instead of `OFFSET` — O(1) regardless of depth. Stable under concurrent writes — the cursor points to a specific record, not a position. Perfect for append-heavy tables like emails.
- Con: Can't jump to "page 5". No `total_pages` concept. Cursor must encode the sort key.

**C: Keyset with raw values (`?after_received_at=2026-03-15T10:00:00Z&after_id=abc-123`)**
- Pro: No encoding, human-readable.
- Con: Exposes sort implementation in the query string. Fragile if sort keys change. Multi-column keys get unwieldy.

## Decision

**Cursor-based pagination (B)** for all collection endpoints. Cursors are opaque Base64-encoded JSON containing the sort key(s).

### API Contract

```
GET /api/v1/inboxes/:id/emails?limit=20&after=<cursor>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 20 | Items per page (max: 100) |
| `after` | string | — | Cursor from previous response |

Response pagination metadata:

```json
{
  "emails": [...],
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJyZWNlaXZlZF9hdCI6IjIwMjYtMDMtMTVUMTA6MDA6MDBaIiwiaWQiOiJhYmMtMTIzIn0=",
    "total_count": 342
  }
}
```

- `has_more` — whether more items exist after this page
- `next_cursor` — pass as `after` for the next page (null when `has_more` is false)
- `total_count` — total items in the collection (cheap `COUNT(*)` for bounded collections)

### Cursor Encoding

```ruby
# Encode
cursor = Base64.urlsafe_encode64({ received_at: email.received_at.iso8601(6), id: email.id }.to_json)

# Decode
decoded = JSON.parse(Base64.urlsafe_decode64(cursor))
```

The cursor encodes the sort key (`received_at`) plus `id` for uniqueness (tiebreaker). Default sort is `received_at DESC` for emails.

### SQL Pattern

```sql
-- First page
SELECT * FROM emails
WHERE inbox_id = ?
ORDER BY received_at DESC, id DESC
LIMIT 21  -- fetch limit+1 to determine has_more

-- Subsequent pages (after cursor)
SELECT * FROM emails
WHERE inbox_id = ?
  AND (received_at, id) < (?, ?)  -- cursor values
ORDER BY received_at DESC, id DESC
LIMIT 21
```

The `(received_at, id) < (?, ?)` uses the composite index `(inbox_id, received_at)` efficiently.

### Per-Resource Sort Keys

| Resource | Default sort | Cursor keys |
|----------|-------------|-------------|
| Emails | `received_at DESC` | `received_at`, `id` |
| Inboxes | `created_at DESC` | `created_at`, `id` |
| Projects (admin) | `created_at DESC` | `created_at`, `id` |

## Consequences

### Easier

- **Performance at scale** — pagination is O(1) regardless of collection size
- **Real-time stability** — new emails don't shift existing pages
- **Index-friendly** — leverages existing composite indexes
- **Consistent pattern** — same pagination shape across all endpoints

### Harder

- **No random page access** — can't jump to "page 5", must iterate from start
- **Opaque cursors** — developers can't construct cursors manually (by design — prevents coupling to sort implementation)
- **Sort key changes require cursor invalidation** — changing the default sort order would break existing cursors

### Mitigations

- For the dashboard, cursor pagination maps naturally to "load more" or infinite scroll
- `total_count` lets the UI show "showing 20 of 342" without needing page numbers
- Cursors are cheap to generate and decode (Base64 JSON)
