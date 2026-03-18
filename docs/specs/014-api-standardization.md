# 014 — API Standardization & MCP Distribution

> Unify the public API v1 response format, add HTTP transport to the MCP server, publish multi-arch Docker images, and document the API with OpenAPI + Redocly.

**Phase:** Cross-cutting (API, MCP, Deploy)
**Status:** implemented
**Release:** —
**Depends on:** [003-rest-api](003-rest-api.md), [005-mcp-server](005-mcp-server.md), [010-http-catcher](010-http-catcher.md)
**ADRs:** [ADR-008](../adrs/008-api-response-format.md), [ADR-032](../adrs/032-api-envelope-standardization.md), [ADR-033](../adrs/033-mcp-dual-transport.md)

---

## 1. Objective

Fix the API response inconsistencies that broke the MCP client in production, standardize all public endpoints to follow ADR-008, add authenticated HTTP transport to the MCP server for remote access, and produce OpenAPI documentation.

After this spec, a developer or AI agent can:
- Consume any API endpoint with one predictable response shape
- Use the MCP server locally (Docker/stdio) or remotely (HTTPS/Streamable HTTP)
- Read interactive API documentation generated from an OpenAPI spec
- Pull a multi-arch MCP Docker image that runs natively on both AMD64 and ARM64

---

## 2. Current State

### 2.1 API inconsistency

Endpoints built in Phases 1-2 follow ADR-008 correctly:

```json
{ "emails": [...], "pagination": { "has_more": true, "next_cursor": "...", "total_count": 128 } }
```

Endpoints built in Phases 7-8 use a different pattern:

```json
{ "data": [...], "meta": { "has_more": true, "next_cursor": "..." } }
```

This caused the MCP server to crash in production with `Cannot read properties of undefined (reading 'length')` when calling `list_emails`.

### 2.2 Error responses

Current errors return `{ "error": "...", "detail": "..." }` instead of the RFC 7807 format specified in ADR-008.

### 2.3 MCP transport

The MCP server only supports stdio transport. A Streamable HTTP entry point (`index-http.ts`) has been created but lacks authentication and CORS.

### 2.4 Docker image

The `docker.yml` workflow specifies multi-arch (`linux/amd64,linux/arm64`) but the published image only has amd64, causing failures on Apple Silicon Macs.

### 2.5 No API documentation

The OpenAPI spec mentioned in spec 003 was never created. No machine-readable API documentation exists.

---

## 3. What This Spec Delivers

### 3.1 Standardized API responses

All public API v1 endpoints follow one format:

**Collections:**
```json
{
  "<resource_plural>": [...],
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJ...",
    "total_count": 128
  }
}
```

**Single resources:**
```json
{
  "<resource_singular>": { ... }
}
```

**Errors (RFC 7807):**
```json
{
  "type": "https://docs.inboxed.dev/errors/not-found",
  "title": "Resource not found",
  "detail": "No inbox with ID 'abc-123' exists in this project.",
  "status": 404
}
```

### 3.2 Controllers to update

| Controller | Action | Current key | Target key |
|------------|--------|-------------|------------|
| `EndpointsController` | `index` | `data` | `endpoints` |
| `EndpointsController` | `show` | `data` | `endpoint` |
| `EndpointsController` | `create` | `data` | `endpoint` |
| `EndpointsController` | `update` | `data` | `endpoint` |
| `Endpoints::RequestsController` | `index` | `data` | `requests` |
| `Endpoints::RequestsController` | `show` | `data` | `request` |
| `WebhooksController` | `index` | `data` | `webhooks` |
| `WebhooksController` | `show` | `data` | `webhook` |
| `WebhooksController` | `create` | `data` | `webhook` |
| `WebhooksController` | `update` | `data` | `webhook` |
| `Webhooks::DeliveriesController` | `index` | `data` | `deliveries` |

Controllers already following ADR-008 (no changes): `InboxesController`, `EmailsController`, `SearchController`.

### 3.3 New Rails concerns and serializers

