# API Refactor Plan

> Standardize the public API v1, fix the MCP client, update the dashboard, document with OpenAPI + Redocly, and remove MCP from production deployment.

**Status:** Phases 1, 3, 4, 5, 6 complete. Phase 2 skipped (dashboard uses admin API). Phase 7 pending next deploy.
**Date:** 2026-03-18
**Experts consulted:** API Design Architect, Full-Stack Engineer, MCP & AI Integrations Engineer, DX Engineer, DevOps Engineer

---

## Problem Statement

The public API v1 has two conflicting response formats that emerged across development phases:

| Endpoints built in Phase 1-2 | Endpoints built in Phase 7-8 |
|-------------------------------|------------------------------|
| `{ "inboxes": [...], "pagination": {...} }` | `{ "data": [...], "meta": {...} }` |
| Resource-named keys (per ADR-008) | Generic keys (violates ADR-008) |
| `pagination.total_count` always present | `meta.total_count` sometimes missing |

This inconsistency forced the MCP server to implement `normalizePaginated()` — a workaround that broke in production when the response shape didn't match either pattern.

Additionally:
- Error responses use `{ "error": "...", "detail": "..." }` instead of RFC 7807 (as specified in ADR-008)
- Some serializers are inline in controllers instead of dedicated classes
- The MCP container is deployed as a service in production but is only needed as a client-side Docker image
- The public API lacks formal documentation (OpenAPI spec)

---

## Guiding Principles

Per the expert panel and existing ADRs:

1. **ADR-008 is the source of truth** — resource-named envelope keys, RFC 7807 errors
2. **One response format** — no exceptions, no normalization layers needed
3. **Design-first** — write the OpenAPI spec, then make the code match
4. **Nobody uses the API externally** — dashboard is the only consumer, so we can break everything without migration

---

## Phase 1: Standardize API Response Format (Rails)

### 1.1 Create `ApiRenderable` concern

Replace ad-hoc response formatting with a single concern that enforces the ADR-008 contract.

**File:** `app/controllers/concerns/api_renderable.rb`

```ruby
module ApiRenderable
  extend ActiveSupport::Concern

  private

  # Collection: render_collection(:emails, records, pagination_result)
  # → { "emails": [...], "pagination": { "has_more": bool, "next_cursor": str|null, "total_count": int } }
  def render_collection(resource_name, records, result, serializer: nil, status: :ok)
    serialized = if serializer
      records.map { |r| serializer.render(r) }
    else
      records
    end

    render json: {
      resource_name => serialized,
      pagination: pagination_meta(result)
    }, status: status
  end

  # Single resource: render_resource(:endpoint, record)
  # → { "endpoint": { ... } }
  def render_resource(resource_name, record, serializer: nil, status: :ok)
    serialized = serializer ? serializer.render(record) : record
    render json: { resource_name => serialized }, status: status
  end
end
```

### 1.2 Implement RFC 7807 error responses

**File:** `app/controllers/concerns/error_renderable.rb`

Update all error handlers to return:

```json
{
  "type": "https://docs.inboxed.dev/errors/not-found",
  "title": "Resource not found",
  "detail": "No inbox with ID 'abc-123' exists in this project.",
  "status": 404
}
```

With `Content-Type: application/problem+json`.

For validation errors, add `errors` array:

```json
{
  "type": "https://docs.inboxed.dev/errors/validation-error",
  "title": "Validation failed",
  "detail": "One or more request parameters are invalid.",
  "status": 422,
  "errors": [
    { "field": "label", "message": "can't be blank" }
  ]
}
```

### 1.3 Create missing serializers

| Serializer | Currently | Action |
|------------|-----------|--------|
| `InboxSerializer` | Inline in `InboxesController#serialize_inbox` | Extract to `app/serializers/inbox_serializer.rb` |
| `AttachmentSerializer` | Inline in `AttachmentsController#serialize_attachment` | Extract to `app/serializers/attachment_serializer.rb` |

### 1.4 Migrate controllers to consistent format

Every controller action must use `render_collection` or `render_resource`:

