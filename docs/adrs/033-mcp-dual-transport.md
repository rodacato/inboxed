# ADR-033: MCP Dual Transport (stdio + Streamable HTTP)

**Status:** accepted
**Date:** 2026-03-18
**Deciders:** Project owner

## Context

The MCP server currently only supports stdio transport — the client must execute the container locally and communicate via stdin/stdout. This works for Claude Code CLI and Docker Desktop but fails for:

- **Browser-based clients** (Chrome extension) that cannot run local processes
- **Users without Docker** who want to connect to a hosted MCP endpoint
- **Remote AI agents** that communicate over HTTP

The MCP SDK v1.27+ includes `StreamableHTTPServerTransport` for HTTP-based communication.

### Options Considered

**A: stdio only — users must run Docker locally**
- Pro: Simple. No auth needed (API key in env var).
- Con: Requires Docker. Excludes browser-based clients.

**B: HTTP only — deploy as a service, remove Docker distribution**
- Pro: Universal access. One endpoint for all clients.
- Con: Requires production hosting. Users lose offline/local capability.

**C: Dual transport — stdio for local, HTTP for remote**
- Pro: Both use cases covered. Same codebase, same tools.
- Con: Two entry points to maintain. HTTP needs auth.

## Decision

**Option C: Dual transport.** Two entry points in the same image:

| Entry point | Transport | Use case |
|-------------|-----------|----------|
| `index.js` | stdio | Docker Desktop, Claude Code CLI, local use |
| `index-http.js` | Streamable HTTP | Remote clients, Chrome extension, hosted MCP |

The Dockerfile uses `MCP_TRANSPORT` env var (default: `stdio`) to select the entry point.

### Authentication for HTTP transport

**Passthrough auth.** The HTTP endpoint reads the `Authorization: Bearer <key>` header from the incoming request and uses that key for all API calls. The Inboxed API is the auth boundary — the MCP server does not maintain its own identity provider.

```
Client → POST /mcp (Authorization: Bearer <user-key>)
  → MCP creates InboxedApi(apiUrl, userKey)
  → MCP calls API with user's key
  → API validates key, returns data
  → MCP returns result to client
```

If no key is provided, the MCP returns 401.

This means:
- Each user's API key scopes their access (same as with stdio)
- No shared secrets or MCP-specific keys needed for remote use
- The `INBOXED_MCP_KEY` env var is only used as a fallback for the deployed instance

### CORS

The HTTP endpoint includes CORS headers for browser-based clients:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

### Deployment model

The MCP container is deployed in production with `MCP_TRANSPORT=http`, exposed via Cloudflare Tunnel at `inboxed-mcp.notdefined.dev`. Users connect with:

```json
{ "url": "https://inboxed-mcp.notdefined.dev/mcp" }
```

The same image is published to `ghcr.io` for local Docker use (stdio mode).

## Consequences

### Easier

- Browser-based and remote clients can use the MCP without Docker
- One Docker image serves both use cases
- Auth is simple — passthrough to existing API key system

### Harder

- Two code paths to test (stdio + HTTP)
- HTTP endpoint is a public surface — needs rate limiting (future)
- Must handle per-request server lifecycle (create → connect → handle → close)

### Mitigations

- Both entry points use the same `createServer(api)` — tools and business logic are shared
- HTTP is stateless (no sessions) — each request creates a fresh server instance
- Rate limiting can be added at the Cloudflare level before adding application-level limits