| File | Purpose |
|------|---------|
| `app/controllers/concerns/api_renderable.rb` | `render_collection` and `render_resource` helpers that enforce the envelope |
| `app/serializers/inbox_serializer.rb` | Extract from inline `serialize_inbox` in controller |
| `app/serializers/attachment_serializer.rb` | Extract from inline `serialize_attachment` in controller |

### 3.4 RFC 7807 error responses

Update `app/controllers/concerns/error_renderable.rb`:

| Error | `Content-Type` | `type` slug |
|-------|---------------|-------------|
| 400 Bad Request | `application/problem+json` | `bad-request` |
| 401 Unauthorized | `application/problem+json` | `unauthorized` |
| 403 Forbidden | `application/problem+json` | `forbidden` |
| 404 Not Found | `application/problem+json` | `not-found` |
| 408 Timeout | `application/problem+json` | `timeout` |
| 422 Validation | `application/problem+json` | `validation-error` |
| 429 Rate Limited | `application/problem+json` | `rate-limited` |
| 500 Server Error | `application/problem+json` | `server-error` |

Validation errors include an `errors` array: `[{ "field": "label", "message": "can't be blank" }]`.

### 3.5 Dashboard updates

| File | Change |
|------|--------|
| `features/hooks/hooks.service.ts` | `data` → `endpoints` / `requests`; `meta` → `pagination` |
| `features/hooks/hooks.types.ts` | Update response interface if needed |
| Error handling | Parse RFC 7807 `detail` field instead of `error` |

### 3.6 MCP server simplification

Remove the `normalizePaginated()` workaround from `inboxed-api.ts`. Each method parses its own resource key directly:

```typescript
async findInboxByAddress(address: string): Promise<Inbox | null> {
  const res = await this.request<{ inboxes: Inbox[], pagination: Pagination }>(
    `/api/v1/inboxes?address=${encodeURIComponent(address)}`
  );
  return res.inboxes.length > 0 ? res.inboxes[0] : null;
}
```

### 3.7 New MCP tools

| Tool | Description | API mapping |
|------|-------------|-------------|
| `list_inboxes` | List all inboxes in the project | `GET /api/v1/inboxes` |
| `list_endpoints` | List HTTP catcher endpoints | `GET /api/v1/endpoints` |
| `get_endpoint` | Get endpoint details by token | `GET /api/v1/endpoints/:token` |

### 3.8 MCP HTTP transport with authentication

Update `apps/mcp/src/index-http.ts`:

- Read `Authorization: Bearer <key>` from the incoming request
- Create a per-request `InboxedApi` instance with the user's key (passthrough auth)
- Return 401 if no key provided
- Add CORS headers for browser-based clients
- Health check at `GET /health`
- MCP endpoint at `POST /mcp`

The Dockerfile uses `MCP_TRANSPORT` env var:
- `stdio` (default) → `index.js` — for Docker Desktop / local use
- `http` → `index-http.js` — for production deployment

### 3.9 Multi-arch Docker image

No code changes needed. The `docker.yml` workflow already specifies `platforms: linux/amd64,linux/arm64`. The next push to master triggers a proper multi-arch build. After this, Mac ARM users no longer need `--platform linux/amd64`.

### 3.10 OpenAPI documentation

Write an OpenAPI 3.1 spec for the public API v1 only (not admin endpoints).

**Structure:**
```
docs/
  api/
    openapi.yaml
    paths/
      inboxes.yaml
      emails.yaml
      search.yaml
      endpoints.yaml
      requests.yaml
      webhooks.yaml
    schemas/
      inbox.yaml
      email.yaml
      endpoint.yaml
      request.yaml
      webhook.yaml
      pagination.yaml
      errors.yaml
  redocly.yaml
```

**CI:** `npx @redocly/cli lint` on changes to `docs/`.
**Publish:** `npx @redocly/cli build-docs` to GitHub Pages.

---

## 4. Endpoints documented in OpenAPI

### Health
- `GET /api/v1/status`

### Inboxes
- `GET /api/v1/inboxes` — List inboxes (`?address=` filter)
- `GET /api/v1/inboxes/:id` — Get inbox
- `DELETE /api/v1/inboxes/:id` — Delete inbox