| Controller | Current format | Target format |
|------------|---------------|---------------|
| `InboxesController#index` | `{ inboxes: [...], pagination: {...} }` | No change (already correct) |
| `InboxesController#show` | `{ inbox: {...} }` | No change |
| `EmailsController#index` | `{ emails: [...], pagination: {...} }` | No change |
| `EmailsController#show` | `{ email: {...} }` | No change |
| `SearchController#show` | `{ emails: [...], pagination: {...} }` | No change |
| `AttachmentsController#index` | `{ attachments: [...] }` | Add `pagination` |
| **EndpointsController#index** | `{ data: [...], meta: {...} }` | **`{ endpoints: [...], pagination: {...} }`** |
| **EndpointsController#show** | `{ data: {...} }` | **`{ endpoint: {...} }`** |
| **EndpointsController#create** | `{ data: {...} }` | **`{ endpoint: {...} }`** |
| **EndpointsController#update** | `{ data: {...} }` | **`{ endpoint: {...} }`** |
| **EndpointsController#purge** | `{ deleted_count: N }` | **`{ deleted_count: N }`** (keep — action result, not resource) |
| **RequestsController#index** | `{ data: [...], meta: {...} }` | **`{ requests: [...], pagination: {...} }`** |
| **RequestsController#show** | `{ data: {...} }` | **`{ request: {...} }`** |
| **WebhooksController#index** | `{ data: [...] }` | **`{ webhooks: [...], pagination: {...} }`** |
| **WebhooksController#show** | `{ data: {...} }` | **`{ webhook: {...} }`** |
| **DeliveriesController#index** | `{ data: [...], meta: {...} }` | **`{ deliveries: [...], pagination: {...} }`** |

### 1.5 Ensure `pagination` always has 3 fields

Every paginated response must include:

```json
{
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJ...",
    "total_count": 128
  }
}
```

Fix `DeliveriesController` which uses raw IDs instead of encoded cursors.

### 1.6 Files to modify

```
app/controllers/concerns/api_renderable.rb        # NEW
app/controllers/concerns/error_renderable.rb       # UPDATE — RFC 7807
app/serializers/inbox_serializer.rb                # NEW
app/serializers/attachment_serializer.rb            # NEW
app/controllers/api/v1/inboxes_controller.rb       # UPDATE — use ApiRenderable
app/controllers/api/v1/emails_controller.rb        # UPDATE — use ApiRenderable
app/controllers/api/v1/attachments_controller.rb   # UPDATE — use ApiRenderable
app/controllers/api/v1/endpoints_controller.rb     # UPDATE — resource-named keys
app/controllers/api/v1/endpoints/requests_controller.rb  # UPDATE — resource-named keys
app/controllers/api/v1/webhooks_controller.rb      # UPDATE — resource-named keys
app/controllers/api/v1/webhooks/deliveries_controller.rb # UPDATE — resource-named keys + encoded cursors
app/controllers/api/v1/search_controller.rb        # UPDATE — use ApiRenderable
```

### 1.7 Update RSpec tests

All controller specs that assert response shape must be updated to expect the new format. Grep for `response.parsed_body["data"]` and `response.parsed_body["meta"]` and change to resource-named keys.

---

## Phase 2: Update Dashboard (Svelte)

The dashboard calls the API through service files in `apps/dashboard/src/features/`.

### 2.1 Files to update

| Service file | Change |
|-------------|--------|
| `features/hooks/hooks.service.ts` | Change `data` → `endpoints`, `requests`; `meta` → `pagination` |
| `features/hooks/hooks.types.ts` | Update response types if needed |

The email/inbox services already use resource-named keys — no changes needed there.

### 2.2 Update Pagination type

Ensure the shared `Pagination` type matches:

```typescript
interface Pagination {
  has_more: boolean;
  next_cursor: string | null;
  total_count: number;
}
```

### 2.3 Update error handling

If the dashboard has error parsing logic, update it to handle RFC 7807 format:

```typescript
interface ApiProblem {
  type: string;
  title: string;
  detail: string;
  status: number;
  errors?: Array<{ field: string; message: string }>;
}
```

---

## Phase 3: Simplify MCP Server

### 3.1 Remove `normalizePaginated`

With a consistent API, the MCP no longer needs the normalization layer.

**File:** `apps/mcp/src/ports/inboxed-api.ts`

- Delete `normalizePaginated()` method
- Delete `requestPaginated()` method
- Update `PaginatedResponse<T>` type to match the API directly
- Change all paginated calls back to `request()` with proper response parsing

### 3.2 Update response type

```typescript
// The API now always returns: { "<resource>": [...], "pagination": {...} }
// Each method parses its own resource key:

async findInboxByAddress(address: string): Promise<Inbox | null> {
  const res = await this.request<{ inboxes: Inbox[], pagination: Pagination }>(
    `/api/v1/inboxes?address=${encodeURIComponent(address)}`
  );
  return res.inboxes.length > 0 ? res.inboxes[0] : null;
}

async listEmails(inboxId: string, limit: number = 10) {
  return this.request<{ emails: EmailSummary[], pagination: Pagination }>(
    `/api/v1/inboxes/${inboxId}/emails?limit=${limit}`
  );
}
```

### 3.3 Update tool response parsing

Tools that access `res.data` or `res.meta` must be updated to use the resource-named keys.

### 3.4 New MCP tools to consider

Based on ADR-021 (HTTP Catcher) and the existing MCP tool set, the MCP Engineer recommends:

| Tool | Status | Notes |
|------|--------|-------|
| `list_emails` | Exists | OK |
| `get_email` | Exists | OK |
| `wait_for_email` | Exists | OK |
| `extract_code` | Exists | OK |
| `extract_link` | Exists | OK |
| `extract_value` | Exists | OK |
| `search_emails` | Exists | OK |
| `delete_inbox` | Exists | OK |
| `create_endpoint` | Exists | OK — already supports webhook/form/heartbeat types |
| `wait_for_request` | Exists | OK |
| `get_latest_request` | Exists | OK |
| `extract_json_field` | Exists | OK |
| `list_requests` | Exists | OK |
| `check_heartbeat` | Exists | OK |
| `delete_endpoint` | Exists | OK |
| `list_endpoints` | **Missing** | Add — useful for agents to discover existing endpoints |
| `get_endpoint` | **Missing** | Add — get endpoint details by token |
| `extract_form_field` | **Missing** | Add — extract fields from form-encoded request bodies |
| `list_inboxes` | **Missing** | Add — useful for agents to discover existing inboxes |

> **MCP Engineer says:** "The current 15 tools cover the core flows well. `list_endpoints` and `list_inboxes` are the highest priority additions — an agent can't operate on resources it can't discover. `extract_form_field` is useful but can wait until forms are more mature."

### 3.5 Files to modify

```
apps/mcp/src/ports/inboxed-api.ts         # Simplify — remove normalization
apps/mcp/src/types/index.ts               # Update PaginatedResponse
apps/mcp/src/tools/list-emails.ts         # Update response parsing
apps/mcp/src/tools/list-requests.ts       # Update response parsing
apps/mcp/src/tools/search-emails.ts       # Update response parsing
apps/mcp/src/tools/list-endpoints.ts      # NEW
apps/mcp/src/tools/get-endpoint.ts        # NEW
apps/mcp/src/tools/list-inboxes.ts        # NEW
apps/mcp/src/server.ts                    # Register new tools
```

---

## Phase 4: OpenAPI Spec + Redocly

### 4.1 Scope

Document **only the public API v1** (authenticated with API key). Exclude:
- Admin endpoints (`/admin/*`)
- Auth endpoints (`/auth/*`)
- Setup endpoints (`/setup`)
- Public catch endpoint (`/hook/:token`) — this is for external services, not API consumers

### 4.2 Endpoints to document

**Health**
- `GET /api/v1/status` — Service health check

**Inboxes**
- `GET /api/v1/inboxes` — List inboxes (with optional `?address=` filter)
- `GET /api/v1/inboxes/:id` — Get inbox details
- `DELETE /api/v1/inboxes/:id` — Delete inbox and all emails

**Emails**
- `GET /api/v1/inboxes/:id/emails` — List emails in inbox (paginated)
- `GET /api/v1/emails/:id` — Get email detail (full body, headers)
- `GET /api/v1/emails/:id/raw` — Get raw MIME source (`text/plain`)
- `POST /api/v1/emails/wait` — Long-poll for new email arrival
- `DELETE /api/v1/emails/:id` — Delete email

**Attachments**
- `GET /api/v1/emails/:id/attachments` — List attachments
- `GET /api/v1/attachments/:id/download` — Download attachment binary

**Search**
- `GET /api/v1/search` — Full-text search across all emails

**Endpoints (HTTP Catcher)**
- `GET /api/v1/endpoints` — List endpoints (filterable by `?type=webhook|form|heartbeat`)
- `POST /api/v1/endpoints` — Create endpoint
- `GET /api/v1/endpoints/:token` — Get endpoint details
- `PATCH /api/v1/endpoints/:token` — Update endpoint
- `DELETE /api/v1/endpoints/:token` — Delete endpoint
- `DELETE /api/v1/endpoints/:token/purge` — Purge all captured requests