### Emails
- `GET /api/v1/inboxes/:id/emails` — List emails (paginated)
- `GET /api/v1/emails/:id` — Get email detail
- `GET /api/v1/emails/:id/raw` — Raw MIME source (`text/plain`)
- `POST /api/v1/emails/wait` — Long-poll for new email
- `DELETE /api/v1/emails/:id` — Delete email

### Attachments
- `GET /api/v1/emails/:id/attachments` — List attachments
- `GET /api/v1/attachments/:id/download` — Download binary

### Search
- `GET /api/v1/search` — Full-text search

### Endpoints (HTTP Catcher)
- `GET /api/v1/endpoints` — List endpoints (`?type=webhook|form|heartbeat`)
- `POST /api/v1/endpoints` — Create endpoint
- `GET /api/v1/endpoints/:token` — Get endpoint
- `PATCH /api/v1/endpoints/:token` — Update endpoint
- `DELETE /api/v1/endpoints/:token` — Delete endpoint
- `DELETE /api/v1/endpoints/:token/purge` — Purge requests

### Requests
- `GET /api/v1/endpoints/:token/requests` — List requests (paginated)
- `GET /api/v1/endpoints/:token/requests/:id` — Get request
- `DELETE /api/v1/endpoints/:token/requests/:id` — Delete request
- `POST /api/v1/endpoints/:token/requests/wait` — Long-poll for request

### Webhooks (Outbound)
- `GET /api/v1/webhooks` — List webhooks
- `POST /api/v1/webhooks` — Create webhook
- `GET /api/v1/webhooks/:id` — Get webhook
- `PATCH /api/v1/webhooks/:id` — Update webhook
- `DELETE /api/v1/webhooks/:id` — Delete webhook
- `POST /api/v1/webhooks/:id/test` — Test delivery
- `GET /api/v1/webhooks/:id/deliveries` — Delivery history (paginated)

---

## 5. Deployment changes

### 5.1 Keep MCP in production

The MCP container stays in the deploy pipeline with `MCP_TRANSPORT=http`. It serves the Streamable HTTP transport at `POST /mcp` for remote clients.

### 5.2 Kamal config change

```yaml
mcp:
  env:
    clear:
      MCP_TRANSPORT: http
      INBOXED_API_URL: https://<api-domain>
```

### 5.3 Expose via Cloudflare Tunnel

Route `inboxed-mcp.notdefined.dev` → `localhost:3001`.

### 5.4 User connection options

| Mode | Transport | Config |
|------|-----------|--------|
| Docker local | stdio | `"command": "docker", "args": ["run", "-i", "--rm", ...]` |
| URL remote | HTTP | `"url": "https://inboxed-mcp.notdefined.dev/mcp"` |

---

## 6. Execution order

```
Step 1: API (Rails)       → Standardize responses, RFC 7807 errors
Step 2: Dashboard (Svelte) → Update hooks services
Step 3: MCP (TypeScript)   → Remove normalization, add tools, add HTTP auth
Step 4: Deploy             → Update Kamal config, trigger multi-arch build
Step 5: OpenAPI            → Write spec, configure Redocly, add CI lint
```

Steps 1-3 must ship together (breaking change). Steps 4-5 are independent.

---

## 7. Exit criteria

- [x] All public API v1 endpoints return resource-named envelope keys
- [x] All paginated responses include `pagination.total_count`
- [x] All error responses follow RFC 7807 with `Content-Type: application/problem+json`
- [x] Dashboard hooks feature works with updated response format — N/A, dashboard uses admin API
- [x] MCP `list_emails` works against production API without normalization
- [x] MCP HTTP transport validates `Authorization` header
- [x] MCP HTTP transport returns CORS headers
- [ ] `ghcr.io/rodacato/inboxed-mcp:latest` has both amd64 and arm64 manifests — pending next push to master
- [x] OpenAPI spec passes `redocly lint`
- [x] All existing RSpec and Vitest tests pass