**Requests (HTTP Catcher)**
- `GET /api/v1/endpoints/:token/requests` — List captured requests (paginated)
- `GET /api/v1/endpoints/:token/requests/:id` — Get request detail
- `DELETE /api/v1/endpoints/:token/requests/:id` — Delete request
- `POST /api/v1/endpoints/:token/requests/wait` — Long-poll for new request

**Webhooks (Outbound)**
- `GET /api/v1/webhooks` — List webhook subscriptions
- `POST /api/v1/webhooks` — Create webhook subscription
- `GET /api/v1/webhooks/:id` — Get webhook details
- `PATCH /api/v1/webhooks/:id` — Update webhook
- `DELETE /api/v1/webhooks/:id` — Delete webhook
- `POST /api/v1/webhooks/:id/test` — Send test delivery
- `GET /api/v1/webhooks/:id/deliveries` — List delivery history (paginated)

### 4.3 Shared schemas

```yaml
# Reusable schemas for the OpenAPI spec
Inbox, EmailSummary, EmailDetail, Attachment,
HttpEndpoint, HttpRequest, HttpRequestSummary,
WebhookEndpoint, WebhookDelivery,
Pagination, ProblemDetail, ValidationProblemDetail
```

### 4.4 File structure

```
docs/
  api/
    openapi.yaml          # Main OpenAPI 3.1 spec
    paths/
      inboxes.yaml        # Inbox endpoints
      emails.yaml         # Email endpoints
      search.yaml         # Search endpoint
      endpoints.yaml      # HTTP Catcher endpoints
      requests.yaml       # HTTP Catcher requests
      webhooks.yaml       # Outbound webhooks
    schemas/
      inbox.yaml
      email.yaml
      endpoint.yaml
      request.yaml
      webhook.yaml
      pagination.yaml
      errors.yaml
  redocly.yaml            # Redocly configuration
```

### 4.5 Redocly configuration

```yaml
# docs/redocly.yaml
extends:
  - recommended

apis:
  main:
    root: api/openapi.yaml

theme:
  openapi:
    generateCodeSamples:
      languages:
        - lang: curl
        - lang: javascript
        - lang: python

rules:
  operation-operationId: error
  operation-summary: error
  no-path-trailing-slash: error
  tag-description: warn
```

### 4.6 CI integration

Add to `.github/workflows/ci.yml`:

```yaml
lint-api-spec:
  runs-on: ubuntu-latest
  if: contains(needs.detect-changes.outputs.changes, 'docs')
  steps:
    - uses: actions/checkout@v4
    - run: npx @redocly/cli lint docs/api/openapi.yaml --config docs/redocly.yaml
```

### 4.7 Generate static docs

Add to `.github/workflows/pages.yml` or a new workflow:

```yaml
- run: npx @redocly/cli build-docs docs/api/openapi.yaml -o docs/api/index.html --config docs/redocly.yaml
```

> **DX Engineer says:** "Publish on GitHub Pages at `docs.inboxed.dev` or embed in the dashboard at `/docs`. The spec file itself should live in the repo so PRs that change the API also update the docs in the same commit."

---

## Phase 5: GitHub Actions & Deployment Changes

### 5.1 Goal

- **Keep building** the MCP Docker image on every push to master (for users to pull via `ghcr.io`)
- **Keep the MCP container in the deploy config** but with `MCP_TRANSPORT=http` — this serves the remote HTTP transport for clients that can't run Docker (Chrome extension, future integrations)
- **Fix the `index-http.ts`** to add auth (passthrough API key) before exposing publicly

### 5.2 Changes to `docker.yml` (Build & Push)

**No changes needed.** This workflow already builds and pushes the image without deploying. It will continue to publish `ghcr.io/rodacato/inboxed-mcp:latest` on every push to master.

### 5.3 Changes to `deploy.yml` (Production Deployment)

**No removals.** Keep the MCP build and deploy steps. The only change is ensuring the MCP accessory uses HTTP transport:

- The `build-mcp` job stays as-is
- The `deploy` job keeps `needs: [build-api, build-dashboard, build-mcp]`
- The MCP deploy step stays as-is

### 5.4 Changes to `config/deploy.yml` (Kamal)

Update the MCP accessory to use HTTP transport:

```diff
   mcp:
     image: ghcr.io/<%= ... %>/inboxed-mcp
     host: <%= ENV["HOST_IP"] %>
     port: "3001:3001"
     env:
       clear:
         INBOXED_API_URL: https://<%= ENV.fetch("INBOXED_API_DOMAIN", "inboxed-api.example.com") %>
+        MCP_TRANSPORT: http
       secret:
         - INBOXED_MCP_KEY
```

### 5.5 Expose MCP via Cloudflare Tunnel

Add a tunnel route for `inboxed-mcp.notdefined.dev` → `localhost:3001`. This makes the MCP accessible at:

```
POST https://inboxed-mcp.notdefined.dev/mcp
Authorization: Bearer <user-api-key>
```

### 5.6 Ensure `docker.yml` builds multi-arch

The workflow already specifies `platforms: linux/amd64,linux/arm64` for the MCP build. Verify the current published image actually has both manifests (the earlier ARM failure suggests it might not):

```bash
docker manifest inspect ghcr.io/rodacato/inboxed-mcp:latest
```

If only amd64 exists, the next push to master after these changes will publish a proper multi-arch image (since the workflow already has the correct config).

---

## Execution Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
  API        Dashboard    MCP       OpenAPI     Deploy
```

Phases 1-3 must be done together (breaking change). Phase 4 can be done in parallel. Phase 5 is independent.

### Estimated scope

| Phase | Files changed | New files | Risk |
|-------|--------------|-----------|------|
| 1. API | ~12 controllers/concerns | 3 (concern + 2 serializers) | Medium — many test updates |
| 2. Dashboard | ~3 service/type files | 0 | Low |
| 3. MCP | ~10 tool/port/type files | 3 (new tools) | Low |
| 4. OpenAPI | 0 app files | ~15 YAML files | None — docs only |
| 5. Deploy | 2 workflow files + 1 Kamal config | 0 | Low — removing, not adding |

---

## Phase 6: MCP Remote HTTP Transport (Future-Ready)

### 6.1 Context

Today the MCP server has two entry points:

| Entry point | Transport | Use case |
|-------------|-----------|----------|
| `index.js` | stdio | Claude Code / Docker Desktop — client runs the container locally |
| `index-http.js` | Streamable HTTP | Remote access — client connects via URL over HTTPS |

The `index-http.ts` we already created exposes `POST /mcp` using the MCP SDK's `StreamableHTTPServerTransport`. This is the standard protocol for remote MCP servers.

### 6.2 What's missing for production-ready HTTP transport

**Authentication.** The current `index-http.ts` accepts any request without validation. For a public endpoint, we need:

```
Client → HTTPS → POST /mcp
         Header: Authorization: Bearer <user-api-key>
         Body: JSON-RPC request
```

The MCP server should validate the API key against the Inboxed API before processing the request. Two approaches:

**Option A: Passthrough auth (recommended)**
The MCP server already forwards the API key to the Inboxed API on every request. If the API key is invalid, the API returns 401 and the MCP returns an error. No additional auth logic needed in the MCP — the API is the auth boundary.

We just need to:
1. Read the `Authorization` header from the incoming HTTP request
2. Use that key instead of the env var `INBOXED_API_KEY`
3. Return 401 if no key is provided

**Option B: Shared secret**
Use a separate `MCP_AUTH_TOKEN` env var that the MCP validates before processing. Simpler but requires managing another secret.

> **Security Engineer says:** "Option A is better — one key, one auth boundary. The MCP should be a transparent proxy for auth, not its own identity provider."

### 6.3 Implementation changes to `index-http.ts`

```typescript
// Extract API key from request header instead of env var
const authHeader = req.headers["authorization"];
const apiKey = authHeader?.startsWith("Bearer ")
  ? authHeader.slice(7)
  : null;

if (!apiKey) {
  res.writeHead(401, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Missing Authorization header" }));
  return;
}

// Create a per-request API client with the user's key
const api = new InboxedApi(apiUrl, apiKey);
const server = createServer(api);
```

### 6.4 CORS headers

Remote MCP clients (browser-based) will need CORS:

```typescript
res.setHeader("Access-Control-Allow-Origin", "*");
res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
```

### 6.5 How clients will connect (when supported)

**Claude Code CLI** (already supports `url` in some versions):
```json
{
  "mcpServers": {
    "inboxed": {
      "url": "https://inboxed-mcp.notdefined.dev/mcp",
      "headers": {
        "Authorization": "Bearer <user-api-key>"
      }
    }
  }
}
```

**Claude Chrome extension** (when remote MCP is supported):
Same config — just a URL and auth header. No Docker, no local install.

**Any MCP-compatible client:**
Standard Streamable HTTP transport — `POST /mcp` with JSON-RPC body.

### 6.6 When to deploy this

Deploy alongside Phase 5 — the production MCP container will use HTTP transport. The code (`index-http.ts`) is already written and compiles. Add auth and CORS before exposing publicly.

### 6.7 Deployment model (when ready)

Two options:

**Option A: Re-enable the MCP accessory in production** with `MCP_TRANSPORT=http`
- Expose via Cloudflare Tunnel at `inboxed-mcp.notdefined.dev`
- Pros: Simple, reuses existing infra
- Cons: Single instance, no horizontal scaling

**Option B: Serverless / edge deployment**
- Deploy `index-http.ts` on Cloudflare Workers or Fly.io
- The MCP SDK supports `WebStandardStreamableHTTPServerTransport` for Workers
- Pros: Global, scales to zero, low latency
- Cons: More infrastructure to manage

> **DevOps Engineer says:** "Start with Option A. You already have the Kamal setup. When you need scale, move to Workers — the MCP SDK already has the adapter."

---

## Phase 7: Multi-Architecture Docker Image

### 7.1 Current state

The `docker.yml` workflow already specifies `platforms: linux/amd64,linux/arm64` for all three images. However, the currently published `ghcr.io/rodacato/inboxed-mcp:latest` only has an amd64 manifest — that's why it failed on Mac ARM with:

```
no matching manifest for linux/arm64/v8
```

### 7.2 Root cause

The `docker.yml` workflow triggers on pushes to `master`. The multi-arch config was added but either:
- No push to `master` happened after adding it
- Or the build was cached from a single-arch run

### 7.3 Fix

The next push to `master` that touches `apps/mcp/` will automatically trigger a multi-arch build. No code changes needed — the workflow is already correct.

To force a rebuild now:

```bash
# Trigger the workflow manually or push any change to master
git commit --allow-empty -m "chore: trigger multi-arch MCP build"
git push origin master
```

### 7.4 Verify after build

```bash
# Check the image has both architectures
docker manifest inspect ghcr.io/rodacato/inboxed-mcp:latest

# Should show two entries:
# - linux/amd64
# - linux/arm64
```

### 7.5 Update user config

Once the multi-arch image is published, Mac ARM users no longer need `--platform linux/amd64`:

```json
{
  "mcpServers": {
    "inboxed": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "INBOXED_API_URL=https://inboxed-api.notdefined.dev",
        "-e", "INBOXED_API_KEY=<key>",
        "ghcr.io/rodacato/inboxed-mcp"
      ]
    }
  }
}
```

No `--platform` flag needed — Docker picks the native arch automatically. This is faster and uses less CPU.

### 7.6 Dockerfile compatibility

The current Dockerfile uses `node:22-alpine` which has official multi-arch support (amd64 + arm64). No changes needed.

The `MCP_TRANSPORT` env var and dual entry point (`index.js` / `index-http.js`) work on both architectures.

---

## Updated Execution Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 5 → Phase 7
  API        Dashboard    MCP       Deploy     Multi-arch
                                      ↕
                                   Phase 4
                                    OpenAPI

Phase 6 (HTTP transport + auth) → With Phase 5
```

| Phase | Priority | Dependency |
|-------|----------|------------|
| 1. API standardization | **Critical** | None |
| 2. Dashboard update | **Critical** | Phase 1 |
| 3. MCP simplification | **Critical** | Phase 1 |
| 4. OpenAPI + Redocly | Medium | Phase 1 (for accurate docs) |
| 5. Deploy changes | Medium | Phase 6 (auth needed before exposing) |
| 6. HTTP transport + auth | **High** | Phase 3 (same MCP codebase) |
| 7. Multi-arch | **High** | Phase 5 (push triggers build) |

---

## Open Questions (Resolved)

- [x] **Purge endpoint format** — Keep `{ "deleted_count": N }` as-is (action result, not resource).
- [x] **OpenAPI contract tests** — Documentation-only for now. Contract tests added in `response_contract_spec.rb` (16 tests).
- [x] **Dockerfile transport** — Both entry points (`index.js` / `index-http.js`) with `MCP_TRANSPORT` env var.
- [x] **HTTP transport auth** — Passthrough: MCP reads client's `Authorization` header and forwards to API.
- [ ] **Remove `--platform linux/amd64`** from MCP config docs — pending multi-arch image verification after next push to master.
